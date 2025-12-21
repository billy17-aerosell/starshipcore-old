// Mobile Load API - Separate Authentication for Mobile Users
// Uses separate mobile whitelist from PC whitelist

import fs from "fs";
import path from "path";

// Redis keys
const PC_WHITELIST_KEY = "starship:whitelist";

// Get Redis client
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded for /api/mobile-load");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Helper to get MOBILE whitelist from Redis (separate key from PC)
async function getMobileWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get("starship:mobile_whitelist");
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis mobile whitelist read error:", error.message);
    return null;
  }
}

// Helper to get PC whitelist from Redis (for cross-platform detection)
async function getPCWhitelistFromRedis() {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get(PC_WHITELIST_KEY);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis PC whitelist read error:", error.message);
    return null;
  }
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

// Helper function to send Discord webhook notification
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) {
    console.log("[Discord] Webhook not configured, skipping notification");
    return;
  }

  try {
    const colors = {
      success: 0x22c55e, // Green
      blocked: 0xef4444, // Red
      invalid: 0xf59e0b, // Orange
      warning: 0xeab308, // Yellow
    };

    const color = colors[logData.status] || 0x6366f1; // Default indigo

    const embed = {
      title: `📱 ${logData.title || "Mobile Access Log"}`,
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
        text: "📱 StarshipCore Mobile Auth",
      },
    };

    if (logData.message) {
      embed.description = logData.message;
    }

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
      console.log("[Discord] ✅ Mobile log sent successfully");
    }
  } catch (error) {
    console.error("[Discord] Error sending webhook:", error.message);
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

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { userId } = req.query;

  if (!userId) {
    return res.status(400).json({ error: "Missing User ID" });
  }

  const now = Math.floor(Date.now() / 1000);
  const timestamp = new Date().toISOString();
  const clientIP = getClientIP(req);

  try {
    // === CHECK MOBILE WHITELIST (Redis) ===
    const mobileWhitelist = await getMobileWhitelistFromRedis();

    if (mobileWhitelist && mobileWhitelist[userId]) {
      const mobileUser = mobileWhitelist[userId];

      // Check if user is active
      if (mobileUser.status === "active") {
        // Check expiry if set
        if (mobileUser.expiresAt) {
          const expiryDate = new Date(mobileUser.expiresAt);
          const expiryTimestamp = Math.floor(expiryDate.getTime() / 1000);

          if (expiryTimestamp < now) {
            console.log(
              `[${timestamp}] ❌ Mobile VIP expired - UserID: ${userId}`,
            );

            await sendDiscordLog({
              title: "Mobile Access Expired",
              status: "blocked",
              authType: "MOBILE_VIP (Expired)",
              owner: mobileUser.username,
              ip: clientIP,
              deviceCount: "N/A",
              timestamp: timestamp,
              message: `❌ Mobile VIP access expired for ${mobileUser.username}\nExpired: ${expiryDate.toISOString()}`,
            });

            return res.status(403).json({
              status: "denied",
              message: "Mobile VIP access expired",
              expiredAt: expiryDate.toISOString(),
            });
          }
        }

        // Mobile user valid - grant access
        console.log(
          `[${timestamp}] 📱 MOBILE VIP ACCESS - UserID: ${userId} (${mobileUser.username}) | IP: ${clientIP}`,
        );

        // Calculate remaining days
        let remainingDays = null;
        if (mobileUser.expiresAt) {
          const expiryTimestamp = Math.floor(
            new Date(mobileUser.expiresAt).getTime() / 1000,
          );
          remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
        }

        // Device tracking
        const redisClient = await getRedis();
        let deviceCount = 1;
        const maxDevices = mobileUser.maxDevices || 2;

        if (redisClient) {
          const deviceKey = `mobile_devices:${userId}`;

          try {
            // Get or create device list
            let devices = [];
            const devicesData = await redisClient.get(deviceKey);
            if (devicesData) {
              devices = JSON.parse(devicesData);
            }

            // Check if this IP is already registered
            const existingDevice = devices.find((d) => d.ip === clientIP);

            if (!existingDevice) {
              // Check device limit
              if (devices.length >= maxDevices) {
                console.log(
                  `[${timestamp}] ❌ Mobile device limit reached - UserID: ${userId} (${devices.length}/${maxDevices})`,
                );

                await sendDiscordLog({
                  title: "Mobile Device Limit Reached",
                  status: "blocked",
                  authType: "MOBILE_VIP",
                  owner: mobileUser.username,
                  ip: clientIP,
                  deviceCount: `${devices.length}/${maxDevices} (LIMIT)`,
                  timestamp: timestamp,
                  message: `⚠️ Device limit reached for ${mobileUser.username}\nNew IP: ${clientIP}\nMax allowed: ${maxDevices} devices`,
                });

                return res.status(403).json({
                  status: "denied",
                  message: `Device limit reached (${maxDevices} devices max)`,
                  currentDevices: devices.length,
                });
              }

              // Add new device
              devices.push({
                ip: clientIP,
                firstSeen: timestamp,
                lastSeen: timestamp,
              });

              await redisClient.set(
                deviceKey,
                JSON.stringify(devices),
                "EX",
                86400 * 30,
              ); // 30 days

              // Send webhook for new device
              await sendDiscordLog({
                title: "New Mobile Device Registered",
                status: "success",
                authType: `MOBILE_VIP (${mobileUser.type || "Standard"})`,
                owner: mobileUser.username,
                ip: clientIP,
                deviceCount: `${devices.length}/${maxDevices}`,
                timestamp: timestamp,
                message: `📱 New device registered for ${mobileUser.username}\n🆕 Device #${devices.length}`,
              });
            } else {
              // Update last seen
              existingDevice.lastSeen = timestamp;
              await redisClient.set(
                deviceKey,
                JSON.stringify(devices),
                "EX",
                86400 * 30,
              );
            }

            deviceCount = devices.length;
          } catch (err) {
            console.error("Device tracking error:", err);
          }
        }

        // Return success with session data
        return res.status(200).json({
          status: "success",
          platform: "mobile",
          role: mobileUser.type || "MOBILE_VIP",
          duration: mobileUser.expiresAt ? `${remainingDays} days` : "LIFETIME",
          expiry: mobileUser.expiresAt
            ? Math.floor(new Date(mobileUser.expiresAt).getTime() / 1000)
            : null,
          remainingDays: remainingDays,
          activatedAt: mobileUser.addedAt
            ? Math.floor(new Date(mobileUser.addedAt).getTime() / 1000)
            : null,
          deviceCount: deviceCount,
          maxDevices: maxDevices,
          username: mobileUser.username,
        });
      } else if (mobileUser.status === "suspended") {
        console.log(
          `[${timestamp}] 🚫 SUSPENDED Mobile VIP - UserID: ${userId}`,
        );

        await sendDiscordLog({
          title: "Suspended Mobile User Attempt",
          status: "blocked",
          authType: "MOBILE_VIP (Suspended)",
          owner: mobileUser.username,
          ip: clientIP,
          deviceCount: "N/A",
          timestamp: timestamp,
          message: `🚫 Suspended user attempted access: ${mobileUser.username}`,
        });

        return res.status(403).json({
          status: "denied",
          message: "Mobile VIP access suspended",
        });
      }
    }

    // === CHECK FILE-BASED MOBILE WHITELIST (Fallback) ===
    const mobileKeysPath = path.join(process.cwd(), "data", "mobile-keys.json");

    if (fs.existsSync(mobileKeysPath)) {
      try {
        const mobileKeysData = JSON.parse(
          fs.readFileSync(mobileKeysPath, "utf8"),
        );
        const fileWhitelist = mobileKeysData.whitelist || {};

        if (fileWhitelist[userId]) {
          const userData = fileWhitelist[userId];

          // Check expiry
          if (userData.expiresAt) {
            const expiryDate = new Date(userData.expiresAt);
            if (expiryDate < new Date()) {
              return res.status(403).json({
                status: "denied",
                message: "Mobile access expired",
                expiredAt: expiryDate.toISOString(),
              });
            }
          }

          // Calculate remaining days
          let remainingDays = null;
          if (userData.expiresAt) {
            const expiryTimestamp = Math.floor(
              new Date(userData.expiresAt).getTime() / 1000,
            );
            remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
          }

          console.log(
            `[${timestamp}] 📱 MOBILE ACCESS (File) - UserID: ${userId} (${userData.username}) | IP: ${clientIP}`,
          );

          return res.status(200).json({
            status: "success",
            platform: "mobile",
            role: userData.type || "MOBILE_VIP",
            duration: userData.duration || "LIFETIME",
            expiry: userData.expiresAt
              ? Math.floor(new Date(userData.expiresAt).getTime() / 1000)
              : null,
            remainingDays: remainingDays,
            username: userData.username,
          });
        }
      } catch (error) {
        console.error("Error reading mobile-keys.json:", error);
      }
    }

    // === CROSS-PLATFORM DETECTION: Check if user is PC-only ===
    const pcWhitelist = await getPCWhitelistFromRedis();

    if (pcWhitelist && pcWhitelist[userId]) {
      const pcUser = pcWhitelist[userId];

      // User has PC license but trying to access Mobile!
      console.log(
        `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT - PC user trying Mobile access - UserID: ${userId} (${pcUser.username}) | IP: ${clientIP}`,
      );

      // Send Discord alert
      await sendCrossPlatformAlert({
        userId: userId,
        username: pcUser.username,
        currentPlatform: "💻 PC",
        attemptedPlatform: "📱 MOBILE",
        licenseType: pcUser.type || "VIP",
        ip: clientIP,
        timestamp: timestamp,
      });

      return res.status(403).json({
        status: "denied",
        message: "You have a PC license, not Mobile",
        hint: "Your whitelist is for PC only. Purchase Mobile VIP for mobile access.",
        currentLicense: "PC",
        attemptedPlatform: "MOBILE",
      });
    }

    // Also check file-based PC whitelist
    const pcKeysPath = path.join(process.cwd(), "data", "keys.json");
    if (fs.existsSync(pcKeysPath)) {
      try {
        const pcKeysData = JSON.parse(fs.readFileSync(pcKeysPath, "utf8"));
        const filePCWhitelist = pcKeysData.whitelist || {};

        if (filePCWhitelist[userId]) {
          const pcUser = filePCWhitelist[userId];

          console.log(
            `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT (File) - PC user trying Mobile access - UserID: ${userId} | IP: ${clientIP}`,
          );

          await sendCrossPlatformAlert({
            userId: userId,
            username: pcUser.username || "Unknown",
            currentPlatform: "💻 PC",
            attemptedPlatform: "📱 MOBILE",
            licenseType: pcUser.type || pcUser.role || "VIP",
            ip: clientIP,
            timestamp: timestamp,
          });

          return res.status(403).json({
            status: "denied",
            message: "You have a PC license, not Mobile",
            hint: "Your whitelist is for PC only. Purchase Mobile VIP for mobile access.",
            currentLicense: "PC",
            attemptedPlatform: "MOBILE",
          });
        }
      } catch (err) {
        console.error("Error checking keys.json:", err);
      }
    }

    // === NOT WHITELISTED AT ALL ===
    console.log(
      `[${timestamp}] ❌ NOT WHITELISTED (Any Platform) - UserID: ${userId} | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: "Mobile Access Denied",
      status: "blocked",
      authType: "None",
      owner: `UserID: ${userId}`,
      ip: clientIP,
      deviceCount: "N/A",
      timestamp: timestamp,
      message: `❌ User not in any whitelist\nUserID: ${userId}`,
    });

    return res.status(403).json({
      status: "denied",
      message: "Not whitelisted for Mobile access",
      hint: "Purchase Mobile VIP to get access",
    });
  } catch (error) {
    console.error("Mobile Load Error:", error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
