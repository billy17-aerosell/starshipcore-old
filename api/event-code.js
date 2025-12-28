// Event Code Redemption API for Mobile Users
// Allows new users to redeem event codes directly from mobile loader

const EVENT_CODE_API_URL = process.env.EVENT_CODE_API_URL || "";

// Helper to get client IP
function getClientIP(req) {
  return (
    req.headers["x-real-ip"] ||
    req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    req.socket?.remoteAddress ||
    "unknown"
  );
}

// Discord webhook for logging
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
  if (!webhookUrl) return;

  try {
    const colors = {
      success: 0x22c55e,
      error: 0xef4444,
      info: 0x3b82f6,
    };

    const embed = {
      title: logData.title || "Event Code",
      color: colors[logData.status] || 0x6366f1,
      fields: [
        { name: "👤 User", value: logData.user || "Unknown", inline: true },
        { name: "🎟️ Code", value: `\`${logData.code || "N/A"}\``, inline: true },
        { name: "🌐 IP", value: `\`${logData.ip}\``, inline: true },
      ],
      description: logData.message,
      timestamp: new Date().toISOString(),
      footer: { text: "📱 Starship Event Code System" },
    };

    await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });
  } catch (e) {
    console.error("[Discord] Webhook error:", e.message);
  }
}

export default async function handler(req, res) {
  // CORS
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  const { action, code, userId, username } = req.query;
  const clientIP = getClientIP(req);
  const timestamp = new Date().toISOString();

  console.log(`[${timestamp}] Event Code API - Action: ${action} | User: ${userId} | Code: ${code} | IP: ${clientIP}`);

  if (!EVENT_CODE_API_URL) {
    return res.status(500).json({
      success: false,
      message: "Event code system not configured",
    });
  }

  try {
    // Action: check - Check if user has active event access
    if (action === "status" || action === "check") {
      const apiUrl = `${EVENT_CODE_API_URL}?action=status&userId=${userId}`;
      
      const response = await fetch(apiUrl);
      const data = await response.json();
      
      return res.status(200).json(data);
    }

    // Action: redeem - Redeem a new event code
    if (action === "redeem") {
      if (!code) {
        return res.status(400).json({
          success: false,
          message: "Kode tidak boleh kosong",
        });
      }

      if (!userId) {
        return res.status(400).json({
          success: false,
          message: "User ID diperlukan",
        });
      }

      const apiUrl = `${EVENT_CODE_API_URL}?action=redeem&code=${encodeURIComponent(code)}&userId=${userId}&username=${encodeURIComponent(username || "Unknown")}`;
      
      const response = await fetch(apiUrl);
      const data = await response.json();

      // Log to Discord
      await sendDiscordLog({
        title: data.success ? "🎟️ Event Code Redeemed" : "❌ Event Code Failed",
        status: data.success ? "success" : "error",
        user: `${username} (${userId})`,
        code: code,
        ip: clientIP,
        message: data.message,
      });

      return res.status(200).json(data);
    }

    return res.status(400).json({
      success: false,
      message: "Invalid action. Use: status, check, or redeem",
    });

  } catch (error) {
    console.error("[Event Code] Error:", error.message);
    
    return res.status(500).json({
      success: false,
      message: "Gagal terhubung ke server",
      error: error.message,
    });
  }
}
