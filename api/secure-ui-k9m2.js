// Get Mobile UI API - Serves protected MobileUI.lua after authentication
// Only accessible after user passes mobile-loader authentication
// + Event Code System Integration

import fs from "fs";
import path from "path";

// Event Code System API (from environment variable for security)
const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";

// R2 Event Code - injected to script for cloud access
const R2_EVENT_CODE = process.env.R2_EVENT_CODE || "";

// Check if user has active event access from Google Sheets
async function checkEventAccess(userId) {
  // Skip if EVENT_CODE_API not configured
  if (!EVENT_CODE_API) {
    console.log("[Event Code] API URL not configured, skipping check");
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
        remainingHours: data.remainingHours,
      };
    }
    return { hasAccess: false };
  } catch (error) {
    console.error("Event code check error:", error.message);
    return { hasAccess: false };
  }
}

// Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded for /api/get-mobile-ui");
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
    return;
  }

  try {
    const colors = {
      success: 0x22c55e,
      blocked: 0xef4444,
      warning: 0xeab308,
    };

    const color = colors[logData.status] || 0x6366f1;

    const embed = {
      title: logData.title || "📱 Mobile UI Access",
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
          name: "⏰ Timestamp",
          value: logData.timestamp,
          inline: true,
        },
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: "📱 StarshipCore Mobile UI Server",
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
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
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

  // Browser detection - block browser access
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
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED (get-mobile-ui) | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: "🚨 Browser Access Blocked - Mobile UI",
      status: "blocked",
      owner: "Browser User",
      authType: "None",
      ip: clientIP,
      timestamp: timestamp,
      message: `⚠️ Someone tried to access Mobile UI from browser!\n\n**User Agent:** \`${userAgent.substring(0, 100)}\``,
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
        .container { max-width: 400px; margin: 0 auto; background: #1a1a2e; padding: 30px; border-radius: 10px; border: 1px solid #8b5cf6; }
    </style>
</head>
<body>
    <div class="container">
        <h1>403 Forbidden</h1>
        <p>This endpoint is for authorized mobile applications only.</p>
    </div>
</body>
</html>
    `);
  }

  if (!userId) {
    return res.status(400).send('error("Missing userId parameter")');
  }

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
              `[${timestamp}] ❌ Mobile UI - VIP expired - UserID: ${userId}`,
            );
            return res
              .status(403)
              .send('error("Mobile VIP access expired. Please renew.")');
          }
        }

        // Granted - serve the protected Mobile UI
        console.log(
          `[${timestamp}] 📱 MOBILE UI ACCESS - UserID: ${userId} (${mobileUser.username}) | IP: ${clientIP}`,
        );

        // Read MobileUI.lua (obfuscated version for security) from data folder
        const uiPath = path.join(process.cwd(), "data", "MobileUI-obfuscated.lua");

        if (!fs.existsSync(uiPath)) {
          console.error("MobileUI.lua not found:", uiPath);
          return res.status(500).send('error("Mobile UI not available")');
        }

        let uiScript = fs.readFileSync(uiPath, "utf8");
        
        // Inject R2 Event Code for cloud access (VIP users get access)
        if (R2_EVENT_CODE) {
          const eventCodeInjection = `_G.StarshipEventCode = "${R2_EVENT_CODE}"\n`;
          uiScript = eventCodeInjection + uiScript;
          console.log(`[${timestamp}] 🔑 Injected R2 event code for VIP user`);
        }

        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        res.setHeader("X-Platform", "mobile");
        res.setHeader("X-Auth", "verified");
        return res.status(200).send(uiScript);
      } else if (mobileUser.status === "suspended") {
        console.log(
          `[${timestamp}] 🚫 SUSPENDED - Mobile UI access - UserID: ${userId}`,
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

          // Check status
          if (userData.status === "suspended") {
            return res
              .status(403)
              .send('error("Your Mobile VIP access has been suspended.")');
          }

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
            `[${timestamp}] 📱 MOBILE UI ACCESS (File) - UserID: ${userId} | IP: ${clientIP}`,
          );

          // Read MobileUI.lua (obfuscated version for security) from data folder
          const uiPath = path.join(process.cwd(), "data", "MobileUI-obfuscated.lua");

          if (!fs.existsSync(uiPath)) {
            return res.status(500).send('error("Mobile UI not available")');
          }

          let uiScript = fs.readFileSync(uiPath, "utf8");
          
          // Inject R2 Event Code for cloud access (file-based VIP users)
          if (R2_EVENT_CODE) {
            const eventCodeInjection = `_G.StarshipEventCode = "${R2_EVENT_CODE}"\n`;
            uiScript = eventCodeInjection + uiScript;
            console.log(`[${timestamp}] 🔑 Injected R2 event code for file-based VIP user`);
          }

          res.setHeader("Content-Type", "text/plain; charset=utf-8");
          res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
          return res.status(200).send(uiScript);
        }
      } catch (err) {
        console.error("Error reading mobile-keys.json:", err);
      }
    }

    // === CHECK EVENT CODE ACCESS (Google Sheets) ===
    // Re-enabled with improved security - only grants access, doesn't bypass whitelist
    const eventAccess = await checkEventAccess(userId);
    
    if (eventAccess.hasAccess) {
      console.log(
        `[${timestamp}] 🎟️ EVENT ACCESS GRANTED - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
      );
      
      // Read MobileUI.lua (obfuscated version for security) from data folder
      const uiPath = path.join(process.cwd(), "data", "MobileUI-obfuscated.lua");

      if (!fs.existsSync(uiPath)) {
        return res.status(500).send('error("Mobile UI not available")');
      }

      let uiScript = fs.readFileSync(uiPath, "utf8");
      
      // Inject R2 Event Code for cloud access
      if (R2_EVENT_CODE) {
        const eventCodeInjection = `_G.StarshipEventCode = "${R2_EVENT_CODE}"\n`;
        uiScript = eventCodeInjection + uiScript;
        console.log(`[${timestamp}] 🔑 Injected R2 event code for event user`);
      }

      await sendDiscordLog({
        title: "🎟️ Event Code Access Granted",
        status: "success",
        owner: `UserID: ${userId}`,
        authType: `Event Code: ${eventAccess.codeUsed}`,
        ip: clientIP,
        timestamp: timestamp,
        message: `✅ Event access granted\nExpires: ${eventAccess.expiresAt}\nRemaining: ${eventAccess.remainingDays} days`,
      });

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      res.setHeader("X-Platform", "mobile");
      res.setHeader("X-Auth", "event");
      return res.status(200).send(uiScript);
    }
    
    console.log(
      `[${timestamp}] ℹ️ No event access - UserID: ${userId} | IP: ${clientIP}`,
    );

    // === NOT WHITELISTED ===
    console.log(
      `[${timestamp}] ❌ MOBILE UI DENIED - Not whitelisted - UserID: ${userId} | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: "📱 Mobile UI Access Denied",
      status: "blocked",
      owner: `UserID: ${userId}`,
      authType: "None",
      ip: clientIP,
      timestamp: timestamp,
      message: `❌ Unauthorized Mobile UI access attempt\\nUserID: ${userId}\\nEvent Code System: DISABLED`,
    });

    return res
      .status(403)
      .send(
        'error("Not whitelisted for Mobile access. Purchase Mobile VIP to get access.")',
      );
  } catch (error) {
    console.error("Get Mobile UI Error:", error);
    return res.status(500).send('error("Internal server error")');
  }
}
