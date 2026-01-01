// Saweria Webhook Handler for Auto-Whitelist VIP Purchases
// Endpoint: /api/saweria-webhook
// This receives payment confirmations from Saweria and automatically adds users to whitelist

// Import Redis helper (same as whitelist-manager)
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
    if (!redisInitAttempted) {
        try {
            const redisModule = await import('../lib/redis.js');
            redis = redisModule.default;
            console.log('✅ Redis module loaded for Saweria webhook');
        } catch (error) {
            console.error('⚠️ Redis module load failed:', error.message);
            redis = null;
        }
        redisInitAttempted = true;
    }
    return redis;
}

// Platform-specific Redis keys
const PLATFORM_CONFIG = {
    pc: {
        whitelistKey: 'starship:whitelist',
        metadataKey: 'starship:metadata',
        defaultType: 'VIP'
    },
    mobile: {
        whitelistKey: 'starship:mobile_whitelist',
        metadataKey: 'starship:mobile_metadata',
        defaultType: 'MOBILE_VIP'
    }
};

// Pricing configuration (must match frontend)
const PRICING = {
    mobile: {
        name: 'Mobile VIP',
        durations: {
            '1d': { label: '1 Day (Test)', price: 1000, days: 1 },
            '3d': { label: '3 Days', price: 5000, days: 3 },
            '7d': { label: '7 Days', price: 10000, days: 7 },
            '14d': { label: '14 Days', price: 25000, days: 14 },
            'lifetime': { label: 'Lifetime', price: 100000, days: null }
        }
    },
    pc: {
        name: 'PC VIP',
        durations: {
            'lifetime': { label: 'Lifetime', price: 250000, days: null }
        }
    },
    bundle: {
        name: 'Bundle (PC + Mobile)',
        durations: {
            'lifetime': { label: 'Lifetime', price: 300000, days: null }
        }
    }
};

// Discord notification helper - Uses separate webhook for VIP purchases
async function sendDiscordNotification(embed) {
    // Use dedicated VIP webhook, fallback to general webhook
    const webhookUrl = process.env.DISCORD_VIP_WEBHOOK_URL || process.env.DISCORD_WEBHOOK_URL;
    if (!webhookUrl) {
        console.log('⚠️ Discord webhook not configured (set DISCORD_VIP_WEBHOOK_URL)');
        return;
    }

    try {
        await fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ embeds: [embed] })
        });
        console.log('✅ Discord VIP notification sent');
    } catch (error) {
        console.error('❌ Discord notification failed:', error.message);
    }
}

// Get username from Roblox API
async function getRobloxUsername(userId) {
    try {
        const response = await fetch(`https://users.roblox.com/v1/users/${userId}`);
        if (response.ok) {
            const data = await response.json();
            return data.name;
        }
    } catch (error) {
        console.error('Failed to fetch Roblox username:', error.message);
    }
    return `User_${userId}`;
}

