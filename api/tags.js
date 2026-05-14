// Discord VIP Verification API
// Usage: POST /api/tags with { robloxId, discordId, action: 'verify' }
// Also handles system status: GET /api/tags?action=status or POST with action: 'set_status'

const DISCORD_BOT_TOKEN = process.env.DISCORD_BOT_TOKEN;
const GUILD_ID = '1449716046905737310';
const ROLE_IDS = {
    mobile: '1451997436707864648',
    pc: '1451997324451647642'
};

let redis = null;
let redisInitAttempted = false;

async function getRedis() {
    if (!redisInitAttempted) {
        try {
            const redisModule = await import('../lib/redis.js');
            redis = redisModule.default;
        } catch (error) {
            console.error('Redis module load failed:', error.message);
            redis = null;
        }
        redisInitAttempted = true;
    }
    return redis;
}

const PLATFORM_CONFIG = {
    pc: { 
        whitelistKey: 'starship:whitelist',
        statusKey: 'starship:status:pc',
        maintenanceKey: 'maintenance:pc:start',
        historyKey: 'maintenance:history:pc',
        label: '💻 PC'
    },
    mobile: { 
        whitelistKey: 'starship:mobile_whitelist',
        statusKey: 'starship:status:mobile',
        maintenanceKey: 'maintenance:mobile:start',
        historyKey: 'maintenance:history:mobile',
        label: '📱 Mobile'
    }
};

// Maintenance Compensation Config
const COMPENSATION_CONFIG = {
    MINIMUM_DURATION_SECONDS: 3600, // 1 hour minimum
    MULTIPLIER: 1,
    MAX_HISTORY_ENTRIES: 50
};

function formatDuration(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    if (hours > 0 && minutes > 0) return `${hours}h ${minutes}m`;
    if (hours > 0) return `${hours} jam`;
    return `${minutes} menit`;
}

function formatDateWIB(isoString) {
    const date = new Date(isoString);
    return date.toLocaleString('id-ID', { 
        timeZone: 'Asia/Jakarta',
        day: '2-digit', month: 'short', year: 'numeric',
        hour: '2-digit', minute: '2-digit'
    }) + ' WIB';
}

// ============ STATUS SYSTEM ============
const STATUS_TYPES = {
    online: {
        emoji: '🟢',
        label: 'Online',
        color: 0x00E676,
        description: 'All systems operational'
    },
    maintenance: {
        emoji: '🟠',
        label: 'Maintenance',
        color: 0xFF9800,
        description: 'System is under maintenance'
    },
    offline: {
        emoji: '🔴',
        label: 'Offline',
        color: 0xF44336,
        description: 'System is currently offline'
    },
    degraded: {
        emoji: '🟡',
        label: 'Degraded',
        color: 0xFFEB3B,
        description: 'Some features may be unavailable'
    },
    updating: {
        emoji: '🔵',
        label: 'Updating',
        color: 0x2196F3,
        description: 'New update is being deployed'
    }
};

// In-memory status fallback (per platform)
let platformStatus = {
    pc: {
        status: 'online',
        message: 'All systems operational',
        lastUpdated: new Date().toISOString()
    },
    mobile: {
        status: 'online',
        message: 'All systems operational',
        lastUpdated: new Date().toISOString()
    }
};

// Legacy single status for backwards compatibility
let currentStatus = {
    status: 'online',
    message: 'All systems operational',
    lastUpdated: new Date().toISOString(),
    discordMessageId: null
};

async function getStatus(platform = null) {
    const redisClient = await getRedis();
    
    // If specific platform requested
    if (platform && (platform === 'pc' || platform === 'mobile')) {
        if (redisClient) {
            try {
                const data = await redisClient.get(`starship:status:${platform}`);
                if (data) return JSON.parse(data);
            } catch (e) {
                console.error('Redis get status error:', e);
            }
        }
        return platformStatus[platform];
    }
    
    // Return combined status (for backwards compatibility)
    if (redisClient) {
        try {
            const pcData = await redisClient.get('starship:status:pc');
            const mobileData = await redisClient.get('starship:status:mobile');
            return {
                pc: pcData ? JSON.parse(pcData) : platformStatus.pc,
                mobile: mobileData ? JSON.parse(mobileData) : platformStatus.mobile,
                lastUpdated: new Date().toISOString()
            };
        } catch (e) {
            console.error('Redis get status error:', e);
        }
    }
    return platformStatus;
}

