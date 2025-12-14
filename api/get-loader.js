// Smart Key Authentication API
// This endpoint validates keys and returns the obfuscated loader script

import fs from 'fs';
import path from 'path';

// Helper function to get client IP
function getClientIP(req) {
  return req.headers['x-forwarded-for']?.split(',')[0] || 
         req.headers['x-real-ip'] || 
         req.connection?.remoteAddress || 
         'unknown';
}

// Helper function to get current date (YYYY-MM-DD)
function getCurrentDate() {
  return new Date().toISOString().split('T')[0];
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

// Helper function to update key data
function updateKeyData(keyId, updates) {
  try {
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const keysData = getKeysData();
    
    if (keysData.keys[keyId]) {
      keysData.keys[keyId] = {
        ...keysData.keys[keyId],
        ...updates
      };
      fs.writeFileSync(keysPath, JSON.stringify(keysData, null, 2));
      return true;
    }
    return false;
  } catch (error) {
    console.error('Error updating key:', error);
    return false;
  }
}

// Helper function to log access
function logAccess(logEntry) {
  try {
    const logsDir = path.join(process.cwd(), 'data', 'logs');
    if (!fs.existsSync(logsDir)) {
      fs.mkdirSync(logsDir, { recursive: true });
    }
    
    const today = getCurrentDate();
    const logFile = path.join(logsDir, `${today}.json`);
    
    let logs = [];
    if (fs.existsSync(logFile)) {
      logs = JSON.parse(fs.readFileSync(logFile, 'utf8'));
    }
    
    logs.push(logEntry);
    fs.writeFileSync(logFile, JSON.stringify(logs, null, 2));
  } catch (error) {
    console.error('Error logging access:', error);
  }
}

// Smart validation: Check if IP usage is suspicious
function validateIPUsage(keyData, currentIP) {
  const today = getCurrentDate();
  
  // Initialize tracking if not exists
  if (!keyData.ipTracking) {
    keyData.ipTracking = {};
  }
  
  if (!keyData.ipTracking[today]) {
    keyData.ipTracking[today] = [];
  }
  
  const ipsToday = keyData.ipTracking[today];
  
  // Add current IP if not already in today's list
  if (!ipsToday.includes(currentIP)) {
    ipsToday.push(currentIP);
  }
  
  // SMART RULES:
  const uniqueIPsToday = ipsToday.length;
  
  // Rule 1: Max 3 different IPs per day (OK)
  if (uniqueIPsToday <= 3) {
    return { valid: true, warning: false, message: 'OK' };
  }
  
  // Rule 2: 4-5 IPs = Warning but still allow
  if (uniqueIPsToday <= 5) {
    return { 
      valid: true, 
      warning: true, 
      message: `Warning: ${uniqueIPsToday} different IPs detected today` 
    };
  }
  
  // Rule 3: More than 5 IPs = Suspicious, block
  return { 
    valid: false, 
    warning: true, 
    message: `Too many devices (${uniqueIPsToday} IPs). Possible key sharing detected.` 
  };
}

export default async function handler(req, res) {
  const startTime = Date.now();
  
  // Only allow GET requests
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  // Get key from query parameter
  const { key } = req.query;
  
  // Get client information
  const clientIP = getClientIP(req);
  const timestamp = new Date().toISOString();
  const userAgent = req.headers['user-agent'] || 'unknown';
  
  // Check if key is provided
  if (!key) {
    const logEntry = {
      timestamp,
      ip: clientIP,
      key: null,
      status: 'failed',
      reason: 'No key provided',
      userAgent
    };
    logAccess(logEntry);
    
    return res.status(400).json({ 
      error: 'Authentication key required',
      message: 'Please provide a valid key in the URL: ?key=YOUR_KEY'
    });
  }
  
  // Get keys database
  const keysData = getKeysData();
  const keyData = keysData.keys[key];
  
  // Check if key exists
  if (!keyData) {
    const logEntry = {
      timestamp,
      ip: clientIP,
      key,
      status: 'failed',
      reason: 'Invalid key',
      userAgent
    };
    logAccess(logEntry);
    
    return res.status(403).json({ 
      error: 'Invalid authentication key',
      message: 'The provided key is not valid. Please contact administrator.'
    });
  }
  
  // Check if key is active
  if (keyData.status !== 'active') {
    const logEntry = {
      timestamp,
      ip: clientIP,
      key,
      owner: keyData.owner,
      status: 'failed',
      reason: `Key is ${keyData.status}`,
      userAgent
    };
    logAccess(logEntry);
    
    return res.status(403).json({ 
      error: 'Key is inactive',
      message: `This key has been ${keyData.status}. Please contact administrator.`
    });
  }
  
  // Check expiration (if set)
  if (keyData.expiresAt) {
    const expiryDate = new Date(keyData.expiresAt);
    if (expiryDate < new Date()) {
      // Update key status to expired
      updateKeyData(key, { status: 'expired' });
      
      const logEntry = {
        timestamp,
        ip: clientIP,
        key,
        owner: keyData.owner,
        status: 'failed',
        reason: 'Key expired',
        userAgent
      };
      logAccess(logEntry);
      
      return res.status(403).json({ 
        error: 'Key expired',
        message: `This key expired on ${expiryDate.toDateString()}.`
      });
    }
  }
  
  // SMART IP VALIDATION
  const ipValidation = validateIPUsage(keyData, clientIP);
  
  if (!ipValidation.valid) {
    const logEntry = {
      timestamp,
      ip: clientIP,
      key,
      owner: keyData.owner,
      status: 'blocked',
      reason: ipValidation.message,
      userAgent,
      uniqueIPsToday: keyData.ipTracking[getCurrentDate()]?.length || 0
    };
    logAccess(logEntry);
    
    return res.status(429).json({ 
      error: 'Too many devices detected',
      message: ipValidation.message,
      contact: 'Please contact administrator if this is a mistake.'
    });
  }
  
  // Update key usage statistics
  const updatedKeyData = {
    ...keyData,
    lastUsed: timestamp,
    lastIP: clientIP,
    totalRequests: (keyData.totalRequests || 0) + 1,
    ipTracking: keyData.ipTracking
  };
  updateKeyData(key, updatedKeyData);
  
  // Log successful access
  const logEntry = {
    timestamp,
    ip: clientIP,
    key,
    owner: keyData.owner,
    keyType: keyData.type,
    status: 'success',
    warning: ipValidation.warning,
    warningMessage: ipValidation.warning ? ipValidation.message : null,
    userAgent,
    responseTime: `${Date.now() - startTime}ms`
  };
  logAccess(logEntry);
  
  // Read and return the obfuscated loader script
  try {
    const loaderPath = path.join(process.cwd(), 'public', 'loader.lua');
    const loaderScript = fs.readFileSync(loaderPath, 'utf8');
    
    // Set appropriate headers
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');
    res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
    
    // Add warning header if applicable
    if (ipValidation.warning) {
      res.setHeader('X-Warning', ipValidation.message);
    }
    
    return res.status(200).send(loaderScript);
    
  } catch (error) {
    console.error('Error reading loader script:', error);
    
    const errorLogEntry = {
      timestamp,
      ip: clientIP,
      key,
      owner: keyData.owner,
      status: 'error',
      reason: 'Failed to load script',
      error: error.message,
      userAgent
    };
    logAccess(errorLogEntry);
    
    return res.status(500).json({ 
      error: 'Internal server error',
      message: 'Failed to load script. Please try again later.'
    });
  }
}