// Add user to whitelist (with expiry extension for renewals)
async function addToWhitelist(redisClient, platform, userId, username, duration, daysUntilExpiry) {
    const config = PLATFORM_CONFIG[platform];
    
    // Get current whitelist
    const whitelistData = await redisClient.get(config.whitelistKey);
    const whitelist = whitelistData ? JSON.parse(whitelistData) : {};

    // Check if user already exists
    const isExisting = !!whitelist[userId];
    const previousData = whitelist[userId];

    // Calculate expiry date with EXTENSION logic
    let expiresAt = null;
    let extendedDays = 0;
    
    if (daysUntilExpiry) {
        if (isExisting && previousData.expiresAt) {
            const currentExpiry = new Date(previousData.expiresAt);
            const now = new Date();
            
            // If current VIP is still active (not expired), EXTEND from current expiry
            if (currentExpiry > now) {
                expiresAt = new Date(currentExpiry.getTime() + daysUntilExpiry * 24 * 60 * 60 * 1000).toISOString();
                extendedDays = Math.ceil((currentExpiry - now) / (24 * 60 * 60 * 1000));
                console.log(`📅 Extended VIP: ${extendedDays} remaining + ${daysUntilExpiry} new = ${extendedDays + daysUntilExpiry} total days`);
            } else {
                // Expired, start fresh from now
                expiresAt = new Date(Date.now() + daysUntilExpiry * 24 * 60 * 60 * 1000).toISOString();
            }
        } else {
            // New user, start from now
            expiresAt = new Date(Date.now() + daysUntilExpiry * 24 * 60 * 60 * 1000).toISOString();
        }
    } else if (isExisting && previousData.expiresAt) {
        // Lifetime purchase - remove expiry if they had one
        expiresAt = null;
        console.log(`♾️ Upgraded to Lifetime - removed expiry`);
    }

    // Create/Update user entry
    whitelist[userId] = {
        userId,
        username,
        type: config.defaultType,
        status: 'active',
        addedAt: isExisting ? previousData.addedAt : new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        expiresAt: expiresAt,
        duration: duration,
        source: 'saweria_purchase',
        restrictions: {
            maxDevices: platform === 'mobile' ? 2 : 5,
            ipTracking: true,
            webhookNotify: true
        },
        permissions: {
            bypassAll: false,
            unlimitedAccess: duration === 'lifetime',
            noLogging: false
        },
        platform,
        notes: isExisting 
            ? `Renewed via Saweria on ${new Date().toLocaleDateString('id-ID')}${extendedDays > 0 ? ` (+${daysUntilExpiry} days extended)` : ''}`
            : `Auto-whitelisted via Saweria payment on ${new Date().toLocaleDateString('id-ID')}`,
        // Track purchase history
        purchaseHistory: [
            ...(previousData?.purchaseHistory || []),
            {
                date: new Date().toISOString(),
                duration: duration,
                daysAdded: daysUntilExpiry || 'lifetime'
            }
        ]
    };

    // Save to Redis
    await redisClient.set(config.whitelistKey, JSON.stringify(whitelist));

    // Update metadata
    const metadataData = await redisClient.get(config.metadataKey);
    const metadata = metadataData ? JSON.parse(metadataData) : { totalWhitelisted: 0 };
    metadata.totalWhitelisted = Object.keys(whitelist).length;
    metadata.lastUpdated = new Date().toISOString();
    await redisClient.set(config.metadataKey, JSON.stringify(metadata));

    // Return with extended info
    const isExtended = isExisting && extendedDays > 0;
    return { 
        isExisting, 
        isExtended, 
        extendedDays,
        totalDays: isExtended ? extendedDays + (daysUntilExpiry || 0) : daysUntilExpiry,
        user: whitelist[userId] 
    };
}

