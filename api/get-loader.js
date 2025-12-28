// Unified Get Loader API - Serves protected loader scripts after authentication
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// With Discord Webhook Logging Integration and device tracking

// Owner userId - bypasses cross-platform restrictions
const OWNER_USER_ID = "9268011358";

import fs from "fs";
import path from "path";

// Event Code System API (from environment variable for security)
const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";

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
    return { hasAccess: false };
  } catch (error) {
    console.error("Event code check error:", error.message);
    return { hasAccess: false };
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
          name: "📱 Device Count",
          value: logData.deviceCount || "N/A",
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

  // Get parameters
  const { key, userId, platform: platformParam } = req.query;
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
      return serveLoaderScript(res, config, "owner", "OWNER");
    }

    // Check if user exists in the OTHER platform's whitelist
    const otherWhitelist = await getWhitelistFromRedis(
      config.otherWhitelistKey,
    );

    if (otherWhitelist && otherWhitelist[userId]) {
      const otherUser = otherWhitelist[userId];

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

      return serveLoaderScript(res, config, "vip", fileWhitelist.type);
    }
  }

  // === PRIORITY 3: CHECK EVENT CODE ACCESS (Google Sheets) - Mobile Only ===
  if (platform === "mobile" && userId) {
    const eventAccess = await checkEventAccess(userId);
    
    if (eventAccess.hasAccess) {
      console.log(
        `[${timestamp}] 🎟️ EVENT ACCESS GRANTED - ${platformLabel} Loader - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
      );
      
      await sendDiscordLog({
        title: `🎟️ Event Code Access - ${platformLabel} Loader`,
        status: "success",
        statusMessage: "✅ Event Access",
        authType: `Event Code: ${eventAccess.codeUsed}`,
        owner: `UserID: ${userId}`,
        ip: clientIP,
        platform: platformLabel,
        deviceCount: "N/A",
        timestamp: timestamp,
        message: `✅ Event access granted for loader\nExpires: ${eventAccess.expiresAt}\nRemaining: ${eventAccess.remainingDays} days`,
      });
      
      return serveLoaderScript(res, config, "event", "EVENT_ACCESS");
    }
  }

  // === NOT WHITELISTED - BLOCK ACCESS (Security Fix 2025-12-28) ===
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
    deviceCount: "N/A",
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
function serveLoaderScript(res, config, accessType, userType) {
  try {
    const loaderPath = path.join(process.cwd(), "protected", config.loaderFile);

    if (!fs.existsSync(loaderPath)) {
      console.error("Loader script not found:", loaderPath);
      return res.status(500).send(`error("Loader not available")`);
    }

    const loaderScript = fs.readFileSync(loaderPath, "utf8");

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Access-Type", accessType);
    res.setHeader("X-User-Type", userType || config.defaultType);
    res.setHeader(
      "X-Platform",
      config.label.includes("Mobile") ? "mobile" : "pc",
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
) {
  const COOLDOWN_MINUTES = 10;
  const redisKey = `webhook_cooldown:${platform}:${userId}`;
  const ipKey = `last_ip:${platform}:${userId}`;
  const deviceTrackingKey = `devices:${platform}:${userId}`;

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
        authType: `VIP (${vipUser.type}) - ${config.label}`,
        owner: vipUser.username,
        ip: clientIP,
        platform: config.label,
        deviceCount: "N/A (Redis unavailable)",
        timestamp: timestamp,
        message: `✅ ${webhookReason}\n💎 VIP loader delivered to ${vipUser.username}\n⚠️ (Rate limiting unavailable)`,
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
        `[${timestamp}] 📱 New device added for ${vipUser.username}: ${clientIP}`,
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
        deviceCount: deviceInfo,
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
      deviceCount: "N/A",
      timestamp: timestamp,
      message: `✅ VIP loader delivered to ${vipUser.username}\n⚠️ (Fallback mode - Rate limiting error)`,
    });
  }
}
