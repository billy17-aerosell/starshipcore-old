// Key Management API
// Endpoints to create, revoke, and manage authentication keys

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';

// Admin secret - CHANGE THIS to your own secret!
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';

// Helper to read keys
function getKeysData() {
  try {
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const data = fs.readFileSync(keysPath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    return { keys: {}, metadata: { totalKeys: 0, activeKeys: 0 } };
  }
}

// Helper to save keys
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

// Generate random key
function generateKey(prefix = 'user') {
  const randomPart = crypto.randomBytes(4).toString('hex');
  return `${prefix}-${randomPart}`;
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
  
  // LIST all keys
  if (action === 'list' && req.method === 'GET') {
    const keysData = getKeysData();
    return res.status(200).json(keysData);
  }
  
  // CREATE new key
  if (action === 'create' && req.method === 'POST') {
    const { owner, type, expiresAt, maxDevices } = req.body;
    
    if (!owner) {
      return res.status(400).json({ error: 'Owner name is required' });
    }
    
    const keysData = getKeysData();
    const newKey = generateKey(type || 'user');
    
    keysData.keys[newKey] = {
      owner,
      type: type || 'standard',
      status: 'active',
      createdAt: new Date().toISOString(),
      expiresAt: expiresAt || null,
      totalRequests: 0,
      lastUsed: null,
      lastIP: null,
      maxDevices: maxDevices || 3,
      ipTracking: {},
      notes: ''
    };
    
    keysData.metadata.totalKeys++;
    keysData.metadata.activeKeys++;
    
    saveKeysData(keysData);
    
    return res.status(201).json({ 
      success: true,
      key: newKey,
      data: keysData.keys[newKey]
    });
  }
  
  // REVOKE a key
  if (action === 'revoke' && req.method === 'POST') {
    const { key } = req.body;
    
    if (!key) {
      return res.status(400).json({ error: 'Key is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.keys[key]) {
      return res.status(404).json({ error: 'Key not found' });
    }
    
    if (keysData.keys[key].status === 'active') {
      keysData.metadata.activeKeys--;
    }
    
    keysData.keys[key].status = 'revoked';
    keysData.keys[key].revokedAt = new Date().toISOString();
    
    saveKeysData(keysData);
    
    return res.status(200).json({ 
      success: true,
      message: `Key ${key} has been revoked`
    });
  }
  
  // DELETE a key
  if (action === 'delete' && req.method === 'DELETE') {
    const { key } = req.body;
    
    if (!key) {
      return res.status(400).json({ error: 'Key is required' });
    }
    
    const keysData = getKeysData();
    
    if (!keysData.keys[key]) {
      return res.status(404).json({ error: 'Key not found' });
    }
    
    if (keysData.keys[key].status === 'active') {
      keysData.metadata.activeKeys--;
    }
    
    delete keysData.keys[key];
    keysData.metadata.totalKeys--;
    
    saveKeysData(keysData);
    
    return res.status(200).json({ 
      success: true,
      message: `Key ${key} has been deleted`
    });
  }
  
  // GET stats for a specific key
  if (action === 'stats' && req.method === 'GET') {
    const { key } = req.query;
    
    if (!key) {
      return res.status(400).json({ error: 'Key parameter is required' });
    }
    
    const keysData = getKeysData();
    const keyData = keysData.keys[key];
    
    if (!keyData) {
      return res.status(404).json({ error: 'Key not found' });
    }
    
    return res.status(200).json({ 
      key,
      ...keyData
    });
  }
  
  // Invalid action
  return res.status(400).json({ 
    error: 'Invalid action',
    availableActions: ['list', 'create', 'revoke', 'delete', 'stats']
  });
}
