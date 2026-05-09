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
import crypto from "crypto";
import {
  evaluateRequest,
  markIPTrusted,
  getClientIP,
} from "../lib/ip-ban.js";

// Import mobile-bootstrap handler for secure mobile loading (no URL exposure)
import mobileBootstrapHandler from "./mobile-bootstrap.js";

// ═══════════════════════════════════════════════════════════════════
// CLOUDFLARE CDN CONFIGURATION (PC ONLY)
// ═══════════════════════════════════════════════════════════════════
const CDN_SECRET_KEY = process.env.CDN_SECRET_KEY || "";
const CDN_BASE_URL = process.env.CDN_PC_URL || "";
const CDN_TOKEN_EXPIRY_MS = 60 * 60 * 1000; // 1 hour

/**
 * Generate signed token for Cloudflare CDN access (PC only)
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

// ════════════════════════════════════════════════════════════════════
// REDIS LAZY LOADER (untuk maintenance status check, bukan ban)
// IP ban / strike / trusted-IP logic udah dipindah ke lib/ip-ban.js
// ════════════════════════════════════════════════════════════════════
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
    } catch (error) {
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
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
  const clientIP = getClientIP(req);
  const userAgent = req.headers["user-agent"] || "";
  const referer = req.headers["referer"] || "Direct";

  // Note: full security evaluation (ban/strike/crawler/browser) dilakukan
  // setelah dev-mode check di bawah, biar dev mode tetap bisa akses dari browser.

  // Determine platform (default: pc)
  const platform = req.query.platform === "mobile" ? "mobile" : "pc";
  const platformLabel = platform === "mobile" ? "📱 Mobile" : "💻 PC";
  const platformEmoji = platform === "mobile" ? "📱" : "💻";

  // ═══════════════════════════════════════════════════════════════
  // CHECK PLATFORM STATUS FROM REDIS (MAINTENANCE/OFFLINE CHECK)
  // ═══════════════════════════════════════════════════════════════
  try {
    const redisClient = await getRedis();
    if (redisClient) {
      const statusData = await redisClient.get(`starship:status:${platform}`);
      if (statusData) {
        const status = JSON.parse(statusData);
        if (status.status === 'maintenance' || status.status === 'offline') {
          console.log(`[${timestamp}] 🔧 ${platform.toUpperCase()} ${status.status.toUpperCase()} - Blocking access | IP: ${clientIP}`);

          res.setHeader("Content-Type", "text/plain; charset=utf-8");
          res.setHeader("X-Status", status.status);

          const statusEmoji = status.status === 'maintenance' ? '🔧' : '🔴';
          const statusTitle = status.status === 'maintenance' ? 'Maintenance Mode' : 'System Offline';
          const statusMessage = status.message || (status.status === 'maintenance'
            ? 'System is under maintenance. Please try again later.'
            : 'System is currently offline. Please try again later.');

          const maintenanceScript = `
-- StarshipCore ${platform === "mobile" ? "Mobile" : "PC"} - ${statusTitle}
print("[StarshipCore] ${statusEmoji} ${statusTitle}")
print("[StarshipCore] ${statusMessage}")

-- Show notification
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "${statusEmoji} ${statusTitle}",
        Text = "${statusMessage}",
        Duration = 10
    })
end)

warn("[StarshipCore] ${platform.toUpperCase()} access is temporarily disabled.")
`;
          return res.status(200).send(maintenanceScript);
        }
      }
    }
  } catch (e) {
    console.error(`[${timestamp}] ⚠️ Status check error:`, e.message);
    // Continue if Redis fails - don't block access
  }

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

-- [DEV MODE] Force enable cloud features
_G.StarshipCloudEnabled = true

-- R2 Event Code for cloud access (auto-injected in dev mode)
_G.StarshipEventCode = "${process.env.R2_EVENT_CODE || ""}"

-- Set mock session data for development (Role = DEVELOPER for cloud access!)
getgenv().StarshipSession = {
    Role = "DEVELOPER",
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
print("[StarshipCore] ☁️ Cloud features ENABLED (dev mode)")
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

  // ═══════════════════════════════════════════════════════════════
  // SECURITY EVALUATION (ban / crawler / browser / strike system)
  // Diletakkan setelah dev-mode bypass biar developer tetap bisa
  // akses dari browser di localhost.
  // ═══════════════════════════════════════════════════════════════
  const evalResult = await evaluateRequest(req);

  if (evalResult.action === "already_banned") {
    console.log(`[${timestamp}] 🚫 BANNED IP BLOCKED (${platformLabel}): ${clientIP}`);
    res.setHeader("Content-Type", "text/plain");
    return res.status(403).send('error("Access denied")');
  }

  if (evalResult.action === "block_crawler") {
    console.log(`[${timestamp}] 🤖 CRAWLER blocked (no ban): ${clientIP} - ${userAgent.substring(0, 60)}`);
    res.setHeader("Content-Type", "text/html");
    return res.status(403).send(`<!DOCTYPE html><html><head><title>403</title></head><body><h1>403 Forbidden</h1></body></html>`);
  }

  if (evalResult.action === "block_trusted" || evalResult.action === "warn" || evalResult.action === "ban") {
    const isBanned = evalResult.action === "ban";
    const isTrusted = evalResult.action === "block_trusted";
    const statusLabel = isTrusted
      ? "⚠️ Trusted IP browser (no ban)"
      : isBanned
        ? "🚫 BANNED (3 strikes)"
        : `⚠️ Strike ${evalResult.strikes}/${evalResult.threshold}`;

    console.log(
      `[${timestamp}] 🚨 BROWSER ${statusLabel} (${platformLabel}) | IP: ${clientIP} | UA: ${userAgent.substring(0, 50)}`,
    );

    if (!isTrusted) {
      await sendDiscordLog({
        title: isBanned
          ? `� BROWSER ACCESS - IP BANNED - ${platformLabel}`
          : `⚠️ Browser Access (Strike ${evalResult.strikes}/${evalResult.threshold}) - ${platformLabel}`,
        status: isBanned ? "blocked" : "warning",
        ip: clientIP,
        userAgent: userAgent,
        endpoint: `/api/bootstrap${platform === "mobile" ? "?platform=mobile" : ""}`,
        platform: platformLabel,
        timestamp: timestamp,
        message: isBanned
          ? `🚫 **IP banned for 7 days (auto-unban after that)**\n\n**Referer:** \`${referer}\`\n**Strikes:** ${evalResult.strikes}/${evalResult.threshold}`
          : `⚠️ Browser tried accessing bootstrap. **Not banned yet** - need ${evalResult.threshold - evalResult.strikes} more strike(s).\n\n**Referer:** \`${referer}\``,
      });
    }

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
        body { font-family: Arial, sans-serif; text-align: center; padding: 50px; background: ${bgColor}; color: #eee; }
        h1 { color: ${accentColor}; font-size: 48px; }
        p { color: #888; margin: 10px 0; }
        .container { max-width: 500px; margin: 0 auto; background: ${containerBg}; padding: 40px; border-radius: 10px; box-shadow: 0 4px 20px rgba(0,0,0,0.3); ${platform === "mobile" ? `border: 1px solid ${accentColor};` : ""} }
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

  // Mark IP sebagai trusted - browser access dari device/IP yang sama
  // selanjutnya gak akan ke-ban (cuma 403).
  await markIPTrusted(clientIP);

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
