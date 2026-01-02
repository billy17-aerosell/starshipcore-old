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
    pc: { whitelistKey: 'starship:whitelist' },
    mobile: { whitelistKey: 'starship:mobile_whitelist' }
};

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

// In-memory status fallback
let currentStatus = {
    status: 'online',
    message: 'All systems operational',
    lastUpdated: new Date().toISOString(),
    discordMessageId: null
};

async function getStatus() {
    const redisClient = await getRedis();
    if (redisClient) {
        try {
            const data = await redisClient.get('starship:status');
            if (data) return JSON.parse(data);
        } catch (e) {
            console.error('Redis get status error:', e);
        }
    }
    return currentStatus;
}

async function saveStatus(status) {
    currentStatus = status;
    const redisClient = await getRedis();
    if (redisClient) {
        try {
            await redisClient.set('starship:status', JSON.stringify(status));
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

// Channel name formats for each status
const STATUS_CHANNEL_NAMES = {
    online: '🔒 🟢 | LIVE',
    maintenance: '🔒 🟠 | MAINTENANCE',
    offline: '🔒 🔴 | OFFLINE',
    degraded: '🔒 🟡 | DEGRADED',
    updating: '🔒 🔵 | UPDATING'
};

// Rename Discord channel to show status (like voice channel with lock)
async function updateDiscordChannelName(status) {
    const botToken = process.env.DISCORD_BOT_TOKEN;
    const channelId = process.env.DISCORD_STATUS_CHANNEL_ID;
    
    console.log('[Status] Attempting channel rename...');
    console.log('[Status] Channel ID:', channelId ? channelId.substring(0, 6) + '...' : 'NOT SET');
    console.log('[Status] Bot Token:', botToken ? 'SET (' + botToken.length + ' chars)' : 'NOT SET');
    
    if (!botToken || !channelId) {
        console.log('[Status] Discord channel rename skipped: missing BOT_TOKEN or STATUS_CHANNEL_ID');
        return false;
    }
    
    const channelName = STATUS_CHANNEL_NAMES[status] || STATUS_CHANNEL_NAMES.online;
    console.log('[Status] Target channel name:', channelName);
    
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
            console.log(`[Status] ✅ Discord channel renamed to: ${channelName}`);
            return true;
        } else {
            const error = await response.text();
            console.error('[Status] ❌ Failed to rename Discord channel:', error);
            console.error('[Status] Response status:', response.status);
            return false;
        }
    } catch (e) {
        console.error('[Status] Discord channel rename error:', e);
        return false;
    }
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
        const status = await getStatus();
        const statusInfo = STATUS_TYPES[status.status] || STATUS_TYPES.online;
        
        return res.status(200).json({
            success: true,
            status: status.status,
            label: statusInfo.label,
            emoji: statusInfo.emoji,
            color: statusInfo.color,
            message: status.message,
            description: statusInfo.description,
            lastUpdated: status.lastUpdated
        });
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    const { robloxId, discordId, action, code, redirectUri, status, message } = req.body;

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

        // Update Discord webhook (send embed message)
        const discordWebhookUrl = process.env.DISCORD_STATUS_WEBHOOK_URL;
        let discordMessageId = null;
        
        if (discordWebhookUrl) {
            discordMessageId = await sendDiscordStatusUpdate(status, message, discordWebhookUrl);
        }

        // Update Discord channel name (🔒 🟢 | LIVE format)
        const channelUpdated = await updateDiscordChannelName(status);

        const newStatus = {
            status,
            message: message || STATUS_TYPES[status].description,
            lastUpdated: new Date().toISOString(),
            discordMessageId
        };
        
        await saveStatus(newStatus);
        const statusInfo = STATUS_TYPES[status];
        
        return res.status(200).json({
            success: true,
            status: newStatus.status,
            label: statusInfo.label,
            emoji: statusInfo.emoji,
            message: newStatus.message,
            lastUpdated: newStatus.lastUpdated,
            discordWebhookUpdated: !!discordMessageId,
            discordChannelUpdated: channelUpdated,
            channelName: STATUS_CHANNEL_NAMES[status]
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
            // Exchange code for access token
            const tokenResponse = await fetch('https://discord.com/api/oauth2/token', {
                method: 'POST',
                headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
                body: new URLSearchParams({
                    client_id: CLIENT_ID,
                    client_secret: CLIENT_SECRET,
                    grant_type: 'authorization_code',
                    code: code,
                    redirect_uri: redirectUri
                })
            });

            const tokenData = await tokenResponse.json();

            if (!tokenData.access_token) {
                console.error('Token error:', tokenData);
                return res.status(400).json({ success: false, error: 'Failed to get access token' });
            }

            // Get user info
            const userResponse = await fetch('https://discord.com/api/users/@me', {
                headers: { 'Authorization': `Bearer ${tokenData.access_token}` }
            });

            const user = await userResponse.json();

            if (!user.id) {
                return res.status(400).json({ success: false, error: 'Failed to get user info' });
            }

            return res.status(200).json({
                success: true,
                user: {
                    id: user.id,
                    username: user.global_name || user.username,
                    avatar: user.avatar
                }
            });
        } catch (error) {
            console.error('OAuth error:', error);
            return res.status(500).json({ success: false, error: 'OAuth failed' });
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

    return res.status(400).json({ error: 'Invalid request' });
}