export default async function handler(req, res) {
    // Allow CORS for webhook
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    // ===== SECURITY CHECKS =====
    
    // 1. Secret Token Check (PRIMARY - Most reliable)
    const WEBHOOK_SECRET = process.env.SAWERIA_WEBHOOK_SECRET;
    const urlToken = req.query.token;
    const hasValidToken = WEBHOOK_SECRET && urlToken === WEBHOOK_SECRET;
    
    // 2. IP Whitelist Check (SECONDARY - for when no secret is configured)
    const SAWERIA_ALLOWED_IPS = [
        '157.230.37.7',     // Saweria Singapore (confirmed)
        '157.230.37.0/24',  // Saweria IP range
    ];
    
    const clientIP = req.headers['x-real-ip'] || 
                     req.headers['x-forwarded-for']?.split(',')[0]?.trim() ||
                     'unknown';
    
    const isAllowedIP = SAWERIA_ALLOWED_IPS.some(ip => {
        if (ip.includes('/')) {
            const baseIP = ip.split('/')[0].split('.').slice(0, 3).join('.');
            return clientIP.startsWith(baseIP);
        }
        return clientIP === ip;
    });

    // SECURITY: Only pass if has valid token OR IP is whitelisted
    // User-Agent is NOT checked because it can be easily spoofed!
    if (!hasValidToken && !isAllowedIP) {
        console.warn(`🚫 BLOCKED webhook attempt - IP: ${clientIP}, Token: ${urlToken ? 'invalid' : 'missing'}`);
        return res.status(403).json({ error: 'Forbidden - Unauthorized source' });
    }

    console.log('📥 Saweria webhook received from:', clientIP);
    console.log('Body:', JSON.stringify(req.body, null, 2));

    try {
        // Saweria webhook payload structure:
        // {
        //   "id": "unique_transaction_id",
        //   "donator_name": "Nama Donatur",
        //   "donator_email": "email@example.com",
        //   "message": "MOBILE:lifetime:9268011358",
        //   "amount_raw": 75000,
        //   "created_at": "2024-01-01T00:00:00Z"
        // }

        const { message, amount_raw, donator_name, id: transactionId } = req.body;

        if (!message) {
            console.error('❌ No message in webhook payload');
            return res.status(400).json({ error: 'Invalid payload: message required' });
        }

        // Parse message format: PLATFORM:DURATION:USERID
        const messageParts = message.split(':');
        if (messageParts.length !== 3) {
            console.error('❌ Invalid message format:', message);
            // Still return 200 to acknowledge receipt (might be a regular donation)
            return res.status(200).json({ 
                success: false, 
                reason: 'Not a VIP purchase message format',
                message: 'Acknowledged but not processed'
            });
        }

        const [platformRaw, duration, userId] = messageParts;
        const platform = platformRaw.toLowerCase();

        // Validate platform
        if (!['mobile', 'pc', 'bundle'].includes(platform)) {
            console.error('❌ Invalid platform:', platform);
            return res.status(200).json({ 
                success: false, 
                reason: 'Invalid platform',
                platform 
            });
        }

        // Validate duration exists for platform
        const pricingConfig = PRICING[platform];
        if (!pricingConfig || !pricingConfig.durations[duration]) {
            console.error('❌ Invalid duration for platform:', platform, duration);
            return res.status(200).json({ 
                success: false, 
                reason: 'Invalid duration for platform',
                platform,
                duration
            });
        }

        const durationConfig = pricingConfig.durations[duration];
        const expectedPrice = durationConfig.price;

        // Validate amount (with 5% tolerance for payment fees)
        const minAmount = expectedPrice * 0.95;
        if (amount_raw < minAmount) {
            console.error(`❌ Amount too low: ${amount_raw} < ${minAmount}`);
            
            // Send Discord alert for underpayment
            await sendDiscordNotification({
                title: '⚠️ Underpayment Detected',
                color: 0xff9800,
                fields: [
                    { name: 'User ID', value: userId, inline: true },
                    { name: 'Platform', value: platform.toUpperCase(), inline: true },
                    { name: 'Duration', value: durationConfig.label, inline: true },
                    { name: 'Expected', value: `Rp ${expectedPrice.toLocaleString()}`, inline: true },
                    { name: 'Received', value: `Rp ${amount_raw.toLocaleString()}`, inline: true },
                    { name: 'Donator', value: donator_name || 'Unknown', inline: true }
                ],
                timestamp: new Date().toISOString()
            });

            return res.status(200).json({ 
                success: false, 
                reason: 'Underpayment',
                expected: expectedPrice,
                received: amount_raw
            });
        }

        // Validate userId is numeric
        if (!/^\d+$/.test(userId)) {
            console.error('❌ Invalid userId:', userId);
            return res.status(200).json({ 
                success: false, 
                reason: 'Invalid userId format',
                userId
            });
        }

        // Get Redis client
        const redisClient = await getRedis();
        if (!redisClient) {
            console.error('❌ Redis not available');
            
            // Send Discord alert
            await sendDiscordNotification({
                title: '🔴 Payment Received - Manual Action Required',
                color: 0xff0000,
                description: 'Redis is unavailable. Please add user manually.',
                fields: [
                    { name: 'User ID', value: userId, inline: true },
                    { name: 'Platform', value: platform.toUpperCase(), inline: true },
                    { name: 'Duration', value: durationConfig.label, inline: true },
                    { name: 'Amount', value: `Rp ${amount_raw.toLocaleString()}`, inline: true },
                    { name: 'Donator', value: donator_name || 'Unknown', inline: true },
                    { name: 'Transaction', value: transactionId || 'N/A', inline: true }
                ],
                timestamp: new Date().toISOString()
            });

            return res.status(503).json({ 
                error: 'Redis unavailable',
                message: 'Payment received but whitelist update failed. Admin notified.'
            });
        }

        // Get Roblox username
        const username = await getRobloxUsername(userId);

        // Handle bundle (add to both PC and Mobile)
        if (platform === 'bundle') {
            // Add to Mobile
            const mobileResult = await addToWhitelist(
                redisClient, 'mobile', userId, username, duration, durationConfig.days
            );
            
            // Add to PC
            const pcResult = await addToWhitelist(
                redisClient, 'pc', userId, username, duration, durationConfig.days
            );

            console.log(`✅ Bundle VIP added: ${username} (${userId})`);

            // Send Discord notification
            await sendDiscordNotification({
                title: '🎁 New Bundle VIP Purchase!',
                color: 0x4caf50,
                thumbnail: { url: `https://www.roblox.com/headshot-thumbnail/image?userId=${userId}&width=150&height=150&format=png` },
                fields: [
                    { name: 'Username', value: username, inline: true },
                    { name: 'User ID', value: userId, inline: true },
                    { name: 'Package', value: 'Bundle (PC + Mobile)', inline: true },
                    { name: 'Duration', value: durationConfig.label, inline: true },
                    { name: 'Amount', value: `Rp ${amount_raw.toLocaleString()}`, inline: true },
                    { name: 'Donator', value: donator_name || 'Anonymous', inline: true },
                    { name: 'Status', value: (mobileResult.isExtended || pcResult.isExtended) 
                        ? `📅 Extended (+${mobileResult.extendedDays || pcResult.extendedDays} days remaining)`
                        : (mobileResult.isExisting || pcResult.isExisting) ? '🔄 Renewed' : '🆕 New VIP', inline: true }
                ],
                footer: { text: `Transaction: ${transactionId || 'N/A'}` },
                timestamp: new Date().toISOString()
            });

            return res.status(200).json({
                success: true,
                message: 'Bundle VIP activated',
                userId,
                username,
                platforms: ['mobile', 'pc'],
                duration: durationConfig.label,
                expiresAt: durationConfig.days 
                    ? new Date(Date.now() + durationConfig.days * 24 * 60 * 60 * 1000).toISOString()
                    : null
            });
        }

        // Single platform (Mobile or PC)
        const result = await addToWhitelist(
            redisClient, platform, userId, username, duration, durationConfig.days
        );

        console.log(`✅ ${platform.toUpperCase()} VIP added: ${username} (${userId})`);

        // Determine status text
        let statusText = '🆕 New VIP';
        if (result.isExtended) {
            statusText = `📅 Extended (+${result.extendedDays} days → ${result.totalDays} total)`;
        } else if (result.isExisting) {
            statusText = '🔄 Renewed';
        }

        // Send Discord notification
        const platformEmoji = platform === 'mobile' ? '📱' : '💻';
        await sendDiscordNotification({
            title: `${platformEmoji} New ${platform.toUpperCase()} VIP Purchase!`,
            color: platform === 'mobile' ? 0x2196f3 : 0x9c27b0,
            thumbnail: { url: `https://www.roblox.com/headshot-thumbnail/image?userId=${userId}&width=150&height=150&format=png` },
            fields: [
                { name: 'Username', value: username, inline: true },
                { name: 'User ID', value: userId, inline: true },
                { name: 'Platform', value: platform.toUpperCase(), inline: true },
                { name: 'Duration', value: durationConfig.label, inline: true },
                { name: 'Amount', value: `Rp ${amount_raw.toLocaleString()}`, inline: true },
                { name: 'Donator', value: donator_name || 'Anonymous', inline: true },
                { name: 'Status', value: statusText, inline: true }
            ],
            footer: { text: `Transaction: ${transactionId || 'N/A'}` },
            timestamp: new Date().toISOString()
        });

        return res.status(200).json({
            success: true,
            message: `${platform.toUpperCase()} VIP activated`,
            userId,
            username,
            platform,
            duration: durationConfig.label,
            expiresAt: durationConfig.days 
                ? new Date(Date.now() + durationConfig.days * 24 * 60 * 60 * 1000).toISOString()
                : null,
            isRenewal: result.isExisting
        });

    } catch (error) {
        console.error('❌ Webhook processing error:', error);

        // Send Discord error notification
        await sendDiscordNotification({
            title: '🔴 Webhook Processing Error',
            color: 0xff0000,
            description: error.message,
            fields: [
                { name: 'Raw Body', value: `\`\`\`${JSON.stringify(req.body).substring(0, 500)}\`\`\`` }
            ],
            timestamp: new Date().toISOString()
        });

        return res.status(500).json({ 
            error: 'Webhook processing failed',
            message: error.message 
        });
    }
}
