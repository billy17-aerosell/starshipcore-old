// Unified Get Loader API - Serves protected loader scripts after authentication
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// With Discord Webhook Logging Integration and device tracking

// Owner userId - bypasses cross-platform restrictions
const OWNER_USER_ID = "9268011358";

import fs from "fs";
import path from "path";
import crypto from "crypto";

// Event Code System API (from environment variable for security)
const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";

// ══════════════════════════════════════════════════════════════════
// CLOUDFLARE CDN CONFIGURATION (PC ONLY)
// ══════════════════════════════════════════════════════════════════
const CDN_SECRET_KEY = process.env.CDN_SECRET_KEY || "";
const CDN_BASE_URL = process.env.CDN_PC_URL || ""; // e.g., https://starship-pc-modules.YOUR_SUBDOMAIN.workers.dev
const CDN_TOKEN_EXPIRY_MS = 60 * 60 * 1000; // 1 hour

/**
 * Generate signed token for Cloudflare CDN access (PC only)
 * Token is verified by Cloudflare Worker before serving modules
 */
function generateCDNToken(userId, platform) {
  if (!CDN_SECRET_KEY) {
    return null;
  }

  const exp = Date.now() + CDN_TOKEN_EXPIRY_MS;
  const dataToSign = `${userId}:${platform}:${exp}`;

  const sig = crypto
    .createHmac("sha256", CDN_SECRET_KEY)
    .update(dataToSign)
    .digest("base64");

  const token = Buffer.from(JSON.stringify({
    userId,
    platform,
    exp,
    sig
  })).toString("base64");

  return token;
}

/**
 * Check if CDN is configured for PC modules
 */
function isCDNEnabled() {
  return CDN_SECRET_KEY && CDN_BASE_URL;
}

// Check if user has active event access from Google Sheets
async function checkEventAccess(userId) {
  // Skip if EVENT_CODE_API not configured
  if (!EVENT_CODE_API) {
    return { hasAccess: false };
  }

  try {
    const apiUrl = `${EVENT_CODE_API}?action=check&userId=${userId}`;
    const response = await fetch(apiUrl);
    const data = await response.json();

    if (data.success && data.hasAccess) {
      return {
        hasAccess: true,
        codeUsed: data.codeUsed,
        expiresAt: data.expiresAt,
        remainingDays: data.remainingDays,
      };
    }
    return { hasAccess: false, isBanned: data.isBanned || false };
  } catch (error) {
    console.error("Event code check error:", error.message);
    return { hasAccess: false };
  }
}

// Check if user is banned in Google Sheets
async function checkUserBanned(userId) {
  if (!EVENT_CODE_API) {
    return { isBanned: false };
  }

  try {
    const apiUrl = `${EVENT_CODE_API}?action=check&userId=${userId}`;
    const response = await fetch(apiUrl);
    const data = await response.json();

    return {
      isBanned: data.isBanned || false,
      reason: data.banReason || "Banned by administrator"
    };
  } catch (error) {
    console.error("Ban check error:", error.message);
    return { isBanned: false };
  }
}

// Get Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded for get-loader");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// ══════════════════════════════════════════════════════════════════
// HWID MANAGEMENT FUNCTIONS
// ══════════════════════════════════════════════════════════════════

// Check if HWID binding is enabled
function isHWIDEnabled() {
  return process.env.HWID_ENABLED === "true";
}

// Get stored HWID for a user
async function getStoredHWID(userId, platform) {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const key = `hwid:${platform}:${userId}`;
    const data = await redisClient.get(key);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("[HWID] Error getting stored HWID:", error.message);
    return null;
  }
}

// Store new HWID for a user
async function storeHWID(userId, platform, hwid, username) {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return false;

    const key = `hwid:${platform}:${userId}`;
    const data = {
      hwid: hwid,
      platform: platform,
      userId: userId,
      username: username || "Unknown",
      registeredAt: new Date().toISOString(),
      lastUsed: new Date().toISOString(),
    };

    // Store with no expiry (permanent until reset)
    await redisClient.set(key, JSON.stringify(data));
    console.log(`[HWID] Registered new HWID for ${userId} (${platform})`);
    return true;
  } catch (error) {
    console.error("[HWID] Error storing HWID:", error.message);
    return false;
  }
}

