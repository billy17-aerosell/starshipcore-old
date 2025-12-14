// Simple Key Authentication API (Read-Only Version)
// This version doesn't write to filesystem (Vercel compatible)
// With Discord Webhook Logging Integration
// UPDATED: Now checks Redis whitelist for VIP users!

import fs from 'fs';
import path from 'path';

// Get Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import('../lib/redis.js');
      redis = redisModule.default;
      console.log('✅ Redis module loaded for get-loader');
    } catch (error) {
      console.error('⚠️ Redis module load failed:', error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Helper to get whitelist from Redis
async function getWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;
    
    const data = await redisClient.get('starship:whitelist');
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error('Redis whitelist read error:', error.message);
    return null;
  }
}

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
    return { keys: {}, whitelist: {} };
  }
}

// Helper function to send Discord webhook notification
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
  
  // Skip if webhook not configured
  if (!webhookUrl) {
    console.log('[Discord] Webhook not configured, skipping notification');
    return;
  }
  
  try {
    // Determine embed color based on status
    const colors = {
      success: 0x00FF00,    // Green
      blocked: 0xFF0000,    // Red
      invalid: 0xFFA500,    // Orange
      warning: 0xFFFF00     // Yellow
    };
    
    // Determine emoji based on status
    const emojis = {
      success: '🟢',
      blocked: '🔴',
      invalid: '🟠',
      warning: '🟡'
    };
    
    const color = colors[logData.status] || 0x808080;
    const emoji = emojis[logData.status] || '⚪';
    
    // Create rich embed
    const embed = {
      title: `${emoji} ${logData.title || 'Access Log'}`,
      color: color,
      fields: [
        {
          name: '👤 User',
          value: logData.owner || 'Unknown',
          inline: true
        },
        {
          name: '🔑 Auth Type',
          value: `\`${logData.authType || 'Key'}\``,
          inline: true
        },
        {
          name: '🌐 IP Address',
          value: `\`${logData.ip}\``,
          inline: true
        },
        {
          name: '📱 Device Count',
          value: logData.deviceCount || 'N/A',
          inline: true
        },
        {
          name: '⏰ Timestamp',
          value: logData.timestamp,
          inline: true
        },
        {
          name: '✅ Status',
          value: logData.statusMessage || logData.status,
          inline: true
        }
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: 'StarshipCore Access Monitor'
      }
    };
    
    // Add additional info if present
    if (logData.message) {
      embed.description = logData.message;
    }
    
    // Send to Discord
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        embeds: [embed]
      })
    });
    
    if (!response.ok) {
      console.error('[Discord] Failed to send webhook:', response.status);
    } else {
      console.log('[Discord] ✅ Log sent successfully');
    }
  } catch (error) {
    console.error('[Discord] Error sending webhook:', error.message);
  }
}

