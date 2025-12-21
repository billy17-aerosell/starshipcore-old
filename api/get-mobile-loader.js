// Get Mobile Loader API - Serves protected mobile-loader.lua after authentication
// Similar to get-loader.js but for mobile platform

import fs from "fs";
import path from "path";

// Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded for /api/get-mobile-loader");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Redis keys
const MOBILE_WHITELIST_KEY = "starship:mobile_whitelist";
const PC_WHITELIST_KEY = "starship:whitelist";

// Helper to get mobile whitelist from Redis
async function getMobileWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get(MOBILE_WHITELIST_KEY);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis mobile whitelist read error:", error.message);
    return null;
  }
}

// Helper to get PC whitelist from Redis (for cross-platform detection)
async function getPCWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get(PC_WHITELIST_KEY);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis PC whitelist read error:", error.message);
    return null;
  }
}

// Get client IP
function getClientIP(req) {
  return (
    req.headers["x-forwarded-for"]?.split(",")[0] ||
    req.headers["x-real-ip"] ||
    req.connection?.remoteAddress ||
    "unknown"
  );
}

// Send Discord webhook
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) {
    console.log("[Discord] Webhook not configured, skipping notification");
    return;
  }

  try {
    const colors = {
      success: 0x22c55e,
      blocked: 0xef4444,
      invalid: 0xf59e0b,
      warning: 0xeab308,
      crossplatform: 0x9333ea,
    };

    const color = colors[logData.status] || 0x6366f1;

    const embed = {
      title: logData.title || "📱 Mobile Loader Access",
      color: color,
      fields: [
        {
          name: "👤 User",
          value: logData.owner || "Unknown",
          inline: true,
        },
        {
          name: "🔑 Auth Type",
          value: `\`${logData.authType || "Mobile VIP"}\``,
          inline: true,
        },
        {
          name: "🌐 IP Address",
          value: `\`${logData.ip}\``,
          inline: true,
        },
        {
          name: "📱 Platform",
          value: logData.platform || "Mobile",
          inline: true,
        },
        {
          name: "⏰ Timestamp",
          value: logData.timestamp,
          inline: true,
        },
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: "📱 StarshipCore Mobile Auth",
      },
    };

    if (logData.message) {
      embed.description = logData.message;
    }

    await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });

    console.log("[Discord] ✅ Mobile loader log sent");
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
  }
}