async function saveStatus(status, platform = null) {
    const redisClient = await getRedis();
    
    // If specific platform
    if (platform && (platform === 'pc' || platform === 'mobile')) {
        platformStatus[platform] = status;
        if (redisClient) {
            try {
                await redisClient.set(`starship:status:${platform}`, JSON.stringify(status));
            } catch (e) {
                console.error('Redis set status error:', e);
            }
        }
        return;
    }
    
    // Set both platforms (all)
    platformStatus.pc = status;
    platformStatus.mobile = status;
    currentStatus = status;
    if (redisClient) {
        try {
            await redisClient.set('starship:status:pc', JSON.stringify(status));
            await redisClient.set('starship:status:mobile', JSON.stringify(status));
            await redisClient.set('starship:status', JSON.stringify(status)); // Legacy
        } catch (e) {
            console.error('Redis set status error:', e);
        }
    }
}

async function sendDiscordStatusUpdate(status, message, discordWebhookUrl) {
    const statusInfo = STATUS_TYPES[status] || STATUS_TYPES.online;
    
    const embed = {
        title: `${statusInfo.emoji} StarshipCore Status: ${statusInfo.label}`,
        description: message || statusInfo.description,
        color: statusInfo.color,
        fields: [
            { name: '📊 Status', value: `\`${status.toUpperCase()}\``, inline: true },
            { name: '🕐 Updated', value: `<t:${Math.floor(Date.now() / 1000)}:R>`, inline: true }
        ],
        footer: {
            text: 'StarshipCore Status Monitor',
            icon_url: 'https://starship-core.my.id/starship-logo.png'
        },
        timestamp: new Date().toISOString()
    };

    if (status === 'maintenance') {
        embed.fields.push({ name: '⚠️ Notice', value: 'System under maintenance. Please wait.', inline: false });
    } else if (status === 'updating') {
        embed.fields.push({ name: '🔄 Update', value: 'New version being deployed (2-5 min).', inline: false });
    }

    try {
        const currentStatusData = await getStatus();
        if (currentStatusData.discordMessageId && discordWebhookUrl) {
            try {
                await fetch(`${discordWebhookUrl}/messages/${currentStatusData.discordMessageId}`, { method: 'DELETE' });
            } catch (e) { /* ignore */ }
        }

        const response = await fetch(`${discordWebhookUrl}?wait=true`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                username: 'StarshipCore Status',
                avatar_url: 'https://starship-core.my.id/starship-logo.png',
                embeds: [embed]
            })
        });

        if (response.ok) {
            const data = await response.json();
            return data.id;
        }
        return null;
    } catch (e) {
        console.error('Discord webhook error:', e);
        return null;
    }
}

// Channel name formats for each status (per platform)
const STATUS_CHANNEL_NAMES = {
    pc: {
        online: '🔒 🟢 PC | LIVE',
        maintenance: '🔒 🟠 PC | MAINTENANCE',
        offline: '🔒 🔴 PC | OFFLINE',
        degraded: '🔒 🟡 PC | DEGRADED',
        updating: '🔒 🔵 PC | UPDATING'
    },
    mobile: {
        online: '🔒 🟢 MOBILE | LIVE',
        maintenance: '🔒 🟠 MOBILE | MAINTENANCE',
        offline: '🔒 🔴 MOBILE | OFFLINE',
        degraded: '🔒 🟡 MOBILE | DEGRADED',
        updating: '🔒 🔵 MOBILE | UPDATING'
    }
};

// Platform channel IDs
const PLATFORM_CHANNEL_IDS = {
    pc: process.env.DISCORD_STATUS_CHANNEL_ID, // Existing PC channel
    mobile: '1457417278155915530' // New Mobile channel
};

