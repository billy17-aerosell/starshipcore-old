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
      console.log('✅ Redis module loaded for /api/load');
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
    
    const color = colors[logData.status] || 0x808080;
    
    // Create rich embed
    const embed = {
      title: `${logData.title || 'Access Log'}`,
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
          name: '⏰ Timestamp',
          value: logData.timestamp,
          inline: true
        }
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: 'StarshipCore Auth Monitor'
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

// GitHub API Configuration
const GITHUB_API = 'https://api.github.com';
const KEYS_PATH = 'data/keys.json'; // Changed from whitelist.json

/**
 * Update keys.json di GitHub Repository
 * @param {object} newKeysData - Complete keys.json data
 * @param {string} currentSha - SHA file saat ini (untuk update)
 */
async function updateKeysOnGitHub(newKeysData, currentSha) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    console.error('GitHub credentials not configured');
    return false;
  }

  try {
    const content = Buffer.from(JSON.stringify(newKeysData, null, 2)).toString('base64');
    
    const response = await fetch(`${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28'
      },
      body: JSON.stringify({
        message: `[Auto] Activate license for user`,
        content: content,
        sha: currentSha
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('GitHub API Error:', errorData);
      return false;
    }

    return true;
  } catch (error) {
    console.error('GitHub Update Error:', error);
    return false;
  }
}

/**
 * Get current keys.json from GitHub (untuk dapat SHA terbaru)
 */
async function getKeysFromGitHub() {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    return null;
  }

  try {
    const response = await fetch(`${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28'
      }
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    const content = Buffer.from(data.content, 'base64').toString('utf8');
    
    return {
      sha: data.sha,
      keysData: JSON.parse(content)
    };
  } catch (error) {
    console.error('GitHub Fetch Error:', error);
    return null;
  }
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { user } = req.query;

  if (!user) {
    return res.status(400).json({ error: 'Missing User ID' });
  }

  const now = Math.floor(Date.now() / 1000);
  const timestamp = new Date().toISOString();

  try {
    // === PRIORITY 1: Check Redis Whitelist (VIP Users) ===
    const redisWhitelist = await getWhitelistFromRedis();
    
    if (redisWhitelist && redisWhitelist[user]) {
      const vipUser = redisWhitelist[user];
      
      // Check if user is active
      if (vipUser.status === 'active') {
        // Check expiry if set
        if (vipUser.expiresAt) {
          const expiryDate = new Date(vipUser.expiresAt);
          const expiryTimestamp = Math.floor(expiryDate.getTime() / 1000);
          
          if (expiryTimestamp < now) {
            console.log(`[${timestamp}] ❌ VIP expired - UserID: ${user}`);
            return res.status(403).json({
              status: 'denied',
              message: 'VIP access expired',
              expiredAt: expiryDate.toISOString()
            });
          }
        }
        
        // VIP user - grant access
        const isOwner = user === "9268011358";
        console.log(`[${timestamp}] ${isOwner ? '👑 OWNER' : '💎 VIP'} ACCESS via Redis - UserID: ${user} (${vipUser.username})`);
        
        // Get client IP
        const clientIP = req.headers['x-forwarded-for']?.split(',')[0] || 
                         req.headers['x-real-ip'] || 
                         req.connection?.remoteAddress || 
                         'unknown';
        
        // Discord webhook with rate limiting (same logic as get-loader)
        if (!isOwner) {
          const COOLDOWN_MINUTES = 10;
          const redisKey = `webhook_cooldown:${user}`;
          const ipKey = `last_ip:${user}`;
          
          let shouldSendWebhook = false;
          let webhookReason = 'Regular Access';
          
          console.log(`[${timestamp}] 📊 Webhook Rate Limiting Check for VIP user: ${vipUser.username}`);
          
          try {
            const redisClient = await getRedis();
            if (redisClient) {
              // Get last notification time and IP
              const lastNotification = await redisClient.get(redisKey);
              const lastIP = await redisClient.get(ipKey);
              const now = Date.now();
              
              console.log(`[${timestamp}] 📝 Last notification: ${lastNotification ? new Date(parseInt(lastNotification)).toLocaleString() : 'Never'}`);
              console.log(`[${timestamp}] 📝 Last IP: ${lastIP || 'Unknown'} | Current IP: ${clientIP}`);
              
              // Check if this is first execution of the day
              const today = new Date().toDateString();
              const lastDate = lastNotification ? new Date(parseInt(lastNotification)).toDateString() : null;
              const isFirstToday = !lastDate || lastDate !== today;
              
              // Check if IP changed (security alert)
              const ipChanged = lastIP && lastIP !== clientIP;
              
              console.log(`[${timestamp}] 🔍 Checks - First Today: ${isFirstToday}, IP Changed: ${ipChanged}`);
              
              // Determine if we should send webhook
              if (isFirstToday) {
                shouldSendWebhook = true;
                webhookReason = '🌅 First Execution Today';
              } else if (ipChanged) {
                shouldSendWebhook = true;
                webhookReason = '🔒 IP Address Changed';
              } else if (!lastNotification) {
                shouldSendWebhook = true;
                webhookReason = '🎉 First Time Access';
              } else {
                const timeSinceLastNotif = now - parseInt(lastNotification);
                const cooldownMs = COOLDOWN_MINUTES * 60 * 1000;
                const minutesSinceLastNotif = Math.floor(timeSinceLastNotif / 60000);
                
                console.log(`[${timestamp}] ⏰ Time since last notification: ${minutesSinceLastNotif} minutes (Cooldown: ${COOLDOWN_MINUTES} minutes)`);
                
                if (timeSinceLastNotif >= cooldownMs) {
                  shouldSendWebhook = true;
                  webhookReason = 'Cooldown Expired';
                }
              }
              
              console.log(`[${timestamp}] 🎯 Should send webhook: ${shouldSendWebhook} - Reason: ${webhookReason}`);
              
              // Send webhook if needed
              if (shouldSendWebhook) {
                console.log(`[${timestamp}] 📤 Sending Discord webhook...`);
                
                // Get device info from vipUser data
                const maxDevices = vipUser.maxDevices || vipUser.restrictions?.maxDevices || 'Unlimited';
                const currentDevices = vipUser.deviceCount || vipUser.devices?.length || 0;
                const deviceInfo = maxDevices === 'Unlimited' || maxDevices === null || maxDevices === 0
                  ? `${currentDevices} device(s)` 
                  : `${currentDevices}/${maxDevices} devices`;
                
                await sendDiscordLog({
                  title: `💎 VIP Access Granted`,
                  status: 'success',
                  authType: `VIP (${vipUser.type})`,
                  owner: vipUser.username,
                  ip: ipChanged ? `${lastIP} → ${clientIP}` : clientIP,
                  deviceCount: deviceInfo,
                  timestamp: timestamp,
                  message: `✅ ${webhookReason}\n💎 VIP script delivered to ${vipUser.username}${ipChanged ? '\n⚠️ IP Address Changed!' : ''}`
                });
                
                console.log(`[${timestamp}] ✅ Webhook sent successfully`);
                
                // Update last notification time and IP
                await redisClient.set(redisKey, now.toString(), { EX: 86400 }); // 24 hours expiry
                await redisClient.set(ipKey, clientIP, { EX: 86400 });
                
                console.log(`[${timestamp}] 💾 Updated Redis cooldown data`);
              } else {
                console.log(`[${timestamp}] 🔕 Webhook skipped for ${vipUser.username} - Cooldown active`);
              }
            } else {
              // Redis not available, send webhook anyway (fallback)
              console.log(`[${timestamp}] 🔄 Fallback: Sending webhook (Redis unavailable)`);
              
              const maxDevices = vipUser.maxDevices || vipUser.restrictions?.maxDevices || 'Unlimited';
              const currentDevices = vipUser.deviceCount || vipUser.devices?.length || 0;
              const deviceInfo = maxDevices === 'Unlimited' || maxDevices === null || maxDevices === 0
                ? `${currentDevices} device(s)` 
                : `${currentDevices}/${maxDevices} devices`;
              
              await sendDiscordLog({
                title: `💎 VIP Access Granted`,
                status: 'success',
                authType: `VIP (${vipUser.type})`,
                owner: vipUser.username,
                ip: clientIP,
                deviceCount: deviceInfo,
                timestamp: timestamp,
                message: `✅ VIP script delivered to ${vipUser.username}\n⚠️ (Fallback mode - Rate limiting unavailable)`
              });
            }
          } catch (error) {
            console.error(`[${timestamp}] ❌ Webhook error:`, error);
            // On error, still try to send webhook
            try {
              const maxDevices = vipUser.maxDevices || vipUser.restrictions?.maxDevices || 'Unlimited';
              const currentDevices = vipUser.deviceCount || vipUser.devices?.length || 0;
              const deviceInfo = maxDevices === 'Unlimited' || maxDevices === null || maxDevices === 0
                ? `${currentDevices} device(s)` 
                : `${currentDevices}/${maxDevices} devices`;
              
              await sendDiscordLog({
                title: `💎 VIP Access Granted`,
                status: 'success',
                authType: `VIP (${vipUser.type})`,
                owner: vipUser.username,
                ip: clientIP,
                deviceCount: deviceInfo,
                timestamp: timestamp,
                message: `✅ VIP script delivered to ${vipUser.username}\n⚠️ (Error fallback)`
              });
            } catch (webhookError) {
              console.error(`[${timestamp}] ❌ Failed to send fallback webhook:`, webhookError);
            }
          }
        } else {
          // Owner: Silent access, no webhook
          console.log(`[${timestamp}] 🔕 Owner access - No webhook sent (UserID: ${user})`);
        }
        
        
        // Read and encrypt script
        const scriptPath = path.join(process.cwd(), 'data', 'StarshipCore.lua');
        
        if (!fs.existsSync(scriptPath)) {
          return res.status(500).json({ error: 'Script file missing on server' });
        }

        // Read as buffer
        let scriptBuffer = fs.readFileSync(scriptPath);

        // Remove BOM if present
        if (scriptBuffer.length >= 3 && scriptBuffer[0] === 0xEF && scriptBuffer[1] === 0xBB && scriptBuffer[2] === 0xBF) {
          scriptBuffer = scriptBuffer.subarray(3);
        }

        // Generate Dynamic Key
        const generateKey = (length) => {
          const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+';
          let result = '';
          for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
          }
          return result;
        };

        const dynamicKey = generateKey(64);
        const keyBuffer = Buffer.from(dynamicKey);

        // XOR Encryption
        const encryptedBuffer = Buffer.alloc(scriptBuffer.length);
        for (let i = 0; i < scriptBuffer.length; i++) {
          encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
        }

        // Encode to Base64
        const base64Blob = encryptedBuffer.toString('base64');

        // Calculate remaining time if has expiry
        let remainingDays = null;
        if (vipUser.expiresAt) {
          const expiryTimestamp = Math.floor(new Date(vipUser.expiresAt).getTime() / 1000);
          remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
        }

        return res.status(200).json({
          status: 'success',
          role: vipUser.type || 'VIP',
          duration: vipUser.expiresAt ? `${remainingDays} days` : 'LIFETIME',
          expiry: vipUser.expiresAt ? Math.floor(new Date(vipUser.expiresAt).getTime() / 1000) : null,
          remainingDays: remainingDays,
          activatedAt: vipUser.addedAt ? Math.floor(new Date(vipUser.addedAt).getTime() / 1000) : null,
          key: dynamicKey,
          blob: base64Blob
        });
      } else if (vipUser.status === 'suspended') {
        console.log(`[${timestamp}] 🚫 SUSPENDED VIP - UserID: ${user}`);
        return res.status(403).json({
          status: 'denied',
          message: 'VIP access suspended'
        });
      }
    }

    // === PRIORITY 2: Check File-based Whitelist (Fallback/Legacy) ===
    // Baca keys.json dari file lokal (CONSOLIDATED)
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const keysFileData = fs.readFileSync(keysPath, 'utf8');
    let keysData = JSON.parse(keysFileData);
    
    // Get whitelist from keys.json
    const whitelist = keysData.whitelist || {};
    const userData = whitelist[user];

    if (!userData) {
      console.log(`[${timestamp}] ❌ NOT WHITELISTED - UserID: ${user}`);
      return res.status(403).json({ 
        status: 'denied',
        message: 'Not Whitelisted' 
      });
    }

    // === ACTIVATION ON FIRST RUN ===
    // Jika expiry null DAN ada durationDays, ini adalah aktivasi pertama
    if (userData.expiry === null && userData.durationDays) {
      console.log(`Activating license for user ${user}...`);
      
      // Hitung expiry berdasarkan durationDays
      const durationSeconds = userData.durationDays * 24 * 60 * 60; // days to seconds
      const newExpiry = now + durationSeconds;
      
      // Update data user
      userData.expiry = newExpiry;
      userData.activatedAt = now;
      keysData.whitelist[user] = userData;

      // Update ke GitHub
      const githubData = await getKeysFromGitHub();
      
      if (githubData) {
        // Update whitelist dalam keys.json dari GitHub (untuk sinkronisasi)
        if (!githubData.keysData.whitelist) {
          githubData.keysData.whitelist = {};
        }
        githubData.keysData.whitelist[user] = userData;
        
        const updateSuccess = await updateKeysOnGitHub(githubData.keysData, githubData.sha);
        
        if (updateSuccess) {
          console.log(`License activated for user ${user}. Expiry: ${new Date(newExpiry * 1000).toISOString()}`);
        } else {
          console.error(`Failed to update GitHub for user ${user}`);
          // Tetap lanjutkan walaupun GitHub update gagal (pakai local)
        }
      } else {
        console.warn('Could not fetch GitHub data, using local keys.json');
      }
    }
    // === END ACTIVATION ===

    // Cek expiry (skip jika LIFETIME / tidak ada expiry)
    if (userData.expiry) {
      if (now > userData.expiry) {
        return res.status(403).json({
          status: 'denied',
          message: 'License Expired',
          expiredAt: new Date(userData.expiry * 1000).toISOString()
        });
      }
    }

    // === Load dan encrypt script ===
    const scriptPath = path.join(process.cwd(), 'data', 'StarshipCore.lua');
    
    if (!fs.existsSync(scriptPath)) {
      return res.status(500).json({ error: 'Script file missing on server' });
    }

    // BACA SEBAGAI BUFFER (PENTING!)
    let scriptBuffer = fs.readFileSync(scriptPath);

    // Hapus BOM jika ada (3 byte pertama: EF BB BF)
    if (scriptBuffer.length >= 3 && scriptBuffer[0] === 0xEF && scriptBuffer[1] === 0xBB && scriptBuffer[2] === 0xBF) {
      scriptBuffer = scriptBuffer.subarray(3);
    }

    // Generate Dynamic Key
    const generateKey = (length) => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+';
      let result = '';
      for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return result;
    };

    const dynamicKey = generateKey(64);
    const keyBuffer = Buffer.from(dynamicKey);

    // Enkripsi XOR (Buffer to Buffer)
    const encryptedBuffer = Buffer.alloc(scriptBuffer.length);
    for (let i = 0; i < scriptBuffer.length; i++) {
      encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
    }

    // Encode ke Base64
    const base64Blob = encryptedBuffer.toString('base64');

    // Hitung remaining time
    let remainingDays = null;
    if (userData.expiry) {
      remainingDays = Math.ceil((userData.expiry - now) / 86400);
    }

    res.status(200).json({
      status: 'success',
      role: userData.role || 'VIP',
      duration: userData.duration || 'LIFETIME',
      expiry: userData.expiry || null,
      remainingDays: remainingDays,
      activatedAt: userData.activatedAt || null,
      key: dynamicKey,
      blob: base64Blob
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
