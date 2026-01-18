/**
 * Cloudflare Worker - StarshipCore PC Modules CDN
 * 
 * This worker serves PC assets from R2 (including the bundled file `/b/pc.json`)
 * with signed token validation.
 * Only authorized requests (token issued by your Vercel API after auth) can access it.
 * 
 * SETUP:
 * 1. Create this worker in Cloudflare Dashboard
 * 2. Bind R2 bucket as "STARSHIP_BUCKET"
 * 3. Add environment variable "CDN_SECRET_KEY" (same as Vercel)
 */

export default {
    async fetch(request, env) {
        const url = new URL(request.url);
        const path = url.pathname;

        // CORS headers for Roblox HTTP requests
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Authorization, X-Token, X-StarshipCore',
        };

        // Handle preflight OPTIONS request
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }

        // Only allow GET requests
        if (request.method !== 'GET') {
            return new Response('-- ERROR: Method not allowed\nerror("Method not allowed")', {
                status: 405,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // Get token from query parameter or header
        const token = url.searchParams.get('token') || request.headers.get('X-Token');

        if (!token) {
            return new Response('-- ERROR: Missing authorization token\nerror("Unauthorized: Missing token")', {
                status: 401,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // Validate token
        const secretKey = env.CDN_SECRET_KEY;
        if (!secretKey) {
            console.error('CDN_SECRET_KEY not configured');
            return new Response('-- ERROR: Server configuration error\nerror("Server error")', {
                status: 500,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        const validation = await validateToken(token, secretKey);

        if (!validation.valid) {
            console.log(`Token validation failed: ${validation.reason}`);
            return new Response(`-- ERROR: ${validation.reason}\nerror("${validation.reason}")`, {
                status: 403,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // Only allow PC platform
        if (validation.platform !== 'pc') {
            return new Response('-- ERROR: This endpoint is for PC only\nerror("PC modules only")', {
                status: 403,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // Determine file path
        // URL format: /StarshipCore.lua or /Modules/UI.lua
        let filePath = path.startsWith('/') ? path.slice(1) : path;

        // Default to main script if no path specified
        if (!filePath || filePath === '' || filePath === 'main') {
            filePath = 'StarshipCore.lua';
        }

        // Prepend 'pc/' prefix for R2 storage structure
        const r2Path = `pc/${filePath}`;

        // Get file from R2
        try {
            const object = await env.STARSHIP_BUCKET.get(r2Path);

            if (!object) {
                console.log(`File not found: ${r2Path}`);
                return new Response(`-- ERROR: Module not found: ${filePath}\nerror("Module not found: ${filePath}")`, {
                    status: 404,
                    headers: { 'Content-Type': 'text/plain', ...corsHeaders }
                });
            }

            const content = await object.text();

            // Log successful access
            console.log(`[${new Date().toISOString()}] ✅ Served: ${filePath} to User: ${validation.userId}`);

            return new Response(content, {
                status: 200,
                headers: {
                    'Content-Type': 'text/plain; charset=utf-8',
                    'Cache-Control': 'private, max-age=3600', // Cache 1 hour on client
                    'X-StarshipCore': 'pc-module',
                    'X-Module': filePath,
                    ...corsHeaders
                }
            });
        } catch (error) {
            console.error(`R2 error: ${error.message}`);
            return new Response(`-- ERROR: Failed to load module\nerror("Server error: ${error.message}")`, {
                status: 500,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }
    }
};

/**
 * Validate signed token from Vercel
 * Token format: base64(JSON{userId, platform, exp, sig})
 */
async function validateToken(token, secretKey) {
    try {
        // Decode base64 token
        let decoded;
        try {
            decoded = JSON.parse(atob(token));
        } catch (e) {
            return { valid: false, reason: 'Invalid token format' };
        }

        // Check required fields
        if (!decoded.userId || !decoded.platform || !decoded.exp || !decoded.sig) {
            return { valid: false, reason: 'Incomplete token' };
        }

        // Check expiry
        if (Date.now() > decoded.exp) {
            return { valid: false, reason: 'Token expired' };
        }

        // Verify signature
        const dataToSign = `${decoded.userId}:${decoded.platform}:${decoded.exp}`;
        const expectedSig = await hmacSign(dataToSign, secretKey);

        if (decoded.sig !== expectedSig) {
            return { valid: false, reason: 'Invalid signature' };
        }

        return {
            valid: true,
            userId: decoded.userId,
            platform: decoded.platform,
            exp: decoded.exp
        };
    } catch (error) {
        console.error(`Token validation error: ${error.message}`);
        return { valid: false, reason: 'Token validation failed' };
    }
}

/**
 * Generate HMAC-SHA256 signature
 */
async function hmacSign(data, secret) {
    const encoder = new TextEncoder();

    const key = await crypto.subtle.importKey(
        'raw',
        encoder.encode(secret),
        { name: 'HMAC', hash: 'SHA-256' },
        false,
        ['sign']
    );

    const signature = await crypto.subtle.sign(
        'HMAC',
        key,
        encoder.encode(data)
    );

    // Convert to base64
    return btoa(String.fromCharCode(...new Uint8Array(signature)));
}
