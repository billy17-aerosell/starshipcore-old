/**
 * Cloudflare Worker - StarshipCore PC Modules CDN
 * 
 * This worker serves PC assets from R2 (including the bundled file `/b/pc.json`)
 * with signed token validation and SINGLE-USE token support.
 * Only authorized requests (token issued by your Vercel API after auth) can access it.
 * 
 * SETUP:
 * 1. Create this worker in Cloudflare Dashboard
 * 2. Bind R2 bucket as "STARSHIP_BUCKET"
 * 3. Add environment variables:
 *    - CDN_SECRET_KEY (same as Vercel)
 *    - UPSTASH_REDIS_REST_URL (from Upstash dashboard)
 *    - UPSTASH_REDIS_REST_TOKEN (from Upstash dashboard)
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

        // Validate token signature and expiry
        const validation = await validateToken(token, secretKey);

        if (!validation.valid) {
            console.log(`Token validation failed: ${validation.reason}`);
            return new Response(`-- ERROR: ${validation.reason}\nerror("${validation.reason}")`, {
                status: 403,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // ═══════════════════════════════════════════════════════════════
        // SINGLE-USE TOKEN: Verify token exists in Redis, then delete it
        // ═══════════════════════════════════════════════════════════════
        if (validation.tokenId && env.UPSTASH_REDIS_REST_URL && env.UPSTASH_REDIS_REST_TOKEN) {
            const tokenKey = `cdn_token:${validation.tokenId}`;
            
            // Check if token exists and delete it (atomic GET + DEL)
            const singleUseResult = await verifySingleUseToken(
                tokenKey,
                env.UPSTASH_REDIS_REST_URL,
                env.UPSTASH_REDIS_REST_TOKEN
            );
            
            if (!singleUseResult.valid) {
                console.log(`Single-use token rejected: ${singleUseResult.reason} - TokenID: ${validation.tokenId.substring(0, 8)}...`);
                return new Response(`-- ERROR: ${singleUseResult.reason}\nerror("${singleUseResult.reason}")`, {
                    status: 403,
                    headers: { 'Content-Type': 'text/plain', ...corsHeaders }
                });
            }
            
            console.log(`[Single-Use] Token consumed: ${validation.tokenId.substring(0, 8)}... for user ${validation.userId}`);
        }

        // Only allow PC platform
        if (validation.platform !== 'pc') {
            return new Response('-- ERROR: This endpoint is for PC only\nerror("PC modules only")', {
                status: 403,
                headers: { 'Content-Type': 'text/plain', ...corsHeaders }
            });
        }

        // Determine file path
        // URL format: /b/pc.json or /StarshipCore.lua or /Modules/UI.lua
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

            // Determine content type based on file
            const contentType = filePath.endsWith('.json') 
                ? 'application/json; charset=utf-8'
                : 'text/plain; charset=utf-8';

            return new Response(content, {
                status: 200,
                headers: {
                    'Content-Type': contentType,
                    'Cache-Control': 'no-store, no-cache, must-revalidate', // No caching for single-use
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
 * Token format: base64(JSON{userId, platform, exp, tokenId, sig})
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

        // Verify signature (include tokenId if present)
        const dataToSign = decoded.tokenId 
            ? `${decoded.userId}:${decoded.platform}:${decoded.exp}:${decoded.tokenId}`
            : `${decoded.userId}:${decoded.platform}:${decoded.exp}`;
        const expectedSig = await hmacSign(dataToSign, secretKey);

        if (decoded.sig !== expectedSig) {
            return { valid: false, reason: 'Invalid signature' };
        }

        return {
            valid: true,
            userId: decoded.userId,
            platform: decoded.platform,
            exp: decoded.exp,
            tokenId: decoded.tokenId || null
        };
    } catch (error) {
        console.error(`Token validation error: ${error.message}`);
        return { valid: false, reason: 'Token validation failed' };
    }
}

/**
 * Verify single-use token exists in Redis and delete it
 * Uses Upstash Redis REST API
 */
async function verifySingleUseToken(tokenKey, redisUrl, redisToken) {
    try {
        // Use GETDEL command (atomic get and delete)
        const response = await fetch(`${redisUrl}/GETDEL/${encodeURIComponent(tokenKey)}`, {
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${redisToken}`
            }
        });

        if (!response.ok) {
            console.error(`Redis error: ${response.status} ${response.statusText}`);
            // If Redis fails, allow the request (fail-open for availability)
            // You can change this to fail-close if security is more important
            return { valid: true, reason: 'Redis unavailable, allowing request' };
        }

        const data = await response.json();
        
        // GETDEL returns null if key doesn't exist
        if (data.result === null) {
            return { valid: false, reason: 'Token already used or invalid' };
        }

        // Token existed and was deleted - valid single-use
        return { valid: true, tokenData: data.result };
    } catch (error) {
        console.error(`Single-use token verification error: ${error.message}`);
        // Fail-open: allow request if Redis is unreachable
        return { valid: true, reason: 'Verification error, allowing request' };
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
