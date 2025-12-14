#!/usr/bin/env python3
"""
Script to fix webhook duplication and device count issues in get-loader.js
"""

import re

def fix_get_loader():
    file_path = r'c:\Users\Administrator\Documents\for pc & mobile\My real Project FOR PC lengkap dengan recording\VercelProject\api\get-loader.js'
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Fix 1: Move 'const now = Date.now()' before the if (!redisClient) check
    # and add device tracking logic
    
    old_pattern = r'''try \{
            // Check if Redis is available
            const redisClient = await getRedis\(\);
            
            if \(!redisClient\) \{
              console\.log\(`\[\$\{timestamp\}\] ⚠️ Redis not available - sending webhook in fallback mode`\);
              shouldSendWebhook = true;
              webhookReason = '⚠️ Fallback Mode \(Redis Unavailable\)';
              
              // Get device info from vipUser data
              const maxDevices = vipUser\.maxDevices \|\| vipUser\.restrictions\?\.maxDevices \|\| null;
              const currentDevices = vipUser\.deviceCount \|\| vipUser\.devices\?\.length \|\| 0;
              const deviceInfo = !maxDevices \|\| maxDevices === 'Unlimited'
                \? `\$\{currentDevices\} device\(s\)` 
                : `\$\{currentDevices\}/\$\{maxDevices\} devices`;
              
              await sendDiscordLog\(\{
                title: `💎 VIP Access Granted`,
                status: 'success',
                statusMessage: '✅ Authorized \(VIP\)',
                authType: `VIP \(\$\{vipUser\.type\}\)`,
                owner: vipUser\.username,
                ip: clientIP,
                deviceCount: deviceInfo,
                timestamp: timestamp,
                message: `✅ \$\{webhookReason\}\\n💎 VIP loader delivered to \$\{vipUser\.username\}\\n⚠️ \(Rate limiting unavailable\)`
              \}\);
              
              console\.log\(`\[\$\{timestamp\}\] ✅ Fallback webhook sent`\);
            \} else \{
              // Redis is available - use rate limiting
              const lastNotification = await redisClient\.get\(redisKey\);
              const lastIP = await redisClient\.get\(ipKey\);
              const now = Date\.now\(\);'''
    
    new_code = '''try {
            // Check if Redis is available
            const redisClient = await getRedis();
            const now = Date.now();
            
            if (!redisClient) {
              console.log(`[${timestamp}] ⚠️ Redis not available - sending webhook in fallback mode`);
              shouldSendWebhook = true;
              webhookReason = '⚠️ Fallback Mode (Redis Unavailable)';
              
              // Get device info from vipUser data
              const maxDevices = vipUser.maxDevices || vipUser.restrictions?.maxDevices || null;
              const currentDevices = vipUser.deviceCount || vipUser.devices?.length || 0;
              const deviceInfo = !maxDevices || maxDevices === 'Unlimited'
                ? `${currentDevices} device(s)` 
                : `${currentDevices}/${maxDevices} devices`;
              
              await sendDiscordLog({
                title: `💎 VIP Access Granted`,
                status: 'success',
                statusMessage: '✅ Authorized (VIP)',
                authType: `VIP (${vipUser.type})`,
                owner: vipUser.username,
                ip: clientIP,
                deviceCount: deviceInfo,
                timestamp: timestamp,
                message: `✅ ${webhookReason}\\n💎 VIP loader delivered to ${vipUser.username}\\n⚠️ (Rate limiting unavailable)`
              });
              
              console.log(`[${timestamp}] ✅ Fallback webhook sent`);
            } else {
              // Redis is available - use rate limiting
              const lastNotification = await redisClient.get(redisKey);
              const lastIP = await redisClient.get(ipKey);
              const deviceTrackingKey = `devices:${userId}`;
            
            // === DEVICE TRACKING ===
            // Track all unique IPs for this user
            let trackedDevices = [];
            const devicesData = await redisClient.get(deviceTrackingKey);
            trackedDevices = devicesData ? JSON.parse(devicesData) : [];
            
            // Add current IP if not already tracked
            if (!trackedDevices.includes(clientIP)) {
              trackedDevices.push(clientIP);
              // Save back to Redis with 30 days expiry
              await redisClient.set(deviceTrackingKey, JSON.stringify(trackedDevices), { EX: 2592000 });
              console.log(`[${timestamp}] 📱 New device added for ${vipUser.username}: ${clientIP}`);
            }
            
            const currentDeviceCount = trackedDevices.length;
            console.log(`[${timestamp}] 📊 Device Count: ${currentDeviceCount}`);'''
    
    content = re.sub(old_pattern, new_code, content, flags=re.DOTALL)
    
    # Fix 2: Update webhook calls to use currentDeviceCount instead of vipUser.deviceCount
    content = re.sub(
        r"const currentDevices = vipUser\.deviceCount \|\| vipUser\.devices\?\.length \|\| 0;",
        "const currentDevices = currentDeviceCount;  // Use tracked count from Redis",
        content
    )
    
    # Write back
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("[OK] File patched successfully!")
    print("\nChanges made:")
    print("1. Moved 'const now = Date.now()' before Redis check")
    print("2. Added device tracking logic to Redis")
    print("3. Updated webhook to use tracked device count")
    print("\nThis fixes:")
    print("- Duplicate webhook notifications")
    print("- Device count showing 0/5")

if __name__ == '__main__':
    fix_get_loader()
