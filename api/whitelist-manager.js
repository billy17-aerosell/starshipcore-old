// Whitelist Management API - Redis/KV Version with File Fallback
// Endpoints to add, remove, and manage VIP/whitelisted users
// Now using Upstash Redis for persistent storage with fallback to keys.json!

import fs from 'fs';
import path from 'path';

// Lazy load redis
let redis = null;
let redisInitialized = false;
let useRedis = false;

async function initRedis() {
  if (redisInitialized) return;
  
  try {
    const redisModule = await import('../lib/redis.js');
    redis = redisModule.default;
    // Test connection
    await redis.ping();
    useRedis = true;
  } catch (error) {
    console.warn('Redis not available, using file system fallback:', error.message);
    useRedis = false;
  }
  
  redisInitialized = true;
}

// Admin secret - must match the one in key-manager.js
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';

// Owner user ID - hardcoded bypass (0 commands used!)
const OWNER_USER_ID = '9268011358';

// Redis keys
const WHITELIST_KEY = 'starship:whitelist';
const METADATA_KEY = 'starship:metadata';

// File paths for fallback
const KEYS_FILE_PATH = path.join(process.cwd(), 'data', 'keys.json');

// In-memory cache to reduce Redis commands
let cache = {
  whitelist: null,
  metadata: null,
  timestamp: null,
  ttl: 2 * 60 * 1000 // 2 minutes cache
};

