// Unified Whitelist Management API - Redis Version with File Fallback
// Supports both PC and Mobile platforms via ?platform=mobile query parameter
// Full CRUD operations with Redis persistence

// Owner userId - bypasses restrictions
const OWNER_USER_ID = "9268011358";

import fs from "fs";
import path from "path";

// Try to initialize Redis
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("✅ Redis module loaded");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

const ADMIN_SECRET = process.env.ADMIN_SECRET || "CHANGE_ME_PLEASE";

// Platform-specific Redis keys and file paths
const PLATFORM_CONFIG = {
  pc: {
    whitelistKey: "starship:whitelist",
    metadataKey: "starship:metadata",
    keysFilePath: path.join(process.cwd(), "data", "keys.json"),
    defaultType: "VIP",
  },
  mobile: {
    whitelistKey: "starship:mobile_whitelist",
    metadataKey: "starship:mobile_metadata",
    keysFilePath: path.join(process.cwd(), "data", "mobile-keys.json"),
    defaultType: "MOBILE_VIP",
  },
};

// === REDIS FUNCTIONS ===
async function getWhitelistFromRedis(platform) {
  const config = PLATFORM_CONFIG[platform];
  const data = await redis.get(config.whitelistKey);
  return data ? JSON.parse(data) : {};
}

async function getMetadataFromRedis(platform) {
  const config = PLATFORM_CONFIG[platform];
  const data = await redis.get(config.metadataKey);
  return data
    ? JSON.parse(data)
    : { totalWhitelisted: 0, lastUpdated: new Date().toISOString() };
}

async function saveWhitelistToRedis(platform, whitelist) {
  const config = PLATFORM_CONFIG[platform];
  await redis.set(config.whitelistKey, JSON.stringify(whitelist));
}

async function saveMetadataToRedis(platform, metadata) {
  const config = PLATFORM_CONFIG[platform];
  metadata.lastUpdated = new Date().toISOString();
  await redis.set(config.metadataKey, JSON.stringify(metadata));
}

// === FILE FUNCTIONS (Fallback) ===
function getKeysDataFromFile(platform) {
  const config = PLATFORM_CONFIG[platform];
  try {
    if (!fs.existsSync(config.keysFilePath)) {
      // Create default file if not exists
      const defaultData = {
        keys: {},
        whitelist: {},
        metadata: {
          totalWhitelisted: 0,
          lastUpdated: new Date().toISOString(),
        },
      };
      fs.writeFileSync(
        config.keysFilePath,
        JSON.stringify(defaultData, null, 2),
      );
      return defaultData;
    }
    const data = fs.readFileSync(config.keysFilePath, "utf8");
    return JSON.parse(data);
  } catch (error) {
    return {
      keys: {},
      whitelist: {},
      metadata: { totalWhitelisted: 0, lastUpdated: new Date().toISOString() },
    };
  }
}

