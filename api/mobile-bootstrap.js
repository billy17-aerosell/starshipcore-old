// Mobile Bootstrap Endpoint - Public entry point for StarshipCore Mobile
// Returns a small script that auto-detects userId and calls secure mobile-load API
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
  console.log(`[${timestamp}] 📱 Mobile Bootstrap requested | IP: ${clientIP}`);

  // Obfuscated bootstrap script for Mobile
  // The actual URL is encoded to prevent easy discovery
  const encodedMobileUrl = Buffer.from(
    "https://starship-core.my.id/api/mobile-load?userId=",
  ).toString("base64");

  const encodedMobileScriptUrl = Buffer.from(
    "https://starship-core.my.id/Mobile/Loader.lua",
  ).toString("base64");

  // Mobile bootstrap script - similar to PC but calls mobile endpoints
  const mobileBootstrapScript = `local a=game:GetService("Players")local b=game:GetService("HttpService")local c=game:GetService("TweenService")local d=a.LocalPlayer;if not d then d=a:GetPropertyChangedSignal("LocalPlayer"):Wait()end;local e=tostring(d.UserId)local function f(g)local h="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"g=string.gsub(g,"[^"..h.."=]","")return(g:gsub(".",function(i)if i=="="then return""end;local j,k="",h:find(i)-1;for l=6,1,-1 do j=j..(k%2^l-k%2^(l-1)>0 and"1"or"0")end;return j end):gsub("%d%d%d?%d?%d?%d?%d?%d?",function(i)if#i~=8 then return""end;local m=0;for l=1,8 do m=m+(i:sub(l,l)=="1"and 2^(8-l)or 0)end;return string.char(m)end))end;local n=f("${encodedMobileUrl}")..e;local o=f("${encodedMobileScriptUrl}");local function p()local q=Instance.new("ScreenGui")q.Name="SMBL"q.ResetOnSpawn=false;q.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;q.IgnoreGuiInset=true;pcall(function()q.Parent=game:GetService("CoreGui")end)if not q.Parent then q.Parent=d:WaitForChild("PlayerGui")end;local r=Instance.new("Frame")r.Size=UDim2.new(1,0,1,0)r.BackgroundColor3=Color3.fromHex("#0a0a0f")r.BorderSizePixel=0;r.Parent=q;local s=Instance.new("TextLabel")s.Size=UDim2.new(0,200,0,30)s.Position=UDim2.new(0.5,0,0.5,0)s.AnchorPoint=Vector2.new(0.5,0.5)s.BackgroundTransparency=1;s.Text="Loading..."s.TextColor3=Color3.fromHex("#8b5cf6")s.TextSize=18;s.Font=Enum.Font.GothamBold;s.Parent=r;return q,s end;local t,u=p()local function v(w)if u then u.Text=w end end;v("Authenticating...")local x,y=pcall(function()return game:HttpGet(n)end)if not x then if t then t:Destroy()end;warn("[SM] Connection failed")return end;v("Verifying license...")local z=nil;pcall(function()z=b:JSONDecode(y)end)if not z then if t then t:Destroy()end;warn("[SM] Invalid response")return end;if z.status~="success"then if t then t:Destroy()end;warn("[SM] "..(z.message or"Access denied"))return end;getgenv().StarshipSession={Role=z.role or"MOBILE VIP",Duration=z.duration or"LIFETIME",Expiry=z.expiry,RemainingDays=z.remainingDays,Platform="mobile",DeviceCount=z.deviceCount,MaxDevices=z.maxDevices,Username=z.username}v("Loading UI...")local A,B=pcall(function()return game:HttpGet(o)end)if not A or not B or B==""then if t then t:Destroy()end;warn("[SM] Failed to load UI")return end;v("Launching...")task.wait(0.3)if t then c:Create(t:FindFirstChild("Frame"),TweenInfo.new(0.3),{BackgroundTransparency=1}):Play()task.wait(0.3)t:Destroy()end;local C,D=loadstring(B)if C then C()else warn("[SM] Execution error: "..tostring(D))end`;

  res.setHeader("Content-Type", "text/plain; charset=utf-8");
  res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
  res.setHeader("X-Bootstrap-Version", "2.0-mobile");
  res.setHeader("X-Platform", "mobile");

  return res.status(200).send(mobileBootstrapScript);
}