// Validate HWID - returns { valid: boolean, reason: string, storedHWID?, providedHWID? }
async function validateHWID(userId, platform, providedHWID, username) {
  // If HWID binding is disabled, always valid
  if (!isHWIDEnabled()) {
    return { valid: true, reason: "HWID binding disabled" };
  }

  // If no HWID provided, reject (required when enabled)
  if (!providedHWID || providedHWID === "" || providedHWID === "unknown") {
    return { valid: false, reason: "No HWID provided" };
  }

  const storedData = await getStoredHWID(userId, platform);

  // If no stored HWID, this is first login - store and allow
  if (!storedData) {
    const stored = await storeHWID(userId, platform, providedHWID, username);
    if (stored) {
      return { valid: true, reason: "New HWID registered", isNew: true };
    } else {
      // Failed to store but allow anyway (Redis issue)
      return { valid: true, reason: "Redis unavailable, allowing access" };
    }
  }

  // Compare stored HWID with provided
  if (storedData.hwid === providedHWID) {
    // Update last used timestamp
    try {
      const redisClient = await getRedis();
      if (redisClient) {
        storedData.lastUsed = new Date().toISOString();
        const key = `hwid:${platform}:${userId}`;
        await redisClient.set(key, JSON.stringify(storedData));
      }
    } catch (e) { }

    return { valid: true, reason: "HWID match" };
  } else {
    // HWID mismatch - reject!
    return {
      valid: false,
      reason: "HWID mismatch - device tidak dikenali",
      storedHWID: storedData.hwid?.substring(0, 16) + "...",
      providedHWID: providedHWID?.substring(0, 16) + "...",
      registeredAt: storedData.registeredAt,
    };
  }
}

// Platform-specific configuration
// NOTE: Using obfuscated versions for production security
const PLATFORM_CONFIG = {
  pc: {
    whitelistKey: "starship:whitelist",
    otherWhitelistKey: "starship:mobile_whitelist",
    loaderFile: "Loader-obfuscated.lua", // Obfuscated for security
    keysFilePath: path.join(process.cwd(), "data", "keys.json"),
    otherKeysFilePath: path.join(process.cwd(), "data", "mobile-keys.json"),
    label: "💻 PC",
    otherLabel: "📱 MOBILE",
    defaultType: "VIP",
  },
  mobile: {
    whitelistKey: "starship:mobile_whitelist",
    otherWhitelistKey: "starship:whitelist",
    loaderFile: "mobile-loader-obfuscated.lua", // Obfuscated for security
    keysFilePath: path.join(process.cwd(), "data", "mobile-keys.json"),
    otherKeysFilePath: path.join(process.cwd(), "data", "keys.json"),
    label: "📱 Mobile",
    otherLabel: "💻 PC",
    defaultType: "MOBILE_VIP",
  },
};

// Helper to get whitelist from Redis
async function getWhitelistFromRedis(whitelistKey) {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get(whitelistKey);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis whitelist read error:", error.message);
    return null;
  }
}

// Helper function to get client IP
function getClientIP(req) {
  return (
    req.headers["x-forwarded-for"]?.split(",")[0] ||
    req.headers["x-real-ip"] ||
    req.connection?.remoteAddress ||
    "unknown"
  );
}

// Helper function to read keys database
function getKeysData(keysFilePath) {
  try {
    if (!fs.existsSync(keysFilePath)) {
      return { keys: {}, whitelist: {} };
    }
    const data = fs.readFileSync(keysFilePath, "utf8");
    return JSON.parse(data);
  } catch (error) {
    console.error("Error reading keys:", error);
    return { keys: {}, whitelist: {} };
  }
}

// Helper function to send Discord webhook notification
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) {
    console.log("[Discord] Webhook not configured, skipping notification");
    return;
  }

  try {
    const colors = {
      success: 0x00ff00,
      blocked: 0xff0000,
      invalid: 0xffa500,
      warning: 0xffff00,
      crossplatform: 0x9333ea,
    };

    const emojis = {
      success: "🟢",
      blocked: "🔴",
      invalid: "🟠",
      warning: "🟡",
      crossplatform: "🔀",
    };

    const color = colors[logData.status] || 0x808080;
    const emoji = emojis[logData.status] || "⚪";

    const embed = {
      title: `${emoji} ${logData.title || "Access Log"}`,
      color: color,
      fields: [
        {
          name: "👤 User",
          value: logData.owner || "Unknown",
          inline: true,
        },
        {
          name: "🔑 Auth Type",
          value: `\`${logData.authType || "Key"}\``,
          inline: true,
        },
        {
          name: "🌐 IP Address",
          value: `\`${logData.ip}\``,
          inline: true,
        },
        {
          name: "🔐 HWID Status",
          value: logData.hwidStatus || "Protected",
          inline: true,
        },
        {
          name: "📍 Platform",
          value: logData.platform || "PC",
          inline: true,
        },
        {
          name: "✅ Status",
          value: logData.statusMessage || logData.status,
          inline: true,
        },
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: `${logData.platform?.includes("Mobile") ? "📱" : "💻"} StarshipCore Access Monitor`,
      },
    };

    if (logData.message) {
      embed.description = logData.message;
    }

    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });

    if (!response.ok) {
      console.error("[Discord] Failed to send webhook:", response.status);
    } else {
      console.log("[Discord] ✅ Log sent successfully");
    }
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
  }
}