export default async function handler(req, res) {
  // Only allow GET requests
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  
  // Get parameters (support both 'key' and 'userId')
  const { key, userId } = req.query;
  
  // Get client information
  const clientIP = getClientIP(req);
  const timestamp = new Date().toISOString();
  
  // === PRIORITY 1: Check User ID Whitelist (Owner + VIP) ===
  if (userId) {
    // First, check Redis whitelist (for VIP users)
    const redisWhitelist = await getWhitelistFromRedis();
    
    if (redisWhitelist && redisWhitelist[userId]) {
      const vipUser = redisWhitelist[userId];
      
      // Check if user is active
      if (vipUser.status === 'active') {
        // Check expiry if set
        if (vipUser.expiresAt) {
          const expiryDate = new Date(vipUser.expiresAt);
          if (expiryDate < new Date()) {
            console.log(`[${timestamp}] ❌ VIP expired - UserID: ${userId} | IP: ${clientIP}`);
            return res.status(403).send(
              `-- ERROR: VIP access expired\n` +
              `-- Expired on: ${expiryDate.toDateString()}\n` +
              `error("VIP access expired")`
            );
          }
        }
        
        // VIP user - grant access
        const isOwner = userId === "9268011358";
        console.log(`[${timestamp}] ${isOwner ? '👑 OWNER' : '💎 VIP'} ACCESS - UserID: ${userId} (${vipUser.username}) | IP: ${clientIP}`);
        
        // Send Discord notification (unless owner and noLogging is true)
        if (!isOwner || !vipUser.permissions?.noLogging) {
          await sendDiscordLog({
            title: `${isOwner ? '👑 Owner' : '💎 VIP'} Access Granted`,
            status: 'success',
            statusMessage: '✅ Authorized (VIP)',
            authType: isOwner ? 'Owner' : `VIP (${vipUser.type})`,
            owner: vipUser.username,
            ip: clientIP,
            deviceCount: 'N/A',
            timestamp: timestamp,
            message: `✅ ${isOwner ? 'Owner' : 'VIP'} loader delivered to ${vipUser.username}`
          });
        }
        
        // Read and return loader script
        try {
          const loaderPath = path.join(process.cwd(), 'protected', 'loader.lua');
          
          if (!fs.existsSync(loaderPath)) {
            return res.status(500).send(`error("Loader not found")`);
          }
          
          const loaderScript = fs.readFileSync(loaderPath, 'utf8');
          
          res.setHeader('Content-Type', 'text/plain; charset=utf-8');
          res.setHeader('Cache-Control', 'no-cache');
          res.setHeader('X-Access-Type', isOwner ? 'owner' : 'vip');
          res.setHeader('X-User-Type', vipUser.type);
          
          return res.status(200).send(loaderScript);
          
        } catch (error) {
          console.error('Error:', error);
          return res.status(500).send(`error("Server error")`);
        }
      } else if (vipUser.status === 'suspended') {
        console.log(`[${timestamp}] 🚫 SUSPENDED VIP - UserID: ${userId} | IP: ${clientIP}`);
        return res.status(403).send(
          `-- ERROR: Your VIP access has been suspended\n` +
          `-- Contact administrator\n` +
          `error("VIP access suspended")`
        );
      }
    }
    
    // Fallback: check file-based whitelist (legacy)
    const keysData = getKeysData();
    const fileWhitelist = keysData.whitelist?.[userId];
    
    if (fileWhitelist && fileWhitelist.status === 'active') {
      console.log(`[${timestamp}] 👑 OWNER ACCESS (file) - UserID: ${userId} | IP: ${clientIP}`);
      
      try {
        const loaderPath = path.join(process.cwd(), 'protected', 'loader.lua');
        if (!fs.existsSync(loaderPath)) {
          return res.status(500).send(`error("Loader not found")`);
        }
        const loaderScript = fs.readFileSync(loaderPath, 'utf8');
        res.setHeader('Content-Type', 'text/plain; charset=utf-8');
        res.setHeader('Cache-Control', 'no-cache');
        res.setHeader('X-Access-Type', 'owner');
        return res.status(200).send(loaderScript);
      } catch (error) {
        console.error('Error:', error);
        return res.status(500).send(`error("Server error")`);
      }
    }
  }
  
  // === PRIORITY 2: Normal Key Authentication ===
  // Check if key is provided
  if (!key) {
    return res.status(400).send(
      `-- ERROR: No authentication provided\n` +
      `-- Usage: ?key=YOUR_KEY or ?userId=YOUR_ROBLOX_ID\n` +
      `error("Authentication required")`
    );  
  }
  
  const keyData = keysData.keys[key];
  
  // Check if key exists
  if (!keyData) {
    console.log(`[${timestamp}] Invalid key attempt: ${key} from IP: ${clientIP}`);
    
    // Send Discord notification
    await sendDiscordLog({
      title: 'Invalid Key Attempt',
      status: 'invalid',
      statusMessage: '❌ Invalid Key',
      key: key,
      owner: 'Unknown',
      ip: clientIP,
      deviceCount: 'N/A',
      timestamp: timestamp,
      message: '⚠️ Someone tried to use an invalid authentication key!'
    });
    
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
    
    // Send Discord notification
    await sendDiscordLog({
      title: 'Inactive Key Used',
      status: 'blocked',
      statusMessage: `🚫 Key is ${keyData.status}`,
      key: key,
      owner: keyData.owner,
      ip: clientIP,
      deviceCount: 'N/A',
      timestamp: timestamp,
      message: `⚠️ Attempted to use ${keyData.status} key!`
    });
    
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
      
      // Send Discord notification
      await sendDiscordLog({
        title: 'Expired Key Used',
        status: 'blocked',
        statusMessage: '🚫 Key Expired',
        key: key,
        owner: keyData.owner,
        ip: clientIP,
        deviceCount: 'N/A',
        timestamp: timestamp,
        message: `⚠️ Key expired on ${expiryDate.toDateString()}`
      });
      
      return res.status(403).send(
        `-- ERROR: Key expired\n` +
        `-- Expired on: ${expiryDate.toDateString()}\n` +
        `-- Contact administrator for renewal\n` +
        `error("Key expired")`
      );
    }
  }
  
  // === DEVICE TRACKING & LIMITING ===
  // Initialize tracking if not exists
  if (!keyData.ipTracking) {
    keyData.ipTracking = {};
  }
  
  // Get current unique IPs
  const currentIPs = Object.keys(keyData.ipTracking);
  const maxDevices = keyData.maxDevices || 5; // Default 5 if not set
  
  // Check if this is a new IP
  const isNewIP = !keyData.ipTracking[clientIP];
  
  if (isNewIP) {
    // Check if we've exceeded device limit
    if (currentIPs.length >= maxDevices) {
      console.log(`[${timestamp}] 🚫 Device limit exceeded - Key: ${key} | Current: ${currentIPs.length}/${maxDevices} | New IP: ${clientIP}`);
      
      // Send Discord notification for blocked access
      await sendDiscordLog({
        title: '🚫 Access Blocked - Device Limit Exceeded',
        status: 'blocked',
        statusMessage: '🚫 Too Many Devices',
        key: key,
        owner: keyData.owner,
        ip: clientIP,
        deviceCount: `${currentIPs.length + 1}/${maxDevices} (EXCEEDED!)`,
        timestamp: timestamp,
        message: `⚠️ Attempted to use key from new device, but limit already reached!\n\n**Current IPs:** ${currentIPs.length}\n**New IP:** \`${clientIP}\``
      });
      
      return res.status(403).send(
        `-- ERROR: Device limit exceeded\n` +
        `-- Current devices: ${currentIPs.length}/${maxDevices}\n` +
        `-- Your IP: ${clientIP}\n` +
        `-- This key is already in use on ${currentIPs.length} device(s)\n` +
        `-- Contact ${keyData.owner} if this is your key\n` +
        `error("Device limit exceeded")`
      );
    }
  }
  
  // Note: In Vercel serverless environment, we can't write to filesystem
  // But we can still track in-memory for this request
  // (In production, use external database like Firebase/Supabase for persistent tracking)
  const deviceCount = isNewIP ? currentIPs.length + 1 : currentIPs.length;
  
  // Log successful access to console
  console.log(`[${timestamp}] ✅ Valid access - Key: ${key} | Owner: ${keyData.owner} | IP: ${clientIP} | Devices: ${deviceCount}/${maxDevices}`);
  
  // Send Discord notification for successful access
  await sendDiscordLog({
    title: 'Access Granted',
    status: 'success',
    statusMessage: '✅ Authorized',
    key: key,
    owner: keyData.owner,
    ip: clientIP,
    deviceCount: `${deviceCount}/${maxDevices}`,
    timestamp: timestamp,
    message: `✅ Loader script successfully delivered to ${keyData.owner}${isNewIP ? '\n🆕 New device detected!' : '\n♻️ Known device'}`
  });
  
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
