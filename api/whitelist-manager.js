// Whitelist Management API - Redis Version with File Fallback
// Full CRUD operations with Redis persistence

import fs from 'fs';
import path from 'path';

// Try to initialize Redis
let redis = null;
let useRedis = false;

async function initRedis() {
  if (redis !== null) return useRedis;
  
  try {
    const redisModule = await import('../lib/redis.js');
    redis = redisModule.default;
    
    // Test connection with a simple ping
    await redis.ping();
    useRedis = true;
    console.log('✅ Redis initialized successfully');
  } catch (error) {
    console.error('⚠️ Redis init failed:', error.message);
    redis = null;
   useRedis = false;
  }
  
  return useRedis;
}

const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';
const WHITELIST_KEY = 'starship:whitelist';
const METADATA_KEY = 'starship:metadata';
const KEYS_FILE_PATH = path.join(process.cwd(), 'data', 'keys.json');

// === REDIS FUNCTIONS ===
async function getWhitelistFromRedis() {
  const data = await redis.hgetall(WHITELIST_KEY);
  const parsed = {};
  for (const [userId, jsonData] of Object.entries(data || {})) {
    parsed[userId] = JSON.parse(jsonData);
  }
  return parsed;
}

async function getMetadataFromRedis() {
  const data = await redis.get(METADATA_KEY);
  return data ? JSON.parse(data) : { totalWhitelisted: 0, lastUpdated: new Date().toISOString() };
}

async function saveUserToRedis(userId, userData) {
  await redis.hset(WHITELIST_KEY, userId, JSON.stringify(userData));
}

async function removeUserFromRedis(userId) {
  await redis.hdel(WHITELIST_KEY, userId);
}

async function saveMetadataToRedis(metadata) {
  metadata.lastUpdated = new Date().toISOString();
  await redis.set(METADATA_KEY, JSON.stringify(metadata));
}

