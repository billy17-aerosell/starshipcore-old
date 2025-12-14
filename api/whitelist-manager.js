// Whitelist Management API - Redis/KV Version
// Endpoints to add, remove, and manage VIP/whitelisted users
// Now using Upstash Redis for persistent storage!

import redis from '../lib/redis.js';

// Admin secret - must match the one in key-manager.js
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';

// Owner user ID - hardcoded bypass (0 commands used!)
const OWNER_USER_ID = '9268011358';

// Redis keys
const WHITELIST_KEY = 'starship:whitelist';
const METADATA_KEY = 'starship:metadata';

// In-memory cache to reduce Redis commands
let cache = {
  whitelist: null,
  metadata: null,
  timestamp: null,
  ttl: 2 * 60 * 1000 // 2 minutes cache
};

// Helper to get whitelist with caching
async function getWhitelist(useCache = true) {
  if (useCache && cache.whitelist && cache.timestamp && (Date.now() - cache.timestamp < cache.ttl)) {
    return cache.whitelist;
  }
  
  const whitelist = await redis.hgetall(WHITELIST_KEY) || {};
  
  // Parse JSON strings back to objects
  const parsed = {};
  for (const [userId, data] of Object.entries(whitelist)) {
    parsed[userId] = typeof data === 'string' ? JSON.parse(data) : data;
  }
  
  cache.whitelist = parsed;
  cache.timestamp = Date.now();
  
  return parsed;
}

// Helper to get metadata
async function getMetadata() {
  if (cache.metadata && cache.timestamp && (Date.now() - cache.timestamp < cache.ttl)) {
    return cache.metadata;
  }
  
  const metadata = await redis.get(METADATA_KEY);
  const parsed = metadata ? (typeof metadata === 'string' ? JSON.parse(metadata) : metadata) : {
    totalWhitelisted: 0,
   lastUpdated: new Date().toISOString()
  };
  
  cache.metadata = parsed;
  return parsed;
}

// Helper to save metadata
async function saveMetadata(metadata) {
  cache.metadata = metadata;
  metadata.lastUpdated = new Date().toISOString();
  await redis.set(METADATA_KEY, JSON.stringify(metadata));
}

// Clear cache
function clearCache() {
  cache.whitelist = null;
  cache.metadata = null;
  cache.timestamp = null;
}

export default async function handler(req, res) {
  // Check admin authentication
  const adminAuth = req.headers['x-admin-secret'];
  
  if (adminAuth !== ADMIN_SECRET) {
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid admin credentials'
    });
  }
  
  const { action } = req.query;
  
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
