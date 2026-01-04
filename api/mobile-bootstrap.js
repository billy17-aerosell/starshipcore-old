// api/mobile-bootstrap.js - Secure Mobile Bootstrap (Server-Side Logic v3.0)
// SECURITY UPDATE: All logic moved to server-side
// Client NO LONGER receives any intermediate URLs
// This prevents hackers from discovering internal endpoints
// 
// Flow: mobile-bootstrap -> returns loader script directly -> loader handles auth

import fs from "fs";
import path from "path";

// Owner userId - bypasses restrictions
const OWNER_USER_ID = "9268011358";

// Owner IPs - NEVER ban these IPs
const OWNER_IPS = [
  "36.80.245.122",
];

// MAINTENANCE MODE - Now fetched from Google Sheets!
// To toggle: Go to Google Sheets > Settings sheet > Set MAINTENANCE to ON or OFF
const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";

async function checkMaintenanceFromSheets() {
  if (!EVENT_CODE_API) {
    console.log("[Maintenance] No EVENT_CODE_API configured, maintenance disabled");
    return { maintenance: false, message: "" };
  }
  
  try {
    const response = await fetch(`${EVENT_CODE_API}?action=maintenance`);
    const data = await response.json();
    return {
      maintenance: data.maintenance === true,
      message: data.message || "Server is under maintenance."
    };
  } catch (error) {
    console.error("[Maintenance] Error checking:", error.message);
    return { maintenance: false, message: "" };
  }
}