function saveKeysDataToFile(platform, data) {
  const config = PLATFORM_CONFIG[platform];
  try {
    fs.writeFileSync(config.keysFilePath, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.error(`Failed to save ${platform} keys file:`, error);
    return false;
  }
}

// === MAIN HANDLER ===
export default async function handler(req, res) {
  // Get Redis client (may be null)
  const redisClient = await getRedis();

  // Check admin auth
  const adminAuth = req.headers["x-admin-secret"];
  if (adminAuth !== ADMIN_SECRET) {
    return res
      .status(401)
      .json({ error: "Unauthorized", message: "Invalid admin credentials" });
  }

  // Determine platform (default: pc)
  // Read from query parameter OR request body (for admin panel compatibility)
  const platformFromQuery = req.query.platform;
  const platformFromBody = req.body?.platform;
  const platform = (platformFromQuery === "mobile" || platformFromBody === "mobile") ? "mobile" : "pc";
  const config = PLATFORM_CONFIG[platform];
  const platformLabel = platform === "mobile" ? "📱 Mobile" : "💻 PC";

  // Read action from query OR body (for admin panel compatibility)
  const action = req.query.action || req.body?.action;
  const { method } = req;

  console.log(
    `[Whitelist Manager] ${platformLabel} | Action: ${action} | Method: ${method}`,
  );

  // ==== MOBILE-STYLE ROUTING (method-based) ====
  // Support both action-based (PC style) and method-based (Mobile style) routing
  if (!action) {
    try {
      switch (method) {
        case "GET":
          return await handleList(req, res, redisClient, platform, config);
        case "POST":
          return await handleAdd(req, res, redisClient, platform, config);
        case "PUT":
          return await handleUpdate(req, res, redisClient, platform, config);
        case "DELETE":
          return await handleRemove(req, res, redisClient, platform, config);
        default:
          return res.status(405).json({ error: "Method not allowed" });
      }
    } catch (error) {
      console.error(`${platformLabel} Whitelist Manager Error:`, error);
      return res
        .status(500)
        .json({ error: "Internal server error", message: error.message });
    }
  }

  // ==== PC-STYLE ROUTING (action-based) ====

  // ==== LIST ====
  if (action === "list" && method === "GET") {
    return await handleList(req, res, redisClient, platform, config);
  }

  // ==== GET INFO ====
  if (action === "info" && method === "GET") {
    const { userId } = req.query;
    if (!userId) return res.status(400).json({ error: "userId required" });

    try {
      let whitelist;

      if (redisClient) {
        try {
          whitelist = await getWhitelistFromRedis(platform);
        } catch (redisError) {
          whitelist = getKeysDataFromFile(platform).whitelist || {};
        }
      } else {
        whitelist = getKeysDataFromFile(platform).whitelist || {};
      }

      if (!whitelist[userId]) {
        return res.status(404).json({ error: "User not found", platform });
      }

      return res.status(200).json({ userId, platform, ...whitelist[userId] });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to get user info", message: error.message });
    }
  }

  // ==== AVATARS (Roblox profile pictures) ====
  if (action === "avatars" && method === "GET") {
    const { userIds } = req.query;

    if (!userIds) {
      return res.status(400).json({ error: 'userIds parameter required' });
    }

    try {
      const response = await fetch(
        `https://thumbnails.roblox.com/v1/users/avatar-headshot?userIds=${userIds}&size=48x48&format=Png&isCircular=false`
      );

      if (!response.ok) {
        throw new Error(`Roblox API returned ${response.status}`);
      }

      const data = await response.json();

      // Transform the response to a simpler format
      const avatars = {};
      if (data.data) {
        data.data.forEach(item => {
          if (item.state === 'Completed' && item.imageUrl) {
            avatars[item.targetId] = item.imageUrl;
          }
        });
      }

      return res.status(200).json({ success: true, avatars });

    } catch (error) {
      console.error('Roblox avatar fetch error:', error);
      return res.status(500).json({ error: error.message });
    }
  }

  // ==== ADD ====
  if (action === "add" && method === "POST") {
    return await handleAdd(req, res, redisClient, platform, config);
  }

  // ==== UPDATE ====
  if (action === "update" && method === "PUT") {
    return await handleUpdate(req, res, redisClient, platform, config);
  }

  // ==== REMOVE ====
  if (action === "remove" && method === "DELETE") {
    return await handleRemove(req, res, redisClient, platform, config);
  }

  // ==== SUSPEND ====
  if (action === "suspend" && method === "POST") {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    try {
      const whitelist = await getWhitelistFromRedis(platform);
      if (!whitelist[userId])
        return res.status(404).json({ error: "User not found", platform });

      whitelist[userId].status = "suspended";
      whitelist[userId].suspendedAt = new Date().toISOString();
      await saveWhitelistToRedis(platform, whitelist);

      return res.status(200).json({
        success: true,
        message: `User ${userId} suspended`,
        platform,
        data: whitelist[userId],
      });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to suspend user", message: error.message });
    }
  }

  // ==== REACTIVATE ====
  if (action === "reactivate" && method === "POST") {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    try {
      const whitelist = await getWhitelistFromRedis(platform);
      if (!whitelist[userId])
        return res.status(404).json({ error: "User not found", platform });

      whitelist[userId].status = "active";
      whitelist[userId].reactivatedAt = new Date().toISOString();
      delete whitelist[userId].suspendedAt;
      await saveWhitelistToRedis(platform, whitelist);

      return res.status(200).json({
        success: true,
        message: `User ${userId} reactivated`,
        platform,
        data: whitelist[userId],
      });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to reactivate user", message: error.message });
    }
  }

  // ==== STATS (Mobile style) ====
  if (action === "stats" && method === "GET") {
    try {
      let whitelist;

      if (redisClient) {
        whitelist = await getWhitelistFromRedis(platform);
      } else {
        const fileData = getKeysDataFromFile(platform);
        whitelist = fileData.whitelist || {};
      }

      const totalUsers = Object.keys(whitelist).length;
      const activeUsers = Object.values(whitelist).filter(
        (u) => u.status === "active",
      ).length;
      const suspendedUsers = Object.values(whitelist).filter(
        (u) => u.status === "suspended",
      ).length;
      const expiredUsers = Object.values(whitelist).filter((u) => {
        if (!u.expiresAt) return false;
        return new Date(u.expiresAt) < new Date();
      }).length;

      return res.status(200).json({
        platform,
        total: totalUsers,
        active: activeUsers,
        suspended: suspendedUsers,
        expired: expiredUsers,
      });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to get stats", message: error.message });
    }
  }

  // ==== EXTEND ====
  if (action === "extend" && method === "POST") {
    const { userId, days } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });
    if (!days || isNaN(parseInt(days))) {
      return res.status(400).json({ error: "days required (number)" });
    }

    try {
      const whitelist = await getWhitelistFromRedis(platform);
      if (!whitelist[userId]) {
        return res.status(404).json({ error: "User not found", platform });
      }

      const user = whitelist[userId];
      const daysToExtend = parseInt(days);
      const msToAdd = daysToExtend * 24 * 60 * 60 * 1000;

      // Calculate new expiry
      let currentExpiry;
      if (user.expiresAt) {
        currentExpiry = new Date(user.expiresAt);
        // If already expired, extend from now
        if (currentExpiry < new Date()) {
          currentExpiry = new Date();
        }
      } else {
        // Lifetime user - convert to timed
        currentExpiry = new Date();
      }

      const newExpiry = new Date(currentExpiry.getTime() + msToAdd);
      user.expiresAt = newExpiry.toISOString();
      user.updatedAt = new Date().toISOString();
      user.lastExtendedAt = new Date().toISOString();
      user.lastExtendedDays = daysToExtend;

      whitelist[userId] = user;
      await saveWhitelistToRedis(platform, whitelist);

      return res.status(200).json({
        success: true,
        message: `Extended ${user.username || userId} by ${daysToExtend} days`,
        platform,
        newExpiresAt: user.expiresAt,
        data: user,
      });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to extend user", message: error.message });
    }
  }

  // ==== RESET HWID ====
  if (action === "reset_hwid" && method === "POST") {
    const { userId } = req.body;
    if (!userId) return res.status(400).json({ error: "userId required" });

    try {
      const whitelist = await getWhitelistFromRedis(platform);
      if (!whitelist[userId]) {
        return res.status(404).json({ error: "User not found", platform });
      }

      const user = whitelist[userId];

      // Save current HWID to history before clearing
      user.hwidHistory = user.hwidHistory || [];
      if (user.hwid) {
        user.hwidHistory.push({
          hwid: user.hwid,
          resetAt: new Date().toISOString(),
        });
      }

      // Clear HWID data
      user.hwid = null;
      user.lastHwidReset = new Date().toISOString();
      user.updatedAt = new Date().toISOString();

      whitelist[userId] = user;
      await saveWhitelistToRedis(platform, whitelist);

      return res.status(200).json({
        success: true,
        message: `HWID reset for ${user.username || userId}`,
        platform,
        data: user,
      });
    } catch (error) {
      return res
        .status(500)
        .json({ error: "Failed to reset HWID", message: error.message });
    }
  }

  return res.status(400).json({
    error: "Invalid action",
    platform,
    availableActions: [
      "list",
      "add",
      "update",
      "remove",
      "info",
      "suspend",
      "reactivate",
      "stats",
      "extend",
      "reset_hwid",
    ],
  });
}

