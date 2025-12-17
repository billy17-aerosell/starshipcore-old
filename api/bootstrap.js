// Bootstrap Endpoint - Public entry point for StarshipCore
// Returns a small script that auto-detects userId and calls secure get-loader
// With browser detection, obfuscated response, and Discord logging

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
          name: "⏰ Timestamp",
          value: logData.timestamp,
          inline: true,
        },
      ],
      timestamp: new Date().toISOString(),
      footer: {
        text: "StarshipCore Security Monitor",
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

  const isBrowser = browserPatterns.some((pattern) =>
    userAgent.includes(pattern),
  );

  // If accessed from browser, log and return fake error page
  if (isBrowser) {
    console.log(
      `[${timestamp}] 🚨 BROWSER ACCESS BLOCKED | IP: ${clientIP} | UA: ${userAgent.substring(0, 50)}`,
    );

    // Send Discord alert for suspicious browser access
    await sendDiscordLog({
      title: "🚨 Suspicious Browser Access Detected",
      status: "suspicious",
      ip: clientIP,
      userAgent: userAgent,
      endpoint: "/api/bootstrap",
      timestamp: timestamp,
      message: `⚠️ **Someone tried to access bootstrap from a browser!**\n\n**Referer:** \`${referer}\`\n**This could be:**\n• Hacker trying to discover API\n• Curious user\n• Bot/crawler`,
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
            background: #1a1a2e;
            color: #eee;
        }
        h1 { color: #ff6b6b; font-size: 48px; }
        p { color: #888; margin: 10px 0; }
        .container {
            max-width: 500px;
            margin: 0 auto;
            background: #16213e;
            padding: 40px;
            border-radius: 10px;
            box-shadow: 0 4px 20px rgba(0,0,0,0.3);
        }
        .icon { font-size: 64px; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">🚫</div>
        <h1>403</h1>
        <p><strong>Forbidden</strong></p>
        <p>Direct access to this endpoint is not allowed.</p>
        <p>This API is for authorized applications only.</p>
    </div>
</body>
</html>
    `);
  }

  // Log legitimate access (from Roblox executor)
  console.log(`[${timestamp}] 🚀 Bootstrap requested | IP: ${clientIP}`);

  // Obfuscated bootstrap script
  // The actual URL is encoded to prevent easy discovery
  const encodedUrl = Buffer.from(
    "https://starship-core.my.id/api/get-loader?userId=",
  ).toString("base64");

  const bootstrapScript = `local a=game:GetService("Players")local b=a.LocalPlayer;if not b then b=a:GetPropertyChangedSignal("LocalPlayer"):Wait()end;local c=tostring(b.UserId)local function d(e)local f=""for g in e:gmatch(".")do local h=string.byte(g)if h>=65 and h<=90 then f=f..string.char((h-65+26-13)%26+65)elseif h>=97 and h<=122 then f=f..string.char((h-97+26-13)%26+97)else f=f..g end end;return f end;local function i(j)local k="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"j=string.gsub(j,"[^"..k.."=]","")return(j:gsub(".",function(l)if l=="="then return""end;local m,n="",k:find(l)-1;for o=6,1,-1 do m=m..(n%2^o-n%2^(o-1)>0 and"1"or"0")end;return m end):gsub("%d%d%d?%d?%d?%d?%d?%d?",function(l)if#l~=8 then return""end;local p=0;for o=1,8 do p=p+(l:sub(o,o)=="1"and 2^(8-o)or 0)end;return string.char(p)end))end;local q=i("${encodedUrl}")..c;local r,s=pcall(function()return game:HttpGet(q)end)if r and s then if s:find("error%(")then warn("[S] "..s)return end;local t,u=loadstring(s)if t then t()else warn("[S] Load failed: "..tostring(u))end else warn("[S] Connection failed")end`;

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("X-Bootstrap-Version", "2.0");

  return res.status(200).send(bootstrapScript);
}