// Send Cross-Platform Detection Alert
async function sendCrossPlatformAlert(alertData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) return;

  try {
    const embed = {
      title: "🔀 Cross-Platform Access Attempt Detected!",
      color: 0x9333ea,
      fields: [
        {
          name: "👤 User",
          value: alertData.username || `UserID: ${alertData.userId}`,
          inline: true,
        },
        {
          name: "🎫 Current License",
          value: `\`${alertData.currentPlatform}\``,
          inline: true,
        },
        {
          name: "🚫 Attempted Access",
          value: `\`${alertData.attemptedPlatform}\``,
          inline: true,
        },
        {
          name: "🌐 IP Address",
          value: `\`${alertData.ip}\``,
          inline: true,
        },
        {
          name: "📅 License Type",
          value: alertData.licenseType || "N/A",
          inline: true,
        },
        {
          name: "⏰ Timestamp",
          value: alertData.timestamp,
          inline: true,
        },
      ],
      description: `⚠️ **${alertData.username || "User"}** has a **${alertData.currentPlatform}** license but tried to access **${alertData.attemptedPlatform}** script!\n\n💡 *Consider offering a bundle upgrade or separate ${alertData.attemptedPlatform} license.*`,
      timestamp: new Date().toISOString(),
      footer: {
        text: "🔀 StarshipCore Cross-Platform Monitor",
      },
    };

    await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });

    console.log("[Discord] ✅ Cross-platform alert sent");
  } catch (error) {
    console.error("[Discord] Cross-platform alert error:", error.message);
  }
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // ══════════════════════════════════════════════════════════════════
  // PUBLIC BUNDLE ENDPOINT (NO EXTRA SERVERLESS FUNCTION)
  // Reached via vercel.json rewrite: /b/pc.json -> /api/pc-ld-q8r4?action=bundle
  // - If Cloudflare CDN is configured, block direct public access to the bundle.
  // - If CDN is NOT configured, serve local bundle (fallback).
  // ══════════════════════════════════════════════════════════════════
  if (req.query.action === "bundle") {
    const cdnEnabled = !!(process.env.CDN_SECRET_KEY && process.env.CDN_PC_URL);
    if (cdnEnabled) {
      res.setHeader("Content-Type", "application/json; charset=utf-8");
      res.setHeader("Cache-Control", "no-store");
      return res.status(404).json({ error: "NOT_FOUND" });
    }

    const bundlePath = path.join(process.cwd(), "public", "b", "pc.json");
    if (!fs.existsSync(bundlePath)) {
      res.setHeader("Content-Type", "application/json; charset=utf-8");
      res.setHeader("Cache-Control", "no-store");
      return res.status(404).json({ error: "NOT_FOUND" });
    }

    const content = fs.readFileSync(bundlePath, "utf8");
    res.setHeader("Content-Type", "application/json; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    return res.status(200).send(content);
  }

  // ══════════════════════════════════════════════════════════════════
  // CDN TOKEN VERIFICATION (Called by Cloudflare Worker)
  // Single-use token: verify token exists in Redis, then delete it
  // ══════════════════════════════════════════════════════════════════
  if (req.query.action === "verify_cdn_token") {
    const tokenId = req.query.tokenId;
    const workerSecret = req.headers["x-worker-secret"];
    
    // Verify worker secret to prevent unauthorized access
    const expectedSecret = process.env.CDN_SECRET_KEY;
    if (!workerSecret || workerSecret !== expectedSecret) {
      return res.status(401).json({ valid: false, reason: "Unauthorized" });
    }
    
    if (!tokenId) {
      return res.status(400).json({ valid: false, reason: "Missing tokenId" });
    }
    
    try {
      const redisClient = await getRedis();
      if (!redisClient) {
        // Redis not available - fail-open (allow request)
        console.log("[CDN Token] Redis unavailable, allowing request");
        return res.status(200).json({ valid: true, reason: "Redis unavailable" });
      }
      
      const tokenKey = `cdn_token:${tokenId}`;
      
      // Get and delete token atomically
      const tokenData = await redisClient.get(tokenKey);
      
      if (!tokenData) {
        // Token doesn't exist - already used or invalid
        console.log(`[CDN Token] Token not found: ${tokenId.substring(0, 8)}...`);
        return res.status(200).json({ valid: false, reason: "Token already used or invalid" });
      }
      
      // Delete the token (single-use)
      await redisClient.del(tokenKey);
      console.log(`[CDN Token] Token consumed: ${tokenId.substring(0, 8)}...`);
      
      return res.status(200).json({ valid: true, tokenData: JSON.parse(tokenData) });
    } catch (error) {
      console.error("[CDN Token] Verification error:", error.message);
      // Fail-open on error
      return res.status(200).json({ valid: true, reason: "Verification error" });
    }
  }

  // Get parameters
  const { key, userId, platform: platformParam, hwid } = req.query;
  const platform = platformParam === "mobile" ? "mobile" : "pc";
  const config = PLATFORM_CONFIG[platform];
  const platformLabel = config.label;

  // Get client information
  const clientIP = getClientIP(req);
  const timestamp = new Date().toISOString();
  const userAgent = req.headers["user-agent"] || "";

  // Browser detection
  const browserPatterns = [
    "Mozilla",
    "Chrome",
    "Safari",
    "Firefox",
    "Edge",
    "Opera",
    "MSIE",
    "Trident",
    "WebKit",
    "Gecko",
  ];

  const robloxPatterns = [
    "Roblox",
    "RobloxApp",
    "RobloxStudio",
    "RobloxPlayer",
    "GameClient",
    "synapse",
    "SYNAPSE_HTTP",
    "krnl",
    "fluxus",
    "arceus",
    "delta",
    "hydrogen",
    "evon",
    "vegax",
    "script-ware",
    "scriptware",
    "comet",
  ];

  const isRobloxExecutor = robloxPatterns.some((pattern) =>
    userAgent.toLowerCase().includes(pattern.toLowerCase()),
  );

  const isBrowser =
    userAgent !== "" &&
    !isRobloxExecutor &&
    browserPatterns.some((pattern) => userAgent.includes(pattern));

  if (isBrowser) {
    console.log(
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED (get-loader ${platform}) | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: `🚨 Browser Access Blocked - ${platformLabel} Loader`,
      status: "blocked",
      owner: "Browser User",
      authType: "None",
      ip: clientIP,
      platform: `${platformLabel} (Blocked)`,
      timestamp: timestamp,
      message: `⚠️ Someone tried to access ${platform} loader from browser!\n\n**User Agent:** \`${userAgent.substring(0, 100)}\``,
    });

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.status(403).send(`
<!DOCTYPE html>
<html>
<head>
    <title>403 - Forbidden</title>
    <style>
        body { font-family: Arial; text-align: center; padding: 50px; background: #0f0f1a; color: #eee; }
        h1 { color: #8b5cf6; }
        .container { max-width: 400px; margin: 0 auto; background: #1a1a2e; padding: 30px; border-radius: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>403 Forbidden</h1>
        <p>This endpoint is for authorized applications only.</p>
    </div>
</body>
</html>
    `);
  }

  // === PRIORITY 1: Check User ID Whitelist (Owner + VIP) ===
  if (userId) {
    // First, check Redis whitelist for this platform
    const redisWhitelist = await getWhitelistFromRedis(config.whitelistKey);

    if (redisWhitelist && redisWhitelist[userId]) {
      const vipUser = redisWhitelist[userId];

      // Check if user is active
      if (vipUser.status === "active") {
        // Check expiry if set
        if (vipUser.expiresAt) {
          const expiryDate = new Date(vipUser.expiresAt);
          if (expiryDate < new Date()) {
            console.log(
              `[${timestamp}] ❌ ${platformLabel} VIP expired - UserID: ${userId} | IP: ${clientIP}`,
            );
            return res
              .status(403)
              .send(
                `-- ERROR: ${platform.toUpperCase()} VIP access expired\n` +
                `-- Expired on: ${expiryDate.toDateString()}\n` +
                `error("${platform.toUpperCase()} VIP access expired")`,
              );
          }
        }

        // VIP user - grant access
        const isOwner = userId === "9268011358";

        // Declare hwidResult before the block so it's accessible later
        let hwidResult = null;

        // === HWID VALIDATION (Skip for owner) ===
        if (!isOwner && isHWIDEnabled()) {
          hwidResult = await validateHWID(userId, platform, hwid, vipUser.username);

          if (!hwidResult.valid) {
            console.log(
              `[${timestamp}] 🚫 HWID MISMATCH - UserID: ${userId} | Platform: ${platform} | Reason: ${hwidResult.reason}`,
            );

            await sendDiscordLog({
              title: `🚫 PC HWID Mismatch Detected`,
              status: "blocked",
              statusMessage: "❌ Device tidak dikenali",
              authType: `${vipUser.type || config.defaultType} (HWID Blocked)`,
              owner: `${vipUser.username} (${userId})`,
              ip: clientIP,
              platform: platformLabel,
              hwidStatus: "❌ MISMATCH",
              timestamp: timestamp,
              message: `⚠️ **Possible account sharing detected!**\n\n**Reason:** ${hwidResult.reason}\n**Stored HWID:** ${hwidResult.storedHWID || "N/A"}\n**Provided HWID:** ${hwidResult.providedHWID || "N/A"}\n**Registered:** ${hwidResult.registeredAt || "N/A"}`,
            });

            res.setHeader("Content-Type", "text/plain; charset=utf-8");
            return res.status(403).send(
              `-- ERROR: Device tidak dikenali\n` +
              `-- Akun ini terdaftar di perangkat lain.\n` +
              `-- Hubungi admin untuk reset HWID jika ini adalah kesalahan.\n` +
              `error("Device tidak dikenali. HWID mismatch.")`
            );
          }

          // Log new HWID registration
          if (hwidResult.isNew) {
            console.log(
              `[${timestamp}] 📱 NEW HWID REGISTERED - UserID: ${userId} (${vipUser.username}) | Platform: ${platform}`,
            );

            await sendDiscordLog({
              title: `📱 New PC HWID Registered`,
              status: "success",
              statusMessage: "✅ HWID Bound",
              authType: `${vipUser.type || config.defaultType} (New Device)`,
              owner: `${vipUser.username} (${userId})`,
              ip: clientIP,
              platform: platformLabel,
              hwidStatus: "🆕 Registered",
              timestamp: timestamp,
              message: `🔐 New device bound to account\n**Platform:** ${platform}`,
            });
          }
        }

        console.log(
          `[${timestamp}] ${isOwner ? "👑 OWNER" : "💎 VIP"} ACCESS [${platformLabel}] - UserID: ${userId} (${vipUser.username}) | IP: ${clientIP}`,
        );

        // Discord webhook with rate limiting (skip for owner)
        if (!isOwner) {
          await handleVIPWebhook(
            userId,
            vipUser,
            clientIP,
            timestamp,
            platform,
            config,
            hwidResult,
          );
        } else {
          console.log(
            `[${timestamp}] 🔕 Owner access - No webhook sent (UserID: ${userId})`,
          );
        }

        // Read and return loader script
        return serveLoaderScript(
          res,
          config,
          isOwner ? "owner" : "vip",
          vipUser.type,
          userId
        );
      } else if (vipUser.status === "suspended") {
        console.log(
          `[${timestamp}] 🚫 SUSPENDED ${platformLabel} VIP - UserID: ${userId} | IP: ${clientIP}`,
        );
        return res
          .status(403)
          .send(
            `-- ERROR: Your ${platform.toUpperCase()} VIP access has been suspended\n` +
            `-- Contact administrator\n` +
            `error("${platform.toUpperCase()} VIP access suspended")`,
          );
      }
    }

    // === CROSS-PLATFORM DETECTION ===
    // Skip for owner - owner can access both platforms
    if (userId === OWNER_USER_ID) {
      console.log(
        `[${timestamp}] 👑 OWNER CROSS-PLATFORM ACCESS GRANTED - ${platformLabel} | UserID: ${userId}`,
      );
      // Owner not in this platform's whitelist, but allow anyway
      // Serve the loader script
      return serveLoaderScript(res, config, "owner", "OWNER", userId);
    }

    // Check if user exists in the OTHER platform's whitelist
    const otherWhitelist = await getWhitelistFromRedis(
      config.otherWhitelistKey,
    );

    if (otherWhitelist && otherWhitelist[userId]) {
      const otherUser = otherWhitelist[userId];

      // === CHECK EVENT ACCESS FIRST (before blocking cross-platform) ===
      // If user has event access for mobile, allow them even if they have PC license
      if (platform === "mobile") {
        const eventAccess = await checkEventAccess(userId);

        if (eventAccess.hasAccess) {
          console.log(
            `[${timestamp}] 🎟️ EVENT ACCESS GRANTED (PC user with event code) - ${platformLabel} Loader - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
          );

          // Note: Discord webhook sent from load.js instead (to avoid duplicate)
          return serveLoaderScript(res, config, "event", "EVENT_ACCESS", userId);
        }
      }

      console.log(
        `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT - ${config.otherLabel} user trying ${platformLabel} loader - UserID: ${userId} | IP: ${clientIP}`,
      );

      await sendCrossPlatformAlert({
        userId: userId,
        username: otherUser.username,
        currentPlatform: config.otherLabel,
        attemptedPlatform: platformLabel,
        licenseType: otherUser.type || "VIP",
        ip: clientIP,
        timestamp: timestamp,
      });

      // SECURITY FIX: Block cross-platform access completely
      console.log(
        `[${timestamp}] ❌ BLOCKING cross-platform access - ${config.otherLabel} user trying ${platformLabel} - UserID: ${userId}`,
      );

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(403).send(
        `-- StarshipCore ${platform.toUpperCase()}\\n` +
        `-- ❌ CROSS-PLATFORM ACCESS DENIED\\n` +
        `-- You have a ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license.\\n` +
        `-- Purchase ${platform.toUpperCase()} VIP separately.\\n` +
        `error("You have ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license, not ${platform.toUpperCase()}")`
      );
    }

    // Check file-based other platform whitelist
    if (fs.existsSync(config.otherKeysFilePath)) {
      try {
        const otherKeysData = JSON.parse(
          fs.readFileSync(config.otherKeysFilePath, "utf8"),
        );
        const fileOtherWhitelist = otherKeysData.whitelist || {};

        if (fileOtherWhitelist[userId]) {
          const otherUser = fileOtherWhitelist[userId];

          // === CHECK EVENT ACCESS FIRST (before blocking cross-platform) ===
          if (platform === "mobile") {
            const eventAccess = await checkEventAccess(userId);

            if (eventAccess.hasAccess) {
              console.log(
                `[${timestamp}] 🎟️ EVENT ACCESS GRANTED (File PC user with event code) - ${platformLabel} Loader - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
              );

              return serveLoaderScript(res, config, "event", "EVENT_ACCESS", userId);
            }
          }

          console.log(
            `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT (File) - ${config.otherLabel} user trying ${platformLabel} loader - UserID: ${userId} | IP: ${clientIP}`,
          );

          await sendCrossPlatformAlert({
            userId: userId,
            username: otherUser.username || "Unknown",
            currentPlatform: config.otherLabel,
            attemptedPlatform: platformLabel,
            licenseType: otherUser.type || otherUser.role || "VIP",
            ip: clientIP,
            timestamp: timestamp,
          });

          // SECURITY FIX: Block cross-platform access completely (file-based)
          console.log(
            `[${timestamp}] ❌ BLOCKING cross-platform access (File) - ${config.otherLabel} user trying ${platformLabel} - UserID: ${userId}`,
          );

          res.setHeader("Content-Type", "text/plain; charset=utf-8");
          return res.status(403).send(
            `-- StarshipCore ${platform.toUpperCase()}\\n` +
            `-- ❌ CROSS-PLATFORM ACCESS DENIED\\n` +
            `-- You have a ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license.\\n` +
            `-- Purchase ${platform.toUpperCase()} VIP separately.\\n` +
            `error("You have ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license, not ${platform.toUpperCase()}")`
          );
        }
      } catch (err) {
        console.error("Error checking other keys file:", err);
      }
    }

    // Fallback: check file-based whitelist for this platform
    const keysData = getKeysData(config.keysFilePath);
    const fileWhitelist = keysData.whitelist?.[userId];

    if (fileWhitelist && fileWhitelist.status === "active") {
      console.log(
        `[${timestamp}] 👑 ${platformLabel} ACCESS (file) - UserID: ${userId} | IP: ${clientIP}`,
      );

      // Check expiry
      if (fileWhitelist.expiresAt) {
        const expiryDate = new Date(fileWhitelist.expiresAt);
        if (expiryDate < new Date()) {
          return res
            .status(403)
            .send(
              `error("${platform.toUpperCase()} access expired. Please renew.")`,
            );
        }
      }

      return serveLoaderScript(res, config, "vip", fileWhitelist.type, userId);
    }
  }

  // === PRIORITY 3: CHECK EVENT CODE ACCESS (Google Sheets) - Mobile Only ===
  if (platform === "mobile" && userId) {
    const eventAccess = await checkEventAccess(userId);

    if (eventAccess.hasAccess) {
      console.log(
        `[${timestamp}] 🎟️ EVENT ACCESS GRANTED - ${platformLabel} Loader - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
      );

      // Note: Discord webhook sent from load.js instead (to avoid duplicate)
      return serveLoaderScript(res, config, "event", "EVENT_ACCESS", userId);
    }
  }

  // === NOT WHITELISTED ===
  // For mobile: Check if banned first, then serve loader for event code popup
  if (platform === "mobile") {
    // Check if user is banned in Google Sheets
    const banCheck = await checkUserBanned(userId);

    if (banCheck.isBanned) {
      console.log(
        `[${timestamp}] 🚫 BANNED USER BLOCKED - UserID: ${userId} | IP: ${clientIP}`,
      );

      await sendDiscordLog({
        title: `🚫 Banned User Attempted Access`,
        status: "blocked",
        statusMessage: "🚫 BANNED",
        authType: "None",
        owner: `UserID: ${userId}`,
        ip: clientIP,
        platform: platformLabel,
        hwidStatus: "Protected",
        timestamp: timestamp,
        message: `🚫 Banned user attempted to access\\nReason: ${banCheck.reason}`,
      });

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(403).send(
        `-- StarshipCore MOBILE\\n` +
        `-- 🚫 ACCESS PERMANENTLY BANNED\\n` +
        `-- You have been banned from using this script.\\n` +
        `-- Reason: ${banCheck.reason}\\n` +
        `-- Your User ID: ${userId}\\n` +
        `error("You are banned from using StarshipCore.")`
      );
    }

    // Not banned - serve loader for event code popup
    console.log(
      `[${timestamp}] ℹ️ NOT WHITELISTED - Serving loader for event code popup - UserID: ${userId} | IP: ${clientIP}`,
    );

    // Serve loader script - it will show event code popup for new users
    return serveLoaderScript(res, config, "pending", "PENDING_EVENT", userId);
  }

  // For PC: Block access (PC doesn't have event code system)
  console.log(
    `[${timestamp}] ❌ NOT ${platform.toUpperCase()} WHITELISTED - ACCESS BLOCKED - UserID: ${userId} | IP: ${clientIP}`,
  );

  await sendDiscordLog({
    title: `🚫 ${platformLabel} Access Blocked - Not Whitelisted`,
    status: "blocked",
    statusMessage: "❌ Not Whitelisted",
    authType: "None",
    owner: `UserID: ${userId}`,
    ip: clientIP,
    platform: platformLabel,
    hwidStatus: "Protected",
    timestamp: timestamp,
    message: `❌ Unauthorized access attempt blocked\\nUserID: ${userId}\\nIP: ${clientIP}`,
  });

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  return res.status(403).send(
    `-- StarshipCore ${platform.toUpperCase()}\\n` +
    `-- ❌ ACCESS DENIED\\n` +
    `-- You are not whitelisted for ${platform.toUpperCase()} access.\\n` +
    `-- Contact administrator to purchase VIP access.\\n` +
    `-- Your User ID: ${userId}\\n` +
    `error("Not authorized for ${platform.toUpperCase()} access. Purchase VIP to continue.")`
  );
}

// Helper function to serve loader script
// Injects bundle key for authenticated users
function serveLoaderScript(res, config, accessType, userType, userId = null) {
  try {
    const loaderPath = path.join(process.cwd(), "protected", config.loaderFile);

    if (!fs.existsSync(loaderPath)) {
      console.error("Loader script not found:", loaderPath);
      return res.status(500).send(`error("Loader not available")`);
    }

    let loaderScript = fs.readFileSync(loaderPath, "utf8");

    const isPlatformPC = !config.label.includes("Mobile");

    // NOTE (SECURITY): Do NOT inject BUNDLE_KEY into the loader.
    // Bundle key is only sent after successful auth via /api/load (signed payload).
    //
    // Optional (PC only): Inject Cloudflare CDN signed access token, so the client
    // can download the *encrypted* bundle from Cloudflare (instead of public Vercel URL).
    if (isPlatformPC && userId && isCDNEnabled()) {
      const cdnToken = generateCDNToken(userId, "pc");
      const cdnBaseUrl = (CDN_BASE_URL || "").replace(/\/+$/, "");

      if (cdnToken && cdnBaseUrl) {
        const cdnInjection = `do
-- [CDN] Signed bundle access (token verified by Cloudflare Worker)
_G.StarshipCDN = {
  enabled = true,
  baseUrl = "${cdnBaseUrl}",
  token = "${cdnToken}"
}
end
`;
        loaderScript = cdnInjection + loaderScript;
      }
    }

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Access-Type", accessType);
    res.setHeader("X-User-Type", userType || config.defaultType);
    res.setHeader(
      "X-Platform",
      isPlatformPC ? "pc" : "mobile",
    );

    return res.status(200).send(loaderScript);
  } catch (error) {
    console.error("Error reading loader script:", error);
    return res.status(500).send(`error("Server error")`);
  }
}

// Helper function to handle VIP webhook with rate limiting
async function handleVIPWebhook(
  userId,
  vipUser,
  clientIP,
  timestamp,
  platform,
  config,
  hwidResult = null,
) {
  const COOLDOWN_MINUTES = 10;
  const redisKey = `webhook_cooldown: ${platform}: ${userId}`;
  const ipKey = `last_ip: ${platform}: ${userId}`;
  const deviceTrackingKey = `devices: ${platform}: ${userId}`;

  let shouldSendWebhook = false;
  let webhookReason = "Regular Access";

  try {
    const redisClient = await getRedis();
    const now = Date.now();

    if (!redisClient) {
      console.log(
        `[${timestamp}] ⚠️ Redis not available - sending webhook in fallback mode`,
      );
      shouldSendWebhook = true;
      webhookReason = "⚠️ Fallback Mode (Redis Unavailable)";

      await sendDiscordLog({
        title: `💎 ${config.label} VIP Access Granted`,
        status: "success",
        statusMessage: "✅ Authorized (VIP)",
        authType: `VIP(${vipUser.type}) - ${config.label}`,
        owner: vipUser.username,
        ip: clientIP,
        platform: config.label,
        hwidStatus: "Protected (Redis unavailable)",
        timestamp: timestamp,
        message: `✅ ${webhookReason}\n💎 VIP loader delivered to ${vipUser.username}\n⚠️(Rate limiting unavailable)`,
      });
      return;
    }

    // Redis is available - use rate limiting
    const lastNotification = await redisClient.get(redisKey);
    const lastIP = await redisClient.get(ipKey);

    // Device tracking
    let trackedDevices = [];
    const devicesData = await redisClient.get(deviceTrackingKey);
    trackedDevices = devicesData ? JSON.parse(devicesData) : [];

    if (!trackedDevices.includes(clientIP)) {
      trackedDevices.push(clientIP);
      await redisClient.set(
        deviceTrackingKey,
        JSON.stringify(trackedDevices),
        "EX",
        2592000, // 30 days
      );
      console.log(
        `[${timestamp}] 📱 New device added for ${vipUser.username}: ${clientIP} `,
      );
    }

    const currentDeviceCount = trackedDevices.length;

    // Check if this is first execution of the day
    const today = new Date().toDateString();
    const lastDate = lastNotification
      ? new Date(parseInt(lastNotification)).toDateString()
      : null;
    const isFirstToday = !lastDate || lastDate !== today;

    // Check if IP changed
    const ipChanged = lastIP && lastIP !== clientIP;

    // Determine if we should send webhook
    if (isFirstToday) {
      shouldSendWebhook = true;
      webhookReason = "🌅 First Execution Today";
    } else if (ipChanged) {
      shouldSendWebhook = true;
      webhookReason = "🔒 IP Address Changed";
    } else if (!lastNotification) {
      shouldSendWebhook = true;
      webhookReason = "🎉 First Time Access";
    } else {
      const timeSinceLastNotif = now - parseInt(lastNotification);
      const cooldownMs = COOLDOWN_MINUTES * 60 * 1000;

      if (timeSinceLastNotif >= cooldownMs) {
        shouldSendWebhook = true;
        webhookReason = "Cooldown Expired";
      }
    }

    if (shouldSendWebhook) {
      const maxDevices =
        vipUser.maxDevices || vipUser.restrictions?.maxDevices || null;
      const deviceInfo =
        !maxDevices || maxDevices === "Unlimited"
          ? `${currentDeviceCount} device(s)`
          : `${currentDeviceCount}/${maxDevices} devices`;

      await sendDiscordLog({
        title: `💎 ${config.label} VIP Access Granted`,
        status: "success",
        statusMessage: "✅ Authorized (VIP)",
        authType: `VIP (${vipUser.type}) - ${config.label}`,
        owner: vipUser.username,
        ip: ipChanged ? `${lastIP} → ${clientIP}` : clientIP,
        platform: config.label,
        hwidStatus: hwidResult ? (hwidResult.isNew ? "New Registered" : "HWID Bound") : "Protected",
        timestamp: timestamp,
        message: `✅ ${webhookReason}\n💎 VIP loader delivered to ${vipUser.username} via ${config.label}${ipChanged ? "\n⚠️ IP Address Changed!" : ""}`,
      });

      // Update last notification time and IP
      await redisClient.set(redisKey, now.toString(), "EX", 86400);
      await redisClient.set(ipKey, clientIP, "EX", 86400);
    } else {
      console.log(
        `[${timestamp}] 🔕 Webhook skipped for ${vipUser.username} - Cooldown active`,
      );
    }
  } catch (error) {
    console.error(`[${timestamp}] ❌ Rate limiting error:`, error);
    // Fallback - send webhook anyway
    await sendDiscordLog({
      title: `💎 ${config.label} VIP Access Granted`,
      status: "success",
      statusMessage: "✅ Authorized (VIP)",
      authType: `VIP (${vipUser.type}) - ${config.label}`,
      owner: vipUser.username,
      ip: clientIP,
      platform: config.label,
      hwidStatus: "Protected",
      timestamp: timestamp,
      message: `✅ VIP loader delivered to ${vipUser.username}\n⚠️ (Fallback mode - Rate limiting error)`,
    });
  }
}