// === HANDLER FUNCTIONS ===

async function handleList(req, res, redisClient, platform, config) {
  const { userId, action } = req.query;

  try {
    let whitelist, metadata;
    let backend = "FileSystem";

    // Try Redis first
    if (redisClient) {
      try {
        whitelist = await getWhitelistFromRedis(platform);
        metadata = await getMetadataFromRedis(platform);
        backend = "Redis";
      } catch (redisError) {
        console.warn(
          "Redis read failed, falling back to file:",
          redisError.message,
        );
        const fileData = getKeysDataFromFile(platform);
        whitelist = fileData.whitelist || {};
        metadata = fileData.metadata || {};
      }
    } else {
      const fileData = getKeysDataFromFile(platform);
      whitelist = fileData.whitelist || {};
      metadata = fileData.metadata || {};
    }

    // Get specific user (Mobile style)
    if (userId) {
      const user = whitelist[userId];
      if (!user) {
        return res
          .status(404)
          .json({ error: "User not found", userId, platform });
      }
      return res.status(200).json({ userId, platform, ...user });
    }

    // Get stats (Mobile style)
    if (action === "stats") {
      const totalUsers = Object.keys(whitelist).length;
      const activeUsers = Object.values(whitelist).filter(
        (u) => u.status === "active",
      ).length;
      const suspendedUsers = Object.values(whitelist).filter(
        (u) => u.status === "suspended",
      ).length;
      const expiredUsers = Object.values(whitelist).filter((u) => {
        if (!u.expiresAt) return false;
        return new Date(u.expiresAt) < new Date();
      }).length;

      return res.status(200).json({
        platform,
        total: totalUsers,
        active: activeUsers,
        suspended: suspendedUsers,
        expired: expiredUsers,
        lastUpdated: metadata.lastUpdated,
      });
    }

    // List all users (both styles)
    const userList = Object.entries(whitelist).map(([id, data]) => ({
      userId: id,
      ...data,
    }));

    res.setHeader("X-Storage-Backend", backend);
    return res.status(200).json({
      platform,
      total: userList.length,
      users: userList,
      whitelist, // PC style compatibility
      metadata,
    });
  } catch (error) {
    return res
      .status(500)
      .json({ error: "Failed to list users", message: error.message });
  }
}

