// Test Webhook Endpoint - Simulates Saweria Payment
// Endpoint: /api/test-webhook
// 
// USAGE:
// GET /api/test-webhook?platform=mobile&duration=lifetime&userId=9268011358
// 
// This will simulate a Saweria payment and trigger the whitelist process
// FOR TESTING ONLY - Remove or secure in production!

export default async function handler(req, res) {
    // Only allow in development or with admin secret
    const isDev = process.env.NODE_ENV !== 'production';
    const adminSecret = req.headers['x-admin-secret'] || req.query.secret;
    const isAuthorized = isDev || adminSecret === process.env.ADMIN_SECRET;

    if (!isAuthorized) {
        return res.status(403).json({ 
            error: 'Forbidden',
            message: 'Test endpoint only available in development or with admin secret',
            hint: 'Add ?secret=YOUR_ADMIN_SECRET or x-admin-secret header'
        });
    }

    // Get test parameters
    const { platform = 'mobile', duration = 'lifetime', userId } = req.query;

    if (!userId) {
        return res.status(400).json({
            error: 'userId required',
            usage: '/api/test-webhook?platform=mobile&duration=lifetime&userId=YOUR_ROBLOX_ID',
            example: '/api/test-webhook?platform=mobile&duration=lifetime&userId=9268011358',
            availablePlatforms: ['mobile', 'pc', 'bundle'],
            availableDurations: {
                mobile: ['7d', '14d', '30d', 'lifetime'],
                pc: ['lifetime'],
                bundle: ['lifetime']
            }
        });
    }

    // Pricing configuration
    const PRICING = {
        mobile: {
            '7d': 25000,
            '14d': 40000,
            '30d': 65000,
            'lifetime': 75000
        },
        pc: {
            'lifetime': 250000
        },
        bundle: {
            'lifetime': 300000
        }
    };

    // Validate platform and duration
    if (!PRICING[platform]) {
        return res.status(400).json({ 
            error: 'Invalid platform',
            valid: ['mobile', 'pc', 'bundle']
        });
    }

    if (!PRICING[platform][duration]) {
        return res.status(400).json({ 
            error: 'Invalid duration for platform',
            platform,
            validDurations: Object.keys(PRICING[platform])
        });
    }

    const amount = PRICING[platform][duration];

    // Create mock Saweria webhook payload
    const mockPayload = {
        id: `TEST_${Date.now()}`,
        donator_name: 'Test User',
        donator_email: 'test@example.com',
        message: `${platform.toUpperCase()}:${duration}:${userId}`,
        amount_raw: amount,
        created_at: new Date().toISOString()
    };

    console.log('🧪 Test webhook triggered');
    console.log('Mock payload:', mockPayload);

    // Get the base URL
    const protocol = req.headers['x-forwarded-proto'] || 'http';
    const host = req.headers.host || 'localhost:3000';
    const webhookUrl = `${protocol}://${host}/api/saweria-webhook`;

    try {
        // Call the actual webhook handler
        const response = await fetch(webhookUrl, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(mockPayload)
        });

        const result = await response.json();

        return res.status(200).json({
            testMode: true,
            message: '🧪 Test webhook executed',
            mockPayload,
            webhookUrl,
            webhookResponse: result
        });

    } catch (error) {
        return res.status(500).json({
            error: 'Test webhook failed',
            message: error.message,
            mockPayload
        });
    }
}
