import fs from "fs";
import path from "path";

// Redis keys
const MOBILE_WHITELIST_KEY = "starship:mobile_whitelist";

// Get Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded for /api/load");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Helper to get whitelist from Redis
async function getWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get("starship:whitelist");
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis whitelist read error:", error.message);
    return null;
  }
}

// Helper to get MOBILE whitelist from Redis (for cross-platform detection)
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

// Helper function to send Discord webhook notification
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  // Skip if webhook not configured
  if (!webhookUrl) {
    console.log("[Discord] Webhook not configured, skipping notification");
    return;
  }

  try {
    // Determine embed color based on status
    const colors = {
      success: 0x00ff00, // Green
      blocked: 0xff0000, // Red
      invalid: 0xffa500, // Orange
      warning: 0xffff00, // Yellow
      crossplatform: 0x9333ea, // Purple - for cross-platform attempts
    };

    const color = colors[logData.status] || 0x808080;

    // Create rich embed
    const embed = {
      title: `${logData.title || "Access Log"}`,
      color: color,
      fields: [
        {
          name: "👤 User",
          value: logData.owner || "Unknown",
          inline: true,
        },
        {
          name: "🔑 Auth Type",
          value: `\`${logData.authType || "Key"}\``,
          inline: true,
        },
        {
          name: "🌐 IP Address",
          value: `\`${logData.ip}\``,
          inline: true,
        },
        {
          name: "📱 Device Count",
          value: logData.deviceCount || "N/A",
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
        text: "StarshipCore Auth Monitor",
      },
    };

    // Add additional info if present
    if (logData.message) {
      embed.description = logData.message;
    }

    // Send to Discord
    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        embeds: [embed],
      }),
    });

    if (!response.ok) {
      console.error("[Discord] Failed to send webhook:", response.status);
    } else {
      console.log("[Discord] ✅ Log sent successfully");
    }
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
  }
}

// GitHub API Configuration
const GITHUB_API = "https://api.github.com";
const KEYS_PATH = "data/keys.json"; // Changed from whitelist.json

/**
 * Update keys.json di GitHub Repository
 * @param {object} newKeysData - Complete keys.json data
 * @param {string} currentSha - SHA file saat ini (untuk update)
 */
async function updateKeysOnGitHub(newKeysData, currentSha) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    console.error("GitHub credentials not configured");
    return false;
  }

  try {
    const content = Buffer.from(JSON.stringify(newKeysData, null, 2)).toString(
      "base64",
    );

    const response = await fetch(
      `${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`,
      {
        method: "PUT",
        headers: {
          Authorization: `Bearer ${token}`,
          "Content-Type": "application/json",
          Accept: "application/vnd.github.v3+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
        body: JSON.stringify({
          message: `[Auto] Activate license for user`,
          content: content,
          sha: currentSha,
        }),
      },
    );

    if (!response.ok) {
      const errorData = await response.json();
      console.error("GitHub API Error:", errorData);
      return false;
    }

    return true;
  } catch (error) {
    console.error("GitHub Update Error:", error);
    return false;
  }
}

/**
 * Get current keys.json from GitHub (untuk dapat SHA terbaru)
 */
async function getKeysFromGitHub() {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    return null;
  }

  try {
    const response = await fetch(
      `${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`,
      {
        headers: {
          Authorization: `Bearer ${token}`,
          Accept: "application/vnd.github.v3+json",
          "X-GitHub-Api-Version": "2022-11-28",
        },
      },
    );

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    const content = Buffer.from(data.content, "base64").toString("utf8");

    return {
      sha: data.sha,
      keysData: JSON.parse(content),
    };
  } catch (error) {
    console.error("GitHub Fetch Error:", error);
    return null;
  }
}

// Get client IP helper
function getClientIP(req) {
  return (
    req.headers["x-forwarded-for"]?.split(",")[0] ||
    req.headers["x-real-ip"] ||
    req.connection?.remoteAddress ||
    "unknown"
  );
}