// ═══════════════════════════════════════════════════════════════════
// REDIS FOR IP BAN
// ═══════════════════════════════════════════════════════════════════
let redis = null;
let redisInitAttempted = false;
const BANNED_IPS_KEY = "starship:banned_ips";

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis loaded for mobile-bootstrap");
    } catch (error) {
      console.error("⚠️ Redis not available:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Check if IP is banned
async function isIPBanned(ip) {
  if (OWNER_IPS.includes(ip)) {
    console.log(`[IP Ban] 👑 Owner IP detected: ${ip}`);
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

// Ban an IP address
async function banIP(ip, reason) {
  if (OWNER_IPS.includes(ip)) {
    console.log(`[IP Ban] 👑 Cannot ban owner IP: ${ip}`);
    return false;
  }
  
  try {
    const redisClient = await getRedis();
    if (!redisClient) return false;
    
    await redisClient.sadd(BANNED_IPS_KEY, ip);
    console.log(`[IP Ban] 🚫 BANNED IP: ${ip} - Reason: ${reason}`);
    return true;
  } catch (error) {
    console.error("[IP Ban] Ban error:", error.message);
    return false;
  }
}

// Send Discord webhook
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
  if (!webhookUrl) return;

  try {
    const colors = {
      success: 0x00ff00,
      blocked: 0xff0000,
      warning: 0xffff00,
      suspicious: 0xff00ff,
    };

    const embed = {
      title: logData.title || "Mobile Access Log",
      color: colors[logData.status] || 0x808080,
      fields: [
        { name: "👤 User", value: logData.user || "Unknown", inline: true },
        { name: "🌐 IP", value: `\`${logData.ip || "Unknown"}\``, inline: true },
        { name: "📱 Platform", value: "Mobile", inline: true },
        { name: "✅ Status", value: logData.statusMessage || logData.status, inline: true },
      ],
      timestamp: new Date().toISOString(),
      footer: { text: "📱 StarshipCore Mobile Security" },
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
    console.error("[Discord] Error:", error.message);
  }
}

// ═══════════════════════════════════════════════════════════════════
// MAIN HANDLER - All logic is server-side, NO URLs exposed to client
// ═══════════════════════════════════════════════════════════════════
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

  // Check development mode
  const isDev =
    process.env.NODE_ENV === "development" ||
    process.env.VERCEL_ENV === "development" ||
    req.headers.host?.includes("localhost");

  // ═══════════════════════════════════════════════════════════════
  // CHECK IF IP IS BANNED
  // ═══════════════════════════════════════════════════════════════
  const banned = await isIPBanned(clientIP);
  if (banned) {
    console.log(`[${timestamp}] 🚫 BANNED IP BLOCKED: ${clientIP}`);
    res.setHeader("Content-Type", "text/plain");
    return res.status(403).send('error("Access denied")');
  }

  // ═══════════════════════════════════════════════════════════════
  // CHECK MOBILE STATUS FROM REDIS (MAINTENANCE/OFFLINE CHECK)
  // This is the PRIMARY status check - consistent with PC and manager
  // ═══════════════════════════════════════════════════════════════
  if (!isDev) {
    try {
      const redisClient = await getRedis();
      if (redisClient) {
        const statusData = await redisClient.get('starship:status:mobile');
        if (statusData) {
          const status = JSON.parse(statusData);
          if (status.status === 'maintenance' || status.status === 'offline') {
            console.log(`[${timestamp}] 🔧 MOBILE ${status.status.toUpperCase()} (Redis) | IP: ${clientIP}`);
            
            res.setHeader("Content-Type", "text/plain; charset=utf-8");
            res.setHeader("X-Status", status.status);
            
            const statusEmoji = status.status === 'maintenance' ? '🔧' : '🔴';
            const statusTitle = status.status === 'maintenance' ? 'Maintenance Mode' : 'System Offline';
            const statusMessage = status.message || (status.status === 'maintenance' 
              ? 'Mobile is under maintenance. Please try again later.'
              : 'Mobile is currently offline. Please try again later.');
            
            return res.status(200).send(`
-- StarshipCore Mobile - ${statusTitle}
print("[StarshipCore Mobile] ${statusEmoji} ${statusTitle}")
print("[StarshipCore Mobile] ${statusMessage}")

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "${statusEmoji} ${statusTitle}",
        Text = "${statusMessage}",
        Duration = 10
    })
end)

warn("[StarshipCore] Mobile access is temporarily disabled.")
`);
          }
        }
      }
    } catch (e) {
      console.error(`[${timestamp}] ⚠️ Redis status check error:`, e.message);
      // Continue if Redis fails
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // MAINTENANCE MODE - Fallback from Google Sheets (legacy)
  // ═══════════════════════════════════════════════════════════════
  if (!isDev) {
    const maintStatus = await checkMaintenanceFromSheets();
    if (maintStatus.maintenance) {
      console.log(`[${timestamp}] 🔧 MOBILE MAINTENANCE (Sheets) | IP: ${clientIP}`);
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(200).send(`
-- StarshipCore Mobile - Maintenance Mode
print("[StarshipCore Mobile] 🔧 Maintenance Mode")
pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "🔧 Maintenance",
        Text = "${maintStatus.message}",
        Duration = 10
    })
end)
warn("[StarshipCore] Mobile access is temporarily disabled.")
`);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // BROWSER DETECTION - Block and ban browsers
  // ═══════════════════════════════════════════════════════════════
  const browserPatterns = ["Mozilla", "Chrome", "Safari", "Firefox", "Edge", "Opera", "MSIE", "Trident", "WebKit", "Gecko"];
  const robloxPatterns = ["Roblox", "RobloxApp", "synapse", "SYNAPSE_HTTP", "krnl", "fluxus", "arceus", "delta", "hydrogen", "evon", "vegax", "script-ware", "comet"];

  const isRobloxExecutor = robloxPatterns.some((p) => userAgent.toLowerCase().includes(p.toLowerCase()));
  const isBrowser = userAgent !== "" && !isRobloxExecutor && browserPatterns.some((p) => userAgent.includes(p));

  if (isBrowser) {
    console.log(`[${timestamp}] 🚨 BROWSER BLOCKED | IP: ${clientIP}`);
    await banIP(clientIP, `Browser access - UA: ${userAgent.substring(0, 50)}`);
    
    await sendDiscordLog({
      title: "🚨 BROWSER ACCESS - IP BANNED",
      status: "suspicious",
      ip: clientIP,
      user: "Browser",
      statusMessage: "🚫 BANNED",
      message: `Browser tried accessing mobile-bootstrap\nUA: ${userAgent.substring(0, 100)}`,
    });

    res.setHeader("Content-Type", "text/html");
    return res.status(403).send(`
<!DOCTYPE html>
<html>
<head><title>403 Forbidden</title>
<style>body{font-family:Arial;text-align:center;padding:50px;background:#0f0f1a;color:#eee}h1{color:#8b5cf6}</style>
</head>
<body><h1>403 Forbidden</h1><p>This endpoint is for authorized applications only.</p></body>
</html>`);
  }

  console.log(`[${timestamp}] 📱 Mobile Bootstrap GRANTED | IP: ${clientIP}`);

  // ═══════════════════════════════════════════════════════════════
  // DEV MODE - Serve script directly with dev config
  // ═══════════════════════════════════════════════════════════════
  if (isDev) {
    try {
      const scriptPath = path.join(process.cwd(), "data", "MobileUI.lua");
      if (!fs.existsSync(scriptPath)) {
        return res.status(404).send('error("MobileUI.lua not found")');
      }

      let scriptContent = fs.readFileSync(scriptPath, "utf8");
      if (scriptContent.charCodeAt(0) === 0xfeff) {
        scriptContent = scriptContent.slice(1);
      }

      const devBootstrap = `
-- StarshipCore Mobile - Development Mode
_G.StarshipServerMode = true
_G.StarshipServerURL = "http://localhost:3000"
_G.StarshipEventCode = "${process.env.R2_EVENT_CODE || ""}"

getgenv().StarshipSession = {
    Role = "DEV_MODE",
    Duration = "DEVELOPMENT",
    Platform = "mobile",
    DevMode = true
}

print("[StarshipCore] 🛠️ Dev Mode - Auth Skipped")
${scriptContent}
`;

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("X-Mode", "development");
      return res.status(200).send(devBootstrap);
    } catch (error) {
      console.error(`[${timestamp}] ❌ DEV Error:`, error);
      return res.status(500).send('error("Dev mode error")');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // PRODUCTION MODE - Serve OBFUSCATED mobile-loader directly
  // This is the key security improvement: we serve the loader directly
  // without exposing any intermediate endpoint URLs
  // ═══════════════════════════════════════════════════════════════
  
  try {
    // Use obfuscated loader for production
    const loaderPath = path.join(process.cwd(), "protected", "mobile-loader-obfuscated.lua");
    
    if (!fs.existsSync(loaderPath)) {
      // Fallback to non-obfuscated if obfuscated doesn't exist
      const fallbackPath = path.join(process.cwd(), "protected", "mobile-loader.lua");
      if (!fs.existsSync(fallbackPath)) {
        console.error(`[${timestamp}] ❌ Mobile loader not found`);
        return res.status(500).send('error("Mobile loader not available")');
      }
      
      let loaderScript = fs.readFileSync(fallbackPath, "utf8");
      
      // Remove BOM if present
      if (loaderScript.charCodeAt(0) === 0xfeff) {
        loaderScript = loaderScript.slice(1);
      }
      
      // Inject server mode config at the top
      const configuredScript = `-- StarshipCore Mobile Loader v3.0 (Secure)
_G.StarshipServerMode = true
_G.StarshipServerURL = "https://starship-core.my.id"

${loaderScript}`;

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      res.setHeader("X-Bootstrap-Version", "3.0-secure");
      res.setHeader("X-Platform", "mobile");
      
      return res.status(200).send(configuredScript);
    }
    
    // Serve obfuscated loader
    let loaderScript = fs.readFileSync(loaderPath, "utf8");
    
    // Remove BOM if present
    if (loaderScript.charCodeAt(0) === 0xfeff) {
      loaderScript = loaderScript.slice(1);
    }
    
    // Inject server mode config at the top (before obfuscated code)
    const configuredScript = `-- StarshipCore Mobile v3.0
_G.StarshipServerMode = true
_G.StarshipServerURL = "https://starship-core.my.id"

${loaderScript}`;

    res.setHeader("Content-Type", "text/plain; charset=utf-8");
    res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
    res.setHeader("X-Bootstrap-Version", "3.0-secure");
    res.setHeader("X-Platform", "mobile");

    return res.status(200).send(configuredScript);
    
  } catch (error) {
    console.error(`[${timestamp}] ❌ Error serving loader:`, error);
    return res.status(500).send('error("Server error")');
  }
}
