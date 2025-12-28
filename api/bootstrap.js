// Unified Bootstrap Endpoint - Public entry point for StarshipCore
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// PC: Returns a small script that auto-detects userId and calls secure get-loader API
// MOBILE: Redirects to mobile-bootstrap (which serves loader directly - no URL exposure)
// With browser detection, obfuscated response, and Discord logging
// Development mode: Skip loader intro and directly serve script
// + AUTO IP BAN for browser access attempts

// Owner userId - bypasses cross-platform restrictions
const OWNER_USER_ID = "9268011358";

// Owner IPs - NEVER ban these IPs (add your IP here if you accidentally got banned)
const OWNER_IPS = [
  "36.80.245.122", // Owner IP - auto-unban on request
];

// ═══════════════════════════════════════════════════════════════════
// MAINTENANCE MODE - Set to true to disable mobile access temporarily
// ═══════════════════════════════════════════════════════════════════
const MOBILE_MAINTENANCE = false; // <-- SECURITY: Re-enabled after security fix (updated: 2025-12-28)

import fs from "fs";
import path from "path";

// Import mobile-bootstrap handler for secure mobile loading (no URL exposure)
import mobileBootstrapHandler from "./mobile-bootstrap.js";

// ═══════════════════════════════════════════════════════════════════
// REDIS FOR IP BAN SYSTEM
// ═══════════════════════════════════════════════════════════════════
let redis = null;
let redisInitAttempted = false;
const BANNED_IPS_KEY = "starship:banned_ips";
const BAN_DURATION_SECONDS = 60 * 60 * 24 * 7; // 7 days

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis loaded for IP ban system");
    } catch (error) {
      console.error("⚠️ Redis not available for IP bans:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Check if IP is banned (skip owner IPs)
async function isIPBanned(ip) {
  // Owner IPs are NEVER banned - auto-unban if they were accidentally banned
  if (OWNER_IPS.includes(ip)) {
    console.log(`[IP Ban] 👑 Owner IP detected: ${ip} - skipping ban check`);
    
    // Auto-unban owner IP if it was accidentally banned
    try {
      const redisClient = await getRedis();
      if (redisClient) {
        await redisClient.srem(BANNED_IPS_KEY, ip);
        console.log(`[IP Ban] 🔓 Auto-unbanned owner IP: ${ip}`);
      }
    } catch (e) {
      // Ignore errors during auto-unban
    }
    
    return false;
  }
  
  try {
    const redisClient = await getRedis();
    if (!redisClient) return false;
    
    const isBanned = await redisClient.sismember(BANNED_IPS_KEY, ip);
    return isBanned === 1;
  } catch (error) {
    console.error("[IP Ban] Check error:", error.message);
    return false;
  }
}

// Ban an IP address (skip owner IPs)
async function banIP(ip, reason) {
  // Never ban owner IPs
  if (OWNER_IPS.includes(ip)) {
    console.log(`[IP Ban] 👑 Cannot ban owner IP: ${ip}`);
    return false;
  }
  
  try {
    const redisClient = await getRedis();
    if (!redisClient) {
      console.log(`[IP Ban] Redis not available, cannot ban ${ip}`);
      return false;
    }
    
    await redisClient.sadd(BANNED_IPS_KEY, ip);
    console.log(`[IP Ban] 🚫 BANNED IP: ${ip} - Reason: ${reason}`);
    return true;
  } catch (error) {
    console.error("[IP Ban] Ban error:", error.message);
    return false;
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
      suspicious: 0xff00ff,
    };

    const color = colors[logData.status] || 0x808080;

    const embed = {
      title: logData.title || "Access Log",
      color: color,
      fields: [
        {
          name: "🌐 IP Address",
          value: `\`${logData.ip || "Unknown"}\``,
          inline: true,
        },
        {
          name: "🖥️ User Agent",
          value: `\`${logData.userAgent?.substring(0, 100) || "Unknown"}\``,
          inline: false,
        },
        {
          name: "📍 Endpoint",
          value: `\`${logData.endpoint || "/api/bootstrap"}\``,
          inline: true,
        },
        {
          name: "📱 Platform",
          value: logData.platform || "PC",
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
        text: `${logData.platform === "mobile" ? "📱" : "💻"} StarshipCore Security Monitor`,
      },
    };

    if (logData.message) {
      embed.description = logData.message;
    }

    await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        embeds: [embed],
      }),
    });

    console.log("[Discord] ✅ Security alert sent");
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
  }
}

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  const timestamp = new Date().toISOString();
  const clientIP =
    req.headers["x-forwarded-for"]?.split(",")[0] ||
    req.headers["x-real-ip"] ||
    req.connection?.remoteAddress ||
    "unknown";
  const userAgent = req.headers["user-agent"] || "";
  const referer = req.headers["referer"] || "Direct";

  // ═══════════════════════════════════════════════════════════════
  // CHECK IF IP IS BANNED
  // ═══════════════════════════════════════════════════════════════
  const banned = await isIPBanned(clientIP);
  if (banned) {
    console.log(`[${timestamp}] 🚫 BANNED IP BLOCKED: ${clientIP}`);
    res.setHeader("Content-Type", "text/plain");
    return res.status(403).send('error("Access denied")');
  }

  // Determine platform (default: pc)
  const platform = req.query.platform === "mobile" ? "mobile" : "pc";
  const platformLabel = platform === "mobile" ? "📱 Mobile" : "💻 PC";
  const platformEmoji = platform === "mobile" ? "📱" : "💻";

  // ═══════════════════════════════════════════════════════════════
  // SECURITY: Redirect mobile to secure mobile-bootstrap handler
  // This handler serves loader DIRECTLY without exposing any URLs
  // ═══════════════════════════════════════════════════════════════
  if (platform === "mobile") {
    console.log(`[${timestamp}] 📱 Mobile request -> Redirecting to secure mobile-bootstrap | IP: ${clientIP}`);
    return mobileBootstrapHandler(req, res);
  }

  // Check for development mode (check this early to bypass maintenance)
  const isDev =
    process.env.NODE_ENV === "development" ||
    process.env.VERCEL_ENV === "development" ||
    req.headers.host?.includes("localhost");
  const forceDevMode = req.query.dev === "true" || req.query.dev === "1";
  
  // Force loader mode - use ?loader=true to test obfuscated loader even on localhost
  const forceLoaderMode = req.query.loader === "true" || req.query.loader === "1";
  
  // Force browser check - use ?testBan=true to test auto-ban even on localhost
  const testBanMode = req.query.testBan === "true" || req.query.testBan === "1";

  // ═══════════════════════════════════════════════════════════════
  // MAINTENANCE MODE CHECK - Block mobile if maintenance is enabled
  // Skip if dev mode is active (localhost or ?dev=true)
  // ═══════════════════════════════════════════════════════════════
  if (platform === "mobile" && MOBILE_MAINTENANCE && !isDev && !forceDevMode) {
    console.log(
      `[${timestamp}] 🔧 MOBILE MAINTENANCE MODE - Access blocked | IP: ${clientIP}`,
    );

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("X-Mode", "maintenance");
    
    // Return a Lua script that shows maintenance message
    const maintenanceScript = `
-- StarshipCore Mobile - Maintenance Mode
print("[StarshipCore Mobile] 🔧 Maintenance Mode")
print("[StarshipCore Mobile] The mobile version is currently under maintenance.")
print("[StarshipCore Mobile] Please try again later!")

-- Show notification if possible
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "🔧 Maintenance",
        Text = "Mobile version is under maintenance. Please try again later!",
        Duration = 10
    })
end)

warn("[StarshipCore] Mobile access is temporarily disabled for updates.")
`;
    return res.status(200).send(maintenanceScript);
  }

  // Platform-specific configuration
  // NOTE: Using obfuscated endpoints for production security
  const platformConfig = {
    pc: {
      scriptFile: "StarshipCore-obfuscated.lua",
      scriptFileDev: "StarshipCore.lua", // Non-obfuscated for dev
      loaderEndpoint: "pc-ld-q8r4", // SECURITY: Obscured endpoint name
      sessionPlatform: "pc",
      bootstrapVersion: "3.0",
    },
    mobile: {
      scriptFile: "MobileUI-obfuscated.lua",
      scriptFileDev: "MobileUI.lua", // Non-obfuscated for dev
      loaderEndpoint: "m-ld-x7k9", // SECURITY: Obscured endpoint name (not used - mobile goes through mobile-bootstrap)
      sessionPlatform: "mobile",
      bootstrapVersion: "3.0-mobile",
    },
  };

  const config = platformConfig[platform];

  // Development Mode: Skip loader intro and directly serve script
  // (isDev and forceDevMode were already checked above for maintenance bypass)
  // Skip this block if forceLoaderMode is true (to test obfuscated loader)
  // Skip this block if testBanMode is true (to test browser detection and auto-ban)
  if ((isDev || forceDevMode) && !forceLoaderMode && !testBanMode) {
    // Use non-obfuscated version for dev mode (easier debugging)
    const devScriptFile = config.scriptFileDev || config.scriptFile;
    
    console.log(
      `[${timestamp}] 🛠️ ${platformLabel} DEV MODE - Skipping loader, serving ${devScriptFile} directly | IP: ${clientIP}`,
    );

    try {
      const scriptPath = path.join(process.cwd(), "data", devScriptFile);

      if (!fs.existsSync(scriptPath)) {
        console.error(
          `[${timestamp}] ❌ DEV MODE - ${devScriptFile} not found`,
        );
        return res.status(404).send(`error("${devScriptFile} not found")`);
      }

      let scriptContent = fs.readFileSync(scriptPath, "utf8");

      // Remove BOM if present
      if (scriptContent.charCodeAt(0) === 0xfeff) {
        scriptContent = scriptContent.slice(1);
      }

      // Create a simple bootstrap that sets session and loads script directly
      const devBootstrap = `
-- StarshipCore ${platform === "mobile" ? "Mobile" : "PC"} - Development Mode
-- Skipping authentication for faster development

-- Server-based module loading configuration (auto-injected)
_G.StarshipServerMode = true
_G.StarshipServerURL = "http://localhost:3000"

-- R2 Event Code for cloud access (auto-injected in dev mode)
_G.StarshipEventCode = "${process.env.R2_EVENT_CODE || ""}"

-- Set mock session data for development
getgenv().StarshipSession = {
    Role = "DEV_MODE",
    Duration = "DEVELOPMENT",
    Expiry = nil,
    RemainingDays = nil,
    Platform = "${config.sessionPlatform}",
    DeviceCount = 1,
    MaxDevices = 99,
    Username = game:GetService("Players").LocalPlayer.Name,
    DevMode = true
}

print("[StarshipCore] 🛠️ Development Mode - Auth Skipped")
print("[StarshipCore] ${platformEmoji} Loading ${config.scriptFile} directly...")

-- Load script directly
${scriptContent}
`;

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      res.setHeader("X-Mode", "development");
      res.setHeader("X-Platform", platform);

      return res.status(200).send(devBootstrap);
    } catch (error) {
      console.error(`[${timestamp}] ❌ DEV MODE Error:`, error);
      return res.status(500).send('error("Development mode error")');
    }
  }

  // Detect browser access
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

  // Log User-Agent for debugging (mobile only for now, can enable for both)
  if (platform === "mobile") {
    console.log(
      `[${timestamp}] ${platformEmoji} Bootstrap - UA: "${userAgent}" | IP: ${clientIP} | IsBrowser: ${isBrowser}`,
    );
  }

  // If accessed from browser, log and return fake error page
  if (isBrowser) {
    console.log(
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED (${platformLabel}) | IP: ${clientIP} | UA: ${userAgent.substring(0, 50)}`,
    );

    // ═══════════════════════════════════════════════════════════════
    // AUTO-BAN IP FOR BROWSER ACCESS
    // ═══════════════════════════════════════════════════════════════
    await banIP(clientIP, `Browser access attempt - UA: ${userAgent.substring(0, 50)}`);

    // Send Discord alert for suspicious browser access + IP banned
    await sendDiscordLog({
      title: `🚨 BROWSER ACCESS - IP BANNED - ${platformLabel} Bootstrap`,
      status: "suspicious",
      ip: clientIP,
      userAgent: userAgent,
      endpoint: `/api/bootstrap${platform === "mobile" ? "?platform=mobile" : ""}`,
      platform: platformLabel,
      timestamp: timestamp,
      message: `⚠️ **Browser access detected - IP AUTO-BANNED!**\n\n**IP:** \`${clientIP}\`\n**Referer:** \`${referer}\`\n**Action:** IP permanently blocked from all endpoints`,
    });

    const bgColor = platform === "mobile" ? "#0f0f1a" : "#1a1a2e";
    const accentColor = platform === "mobile" ? "#8b5cf6" : "#ff6b6b";
    const containerBg = platform === "mobile" ? "#1a1a2e" : "#16213e";
    const icon = platform === "mobile" ? "📱🚫" : "🚫";

    res.setHeader("Content-Type", "text/html; charset=utf-8");
    return res.status(403).send(`
<!DOCTYPE html>
<html>
<head>
    <title>403 - Forbidden</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: ${bgColor};
            color: #eee;
        }
        h1 { color: ${accentColor}; font-size: 48px; }
        p { color: #888; margin: 10px 0; }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: ${containerBg};
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
            ${platform === "mobile" ? `border: 1px solid ${accentColor};` : ""}
        }
        .icon { font-size: 64px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">${icon}</div>
        <h1>403</h1>
        <p><strong>Forbidden</strong></p>
        <p>Direct access to this endpoint is not allowed.</p>
        <p>This API is for authorized ${platform === "mobile" ? "mobile " : ""}applications only.</p>
    </div>
</body>
</html>
    `);
  }

  // Log legitimate access (from Roblox executor)
  console.log(
    `[${timestamp}] ${platformEmoji} Bootstrap GRANTED | IP: ${clientIP}${platform === "mobile" ? ` | UA: "${userAgent}"` : ""}`,
  );

  // ═══════════════════════════════════════════════════════════════
  // PRODUCTION MODE - Serve obfuscated Loader directly (SECURE)
  // NO URLs are exposed to the client - loader is served directly
  // This prevents hackers from discovering internal endpoints
  // ═══════════════════════════════════════════════════════════════
  
  try {
    // Use obfuscated loader for production
    const loaderPath = path.join(process.cwd(), "protected", "Loader-obfuscated.lua");
    
    if (!fs.existsSync(loaderPath)) {
      // Fallback to non-obfuscated if obfuscated doesn't exist
      const fallbackPath = path.join(process.cwd(), "Loader.lua");
      if (!fs.existsSync(fallbackPath)) {
        console.error(`[${timestamp}] ❌ PC Loader not found`);
        return res.status(500).send('error("PC Loader not available")');
      }
      
      let loaderScript = fs.readFileSync(fallbackPath, "utf8");
      
      // Remove BOM if present
      if (loaderScript.charCodeAt(0) === 0xfeff) {
        loaderScript = loaderScript.slice(1);
      }
      
      // Inject server mode config at the top
      const configuredScript = `-- StarshipCore PC Loader v3.0 (Secure)
_G.StarshipServerMode = true
_G.StarshipServerURL = "https://starship-core.my.id"

${loaderScript}`;

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      res.setHeader("X-Bootstrap-Version", "3.0-secure");
      res.setHeader("X-Platform", "pc");
      
      return res.status(200).send(configuredScript);
    }
    
    // Serve obfuscated loader
    let loaderScript = fs.readFileSync(loaderPath, "utf8");
    
    // Remove BOM if present
    if (loaderScript.charCodeAt(0) === 0xfeff) {
      loaderScript = loaderScript.slice(1);
    }
    
    // Inject server mode config at the top (before obfuscated code)
    const configuredScript = `-- StarshipCore PC v3.0
_G.StarshipServerMode = true
_G.StarshipServerURL = "https://starship-core.my.id"

${loaderScript}`;

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Bootstrap-Version", "3.0-secure");
    res.setHeader("X-Platform", "pc");

    return res.status(200).send(configuredScript);
    
  } catch (error) {
    console.error(`[${timestamp}] ❌ Error serving PC loader:`, error);
    return res.status(500).send('error("Server error")');
  }
}