// Send Cross-Platform Detection Alert
async function sendCrossPlatformAlert(alertData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) return;

  try {
    const embed = {
      title: "🔀 Cross-Platform Access Attempt Detected!",
      color: 0x9333ea, // Purple
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
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { user } = req.query;

  if (!user) {
    return res.status(400).json({ error: "Missing User ID" });
  }

  const now = Math.floor(Date.now() / 1000);
  const timestamp = new Date().toISOString();
  const clientIP = getClientIP(req);

  try {
    // === PRIORITY 1: Check Redis Whitelist (VIP Users) ===
    const redisWhitelist = await getWhitelistFromRedis();

    if (redisWhitelist && redisWhitelist[user]) {
      const vipUser = redisWhitelist[user];

      // Check if user is active
      if (vipUser.status === "active") {
        // Check expiry if set
        if (vipUser.expiresAt) {
          const expiryDate = new Date(vipUser.expiresAt);
          const expiryTimestamp = Math.floor(expiryDate.getTime() / 1000);

          if (expiryTimestamp < now) {
            console.log(`[${timestamp}] ❌ VIP expired - UserID: ${user}`);
            return res.status(403).json({
              status: "denied",
              message: "VIP access expired",
              expiredAt: expiryDate.toISOString(),
            });
          }
        }

        // VIP user - grant access
        const isOwner = user === "9268011358";
        console.log(
          `[${timestamp}] ${isOwner ? "👑 OWNER" : "💎 VIP"} ACCESS via Redis - UserID: ${user} (${vipUser.username})`,
        );

        // Get client IP
        const clientIP =
          req.headers["x-forwarded-for"]?.split(",")[0] ||
          req.headers["x-real-ip"] ||
          req.connection?.remoteAddress ||
          "unknown";

        // Webhook notification is handled by /api/get-loader.js
        // This endpoint only handles script encryption and delivery
        console.log(
          `[${timestamp}] � Script delivery for ${isOwner ? "OWNER" : "VIP"}: ${vipUser.username}`,
        );

        // Read and encrypt script
        const scriptPath = path.join(process.cwd(), "data", "StarshipCore.lua");

        if (!fs.existsSync(scriptPath)) {
          return res
            .status(500)
            .json({ error: "Script file missing on server" });
        }

        // Read as buffer
        let scriptBuffer = fs.readFileSync(scriptPath);

        // Remove BOM if present
        if (
          scriptBuffer.length >= 3 &&
          scriptBuffer[0] === 0xef &&
          scriptBuffer[1] === 0xbb &&
          scriptBuffer[2] === 0xbf
        ) {
          scriptBuffer = scriptBuffer.subarray(3);
        }

        // Generate Dynamic Key
        const generateKey = (length) => {
          const chars =
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+";
          let result = "";
          for (let i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
          }
          return result;
        };

        const dynamicKey = generateKey(64);
        const keyBuffer = Buffer.from(dynamicKey);

        // XOR Encryption
        const encryptedBuffer = Buffer.alloc(scriptBuffer.length);
        for (let i = 0; i < scriptBuffer.length; i++) {
          encryptedBuffer[i] =
            scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
        }

        // Encode to Base64
        const base64Blob = encryptedBuffer.toString("base64");

        // Calculate remaining time if has expiry
        let remainingDays = null;
        if (vipUser.expiresAt) {
          const expiryTimestamp = Math.floor(
            new Date(vipUser.expiresAt).getTime() / 1000,
          );
          remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
        }

        return res.status(200).json({
          status: "success",
          role: vipUser.type || "VIP",
          duration: vipUser.expiresAt ? `${remainingDays} days` : "LIFETIME",
          expiry: vipUser.expiresAt
            ? Math.floor(new Date(vipUser.expiresAt).getTime() / 1000)
            : null,
          remainingDays: remainingDays,
          activatedAt: vipUser.addedAt
            ? Math.floor(new Date(vipUser.addedAt).getTime() / 1000)
            : null,
          key: dynamicKey,
          blob: base64Blob,
        });
      } else if (vipUser.status === "suspended") {
        console.log(`[${timestamp}] 🚫 SUSPENDED VIP - UserID: ${user}`);
        return res.status(403).json({
          status: "denied",
          message: "VIP access suspended",
        });
      }
    }

    // === CROSS-PLATFORM DETECTION: Check if user is Mobile-only ===
    const mobileWhitelist = await getMobileWhitelistFromRedis();

    if (mobileWhitelist && mobileWhitelist[user]) {
      const mobileUser = mobileWhitelist[user];

      // User has Mobile license but trying to access PC!
      console.log(
        `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT - Mobile user trying PC access - UserID: ${user} (${mobileUser.username}) | IP: ${clientIP}`,
      );

      // Send Discord alert
      await sendCrossPlatformAlert({
        userId: user,
        username: mobileUser.username,
        currentPlatform: "📱 MOBILE",
        attemptedPlatform: "💻 PC",
        licenseType: mobileUser.type || "MOBILE_VIP",
        ip: clientIP,
        timestamp: timestamp,
      });

      return res.status(403).json({
        status: "denied",
        message: "You have a Mobile license, not PC",
        hint: "Your whitelist is for Mobile only. Purchase PC VIP for desktop access.",
        currentLicense: "MOBILE",
        attemptedPlatform: "PC",
      });
    }

    // Also check file-based mobile whitelist
    const mobileKeysPath = path.join(process.cwd(), "data", "mobile-keys.json");
    if (fs.existsSync(mobileKeysPath)) {
      try {
        const mobileKeysData = JSON.parse(
          fs.readFileSync(mobileKeysPath, "utf8"),
        );
        const fileMobileWhitelist = mobileKeysData.whitelist || {};

        if (fileMobileWhitelist[user]) {
          const mobileUser = fileMobileWhitelist[user];

          console.log(
            `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT (File) - Mobile user trying PC access - UserID: ${user} | IP: ${clientIP}`,
          );

          await sendCrossPlatformAlert({
            userId: user,
            username: mobileUser.username,
            currentPlatform: "📱 MOBILE",
            attemptedPlatform: "💻 PC",
            licenseType: mobileUser.type || "MOBILE_VIP",
            ip: clientIP,
            timestamp: timestamp,
          });

          return res.status(403).json({
            status: "denied",
            message: "You have a Mobile license, not PC",
            hint: "Your whitelist is for Mobile only. Purchase PC VIP for desktop access.",
            currentLicense: "MOBILE",
            attemptedPlatform: "PC",
          });
        }
      } catch (err) {
        console.error("Error checking mobile-keys.json:", err);
      }
    }

    // === PRIORITY 2: Check File-based Whitelist (Fallback/Legacy) ===
    // Baca keys.json dari file lokal (CONSOLIDATED)
    const keysPath = path.join(process.cwd(), "data", "keys.json");
    const keysFileData = fs.readFileSync(keysPath, "utf8");
    let keysData = JSON.parse(keysFileData);

    // Get whitelist from keys.json
    const whitelist = keysData.whitelist || {};
    const userData = whitelist[user];

    if (!userData) {
      console.log(`[${timestamp}] ❌ NOT WHITELISTED - UserID: ${user}`);
      return res.status(403).json({
        status: "denied",
        message: "Not Whitelisted",
      });
    }

    // === ACTIVATION ON FIRST RUN ===
    // Jika expiry null DAN ada durationDays, ini adalah aktivasi pertama
    if (userData.expiry === null && userData.durationDays) {
      console.log(`Activating license for user ${user}...`);

      // Hitung expiry berdasarkan durationDays
      const durationSeconds = userData.durationDays * 24 * 60 * 60; // days to seconds
      const newExpiry = now + durationSeconds;

      // Update data user
      userData.expiry = newExpiry;
      userData.activatedAt = now;
      keysData.whitelist[user] = userData;

      // Update ke GitHub
      const githubData = await getKeysFromGitHub();

      if (githubData) {
        // Update whitelist dalam keys.json dari GitHub (untuk sinkronisasi)
        if (!githubData.keysData.whitelist) {
          githubData.keysData.whitelist = {};
        }
        githubData.keysData.whitelist[user] = userData;

        const updateSuccess = await updateKeysOnGitHub(
          githubData.keysData,
          githubData.sha,
        );

        if (updateSuccess) {
          console.log(
            `License activated for user ${user}. Expiry: ${new Date(newExpiry * 1000).toISOString()}`,
          );
        } else {
          console.error(`Failed to update GitHub for user ${user}`);
          // Tetap lanjutkan walaupun GitHub update gagal (pakai local)
        }
      } else {
        console.warn("Could not fetch GitHub data, using local keys.json");
      }
    }
    // === END ACTIVATION ===

    // Cek expiry (skip jika LIFETIME / tidak ada expiry)
    if (userData.expiry) {
      if (now > userData.expiry) {
        return res.status(403).json({
          status: "denied",
          message: "License Expired",
          expiredAt: new Date(userData.expiry * 1000).toISOString(),
        });
      }
    }

    // === Load dan encrypt script ===
    const scriptPath = path.join(process.cwd(), "data", "StarshipCore.lua");

    if (!fs.existsSync(scriptPath)) {
      return res.status(500).json({ error: "Script file missing on server" });
    }

    // BACA SEBAGAI BUFFER (PENTING!)
    let scriptBuffer = fs.readFileSync(scriptPath);

    // Hapus BOM jika ada (3 byte pertama: EF BB BF)
    if (
      scriptBuffer.length >= 3 &&
      scriptBuffer[0] === 0xef &&
      scriptBuffer[1] === 0xbb &&
      scriptBuffer[2] === 0xbf
    ) {
      scriptBuffer = scriptBuffer.subarray(3);
    }

    // Generate Dynamic Key
    const generateKey = (length) => {
      const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+";
      let result = "";
      for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return result;
    };

    const dynamicKey = generateKey(64);
    const keyBuffer = Buffer.from(dynamicKey);

    // Enkripsi XOR (Buffer to Buffer)
    const encryptedBuffer = Buffer.alloc(scriptBuffer.length);
    for (let i = 0; i < scriptBuffer.length; i++) {
      encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
    }

    // Encode ke Base64
    const base64Blob = encryptedBuffer.toString("base64");

    // Hitung remaining time
    let remainingDays = null;
    if (userData.expiry) {
      remainingDays = Math.ceil((userData.expiry - now) / 86400);
    }

    res.status(200).json({
      status: "success",
      role: userData.role || "VIP",
      duration: userData.duration || "LIFETIME",
      expiry: userData.expiry || null,
      remainingDays: remainingDays,
      activatedAt: userData.activatedAt || null,
      key: dynamicKey,
      blob: base64Blob,
    });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: "Internal Server Error" });
  }
}