// Rename Discord channel to show status (per platform)
async function updateDiscordChannelName(status, platform = null) {
    const botToken = process.env.DISCORD_BOT_TOKEN;
    
    console.log('[Status] Attempting channel rename...');
    console.log('[Status] Bot Token:', botToken ? 'SET (' + botToken.length + ' chars)' : 'NOT SET');
    console.log('[Status] Platform:', platform || 'all');
    
    if (!botToken) {
        console.log('[Status] Discord channel rename skipped: missing BOT_TOKEN');
        return false;
    }
    
    // Determine which channels to update
    const platformsToUpdate = platform && platform !== 'all' ? [platform] : ['pc', 'mobile'];
    let allSuccess = true;
    
    for (const plat of platformsToUpdate) {
        const channelId = PLATFORM_CHANNEL_IDS[plat];
        if (!channelId) {
            console.log(`[Status] No channel ID for platform: ${plat}`);
            continue;
        }
        
        const channelName = STATUS_CHANNEL_NAMES[plat]?.[status] || STATUS_CHANNEL_NAMES[plat]?.online;
        if (!channelName) {
            console.log(`[Status] No channel name format for: ${plat}/${status}`);
            continue;
        }
        
        console.log(`[Status] Updating ${plat} channel to: ${channelName}`);
        
        try {
            const response = await fetch(`https://discord.com/api/v10/channels/${channelId}`, {
                method: 'PATCH',
                headers: {
                    'Authorization': `Bot ${botToken}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    name: channelName
                })
            });
            
            if (response.ok) {
                console.log(`[Status] ✅ ${plat.toUpperCase()} channel renamed to: ${channelName}`);
            } else {
                const error = await response.text();
                console.error(`[Status] ❌ Failed to rename ${plat} channel:`, error);
                allSuccess = false;
            }
        } catch (e) {
            console.error(`[Status] Discord ${plat} channel rename error:`, e);
            allSuccess = false;
        }
    }
    
    return allSuccess;
}


// Add role to Discord user
async function addDiscordRole(discordId, roleId) {
    if (!DISCORD_BOT_TOKEN) {
        console.error('DISCORD_BOT_TOKEN not set');
        return { success: false, error: 'Bot token not configured' };
    }

    try {
        const response = await fetch(
            `https://discord.com/api/v10/guilds/${GUILD_ID}/members/${discordId}/roles/${roleId}`,
            {
                method: 'PUT',
                headers: {
                    'Authorization': `Bot ${DISCORD_BOT_TOKEN}`,
                    'Content-Type': 'application/json'
                }
            }
        );

        if (response.ok || response.status === 204) {
            return { success: true };
        } else {
            const error = await response.text();
            console.error('Discord API error:', error);
            return { success: false, error };
        }
    } catch (error) {
        console.error('Failed to add Discord role:', error);
        return { success: false, error: error.message };
    }
}

// Check VIP status for a Roblox user
async function checkVipStatus(robloxId) {
    const redisClient = await getRedis();
    if (!redisClient) {
        return { error: 'Database unavailable' };
    }

    const results = {
        mobile: null,
        pc: null
    };

    for (const [platform, config] of Object.entries(PLATFORM_CONFIG)) {
        const whitelistData = await redisClient.get(config.whitelistKey);
        const whitelist = whitelistData ? JSON.parse(whitelistData) : {};
        
        const user = whitelist[robloxId];
        if (user) {
            let isExpired = false;
            if (user.expiresAt) {
                isExpired = new Date(user.expiresAt) < new Date();
            }
            
            results[platform] = {
                isVip: user.status === 'active' && !isExpired,
                username: user.username,
                duration: user.duration,
                expiresAt: user.expiresAt,
                isLifetime: !user.expiresAt
            };
        }
    }

    return results;
}

export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, x-admin-secret');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    // ============ GET STATUS (PUBLIC) ============
    if (req.method === 'GET' && req.query.action === 'status') {
        const platform = req.query.platform; // pc, mobile, or null for all
        const status = await getStatus(platform);
        
        // If specific platform, return single status
        if (platform && (platform === 'pc' || platform === 'mobile')) {
            const statusInfo = STATUS_TYPES[status.status] || STATUS_TYPES.online;
            return res.status(200).json({
                success: true,
                platform: platform,
                status: status.status,
                label: statusInfo.label,
                emoji: statusInfo.emoji,
                color: statusInfo.color,
                message: status.message,
                description: statusInfo.description,
                lastUpdated: status.lastUpdated
            });
        }
        
        // Return both platforms
        const pcInfo = STATUS_TYPES[status.pc?.status] || STATUS_TYPES.online;
        const mobileInfo = STATUS_TYPES[status.mobile?.status] || STATUS_TYPES.online;
        
        return res.status(200).json({
            success: true,
            pc: {
                status: status.pc?.status || 'online',
                label: pcInfo.label,
                emoji: pcInfo.emoji,
                message: status.pc?.message,
                lastUpdated: status.pc?.lastUpdated
            },
            mobile: {
                status: status.mobile?.status || 'online',
                label: mobileInfo.label,
                emoji: mobileInfo.emoji,
                message: status.mobile?.message,
                lastUpdated: status.mobile?.lastUpdated
            }
        });
    }

    // ============ MAINTENANCE HISTORY (ADMIN) - GET ============
    if (req.method === 'GET' && req.query.action === 'maintenance_history') {
        const adminSecret = req.headers['x-admin-secret'];
        if (!adminSecret || adminSecret !== process.env.ADMIN_SECRET) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const redisClient = await getRedis();
        if (!redisClient) {
            return res.status(500).json({ success: false, error: 'Database unavailable' });
        }

        // Get current status
        const currentStatusResult = { pc: { status: 'online' }, mobile: { status: 'online' } };
        for (const [plat, config] of Object.entries(PLATFORM_CONFIG)) {
            const startTime = await redisClient.get(config.maintenanceKey);
            if (startTime) {
                const duration = Math.floor((Date.now() - new Date(startTime).getTime()) / 1000);
                currentStatusResult[plat] = {
                    status: 'maintenance',
                    inMaintenance: true,
                    startedAt: startTime,
                    runningDurationText: formatDuration(duration)
                };
            } else {
                const statusData = await redisClient.get(config.statusKey);
                if (statusData) {
                    const parsed = JSON.parse(statusData);
                    currentStatusResult[plat] = {
                        status: parsed.status || 'online',
                        inMaintenance: false
                    };
                }
            }
        }

        // Get history from both platforms
        let history = [];
        let statistics = { totalMaintenance: 0, totalDowntime: 0, totalCompensation: 0, totalUsersCompensated: 0 };

        for (const [plat, config] of Object.entries(PLATFORM_CONFIG)) {
            const historyData = await redisClient.get(config.historyKey);
            const platHistory = historyData ? JSON.parse(historyData) : [];
            history = history.concat(platHistory);

            for (const entry of platHistory) {
                statistics.totalMaintenance++;
                statistics.totalDowntime += entry.actualDuration || 0;
                statistics.totalCompensation += entry.compensationGiven || 0;
                statistics.totalUsersCompensated += entry.usersCompensated || 0;
            }
        }

        history.sort((a, b) => new Date(b.endAt) - new Date(a.endAt));

        return res.status(200).json({
            success: true,
            currentStatus: currentStatusResult,
            history,
            statistics: {
                ...statistics,
                totalDowntimeText: formatDuration(statistics.totalDowntime),
                totalCompensationText: formatDuration(statistics.totalCompensation)
            }
        });
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    const { robloxId, discordId, code, redirectUri, status, message } = req.body;
    // Check action from both body and query parameter
    const action = req.body.action || req.query.action;

    // ============ SET STATUS (ADMIN ONLY) ============
    if (action === 'set_status') {
        const adminSecret = req.headers['x-admin-secret'];
        
        if (!adminSecret || adminSecret !== process.env.ADMIN_SECRET) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        if (!status || !STATUS_TYPES[status]) {
            return res.status(400).json({
                success: false,
                error: 'Invalid status. Valid: ' + Object.keys(STATUS_TYPES).join(', ')
            });
        }

        // Get platform from request body (pc, mobile, or all/null)
        const platform = req.body.platform;
        const effectivePlatform = platform === 'all' ? null : platform;
        const platformsToProcess = effectivePlatform ? [effectivePlatform] : ['pc', 'mobile'];

        // ═══════════════════════════════════════════════════════════════
        // MAINTENANCE COMPENSATION INTEGRATION
        // ═══════════════════════════════════════════════════════════════
        let compensationResults = [];
        const redisClient = await getRedis();
        
        for (const plat of platformsToProcess) {
            const maintenanceKey = `maintenance:${plat}:start`;
            
            if (status === 'maintenance') {
                // Starting maintenance - record start time if not already in maintenance
                if (redisClient) {
                    const existingStart = await redisClient.get(maintenanceKey);
                    if (!existingStart) {
                        await redisClient.set(maintenanceKey, new Date().toISOString());
                        console.log(`[Maintenance] ✅ ${plat.toUpperCase()} maintenance started`);
                    }
                }
            } else if (status === 'online') {
                // Ending maintenance - check if we were in maintenance and need to compensate
                if (redisClient) {
                    const startTimeStr = await redisClient.get(maintenanceKey);
                    if (startTimeStr) {
                        // We were in maintenance, need to compensate!
                        console.log(`[Maintenance] 📋 ${plat.toUpperCase()} maintenance ending, processing compensation...`);
                        
                        try {
                            const config = PLATFORM_CONFIG[plat];
                            const startTime = new Date(startTimeStr);
                            const endTime = new Date();
                            const actualDuration = Math.floor((endTime - startTime) / 1000);
                            const compensationDuration = Math.max(actualDuration * COMPENSATION_CONFIG.MULTIPLIER, COMPENSATION_CONFIG.MINIMUM_DURATION_SECONDS);
                            
                            // Get whitelist and compensate
                            const whitelistData = await redisClient.get(config.whitelistKey);
                            let whitelist = whitelistData ? JSON.parse(whitelistData) : {};
                            const compensatedUsers = [];
                            const now = new Date();
                            
                            for (const [userId, user] of Object.entries(whitelist)) {
                                if (user.status !== 'active') continue;
                                if (!user.expiresAt) continue; // Skip lifetime
                                const expiryDate = new Date(user.expiresAt);
                                if (expiryDate < now) continue; // Skip expired
                                
                                const newExpiryDate = new Date(expiryDate.getTime() + (compensationDuration * 1000));
                                whitelist[userId] = {
                                    ...user,
                                    expiresAt: newExpiryDate.toISOString(),
                                    pendingAnnouncement: {
                                        type: 'compensation',
                                        title: '🎁 Kompensasi Maintenance',
                                        message: `VIP Anda diperpanjang +${formatDuration(compensationDuration)}`,
                                        duration: compensationDuration,
                                        date: endTime.toISOString()
                                    }
                                };
                                compensatedUsers.push({ 
                                    userId, 
                                    username: user.username || 'Unknown', 
                                    added: compensationDuration,
                                    expiryBefore: expiryDate.toISOString(),
                                    expiryAfter: newExpiryDate.toISOString()
                                });
                            }
                            
                            await redisClient.set(config.whitelistKey, JSON.stringify(whitelist));
                            
                            // Save history
                            const historyEntry = {
                                id: `maint_${plat}_${Date.now()}`,
                                platform: plat,
                                startAt: startTimeStr,
                                endAt: endTime.toISOString(),
                                actualDuration,
                                actualDurationText: formatDuration(actualDuration),
                                compensationGiven: compensationDuration,
                                compensationText: `+${formatDuration(compensationDuration)}`,
                                usersCompensated: compensatedUsers.length,
                                usersList: compensatedUsers.slice(0, 50)
                            };
                            
                            const historyData = await redisClient.get(config.historyKey);
                            let history = historyData ? JSON.parse(historyData) : [];
                            history.unshift(historyEntry);
                            history = history.slice(0, COMPENSATION_CONFIG.MAX_HISTORY_ENTRIES);
                            await redisClient.set(config.historyKey, JSON.stringify(history));
                            
                            // Clear maintenance start
                            await redisClient.del(config.maintenanceKey);
                            
                            // Discord webhook
                            const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
                            if (webhookUrl) {
                                try {
                                    await fetch(webhookUrl, {
                                        method: 'POST',
                                        headers: { 'Content-Type': 'application/json' },
                                        body: JSON.stringify({
                                            embeds: [{
                                                title: '✅ MAINTENANCE COMPLETED',
                                                color: 0x00E676,
                                                fields: [
                                                    { name: '📍 Platform', value: config.label, inline: true },
                                                    { name: '⏱️ Duration', value: formatDuration(actualDuration), inline: true },
                                                    { name: '🎁 Compensation', value: `+${formatDuration(compensationDuration)}`, inline: true },
                                                    { name: '👥 Users', value: `${compensatedUsers.length} users`, inline: true }
                                                ],
                                                timestamp: new Date().toISOString()
                                            }]
                                        })
                                    });
                                } catch (e) { console.error('[Discord] Webhook error:', e.message); }
                            }
                            
                            compensationResults.push({
                                platform: plat,
                                usersCompensated: compensatedUsers.length,
                                compensation: `+${formatDuration(compensationDuration)}`
                            });
                            console.log(`[Maintenance] ✅ ${plat.toUpperCase()} compensation complete: ${compensatedUsers.length} users`);
                        } catch (e) {
                            console.error(`[Maintenance] Error processing compensation for ${plat}:`, e.message);
                        }
                    }
                }
            }
        }

        // Update Discord channel name (per platform)
        const channelUpdated = await updateDiscordChannelName(status, effectivePlatform);

        const newStatus = {
            status,
            message: message || STATUS_TYPES[status].description,
            lastUpdated: new Date().toISOString()
        };
        
        await saveStatus(newStatus, effectivePlatform);
        const statusInfo = STATUS_TYPES[status];
        
        return res.status(200).json({
            success: true,
            platform: req.body.platform || 'all',
            status: newStatus.status,
            label: statusInfo.label,
            emoji: statusInfo.emoji,
            message: newStatus.message,
            lastUpdated: newStatus.lastUpdated,
            discordChannelUpdated: channelUpdated,
            channelName: STATUS_CHANNEL_NAMES[status],
            compensationResults: compensationResults.length > 0 ? compensationResults : undefined
        });
    }

    // ============ DISCORD OAUTH EXCHANGE ============
    if (action === 'discord_oauth' && code) {
        const CLIENT_ID = '1456290071337762892';
        const CLIENT_SECRET = process.env.DISCORD_CLIENT_SECRET;

        if (!CLIENT_SECRET) {
            return res.status(500).json({ success: false, error: 'OAuth not configured' });
        }

        try {
            // Normalize redirect URI - strip trailing slash for consistency with Discord app settings
            const normalizedRedirectUri = (redirectUri || '').replace(/\/$/, '');

            console.log('[OAuth] Exchanging code for token...');
            console.log('[OAuth] Redirect URI:', normalizedRedirectUri);

            // Exchange code for access token
            const tokenResponse = await fetch('https://discord.com/api/oauth2/token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({
                    client_id: CLIENT_ID,
                    client_secret: CLIENT_SECRET,
                    grant_type: 'authorization_code',
                    code: code,
                    redirect_uri: normalizedRedirectUri
                })
            });

            const tokenData = await tokenResponse.json();

            if (!tokenData.access_token) {
                console.error('[OAuth] Token exchange failed:', JSON.stringify(tokenData));

                // Provide user-friendly error based on Discord's error response
                const errorDesc = tokenData.error_description || tokenData.error || 'Unknown error';
                const isCodeInvalid = errorDesc.toLowerCase().includes('invalid') ||
                                     errorDesc.toLowerCase().includes('expired') ||
                                     errorDesc.toLowerCase().includes('used');

                return res.status(400).json({
                    success: false,
                    error: isCodeInvalid
                        ? 'Login session expired. Please close this page and try logging in again.'
                        : `Authentication failed: ${errorDesc}`,
                    errorType: isCodeInvalid ? 'CODE_EXPIRED' : 'OAUTH_ERROR'
                });
            }

            console.log('[OAuth] Token received, fetching user info...');

            // Get user info
            const userResponse = await fetch('https://discord.com/api/users/@me', {
                headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
            });

            const user = await userResponse.json();

            if (!user.id) {
                console.error('[OAuth] Failed to get user info:', user);
                return res.status(400).json({ success: false, error: 'Failed to get user info' });
            }

            console.log('[OAuth] Success! User:', user.username || user.id);

            return res.status(200).json({
                success: true,
                user: {
                    id: user.id,
                    username: user.global_name || user.username,
                    avatar: user.avatar
                }
            });
        } catch (error) {
            console.error('[OAuth] Exception:', error);
            return res.status(500).json({ success: false, error: 'OAuth failed: ' + error.message });
        }
    }

    // ============ VERIFY ACTION ============
    if (action === 'verify') {
        if (!robloxId) {
            return res.status(400).json({ error: 'robloxId is required' });
        }

        // Check VIP status
        const vipStatus = await checkVipStatus(robloxId);
        
        if (vipStatus.error) {
            return res.status(503).json({ error: vipStatus.error });
        }

        const isMobileVip = vipStatus.mobile?.isVip || false;
        const isPcVip = vipStatus.pc?.isVip || false;

        if (!isMobileVip && !isPcVip) {
            return res.status(200).json({
                success: false,
                message: 'Roblox ID not found in VIP list',
                robloxId
            });
        }

        // If discordId provided, try to assign roles
        let rolesAssigned = [];
        if (discordId && DISCORD_BOT_TOKEN) {
            if (isMobileVip) {
                const result = await addDiscordRole(discordId, ROLE_IDS.mobile);
                if (result.success) rolesAssigned.push('Mobile VIP');
            }
            if (isPcVip) {
                const result = await addDiscordRole(discordId, ROLE_IDS.pc);
                if (result.success) rolesAssigned.push('PC VIP');
            }
        }

        return res.status(200).json({
            success: true,
            robloxId,
            discordId,
            vipStatus: {
                mobile: isMobileVip ? vipStatus.mobile : null,
                pc: isPcVip ? vipStatus.pc : null
            },
            rolesAssigned,
            message: rolesAssigned.length > 0 
                ? `Verified! Roles assigned: ${rolesAssigned.join(', ')}`
                : 'Verified! VIP status confirmed.'
        });
    }

    // ============ LEGACY: BATCH TAG CHECK ============
    const { userIds } = req.body;
    if (userIds && Array.isArray(userIds)) {
        const redisClient = await getRedis();
        const results = {};

        if (redisClient) {
            for (const [platform, config] of Object.entries(PLATFORM_CONFIG)) {
                const whitelistData = await redisClient.get(config.whitelistKey);
                const whitelist = whitelistData ? JSON.parse(whitelistData) : {};
                
                userIds.forEach(id => {
                    const strId = String(id);
                    if (whitelist[strId]) {
                        results[strId] = {
                            role: whitelist[strId].type || 'VIP',
                            tag: `${platform.toUpperCase()} VIP`,
                            platform
                        };
                    }
                });
            }
        }

        return res.status(200).json({
            status: 'success',
            tags: results
        });
    }

    // ============ MAINTENANCE HISTORY (ADMIN) ============
    if (req.method === 'GET' && action === 'maintenance_history') {
        const adminSecret = req.headers['x-admin-secret'];
        if (!adminSecret || adminSecret !== process.env.ADMIN_SECRET) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const redisClient = await getRedis();
        if (!redisClient) {
            return res.status(500).json({ success: false, error: 'Database unavailable' });
        }

        // Get current status
        const currentStatusResult = { pc: { status: 'online' }, mobile: { status: 'online' } };
        for (const [plat, config] of Object.entries(PLATFORM_CONFIG)) {
            const startTime = await redisClient.get(config.maintenanceKey);
            if (startTime) {
                const duration = Math.floor((Date.now() - new Date(startTime).getTime()) / 1000);
                currentStatusResult[plat] = {
                    status: 'maintenance',
                    inMaintenance: true,
                    startedAt: startTime,
                    runningDurationText: formatDuration(duration)
                };
            } else {
                const statusData = await redisClient.get(config.statusKey);
                if (statusData) {
                    const parsed = JSON.parse(statusData);
                    currentStatusResult[plat] = {
                        status: parsed.status || 'online',
                        inMaintenance: false
                    };
                }
            }
        }

        // Get history
        let history = [];
        let statistics = { totalMaintenance: 0, totalDowntime: 0, totalCompensation: 0, totalUsersCompensated: 0 };

        for (const [plat, config] of Object.entries(PLATFORM_CONFIG)) {
            const historyData = await redisClient.get(config.historyKey);
            const platHistory = historyData ? JSON.parse(historyData) : [];
            history = history.concat(platHistory);

            for (const entry of platHistory) {
                statistics.totalMaintenance++;
                statistics.totalDowntime += entry.actualDuration || 0;
                statistics.totalCompensation += entry.compensationGiven || 0;
                statistics.totalUsersCompensated += entry.usersCompensated || 0;
            }
        }

        history.sort((a, b) => new Date(b.endAt) - new Date(a.endAt));

        return res.status(200).json({
            success: true,
            currentStatus: currentStatusResult,
            history,
            statistics: {
                ...statistics,
                totalDowntimeText: formatDuration(statistics.totalDowntime),
                totalCompensationText: formatDuration(statistics.totalCompensation)
            }
        });
    }

    // ============ END MAINTENANCE & COMPENSATE (ADMIN) ============
    if (req.method === 'POST' && action === 'end_maintenance') {
        const adminSecret = req.headers['x-admin-secret'];
        if (!adminSecret || adminSecret !== process.env.ADMIN_SECRET) {
            return res.status(401).json({ success: false, error: 'Unauthorized' });
        }

        const platform = req.body.platform;
        if (!platform || !PLATFORM_CONFIG[platform]) {
            return res.status(400).json({ success: false, error: 'Invalid platform' });
        }

        const redisClient = await getRedis();
        if (!redisClient) {
            return res.status(500).json({ success: false, error: 'Database unavailable' });
        }

        const config = PLATFORM_CONFIG[platform];
        const startTimeStr = await redisClient.get(config.maintenanceKey);

        if (!startTimeStr) {
            return res.status(400).json({ success: false, error: 'No active maintenance', message: 'Platform was not in maintenance mode' });
        }

        const startTime = new Date(startTimeStr);
        const endTime = new Date();
        const actualDuration = Math.floor((endTime - startTime) / 1000);
        const compensationDuration = Math.max(actualDuration * COMPENSATION_CONFIG.MULTIPLIER, COMPENSATION_CONFIG.MINIMUM_DURATION_SECONDS);

        // Get whitelist and compensate
        const whitelistData = await redisClient.get(config.whitelistKey);
        let whitelist = whitelistData ? JSON.parse(whitelistData) : {};
        const compensatedUsers = [];
        const now = new Date();

        for (const [userId, user] of Object.entries(whitelist)) {
            if (user.status !== 'active') continue;
            if (!user.expiresAt) continue; // Skip lifetime
            const expiryDate = new Date(user.expiresAt);
            if (expiryDate < now) continue; // Skip expired

            const newExpiryDate = new Date(expiryDate.getTime() + (compensationDuration * 1000));
            whitelist[userId] = {
                ...user,
                expiresAt: newExpiryDate.toISOString(),
                pendingAnnouncement: {
                    type: 'compensation',
                    title: '🎁 Kompensasi Maintenance',
                    message: `VIP Anda diperpanjang +${formatDuration(compensationDuration)}`,
                    duration: compensationDuration,
                    date: endTime.toISOString()
                }
            };
            compensatedUsers.push({ userId, username: user.username || 'Unknown', added: compensationDuration });
        }

        await redisClient.set(config.whitelistKey, JSON.stringify(whitelist));

        // Save history
        const historyEntry = {
            id: `maint_${platform}_${Date.now()}`,
            platform,
            startAt: startTimeStr,
            endAt: endTime.toISOString(),
            actualDuration,
            actualDurationText: formatDuration(actualDuration),
            compensationGiven: compensationDuration,
            compensationText: `+${formatDuration(compensationDuration)}`,
            usersCompensated: compensatedUsers.length,
            usersList: compensatedUsers.slice(0, 50)
        };

        const historyData = await redisClient.get(config.historyKey);
        let history = historyData ? JSON.parse(historyData) : [];
        history.unshift(historyEntry);
        history = history.slice(0, COMPENSATION_CONFIG.MAX_HISTORY_ENTRIES);
        await redisClient.set(config.historyKey, JSON.stringify(history));

        // Clear maintenance start
        await redisClient.del(config.maintenanceKey);

        // Set status to online
        await redisClient.set(config.statusKey, JSON.stringify({ status: 'online', message: 'All systems operational', lastUpdated: endTime.toISOString() }));

        // Send Discord webhook
        const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
        if (webhookUrl) {
            try {
                await fetch(webhookUrl, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        embeds: [{
                            title: '✅ MAINTENANCE COMPLETED',
                            color: 0x00E676,
                            fields: [
                                { name: '📍 Platform', value: config.label, inline: true },
                                { name: '⏱️ Duration', value: formatDuration(actualDuration), inline: true },
                                { name: '🎁 Compensation', value: `+${formatDuration(compensationDuration)}`, inline: true },
                                { name: '👥 Users', value: `${compensatedUsers.length} users`, inline: true }
                            ],
                            timestamp: new Date().toISOString()
                        }]
                    })
                });
            } catch (e) { console.error('[Discord] Webhook error:', e.message); }
        }

        console.log(`[Maintenance] ✅ ${platform.toUpperCase()} ended. ${compensatedUsers.length} users compensated`);

        return res.status(200).json({
            success: true,
            platform,
            actualDuration,
            actualDurationText: formatDuration(actualDuration),
            compensationGiven: compensationDuration,
            compensationText: `+${formatDuration(compensationDuration)}`,
            usersCompensated: compensatedUsers.length,
            message: `Maintenance ended. ${compensatedUsers.length} users received +${formatDuration(compensationDuration)}`
        });
    }

    return res.status(400).json({ error: 'Invalid request' });
}