async function handleAdd(req, res, redisClient, platform, config) {
  const {
    userId,
    username,
    type,
    expiresAt = null,
    duration,
    maxDevices,
    notes = "",
    note = "",
  } = req.body;

  if (!userId || !username) {
    return res.status(400).json({ error: "userId and username required" });
  }

  if (!redisClient) {
    return res.status(503).json({
      error: "Redis not available",
      message:
        "Redis client failed to initialize. Check REDIS_URL environment variable.",
      solution:
        "Verify REDIS_URL is set correctly in Vercel environment variables",
    });
  }

  try {
    const whitelist = await getWhitelistFromRedis(platform);

    if (whitelist[userId]) {
      return res.status(409).json({ error: "User already exists", platform });
    }

    // Calculate expiry date if duration is provided
    let calculatedExpiry = expiresAt;
    if (duration && duration !== "LIFETIME") {
      const days = parseInt(duration);
      if (!isNaN(days)) {
        calculatedExpiry = new Date(
          Date.now() + days * 24 * 60 * 60 * 1000,
        ).toISOString();
      }
    }

    const newUser = {
      userId,
      username,
      type: type || config.defaultType,
      status: "active",
      addedAt: new Date().toISOString(),
      expiresAt: calculatedExpiry,
      duration: duration || (calculatedExpiry ? undefined : "LIFETIME"),
      restrictions: {
        maxDevices: maxDevices || (platform === "mobile" ? 2 : 5),
        ipTracking: true,
        webhookNotify: true,
      },
      permissions: {
        bypassAll: false,
        unlimitedAccess: false,
        noLogging: false,
      },
      notes: notes || note || "",
      platform,
    };

    // Add user to whitelist
    whitelist[userId] = newUser;
    await saveWhitelistToRedis(platform, whitelist);

    // Update metadata
    const metadata = await getMetadataFromRedis(platform);
    metadata.totalWhitelisted = Object.keys(whitelist).length;
    await saveMetadataToRedis(platform, metadata);

    return res.status(201).json({
      success: true,
      message: `${platform.toUpperCase()} user ${username} added`,
      platform,
      user: { userId, ...newUser },
      data: newUser, // PC style compatibility
    });
  } catch (error) {
    console.error("Redis ADD error:", error);
    return res.status(500).json({
      error: "Failed to add user",
      message: error.message,
      details: "Redis operation failed. Server logs may have more details.",
    });
  }
}

