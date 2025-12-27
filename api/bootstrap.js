// Unified Bootstrap Endpoint - Public entry point for StarshipCore
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// Returns a small script that auto-detects userId and calls secure get-loader API
// With browser detection, obfuscated response, and Discord logging
// Development mode: Skip loader intro and directly serve script

// Owner userId - bypasses cross-platform restrictions
const OWNER_USER_ID = "9268011358";

// ═══════════════════════════════════════════════════════════════════
// MAINTENANCE MODE - Set to true to disable mobile access temporarily
// ═══════════════════════════════════════════════════════════════════
const MOBILE_MAINTENANCE = true; // <-- SECURITY: Mobile disabled during investigation (updated: 2025-12-28)

import fs from "fs";
import path from "path";

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

  // Determine platform (default: pc)
  const platform = req.query.platform === "mobile" ? "mobile" : "pc";
  const platformLabel = platform === "mobile" ? "📱 Mobile" : "💻 PC";
  const platformEmoji = platform === "mobile" ? "📱" : "💻";

  // Check for development mode (check this early to bypass maintenance)
  const isDev =
    process.env.NODE_ENV === "development" ||
    process.env.VERCEL_ENV === "development" ||
    req.headers.host?.includes("localhost");
  const forceDevMode = req.query.dev === "true" || req.query.dev === "1";

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
  const platformConfig = {
    pc: {
      scriptFile: "StarshipCore.lua",
      loaderEndpoint: "get-loader",
      sessionPlatform: "pc",
      bootstrapVersion: "2.0",
    },
    mobile: {
      scriptFile: "MobileUI.lua",
      loaderEndpoint: "get-mobile-loader",
      sessionPlatform: "mobile",
      bootstrapVersion: "2.0-mobile",
    },
  };

  const config = platformConfig[platform];

  // Development Mode: Skip loader intro and directly serve script
  // (isDev and forceDevMode were already checked above for maintenance bypass)
  if (isDev || forceDevMode) {
    console.log(
      `[${timestamp}] 🛠️ ${platformLabel} DEV MODE - Skipping loader, serving ${config.scriptFile} directly | IP: ${clientIP}`,
    );

    try {
      const scriptPath = path.join(process.cwd(), "data", config.scriptFile);

      if (!fs.existsSync(scriptPath)) {
        console.error(
          `[${timestamp}] ❌ DEV MODE - ${config.scriptFile} not found`,
        );
        return res.status(404).send(`error("${config.scriptFile} not found")`);
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

    // Send Discord alert for suspicious browser access
    await sendDiscordLog({
      title: `🚨 Suspicious Browser Access - ${platformLabel} Bootstrap`,
      status: "suspicious",
      ip: clientIP,
      userAgent: userAgent,
      endpoint: `/api/bootstrap${platform === "mobile" ? "?platform=mobile" : ""}`,
      platform: platformLabel,
      timestamp: timestamp,
      message: `⚠️ **Someone tried to access ${platform} bootstrap from a browser!**\n\n**Referer:** \`${referer}\`\n**This could be:**\n• Hacker trying to discover API\n• Curious user\n• Bot/crawler`,
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

  // Obfuscated bootstrap script
  // The actual URL is encoded to prevent easy discovery
  const loaderUrl = `https://starship-core.my.id/api/${config.loaderEndpoint}?userId=`;
  const serverUrl = "https://starship-core.my.id";
  const encodedUrl = Buffer.from(loaderUrl).toString("base64");

  // Prefix for error messages (S for PC, SM for Mobile)
  const errorPrefix = platform === "mobile" ? "SM" : "S";

  const bootstrapScript = `_G.StarshipServerMode=true;_G.StarshipServerURL="${serverUrl}";local a=game:GetService("Players")local b=a.LocalPlayer;if not b then b=a:GetPropertyChangedSignal("LocalPlayer"):Wait()end;local c=tostring(b.UserId)local function d(e)local f=""for g in e:gmatch(".")do local h=string.byte(g)if h>=65 and h<=90 then f=f..string.char((h-65+26-13)%26+65)elseif h>=97 and h<=122 then f=f..string.char((h-97+26-13)%26+97)else f=f..g end end;return f end;local function i(j)local k="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"j=string.gsub(j,"[^"..k.."=]","")return(j:gsub(".",function(l)if l=="="then return""end;local m,n="",k:find(l)-1;for o=6,1,-1 do m=m..(n%2^o-n%2^(o-1)>0 and"1"or"0")end;return m end):gsub("%d%d%d?%d?%d?%d?%d?%d?",function(l)if#l~=8 then return""end;local p=0;for o=1,8 do p=p+(l:sub(o,o)=="1"and 2^(8-o)or 0)end;return string.char(p)end))end;local q=i("${encodedUrl}")..c;local r,s=pcall(function()return game:HttpGet(q)end)if r and s then if s:find("error%(")then warn("[${errorPrefix}] "..s)return end;local t,u=loadstring(s)if t then t()else warn("[${errorPrefix}] Load failed: "..tostring(u))end else warn("[${errorPrefix}] Connection failed")end`;

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("X-Bootstrap-Version", config.bootstrapVersion);
  res.setHeader("X-Platform", platform);

  return res.status(200).send(bootstrapScript);
}