// === FILE FUNCTIONS (Fallback) ===
function getKeysDataFromFile() {
  try {
    const data = fs.readFileSync(KEYS_FILE_PATH, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return { keys: {}, whitelist: {}, metadata: { totalWhitelisted: 0, lastUpdated: new Date().toISOString() } };
  }
}

// === MAIN HANDLER ===
export default async function handler(req, res) {
  // Initialize Redis
  const redisReady = await initRedis();
  
  // Check admin auth
  const adminAuth = req.headers['x-admin-secret'];
  if (adminAuth !== ADMIN_SECRET) {
    return res.status(401).json({ error: 'Unauthorized', message: 'Invalid admin credentials' });
  }
  
  const { action } = req.query;
  res.setHeader('X-Storage-Backend', redisReady ? 'Redis' : 'FileSystem');
  
  // ==== LIST ====
  if (action === 'list' && req.method === 'GET') {
    try {
      let whitelist, metadata;
      
      if (redisReady) {
        whitelist = await getWhitelistFromRedis();
        metadata = await getMetadataFromRedis();
      } else {
        const fileData = getKeysDataFromFile();
        whitelist = fileData.whitelist || {};
        metadata = fileData.metadata || {};
      }
      
      return res.status(200).json({ whitelist, metadata });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to list users', message: error.message });
    }
  }
  
  // ==== GET INFO ====
  if (action === 'info' && req.method === 'GET') {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    
    try {
      let whitelist;
      if (redisReady) {
        whitelist = await getWhitelistFromRedis();
      } else {
        whitelist = getKeysDataFromFile().whitelist || {};
      }
      
      if (!whitelist[userId]) {
        return res.status(404).json({ error: 'User not found' });
      }
      
      return res.status(200).json({ userId, ...whitelist[userId] });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to get user info', message: error.message });
    }
  }
  
  // For write operations, Redis is REQUIRED
  if (!redisReady && ['add', 'update', 'remove', 'suspend', 'reactivate'].includes(action)) {
    return res.status(503).json({
      error: 'Redis not available',
      message: 'Write operations require Redis connection',
      debug: 'Check REDIS_URL environment variable and Redis server status'
    });
  }
  
  // ==== ADD ====
  if (action === 'add' && req.method === 'POST') {
    const { userId, username, type = 'vip', expiresAt = null, maxDevices = 5, notes = '' } = req.body;
    
    if (!userId || !username) {
      return res.status(400).json({ error: 'userId and username required' });
    }
    
    try {
      const whitelist = await getWhitelistFromRedis();
      
      if (whitelist[userId]) {
        return res.status(409).json({ error: 'User already exists' });
      }
      
      const newUser = {
        userId, username, type,
        status: 'active',
        addedAt: new Date().toISOString(),
        expiresAt,
        restrictions: { maxDevices, ipTracking: true, webhookNotify: true },
        permissions: { bypassAll: false, unlimitedAccess: false, noLogging: false },
        notes
      };
      
      await saveUserToRedis(userId, newUser);
      
      const metadata = await getMetadataFromRedis();
      metadata.totalWhitelisted++;
      await saveMetadataToRedis(metadata);
      
      return res.status(201).json({ success: true, message: `User ${username} added`, data: newUser });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to add user', message: error.message });
    }
  }
  
  // ==== UPDATE ====
  if (action === 'update' && req.method === 'PUT') {
    const { userId, ...updates } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    
    try {
      const whitelist = await getWhitelistFromRedis();
      if (!whitelist[userId]) return res.status(404).json({ error: 'User not found' });
      
      const user = whitelist[userId];
      if (updates.username) user.username = updates.username;
      if (updates.type) user.type = updates.type;
      if (updates.status) user.status = updates.status;
      if (updates.expiresAt !== undefined) user.expiresAt = updates.expiresAt;
      if (updates.notes !== undefined) user.notes = updates.notes;
      if (updates.maxDevices !== undefined) user.restrictions.maxDevices = updates.maxDevices;
      user.updatedAt = new Date().toISOString();
      
      await saveUserToRedis(userId, user);
      
      return res.status(200).json({ success: true, message: `User ${userId} updated`, data: user });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to update user', message: error.message });
    }
  }
  
  // ==== REMOVE ====
  if (action === 'remove' && req.method === 'DELETE') {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    
    try {
      const whitelist = await getWhitelistFromRedis();
      if (!whitelist[userId]) return res.status(404).json({ error: 'User not found' });
      
      const username = whitelist[userId].username;
      await removeUserFromRedis(userId);
      
      const metadata = await getMetadataFromRedis();
      metadata.totalWhitelisted--;
      await saveMetadataToRedis(metadata);
      
      return res.status(200).json({ success: true, message: `User ${username} removed` });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to remove user', message: error.message });
    }
  }
  
  // ==== SUSPEND ====
  if (action === 'suspend' && req.method === 'POST') {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    
    try {
      const whitelist = await getWhitelistFromRedis();
      if (!whitelist[userId]) return res.status(404).json({ error: 'User not found' });
      
      whitelist[userId].status = 'suspended';
      whitelist[userId].suspendedAt = new Date().toISOString();
      await saveUserToRedis(userId, whitelist[userId]);
      
      return res.status(200).json({ success: true, message: `User ${userId} suspended`, data: whitelist[userId] });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to suspend user', message: error.message });
    }
  }
  
  // ==== REACTIVATE ====
  if (action === 'reactivate' && req.method === 'POST') {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: 'userId required' });
    
    try {
      const whitelist = await getWhitelistFromRedis();
      if (!whitelist[userId]) return res.status(404).json({ error: 'User not found' });
      
      whitelist[userId].status = 'active';
      whitelist[userId].reactivatedAt = new Date().toISOString();
      delete whitelist[userId].suspendedAt;
      await saveUserToRedis(userId, whitelist[userId]);
      
      return res.status(200).json({ success: true, message: `User ${userId} reactivated`, data: whitelist[userId] });
    } catch (error) {
      return res.status(500).json({ error: 'Failed to reactivate user', message: error.message });
    }
  }
  
  return res.status(400).json({ 
    error: 'Invalid action',
    availableActions: ['list', 'add', 'update', 'remove', 'info', 'suspend', 'reactivate']
  });
}
