// Unified Load API - Serves encrypted script after authentication
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// With Discord Webhook Logging Integration and cross-platform detection

// Owner userId - bypasses cross-platform restrictions
const OWNER_USER_ID = "9268011358";

import fs from "fs";
import path from "path";

// Event Code System API (from environment variable for security)
const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";

// Check if user has active event access from Google Sheets
async function checkEventAccess(userId) {
  // Skip if EVENT_CODE_API not configured
  if (!EVENT_CODE_API) {
    return { hasAccess: false };
  }
  
  try {
    const apiUrl = `${EVENT_CODE_API}?action=check&userId=${userId}`;
    const response = await fetch(apiUrl);
    const data = await response.json();

    if (data.success && data.hasAccess) {
      return {
        hasAccess: true,
        codeUsed: data.codeUsed,
        expiresAt: data.expiresAt,
        remainingDays: data.remainingDays,
        remainingHours: data.remainingHours,
      };
    }
    return { hasAccess: false };
  } catch (error) {
    console.error("Event code check error:", error.message);
    return { hasAccess: false };
  }
}

// Platform-specific configuration
const PLATFORM_CONFIG = {
  pc: {
    whitelistKey: "starship:whitelist",
    otherWhitelistKey: "starship:mobile_whitelist",
    scriptFile: "StarshipCore-obfuscated.lua", // Obfuscated for security
    keysFilePath: path.join(process.cwd(), "data", "keys.json"),
    otherKeysFilePath: path.join(process.cwd(), "data", "mobile-keys.json"),
    label: "💻 PC",
    otherLabel: "📱 MOBILE",
    defaultType: "VIP",
    userIdParam: "user",
  },
  mobile: {
    whitelistKey: "starship:mobile_whitelist",
    otherWhitelistKey: "starship:whitelist",
    scriptFile: null, // Mobile doesn't use encrypted script delivery
    keysFilePath: path.join(process.cwd(), "data", "mobile-keys.json"),
    otherKeysFilePath: path.join(process.cwd(), "data", "keys.json"),
    label: "📱 Mobile",
    otherLabel: "💻 PC",
    defaultType: "MOBILE_VIP",
    userIdParam: "userId",
  },
};

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
async function getWhitelistFromRedis(whitelistKey) {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return null;

    const data = await redisClient.get(whitelistKey);
    return data ? JSON.parse(data) : null;
  } catch (error) {
    console.error("Redis whitelist read error:", error.message);
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
      crossplatform: 0x9333ea,
    };

    const color = colors[logData.status] || 0x808080;

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
          name: "📍 Platform",
          value: logData.platform || "PC",
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
        text: `${logData.platform?.includes("Mobile") ? "📱" : "💻"} StarshipCore Auth Monitor`,
      },
    };

    if (logData.message) {
      embed.description = logData.message;
    }

    const response = await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
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

