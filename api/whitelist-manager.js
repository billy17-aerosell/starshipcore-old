// Whitelist Management API
// Endpoints to add, remove, and manage VIP/whitelisted users

import fs from 'fs';
import path from 'path';

// Admin secret - must match the one in key-manager.js
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';

// Helper to read keys data
function getKeysData() {
  try {
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const data = fs.readFileSync(keysPath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return { 
      keys: {}, 
      whitelist: {},
      metadata: { 
        totalKeys: 0, 
        activeKeys: 0,
        totalWhitelisted: 0,
        lastUpdated: new Date().toISOString()
      } 
    };
  }
}

// Helper to save keys data
function saveKeysData(keysData) {
  try {
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const dataDir = path.dirname(keysPath);
    
    if (!fs.existsSync(dataDir)) {
      fs.mkdirSync(dataDir, { recursive: true });
    }
    
    keysData.metadata.lastUpdated = new Date().toISOString();
    fs.writeFileSync(keysPath, JSON.stringify(keysData, null, 2));
    return true;
  } catch (error) {
    console.error('Error saving keys:', error);
    return false;
  }
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
    const keysData = getKeysData();
    return res.status(200).json({
      whitelist: keysData.whitelist || {},
      metadata: {
        totalWhitelisted: keysData.metadata.totalWhitelisted || 0,
        lastUpdated: keysData.metadata.lastUpdated
      }
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
    
    const keysData = getKeysData();
    
    // Initialize whitelist if it doesn't exist
    if (!keysData.whitelist) {
      keysData.whitelist = {};
    }
    
    // Initialize metadata if it doesn't exist
    if (!keysData.metadata.totalWhitelisted) {
      keysData.metadata.totalWhitelisted = 0;
    }
    
    // Check if user already exists
    if (keysData.whitelist[userId]) {
      return res.status(409).json({ 
        error: 'User already exists',
        message: `User ${userId} is already whitelisted`
      });
    }
    
    // Add new whitelisted user
    keysData.whitelist[userId] = {
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
    
    keysData.metadata.totalWhitelisted++;
    
    saveKeysData(keysData);
    
    return res.status(201).json({ 
      success: true,
      message: `User ${username} (${userId}) has been whitelisted`,
      data: keysData.whitelist[userId]
    });
  }
  
  // UPDATE whitelisted user
  if (action === 'update' && req.method === 'PUT') {
    const { userId, ...updates } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.whitelist || !keysData.whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    // Update allowed fields
    const allowedUpdates = {
      username: updates.username,
      type: updates.type,
      status: updates.status,
      expiresAt: updates.expiresAt,
      notes: updates.notes
    };
    
    // Update restrictions if provided
    if (updates.maxDevices !== undefined) {
      keysData.whitelist[userId].restrictions.maxDevices = updates.maxDevices;
    }
    if (updates.ipTracking !== undefined) {
      keysData.whitelist[userId].restrictions.ipTracking = updates.ipTracking;
    }
    if (updates.webhookNotify !== undefined) {
      keysData.whitelist[userId].restrictions.webhookNotify = updates.webhookNotify;
    }
    
    // Update permissions if provided
    if (updates.bypassAll !== undefined) {
      keysData.whitelist[userId].permissions.bypassAll = updates.bypassAll;
    }
    if (updates.unlimitedAccess !== undefined) {
      keysData.whitelist[userId].permissions.unlimitedAccess = updates.unlimitedAccess;
    }
    if (updates.noLogging !== undefined) {
      keysData.whitelist[userId].permissions.noLogging = updates.noLogging;
    }
    
    // Apply allowed updates
    Object.keys(allowedUpdates).forEach(key => {
      if (allowedUpdates[key] !== undefined) {
        keysData.whitelist[userId][key] = allowedUpdates[key];
      }
    });
    
    keysData.whitelist[userId].updatedAt = new Date().toISOString();
    
    saveKeysData(keysData);
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been updated`,
      data: keysData.whitelist[userId]
    });
  }
  
  // REMOVE whitelisted user
  if (action === 'remove' && req.method === 'DELETE') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.whitelist || !keysData.whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    const username = keysData.whitelist[userId].username;
    delete keysData.whitelist[userId];
    keysData.metadata.totalWhitelisted--;
    
    saveKeysData(keysData);
    
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
    
    const keysData = getKeysData();
    
    if (!keysData.whitelist || !keysData.whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    return res.status(200).json({ 
      userId,
      ...keysData.whitelist[userId]
    });
  }
  
  // SUSPEND user (set status to suspended without removing)
  if (action === 'suspend' && req.method === 'POST') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.whitelist || !keysData.whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    keysData.whitelist[userId].status = 'suspended';
    keysData.whitelist[userId].suspendedAt = new Date().toISOString();
    
    saveKeysData(keysData);
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been suspended`,
      data: keysData.whitelist[userId]
    });
  }
  
  // REACTIVATE suspended user
  if (action === 'reactivate' && req.method === 'POST') {
    const { userId } = req.body;
    
    if (!userId) {
      return res.status(400).json({ error: 'userId is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.whitelist || !keysData.whitelist[userId]) {
      return res.status(404).json({ error: 'User not found in whitelist' });
    }
    
    keysData.whitelist[userId].status = 'active';
    keysData.whitelist[userId].reactivatedAt = new Date().toISOString();
    delete keysData.whitelist[userId].suspendedAt;
    
    saveKeysData(keysData);
    
    return res.status(200).json({ 
      success: true,
      message: `User ${userId} has been reactivated`,
      data: keysData.whitelist[userId]
    });
  }
  
  // Invalid action
  return res.status(400).json({ 
    error: 'Invalid action',
    availableActions: ['list', 'add', 'update', 'remove', 'info', 'suspend', 'reactivate']
  });
}
