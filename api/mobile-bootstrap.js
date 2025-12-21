// Mobile Bootstrap Endpoint - Public entry point for StarshipCore Mobile
// Returns a small script that auto-detects userId and calls secure get-mobile-loader API
// With browser detection, obfuscated response, and Discord logging
// Development mode: Skip loader intro and directly serve MobileUI

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
      success: 0x22c55e,
      blocked: 0xef4444,
      invalid: 0xf59e0b,
      warning: 0xeab308,
      suspicious: 0x9333ea,
    };

    const color = colors[logData.status] || 0x6366f1;

    const embed = {
      title: logData.title || "📱 Mobile Access Log",
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
          value: `\`${logData.endpoint || "/api/mobile-bootstrap"}\``,
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
        text: "📱 StarshipCore Mobile Security Monitor",
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

    console.log("[Discord] ✅ Mobile security alert sent");
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

  // Check for development mode
  const isDev =
    process.env.NODE_ENV === "development" ||
    process.env.VERCEL_ENV === "development" ||
    req.headers.host?.includes("localhost");

  // Check for dev query parameter to force dev mode
  const forceDevMode = req.query.dev === "true" || req.query.dev === "1";

  // Development Mode: Skip loader intro and directly serve MobileUI
  if (isDev || forceDevMode) {
    console.log(
      `[${timestamp}] 🛠️ MOBILE DEV MODE - Skipping loader, serving MobileUI directly | IP: ${clientIP}`,
    );

    try {
      const uiPath = path.join(process.cwd(), "data", "MobileUI.lua");

      if (!fs.existsSync(uiPath)) {
        console.error(`[${timestamp}] ❌ DEV MODE - MobileUI.lua not found`);
        return res.status(404).send('error("MobileUI.lua not found")');
      }

      const uiScript = fs.readFileSync(uiPath, "utf8");

      // Create a simple bootstrap that sets session and loads UI directly
      const devBootstrap = `
-- StarshipCore Mobile - Development Mode
-- Skipping authentication for faster development

-- Set mock session data for development
getgenv().StarshipSession = {
    Role = "DEV_MODE",
    Duration = "DEVELOPMENT",
    Expiry = nil,
    RemainingDays = nil,
    Platform = "mobile",
    DeviceCount = 1,
    MaxDevices = 99,
    Username = game:GetService("Players").LocalPlayer.Name,
    DevMode = true
}

print("[StarshipCore] 🛠️ Development Mode - Auth Skipped")
print("[StarshipCore] 📱 Loading MobileUI directly...")

-- Load MobileUI directly
${uiScript}
`;

      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      res.setHeader("X-Mode", "development");
      res.setHeader("X-Platform", "mobile");

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

  // Log User-Agent for debugging
  console.log(
    `[${timestamp}] 📱 Mobile Bootstrap - UA: "${userAgent}" | IP: ${clientIP} | IsBrowser: ${isBrowser}`,
  );

  // If accessed from browser, log and return fake error page
  if (isBrowser) {
    console.log(
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED (Mobile) | IP: ${clientIP} | UA: ${userAgent.substring(0, 50)}`,
    );

    // Send Discord alert for suspicious browser access
    await sendDiscordLog({
      title: "🚨 Suspicious Browser Access - Mobile Bootstrap",
      status: "suspicious",
      ip: clientIP,
      userAgent: userAgent,
      endpoint: "/api/mobile-bootstrap",
      timestamp: timestamp,
      message: `⚠️ **Someone tried to access mobile bootstrap from a browser!**\n\n**Referer:** \`${referer}\`\n**This could be:**\n• Hacker trying to discover API\n• Curious user\n• Bot/crawler`,
    });

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
            background: #0f0f1a;
            color: #eee;
        }
        h1 { color: #8b5cf6; font-size: 48px; }
        p { color: #888; margin: 10px 0; }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: #1a1a2e;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(139, 92, 246, 0.2);
            border: 1px solid #8b5cf6;
        }
        .icon { font-size: 64px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📱🚫</div>
        <h1>403</h1>
        <p><strong>Forbidden</strong></p>
        <p>Direct access to this endpoint is not allowed.</p>
        <p>This API is for authorized mobile applications only.</p>
    </div>
</body>
</html>
    `);
  }

  // Log legitimate access (from Roblox executor on mobile)
  console.log(
    `[${timestamp}] 📱 Mobile Bootstrap GRANTED | IP: ${clientIP} | UA: "${userAgent}"`,
  );

  // Obfuscated bootstrap script for Mobile
  // Uses get-mobile-loader API (same pattern as PC bootstrap)
  const encodedUrl = Buffer.from(
    "https://starship-core.my.id/api/get-mobile-loader?userId=",
  ).toString("base64");

  // Mobile bootstrap script - calls get-mobile-loader first (like PC pattern)
  const mobileBootstrapScript = `local a=game:GetService("Players")local b=a.LocalPlayer;if not b then b=a:GetPropertyChangedSignal("LocalPlayer"):Wait()end;local c=tostring(b.UserId)local function d(e)local f=""for g in e:gmatch(".")do local h=string.byte(g)if h>=65 and h<=90 then f=f..string.char((h-65+26-13)%26+65)elseif h>=97 and h<=122 then f=f..string.char((h-97+26-13)%26+97)else f=f..g end end;return f end;local function i(j)local k="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"j=string.gsub(j,"[^"..k.."=]","")return(j:gsub(".",function(l)if l=="="then return""end;local m,n="",k:find(l)-1;for o=6,1,-1 do m=m..(n%2^o-n%2^(o-1)>0 and"1"or"0")end;return m end):gsub("%d%d%d?%d?%d?%d?%d?%d?",function(l)if#l~=8 then return""end;local p=0;for o=1,8 do p=p+(l:sub(o,o)=="1"and 2^(8-o)or 0)end;return string.char(p)end))end;local q=i("${encodedUrl}")..c;local r,s=pcall(function()return game:HttpGet(q)end)if r and s then if s:find("error%(")then warn("[SM] "..s)return end;local t,u=loadstring(s)if t then t()else warn("[SM] Load failed: "..tostring(u))end else warn("[SM] Connection failed")end`;

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("X-Bootstrap-Version", "2.0-mobile");
  res.setHeader("X-Platform", "mobile");

  return res.status(200).send(mobileBootstrapScript);
}