// Send Cross-Platform Alert
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

  const { userId } = req.query;
  const timestamp = new Date().toISOString();
  const clientIP = getClientIP(req);
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

  // Roblox executor patterns - these should be allowed even if they contain browser-like UA
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

  // Check if it's a Roblox executor first (case insensitive)
  const isRobloxExecutor = robloxPatterns.some((pattern) =>
    userAgent.toLowerCase().includes(pattern.toLowerCase()),
  );

  // Only flag as browser if it matches browser patterns AND is not a Roblox executor
  // Also allow empty User-Agent (common for executors)
  const isBrowser =
    userAgent !== "" &&
    !isRobloxExecutor &&
    browserPatterns.some((pattern) => userAgent.includes(pattern));

  if (isBrowser) {
    console.log(
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED (get-mobile-loader) | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: "🚨 Browser Access Blocked - Mobile Loader",
      status: "blocked",
      owner: "Browser User",
      authType: "None",
      ip: clientIP,
      platform: "Browser (Blocked)",
      timestamp: timestamp,
      message: `⚠️ Someone tried to access mobile loader from browser!\n\n**User Agent:** \`${userAgent.substring(0, 100)}\``,
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

  if (!userId) {
    return res.status(400).send('error("Missing userId parameter")');
  }

  const now = Math.floor(Date.now() / 1000);

  try {
    // === CHECK MOBILE WHITELIST (Redis) ===
    const mobileWhitelist = await getMobileWhitelistFromRedis();

    if (mobileWhitelist && mobileWhitelist[userId]) {
      const mobileUser = mobileWhitelist[userId];

      // Check if active
      if (mobileUser.status === "active") {
        // Check expiry
        if (mobileUser.expiresAt) {
          const expiryDate = new Date(mobileUser.expiresAt);
          if (expiryDate < new Date()) {
            console.log(
              `[${timestamp}] ❌ Mobile VIP expired - UserID: ${userId}`,
            );
            return res
              .status(403)
              .send('error("Mobile VIP access expired. Please renew.")');
          }
        }

        // Granted - serve the protected loader
        console.log(
          `[${timestamp}] 📱 MOBILE LOADER ACCESS - UserID: ${userId} (${mobileUser.username}) | IP: ${clientIP}`,
        );

        await sendDiscordLog({
          title: "📱 Mobile Loader Access Granted",
          status: "success",
          owner: mobileUser.username,
          authType: mobileUser.type || "MOBILE_VIP",
          ip: clientIP,
          platform: "📱 Mobile",
          timestamp: timestamp,
          message: `✅ Mobile loader served to **${mobileUser.username}**`,
        });

        // Read mobile-loader.lua from protected folder
        const loaderPath = path.join(
          process.cwd(),
          "protected",
          "mobile-loader.lua",
        );

        if (!fs.existsSync(loaderPath)) {
          console.error("Mobile loader file not found:", loaderPath);
          return res.status(500).send('error("Mobile loader not available")');
        }

        const loaderScript = fs.readFileSync(loaderPath, "utf8");

        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        res.setHeader("X-Platform", "mobile");
        return res.status(200).send(loaderScript);
      } else if (mobileUser.status === "suspended") {
        console.log(
          `[${timestamp}] 🚫 SUSPENDED Mobile VIP - UserID: ${userId}`,
        );
        return res
          .status(403)
          .send('error("Your Mobile VIP access has been suspended.")');
      }
    }

    // === CHECK FILE-BASED MOBILE WHITELIST ===
    const mobileKeysPath = path.join(process.cwd(), "data", "mobile-keys.json");

    if (fs.existsSync(mobileKeysPath)) {
      try {
        const mobileKeysData = JSON.parse(
          fs.readFileSync(mobileKeysPath, "utf8"),
        );
        const fileWhitelist = mobileKeysData.whitelist || {};

        if (fileWhitelist[userId]) {
          const userData = fileWhitelist[userId];

          // Check expiry
          if (userData.expiresAt) {
            const expiryDate = new Date(userData.expiresAt);
            if (expiryDate < new Date()) {
              return res
                .status(403)
                .send('error("Mobile access expired. Please renew.")');
            }
          }

          console.log(
            `[${timestamp}] 📱 MOBILE LOADER ACCESS (File) - UserID: ${userId} | IP: ${clientIP}`,
          );

          // Read mobile-loader.lua from protected folder
          const loaderPath = path.join(
            process.cwd(),
            "protected",
            "mobile-loader.lua",
          );

          if (!fs.existsSync(loaderPath)) {
            return res.status(500).send('error("Mobile loader not available")');
          }

          const loaderScript = fs.readFileSync(loaderPath, "utf8");

          res.setHeader("Content-Type", "text/plain; charset=utf-8");
          res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
          return res.status(200).send(loaderScript);
        }
      } catch (err) {
        console.error("Error reading mobile-keys.json:", err);
      }
    }

    // === CROSS-PLATFORM DETECTION: Check if user is PC-only ===
    const pcWhitelist = await getPCWhitelistFromRedis();

    if (pcWhitelist && pcWhitelist[userId]) {
      const pcUser = pcWhitelist[userId];

      console.log(
        `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT - PC user trying Mobile loader - UserID: ${userId} | IP: ${clientIP}`,
      );

      await sendCrossPlatformAlert({
        userId: userId,
        username: pcUser.username,
        currentPlatform: "💻 PC",
        attemptedPlatform: "📱 MOBILE",
        licenseType: pcUser.type || "VIP",
        ip: clientIP,
        timestamp: timestamp,
      });

      return res
        .status(403)
        .send(
          'error("You have a PC license, not Mobile. Purchase Mobile VIP for mobile access.")',
        );
    }

    // Check file-based PC whitelist
    const pcKeysPath = path.join(process.cwd(), "data", "keys.json");
    if (fs.existsSync(pcKeysPath)) {
      try {
        const pcKeysData = JSON.parse(fs.readFileSync(pcKeysPath, "utf8"));
        const filePCWhitelist = pcKeysData.whitelist || {};

        if (filePCWhitelist[userId]) {
          const pcUser = filePCWhitelist[userId];

          console.log(
            `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT (File) - PC user trying Mobile loader - UserID: ${userId} | IP: ${clientIP}`,
          );

          await sendCrossPlatformAlert({
            userId: userId,
            username: pcUser.username || "Unknown",
            currentPlatform: "💻 PC",
            attemptedPlatform: "📱 MOBILE",
            licenseType: pcUser.type || pcUser.role || "VIP",
            ip: clientIP,
            timestamp: timestamp,
          });

          return res
            .status(403)
            .send(
              'error("You have a PC license, not Mobile. Purchase Mobile VIP for mobile access.")',
            );
        }
      } catch (err) {
        console.error("Error checking keys.json:", err);
      }
    }

    // === NOT WHITELISTED ===
    console.log(
      `[${timestamp}] ❌ NOT MOBILE WHITELISTED - UserID: ${userId} | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: "📱 Mobile Loader Access Denied",
      status: "blocked",
      owner: `UserID: ${userId}`,
      authType: "None",
      ip: clientIP,
      platform: "Mobile (Denied)",
      timestamp: timestamp,
      message: `❌ User not in mobile whitelist\nUserID: ${userId}`,
    });

    return res
      .status(403)
      .send(
        'error("Not whitelisted for Mobile access. Purchase Mobile VIP to get access.")',
      );
  } catch (error) {
    console.error("Get Mobile Loader Error:", error);
    return res.status(500).send('error("Internal server error")');
  }
}
