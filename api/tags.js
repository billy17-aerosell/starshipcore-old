// Discord VIP Verification API
// Usage: POST /api/tags with { robloxId, discordId, action: 'verify' }
// Returns VIP status and can trigger role assignment

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
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method Not Allowed' });
    }

    const { robloxId, discordId, action, code, redirectUri } = req.body;

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