// Send Cross-Platform Detection Alert
async function sendCrossPlatformAlert(alertData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;

  if (!webhookUrl) return;

  try {
    const embed = {
      title: "🔀 Cross-Platform Access Attempt Detected!",
      color: 0x9333ea,
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

// GitHub API Configuration
const GITHUB_API = "https://api.github.com";
const KEYS_PATH = "data/keys.json";

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

export default async function handler(req, res) {
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  // Determine platform (default: pc)
  const platform = req.query.platform === "mobile" ? "mobile" : "pc";
  const config = PLATFORM_CONFIG[platform];
  const platformLabel = config.label;

  // Get user ID (different param names for PC vs Mobile)
  const userId = req.query.user || req.query.userId;

  if (!userId) {
    console.log(
      `[${new Date().toISOString()}] ❌ ${platformLabel} - Missing userId parameter`,
    );
    return res.status(400).json({ error: "Missing User ID" });
  }

  const now = Math.floor(Date.now() / 1000);
  const timestamp = new Date().toISOString();
  const clientIP = getClientIP(req);
  const userAgent = req.headers["user-agent"] || "";

  console.log(
    `[${timestamp}] ${platformLabel} LOAD Request | UserID: ${userId} | IP: ${clientIP}`,
  );

  try {
    // === CHECK WHITELIST (Redis) ===
    const whitelist = await getWhitelistFromRedis(config.whitelistKey);

    if (whitelist && whitelist[userId]) {
      const vipUser = whitelist[userId];

      // Check if user is active
      if (vipUser.status === "active") {
        // Check expiry if set
        if (vipUser.expiresAt) {
          const expiryDate = new Date(vipUser.expiresAt);
          const expiryTimestamp = Math.floor(expiryDate.getTime() / 1000);

          if (expiryTimestamp < now) {
            console.log(
              `[${timestamp}] ❌ ${platformLabel} VIP expired - UserID: ${userId}`,
            );

            if (platform === "mobile") {
              await sendDiscordLog({
                title: `${platformLabel} Access Expired`,
                status: "blocked",
                authType: `${config.defaultType} (Expired)`,
                owner: vipUser.username,
                ip: clientIP,
                platform: platformLabel,
                deviceCount: "N/A",
                timestamp: timestamp,
                message: `❌ ${platformLabel} VIP access expired for ${vipUser.username}\nExpired: ${expiryDate.toISOString()}`,
              });
            }

            return res.status(403).json({
              status: "denied",
              message: `${platform.toUpperCase()} VIP access expired`,
              expiredAt: expiryDate.toISOString(),
            });
          }
        }

        // User valid - grant access
        const isOwner = userId === "9268011358";
        console.log(
          `[${timestamp}] ${isOwner ? "👑 OWNER" : "💎 VIP"} ${platformLabel} ACCESS - UserID: ${userId} (${vipUser.username}) | IP: ${clientIP}`,
        );

        // Calculate remaining days
        let remainingDays = null;
        if (vipUser.expiresAt) {
          const expiryTimestamp = Math.floor(
            new Date(vipUser.expiresAt).getTime() / 1000,
          );
          remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
        }

        // Platform-specific handling
        if (platform === "mobile") {
          // Mobile: Return session data with device tracking
          return await handleMobileSuccess(
            res,
            userId,
            vipUser,
            clientIP,
            timestamp,
            now,
            remainingDays,
            config,
          );
        } else {
          // PC: Return encrypted script
          return await handlePCSuccess(
            res,
            userId,
            vipUser,
            clientIP,
            timestamp,
            now,
            remainingDays,
            config,
            isOwner,
          );
        }
      } else if (vipUser.status === "suspended") {
        console.log(
          `[${timestamp}] 🚫 SUSPENDED ${platformLabel} VIP - UserID: ${userId}`,
        );

        if (platform === "mobile") {
          await sendDiscordLog({
            title: `Suspended ${platformLabel} User Attempt`,
            status: "blocked",
            authType: `${config.defaultType} (Suspended)`,
            owner: vipUser.username,
            ip: clientIP,
            platform: platformLabel,
            deviceCount: "N/A",
            timestamp: timestamp,
            message: `🚫 Suspended user attempted access: ${vipUser.username}`,
          });
        }

        return res.status(403).json({
          status: "denied",
          message: `${platform.toUpperCase()} VIP access suspended`,
        });
      }
    }

    // === CROSS-PLATFORM DETECTION ===
    // Skip for owner - owner can access both platforms
    if (userId === OWNER_USER_ID) {
      console.log(
        `[${timestamp}] 👑 OWNER CROSS-PLATFORM ACCESS GRANTED - ${platformLabel} | UserID: ${userId}`,
      );

      // Calculate remaining days (null for owner = lifetime)
      const remainingDays = null;

      if (platform === "mobile") {
        return await handleMobileSuccess(
          res,
          userId,
          {
            username: "OWNER",
            type: "OWNER",
            expiresAt: null,
            addedAt: new Date().toISOString(),
            maxDevices: 99,
            restrictions: { maxDevices: 99 },
          },
          clientIP,
          timestamp,
          now,
          remainingDays,
          config,
        );
      } else {
        return await handlePCSuccess(
          res,
          userId,
          {
            username: "OWNER",
            type: "OWNER",
            expiresAt: null,
            addedAt: new Date().toISOString(),
          },
          clientIP,
          timestamp,
          now,
          remainingDays,
          config,
          true, // isOwner
        );
      }
    }

    const otherWhitelist = await getWhitelistFromRedis(
      config.otherWhitelistKey,
    );

    if (otherWhitelist && otherWhitelist[userId]) {
      const otherUser = otherWhitelist[userId];

      // === CHECK EVENT ACCESS FIRST (before blocking cross-platform) ===
      // If user has event access for mobile, allow them even if they have PC license
      if (platform === "mobile") {
        const eventAccess = await checkEventAccess(userId);
        
        if (eventAccess.hasAccess) {
          console.log(
            `[${timestamp}] 🎟️ EVENT ACCESS GRANTED (PC user with event code) - ${platformLabel} - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
          );
          
          return res.status(200).json({
            status: "success",
            platform: "mobile",
            role: "EVENT_ACCESS",
            duration: `${eventAccess.remainingDays} days`,
            remainingDays: eventAccess.remainingDays,
            username: otherUser.username || `EventUser_${userId}`,
            isEventAccess: true,
            eventCode: eventAccess.codeUsed,
            expiresAt: eventAccess.expiresAt,
          });
        }
      }

      console.log(
        `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT - ${config.otherLabel} user trying ${platformLabel} access - UserID: ${userId} (${otherUser.username}) | IP: ${clientIP}`,
      );

      await sendCrossPlatformAlert({
        userId: userId,
        username: otherUser.username,
        currentPlatform: config.otherLabel,
        attemptedPlatform: platformLabel,
        licenseType:
          otherUser.type || config.otherLabel.includes("Mobile")
            ? "MOBILE_VIP"
            : "VIP",
        ip: clientIP,
        timestamp: timestamp,
      });

      return res.status(403).json({
        status: "denied",
        message: `You have a ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license, not ${platform.toUpperCase()}`,
        hint: `Your whitelist is for ${config.otherLabel.replace(/[📱💻]/g, "").trim()} only. Purchase ${platform.toUpperCase()} VIP for ${platform} access.`,
        currentLicense: config.otherLabel.replace(/[📱💻]/g, "").trim(),
        attemptedPlatform: platform.toUpperCase(),
      });
    }

    // Also check file-based other platform whitelist
    if (fs.existsSync(config.otherKeysFilePath)) {
      try {
        const otherKeysData = JSON.parse(
          fs.readFileSync(config.otherKeysFilePath, "utf8"),
        );
        const fileOtherWhitelist = otherKeysData.whitelist || {};

        if (fileOtherWhitelist[userId]) {
          const otherUser = fileOtherWhitelist[userId];

          console.log(
            `[${timestamp}] 🔀 CROSS-PLATFORM ATTEMPT (File) - ${config.otherLabel} user trying ${platformLabel} access - UserID: ${userId} | IP: ${clientIP}`,
          );

          await sendCrossPlatformAlert({
            userId: userId,
            username: otherUser.username,
            currentPlatform: config.otherLabel,
            attemptedPlatform: platformLabel,
            licenseType: otherUser.type || otherUser.role || "VIP",
            ip: clientIP,
            timestamp: timestamp,
          });

          return res.status(403).json({
            status: "denied",
            message: `You have a ${config.otherLabel.replace(/[📱💻]/g, "").trim()} license, not ${platform.toUpperCase()}`,
            hint: `Your whitelist is for ${config.otherLabel.replace(/[📱💻]/g, "").trim()} only. Purchase ${platform.toUpperCase()} VIP for ${platform} access.`,
            currentLicense: config.otherLabel.replace(/[📱💻]/g, "").trim(),
            attemptedPlatform: platform.toUpperCase(),
          });
        }
      } catch (err) {
        console.error("Error checking other keys file:", err);
      }
    }

    // === CHECK FILE-BASED WHITELIST (Fallback) ===
    if (fs.existsSync(config.keysFilePath)) {
      try {
        const keysFileData = fs.readFileSync(config.keysFilePath, "utf8");
        const keysData = JSON.parse(keysFileData);
        const fileWhitelist = keysData.whitelist || {};
        const userData = fileWhitelist[userId];

        if (userData) {
          // Check expiry
          if (userData.expiresAt) {
            const expiryDate = new Date(userData.expiresAt);
            if (expiryDate < new Date()) {
              return res.status(403).json({
                status: "denied",
                message: `${platform.toUpperCase()} access expired`,
                expiredAt: expiryDate.toISOString(),
              });
            }
          }

          // For PC: Handle first-time activation
          if (
            platform === "pc" &&
            userData.expiry === null &&
            userData.durationDays
          ) {
            console.log(`Activating license for user ${userId}...`);

            const durationSeconds = userData.durationDays * 24 * 60 * 60;
            const newExpiry = now + durationSeconds;

            userData.expiry = newExpiry;
            userData.activatedAt = now;
            keysData.whitelist[userId] = userData;

            const githubData = await getKeysFromGitHub();

            if (githubData) {
              if (!githubData.keysData.whitelist) {
                githubData.keysData.whitelist = {};
              }
              githubData.keysData.whitelist[userId] = userData;

              const updateSuccess = await updateKeysOnGitHub(
                githubData.keysData,
                githubData.sha,
              );

              if (updateSuccess) {
                console.log(
                  `License activated for user ${userId}. Expiry: ${new Date(newExpiry * 1000).toISOString()}`,
                );
              } else {
                console.error(`Failed to update GitHub for user ${userId}`);
              }
            }
          }

          // Check PC expiry (file-based)
          if (platform === "pc" && userData.expiry) {
            if (now > userData.expiry) {
              return res.status(403).json({
                status: "denied",
                message: "License Expired",
                expiredAt: new Date(userData.expiry * 1000).toISOString(),
              });
            }
          }

          // Calculate remaining days
          let remainingDays = null;
          if (platform === "pc" && userData.expiry) {
            remainingDays = Math.ceil((userData.expiry - now) / 86400);
          } else if (userData.expiresAt) {
            const expiryTimestamp = Math.floor(
              new Date(userData.expiresAt).getTime() / 1000,
            );
            remainingDays = Math.ceil((expiryTimestamp - now) / 86400);
          }

          console.log(
            `[${timestamp}] ${platformLabel} ACCESS (File) - UserID: ${userId} (${userData.username}) | IP: ${clientIP}`,
          );

          if (platform === "mobile") {
            return res.status(200).json({
              status: "success",
              platform: "mobile",
              role: userData.type || config.defaultType,
              duration: userData.duration || "LIFETIME",
              expiry: userData.expiresAt
                ? Math.floor(new Date(userData.expiresAt).getTime() / 1000)
                : null,
              remainingDays: remainingDays,
              username: userData.username,
            });
          } else {
            // PC: Return encrypted script
            return await servePCScript(
              res,
              userId,
              userData,
              now,
              remainingDays,
            );
          }
        }
      } catch (error) {
        console.error("Error reading keys file:", error);
      }
    }

    // === CHECK EVENT CODE ACCESS (Google Sheets) - Mobile Only ===
    if (platform === "mobile") {
      const eventAccess = await checkEventAccess(userId);
      
      if (eventAccess.hasAccess) {
        console.log(
          `[${timestamp}] 🎟️ EVENT ACCESS GRANTED - ${platformLabel} - UserID: ${userId} | Code: ${eventAccess.codeUsed} | IP: ${clientIP}`,
        );
        
        await sendDiscordLog({
          title: `🎟️ Event Code Access Granted - ${platformLabel}`,
          status: "success",
          authType: `Event Code: ${eventAccess.codeUsed}`,
          owner: `UserID: ${userId}`,
          ip: clientIP,
          platform: platformLabel,
          deviceCount: "N/A",
          timestamp: timestamp,
          message: `✅ Event access granted\nExpires: ${eventAccess.expiresAt}\nRemaining: ${eventAccess.remainingDays} days`,
        });
        
        // Return success for mobile event access
        return res.status(200).json({
          status: "success",
          platform: "mobile",
          role: "EVENT_ACCESS",
          duration: `${eventAccess.remainingDays} days`,
          remainingDays: eventAccess.remainingDays,
          username: `EventUser_${userId}`,
          isEventAccess: true,
          eventCode: eventAccess.codeUsed,
          expiresAt: eventAccess.expiresAt,
        });
      }
    }

    // === NOT WHITELISTED ===
    console.log(
      `[${timestamp}] ❌ NOT ${platform.toUpperCase()} WHITELISTED - UserID: ${userId} | IP: ${clientIP}`,
    );

    await sendDiscordLog({
      title: `${platformLabel} Access Denied`,
      status: "blocked",
      authType: "None",
      owner: `UserID: ${userId}`,
      ip: clientIP,
      platform: platformLabel,
      deviceCount: "N/A",
      timestamp: timestamp,
      message: `❌ User not in ${platform} whitelist\nUserID: ${userId}`,
    });

    return res.status(403).json({
      status: "denied",
      message: `Not whitelisted for ${platform.toUpperCase()} access`,
      hint: `Purchase ${platform.toUpperCase()} VIP to get access`,
    });
  } catch (error) {
    console.error(`${platformLabel} Load Error:`, error);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}

// Handle Mobile success with device tracking
async function handleMobileSuccess(
  res,
  userId,
  mobileUser,
  clientIP,
  timestamp,
  now,
  remainingDays,
  config,
) {
  const redisClient = await getRedis();
  let deviceCount = 1;
  const maxDevices =
    mobileUser.maxDevices || mobileUser.restrictions?.maxDevices || 2;

  if (redisClient) {
    const deviceKey = `mobile_devices:${userId}`;

    try {
      let devices = [];
      const devicesData = await redisClient.get(deviceKey);
      if (devicesData) {
        devices = JSON.parse(devicesData);
      }

      const existingDevice = devices.find((d) => d.ip === clientIP);

      if (!existingDevice) {
        if (devices.length >= maxDevices) {
          console.log(
            `[${timestamp}] ❌ Mobile device limit reached - UserID: ${userId} (${devices.length}/${maxDevices})`,
          );

          await sendDiscordLog({
            title: "Mobile Device Limit Reached",
            status: "blocked",
            authType: config.defaultType,
            owner: mobileUser.username,
            ip: clientIP,
            platform: config.label,
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
        );

        await sendDiscordLog({
          title: "New Mobile Device Registered",
          status: "success",
          authType: `${config.defaultType} (${mobileUser.type || "Standard"})`,
          owner: mobileUser.username,
          ip: clientIP,
          platform: config.label,
          deviceCount: `${devices.length}/${maxDevices}`,
          timestamp: timestamp,
          message: `📱 New device registered for ${mobileUser.username}\n🆕 Device #${devices.length}`,
        });
      } else {
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

  return res.status(200).json({
    status: "success",
    platform: "mobile",
    role: mobileUser.type || config.defaultType,
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
}

// Handle PC success with encrypted script delivery
async function handlePCSuccess(
  res,
  userId,
  vipUser,
  clientIP,
  timestamp,
  now,
  remainingDays,
  config,
  isOwner,
) {
  console.log(
    `[${timestamp}] 📦 Script delivery for ${isOwner ? "OWNER" : "VIP"}: ${vipUser.username}`,
  );

  const scriptPath = path.join(process.cwd(), "data", config.scriptFile);

  if (!fs.existsSync(scriptPath)) {
    return res.status(500).json({ error: "Script file missing on server" });
  }

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
    encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
  }

  // Encode to Base64
  const base64Blob = encryptedBuffer.toString("base64");

  return res.status(200).json({
    status: "success",
    role: vipUser.type || config.defaultType,
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
}

// Serve PC script from file-based whitelist
async function servePCScript(res, userId, userData, now, remainingDays) {
  const scriptPath = path.join(process.cwd(), "data", "StarshipCore.lua");

  if (!fs.existsSync(scriptPath)) {
    return res.status(500).json({ error: "Script file missing on server" });
  }

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
    encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
  }

  // Encode to Base64
  const base64Blob = encryptedBuffer.toString("base64");

  return res.status(200).json({
    status: "success",
    role: userData.role || "VIP",
    duration: userData.duration || "LIFETIME",
    expiry: userData.expiry || null,
    remainingDays: remainingDays,
    activatedAt: userData.activatedAt || null,
    key: dynamicKey,
    blob: base64Blob,
  });
}
