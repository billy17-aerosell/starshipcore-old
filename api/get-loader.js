// Simple Key Authentication API (Read-Only Version)
// This version doesn't write to filesystem (Vercel compatible)
// With Discord Webhook Logging Integration

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
          name: '👤 Key Owner',
          value: logData.owner || 'Unknown',
          inline: true
        },
        {
          name: '🔑 Key',
          value: `\`${logData.key || 'N/A'}\``,
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
  
  // Log successful access to console
  console.log(`[${timestamp}] ✅ Valid access - Key: ${key} | Owner: ${keyData.owner} | IP: ${clientIP}`);
  
  // Send Discord notification for successful access
  await sendDiscordLog({
    title: 'Access Granted',
    status: 'success',
    statusMessage: '✅ Authorized',
    key: key,
    owner: keyData.owner,
    ip: clientIP,
    deviceCount: 'N/A', // Can be enhanced with device tracking
    timestamp: timestamp,
    message: `✅ Loader script successfully delivered to ${keyData.owner}`
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
