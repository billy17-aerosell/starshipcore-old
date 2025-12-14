// Simple Key Authentication API (Read-Only Version)
// This version doesn't write to filesystem (Vercel compatible)

import fs from 'fs';
import path from 'path';

// Helper function to get client IP
function getClientIP(req) {
  return req.headers['x-forwarded-for']?.split(',')[0] || 
         req.headers['x-real-ip'] || 
         req.connection?.remoteAddress || 
         'unknown';
}

// Helper function to read keys database
function getKeysData() {
  try {
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const data = fs.readFileSync(keysPath, 'utf8');
    return JSON.parse(data);
  } catch (error) {
    console.error('Error reading keys:', error);
    return { keys: {} };
  }
}

export default async function handler(req, res) {
  // Only allow GET requests
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  // Get key from query parameter
  const { key } = req.query;
  
  // Get client information
  const clientIP = getClientIP(req);
  const timestamp = new Date().toISOString();
  
  // Check if key is provided
  if (!key) {
    return res.status(400).send(
      `-- ERROR: No authentication key provided\n` +
      `-- Usage: https://www.starship-core.my.id/api/get-loader?key=YOUR_KEY\n` +
      `error("Authentication key required")`
    );
  }
  
  // Get keys database
  const keysData = getKeysData();
  const keyData = keysData.keys[key];
  
  // Check if key exists
  if (!keyData) {
    console.log(`[${timestamp}] Invalid key attempt: ${key} from IP: ${clientIP}`);
    return res.status(403).send(
      `-- ERROR: Invalid authentication key\n` +
      `-- Key: ${key}\n` +
      `-- Contact administrator for access\n` +
      `error("Invalid authentication key")`
    );
  }
  
  // Check if key is active
  if (keyData.status !== 'active') {
    console.log(`[${timestamp}] Inactive key used: ${key} (${keyData.status}) from IP: ${clientIP}`);
    return res.status(403).send(
      `-- ERROR: Key is ${keyData.status}\n` +
      `-- Owner: ${keyData.owner}\n` +
      `-- Contact administrator\n` +
      `error("Key is ${keyData.status}")`
    );
  }
  
  // Check expiration (if set)
  if (keyData.expiresAt) {
    const expiryDate = new Date(keyData.expiresAt);
    if (expiryDate < new Date()) {
      console.log(`[${timestamp}] Expired key used: ${key} from IP: ${clientIP}`);
      return res.status(403).send(
        `-- ERROR: Key expired\n` +
        `-- Expired on: ${expiryDate.toDateString()}\n` +
        `-- Contact administrator for renewal\n` +
        `error("Key expired")`
      );
    }
  }
  
  // Log successful access to console
  console.log(`[${timestamp}] ✅ Valid access - Key: ${key} | Owner: ${keyData.owner} | IP: ${clientIP}`);
  
  // Read and return the obfuscated loader script
  try {
    const loaderPath = path.join(process.cwd(), 'protected', 'loader.lua');
    
    // Check if file exists
    if (!fs.existsSync(loaderPath)) {
      console.error(`Loader script not found at: ${loaderPath}`);
      return res.status(500).send(
        `-- ERROR: Loader script not found\n` +
        `-- Path: ${loaderPath}\n` +
        `error("Internal server error: Script not found")`
      );
    }
    
    const loaderScript = fs.readFileSync(loaderPath, 'utf8');
    
    // Validate script content
    if (!loaderScript || loaderScript.length < 100) {
      console.error(`Loader script is empty or too short`);
      return res.status(500).send(
        `-- ERROR: Invalid loader script\n` +
        `error("Internal server error: Invalid script")`
      );
    }
    
    // Set appropriate headers
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    res.setHeader('X-Key-Owner', keyData.owner);
    res.setHeader('X-Key-Type', keyData.type);
    
    return res.status(200).send(loaderScript);
    
  } catch (error) {
    console.error('Error reading loader script:', error);
    return res.status(500).send(
      `-- ERROR: Failed to load script\n` +
      `-- Error: ${error.message}\n` +
      `error("Internal server error")`
    );
  }
}
