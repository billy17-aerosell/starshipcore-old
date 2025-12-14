// Whitelist Management API - File-Based Version
// Simple, reliable, read from keys.json

import fs from 'fs';
import path from 'path';

const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';
const KEYS_FILE_PATH = path.join(process.cwd(), 'data', 'keys.json');

function getKeysData() {
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

export default async function handler(req, res) {
  const adminAuth = req.headers['x-admin-secret'];
  
  if (adminAuth !== ADMIN_SECRET) {
    return res.status(401).json({ 
      error: 'Unauthorized',
      message: 'Invalid admin credentials'
    });
  }
  
  const { action } = req.query;
  
  // LIST - Read from file (always works!)
  if (action === 'list' && req.method === 'GET') {
    const keysData = getKeysData();
    
    return res.status(200).json({
      whitelist: keysData.whitelist || {},
      metadata: keysData.metadata || {},
      mode: 'file-system',
      note: 'Read-only mode. Use test-add-vip.js script to add users.'
    });
  }
  
  // GET user info
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
  
  // WRITE operations - Not supported in serverless (file system is read-only)
  if (['add', 'update', 'remove', 'suspend', 'reactivate'].includes(action)) {
    return res.status(501).json({
      error: 'Write operations not supported',
      message: 'Vercel serverless functions have read-only file system.',
      solution: 'Use the test-add-vip.js script locally to add/edit users.',
      instructions: [
        '1. Edit test-add-vip.js with user details',
        '2. Run: node test-add-vip.js',
        '3. Commit: git add data/keys.json && git commit -m "Add VIP user"',
        '4. Push: git push origin main',
        '5. Vercel will auto-deploy with new user data'
      ]
    });
  }
  
  return res.status(400).json({ 
    error: 'Invalid action',
    availableActions: ['list', 'info']
  });
}