async function handleUpdate(req, res, redisClient, platform, config) {
  // Accept userId from query or body
  const userId = req.query.userId || req.body.userId;
  const updates = { ...req.body };
  delete updates.userId;

  if (!userId) return res.status(400).json({ error: "userId required" });

  try {
    const whitelist = await getWhitelistFromRedis(platform);
    if (!whitelist[userId])
      return res.status(404).json({ error: "User not found", platform });

    const user = whitelist[userId];

    // Handle duration update
    if (updates.duration) {
      if (updates.duration === "LIFETIME") {
        updates.expiresAt = null;
      } else {
        const days = parseInt(updates.duration);
        if (!isNaN(days)) {
          updates.expiresAt = new Date(
            Date.now() + days * 24 * 60 * 60 * 1000,
          ).toISOString();
        }
      }
    }

    // Apply updates
    if (updates.username) user.username = updates.username;
    if (updates.type) user.type = updates.type;
    if (updates.status) user.status = updates.status;
    if (updates.expiresAt !== undefined) user.expiresAt = updates.expiresAt;
    if (updates.notes !== undefined) user.notes = updates.notes;
    if (updates.note !== undefined) user.notes = updates.note;
    if (updates.maxDevices !== undefined) {
      if (!user.restrictions) user.restrictions = {};
      user.restrictions.maxDevices = updates.maxDevices;
    }
    user.updatedAt = new Date().toISOString();

    whitelist[userId] = user;
    await saveWhitelistToRedis(platform, whitelist);

    return res.status(200).json({
      success: true,
      message: `${platform.toUpperCase()} user ${userId} updated`,
      platform,
      user: { userId, ...user },
      data: user, // PC style compatibility
    });
  } catch (error) {
    return res
      .status(500)
      .json({ error: "Failed to update user", message: error.message });
  }
}

async function handleRemove(req, res, redisClient, platform, config) {
  // Accept userId from query or body
  const userId = req.query.userId || req.body?.userId;

  if (!userId) return res.status(400).json({ error: "userId required" });

  try {
    const whitelist = await getWhitelistFromRedis(platform);
    if (!whitelist[userId])
      return res.status(404).json({ error: "User not found", platform });

    const deletedUser = whitelist[userId];
    const username = deletedUser.username;
    delete whitelist[userId];
    await saveWhitelistToRedis(platform, whitelist);

    const metadata = await getMetadataFromRedis(platform);
    metadata.totalWhitelisted = Object.keys(whitelist).length;
    await saveMetadataToRedis(platform, metadata);

    return res.status(200).json({
      success: true,
      message: `${platform.toUpperCase()} user ${username} removed`,
      platform,
      deletedUser: { userId, ...deletedUser },
    });
  } catch (error) {
    return res
      .status(500)
      .json({ error: "Failed to remove user", message: error.message });
  }
}
