// Proxy API for Roblox User validation (bypasses CORS)
// Also supports VIP status check with ?checkVip=true&platform=mobile

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

export default async function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { userId, username, checkVip, platform = 'mobile' } = req.query;

    // ============ VIP CHECK MODE ============
    if (checkVip === 'true' && userId) {
        try {
            const redisClient = await getRedis();
            if (!redisClient) {
                return res.status(503).json({ error: 'Database unavailable' });
            }

            if (!['mobile', 'pc'].includes(platform)) {
                return res.status(400).json({ error: 'Invalid platform' });
            }

            const config = PLATFORM_CONFIG[platform];
            const whitelistData = await redisClient.get(config.whitelistKey);
            const whitelist = whitelistData ? JSON.parse(whitelistData) : {};

            const user = whitelist[userId];

            if (!user) {
                return res.status(200).json({
                    found: false,
                    isVip: false,
                    message: 'User not found in VIP list'
                });
            }

            // Check if expired
            let isExpired = false;
            let daysRemaining = null;

            if (user.expiresAt) {
                const expiryDate = new Date(user.expiresAt);
                const now = new Date();
                isExpired = expiryDate < now;

                if (!isExpired) {
                    daysRemaining = Math.ceil((expiryDate - now) / (1000 * 60 * 60 * 24));
                }
            }

            return res.status(200).json({
                found: true,
                isVip: user.status === 'active' && !isExpired,
                userId: user.userId,
                username: user.username,
                platform: user.platform,
                duration: user.duration,
                status: isExpired ? 'expired' : user.status,
                addedAt: user.addedAt,
                updatedAt: user.updatedAt,
                expiresAt: user.expiresAt,
                daysRemaining: user.expiresAt ? (isExpired ? 0 : daysRemaining) : 'lifetime',
                isLifetime: !user.expiresAt,
                // Include purchase history for renewal detection
                purchaseHistory: user.purchaseHistory || []
            });

        } catch (error) {
            console.error('Check VIP error:', error);
            return res.status(500).json({ error: 'Internal server error' });
        }
    }

    // ============ ROBLOX USER LOOKUP MODE ============
    try {
        let userData = null;

        // If userId is provided, fetch by ID
        if (userId) {
            const response = await fetch(`https://users.roblox.com/v1/users/${userId}`);

            if (!response.ok) {
                return res.status(404).json({ error: 'User not found' });
            }

            userData = await response.json();
        }
        // If username is provided, search by username
        else if (username) {
            // First try exact match
            const searchResponse = await fetch(
                `https://users.roblox.com/v1/usernames/users`,
                {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        usernames: [username],
                        excludeBannedUsers: true
                    })
                }
            );

            if (searchResponse.ok) {
                const searchData = await searchResponse.json();
                if (searchData.data && searchData.data.length > 0) {
                    const foundUser = searchData.data[0];
                    // Fetch full user data
                    const userResponse = await fetch(`https://users.roblox.com/v1/users/${foundUser.id}`);
                    if (userResponse.ok) {
                        userData = await userResponse.json();
                    }
                }
            }

            if (!userData) {
                return res.status(404).json({ error: 'User not found' });
            }
        }
        else {
            return res.status(400).json({ error: 'userId or username required' });
        }

        // Fetch avatar thumbnail URL from Roblox Thumbnails API
        let avatarUrl = null;
        try {
            const thumbnailResponse = await fetch(
                `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userData.id}&size=150x150&format=Png&isCircular=false`
            );

            if (thumbnailResponse.ok) {
                const thumbnailData = await thumbnailResponse.json();
                if (thumbnailData.data && thumbnailData.data.length > 0) {
                    avatarUrl = thumbnailData.data[0].imageUrl;
                }
            }
        } catch (e) {
            console.error('Failed to fetch avatar:', e);
        }

        // Fallback avatar if thumbnails API fails
        if (!avatarUrl) {
            avatarUrl = `https://tr.rbxcdn.com/30DAY-AvatarHeadshot-${userData.id}-150x150.png`;
        }

        // Return user data with avatar URL
        return res.status(200).json({
            id: userData.id,
            name: userData.name,
            displayName: userData.displayName,
            avatar: avatarUrl
        });

    } catch (error) {
        console.error('Roblox API error:', error);
        return res.status(500).json({ error: 'Failed to fetch user data' });
    }
}