// FILE SYSTEM FALLBACK FUNCTIONS
function getKeysDataFromFile() {
  try {
    const data = fs.readFileSync(KEYS_FILE_PATH, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return { 
      keys: {}, 
      whitelist: {},
      metadata: { totalWhitelisted: 0, lastUpdated: new Date().toISOString() }
    };
  }
}

function saveKeysDataToFile(keysData) {
  try {
    const dataDir = path.dirname(KEYS_FILE_PATH);
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    keysData.metadata.lastUpdated = new Date().toISOString();
    fs.writeFileSync(KEYS_FILE_PATH, JSON.stringify(keysData, null, 2));
    return true;
  } catch (error) {
    console.error('Error saving keys:', error);
    return false;
  }
}

// Helper to get whitelist with caching
async function getWhitelist(useCache = true) {
  if (useCache && cache.whitelist && cache.timestamp && (Date.now() - cache.timestamp < cache.ttl)) {
    return cache.whitelist;
  }
  
  let whitelist = {};
  
  if (useRedis && redis) {
    try {
      whitelist = await redis.hgetall(WHITELIST_KEY) || {};
      
      // Parse JSON strings back to objects
      const parsed = {};
      for (const [userId, data] of Object.entries(whitelist)) {
        parsed[userId] = typeof data === 'string' ? JSON.parse(data) : data;
      }
      whitelist = parsed;
    } catch (error) {
      console.error('Redis error, falling back to file:', error);
      const fileData = getKeysDataFromFile();
      whitelist = fileData.whitelist || {};
    }
  } else {
    const fileData = getKeysDataFromFile();
    whitelist = fileData.whitelist || {};
  }
  
  cache.whitelist = whitelist;
  cache.timestamp = Date.now();
  
  return whitelist;
}

// Helper to get metadata
async function getMetadata() {
  if (cache.metadata && cache.timestamp && (Date.now() - cache.timestamp < cache.ttl)) {
    return cache.metadata;
  }
  
  let metadata = { totalWhitelisted: 0, lastUpdated: new Date().toISOString() };
  
  if (useRedis && redis) {
    try {
      const redisMetadata = await redis.get(METADATA_KEY);
      metadata = redisMetadata ? (typeof redisMetadata === 'string' ? JSON.parse(redisMetadata) : redisMetadata) : metadata;
    } catch (error) {
      console.error('Redis error, falling back to file:', error);
      const fileData = getKeysDataFromFile();
      metadata = fileData.metadata || metadata;
    }
  } else {
    const fileData = getKeysDataFromFile();
    metadata = fileData.metadata || metadata;
  }
  
  cache.metadata = metadata;
  return metadata;
}

// Helper to save metadata
async function saveMetadata(metadata) {
  cache.metadata = metadata;
  metadata.lastUpdated = new Date().toISOString();
  
  if (useRedis && redis) {
    try {
      await redis.set(METADATA_KEY, JSON.stringify(metadata));
    } catch (error) {
      console.error('Redis error, cannot save metadata:', error);
      // Fallback: cannot save to file in serverless (read-only)
    }
  }
  // Note: File system is read-only in Vercel, so we can't write
}

// Clear cache
function clearCache() {
  cache.whitelist = null;
  cache.metadata = null;
  cache.timestamp = null;
}

export default async function handler(req, res) {
  // Initialize Redis (lazy load)
  await initRedis();
  
  // Check admin authentication
  const adminAuth = req.headers['x-admin-secret'];
  
  if (adminAuth !== ADMIN_SECRET) {
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid admin credentials'
    });
  }
  
  const { action } = req.query;
  
  // Show system status in response headers
  res.setHeader('X-Storage-Backend', useRedis ? 'Redis' : 'FileSystem');
  
  // If using file system, warn that writes won't persist
  if (!useRedis && ['add', 'update', 'remove', 'suspend', 'reactivate'].includes(action)) {
    return res.status(503).json({
      error: 'Storage not ready',
      message: 'Redis database is not connected yet. Please connect database in Vercel dashboard.',
      instructions: 'Go to Vercel Dashboard → Storage → Connect Redis database to your project',
      readOnlyMode: true
    });
  }
  
  
  // LIST all whitelisted users
  if (action === 'list' && req.method === 'GET') {
    const whitelist = await getWhitelist();
    const metadata = await getMetadata();
    
    return res.status(200).json({
      whitelist,
      metadata
    });
  }
  
  // ADD new whitelisted user
  if (action === 'add' && req.method === 'POST') {
    const { 
      userId, 
      username, 
      type = 'vip',
      expiresAt = null,
      maxDevices = 5,
      ipTracking = true,
      webhookNotify = true,
      bypassAll = false,
      unlimitedAccess = false,
      noLogging = false,
      notes = ''
    } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    if (!username) {
      return res.status(400).json({ error: 'username is required' });
    }
    
    // Check if user already exists
    const whitelist = await getWhitelist(false); // Force fresh data
    
    if (whitelist[userId]) {
      return res.status(409).json({ 
        error: 'User already exists',
        message: `User ${userId} is already whitelisted`
      });
    }
    
    // Create new user object
    const newUser = {
      userId,
      username,
      type,
      status: 'active',
      addedAt: new Date().toISOString(),
      expiresAt,
      restrictions: {
        maxDevices,
        ipTracking,
        webhookNotify
      },
      permissions: {
        bypassAll,
        unlimitedAccess,
        noLogging
      },
      notes
    };
    
    // Save to Redis
    await redis.hset(WHITELIST_KEY, userId, JSON.stringify(newUser));
    
    // Update metadata
    const metadata = await getMetadata();
    metadata.totalWhitelisted++;
    await saveMetadata(metadata);
    
    // Clear cache
    clearCache();
    
    return res.status(201).json({ 
      success: true,
      message: `User ${username} (${userId}) has been whitelisted`,
      data: newUser
    });
  }
  
  // UPDATE whitelisted user
  if (action === 'update' && req.method === 'PUT') {
    const { userId, ...updates } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const whitelist = await getWhitelist(false);
    
    if (!whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    const user = whitelist[userId];
    
    // Update allowed fields
    if (updates.username !== undefined) user.username = updates.username;
    if (updates.type !== undefined) user.type = updates.type;
    if (updates.status !== undefined) user.status = updates.status;
    if (updates.expiresAt !== undefined) user.expiresAt = updates.expiresAt;
    if (updates.notes !== undefined) user.notes = updates.notes;
    
    // Update restrictions
    if (updates.maxDevices !== undefined) user.restrictions.maxDevices = updates.maxDevices;
    if (updates.ipTracking !== undefined) user.restrictions.ipTracking = updates.ipTracking;
    if (updates.webhookNotify !== undefined) user.restrictions.webhookNotify = updates.webhookNotify;
    
    // Update permissions
    if (updates.bypassAll !== undefined) user.permissions.bypassAll = updates.bypassAll;
    if (updates.unlimitedAccess !== undefined) user.permissions.unlimitedAccess = updates.unlimitedAccess;
    if (updates.noLogging !== undefined) user.permissions.noLogging = updates.noLogging;
    
    user.updatedAt = new Date().toISOString();
    
    // Save to Redis
    await redis.hset(WHITELIST_KEY, userId, JSON.stringify(user));
    
    // Clear cache
    clearCache();
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been updated`,
      data: user
    });
  }
  
  // REMOVE whitelisted user
  if (action === 'remove' && req.method === 'DELETE') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const whitelist = await getWhitelist(false);
    
    if (!whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    const username = whitelist[userId].username;
    
    // Remove from Redis
    await redis.hdel(WHITELIST_KEY, userId);
    
    // Update metadata
    const metadata = await getMetadata();
    metadata.totalWhitelisted--;
    await saveMetadata(metadata);
    
    // Clear cache
    clearCache();
    
    return res.status(200).json({ 
      success: true,
      message: `User ${username} (${userId}) has been removed from whitelist`
    });
  }
  
  // GET info for a specific user
  if (action === 'info' && req.method === 'GET') {
    const { userId } = req.query;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId parameter is required' });
    }
    
    const whitelist = await getWhitelist();
    
    if (!whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    return res.status(200).json({ 
      userId,
      ...whitelist[userId]
    });
  }
  
  // SUSPEND user
  if (action === 'suspend' && req.method === 'POST') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const whitelist = await getWhitelist(false);
    
    if (!whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    const user = whitelist[userId];
    user.status = 'suspended';
    user.suspendedAt = new Date().toISOString();
    
    await redis.hset(WHITELIST_KEY, userId, JSON.stringify(user));
    clearCache();
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been suspended`,
      data: user
    });
  }
  
  // REACTIVATE suspended user
  if (action === 'reactivate' && req.method === 'POST') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const whitelist = await getWhitelist(false);
    
    if (!whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    const user = whitelist[userId];
    user.status = 'active';
    user.reactivatedAt = new Date().toISOString();
    delete user.suspendedAt;
    
    await redis.hset(WHITELIST_KEY, userId, JSON.stringify(user));
    clearCache();
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been reactivated`,
      data: user
    });
  }
  
  // Invalid action
  return res.status(400).json({ 
    error: 'Invalid action',
    availableActions: ['list', 'add', 'update', 'remove', 'info', 'suspend', 'reactivate']
  });
}
