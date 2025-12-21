// Mobile Whitelist Management API - Separate from PC Whitelist
// Full CRUD operations with Redis persistence

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
      console.log("✅ Redis module loaded for Mobile Whitelist");
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

const ADMIN_SECRET = process.env.ADMIN_SECRET || "CHANGE_ME_PLEASE";
const MOBILE_WHITELIST_KEY = "starship:mobile_whitelist";
const MOBILE_METADATA_KEY = "starship:mobile_metadata";
const MOBILE_KEYS_FILE_PATH = path.join(
  process.cwd(),
  "data",
  "mobile-keys.json",
);

// === REDIS FUNCTIONS ===
async function getWhitelistFromRedis() {
  const data = await redis.get(MOBILE_WHITELIST_KEY);
  return data ? JSON.parse(data) : {};
}

async function getMetadataFromRedis() {
  const data = await redis.get(MOBILE_METADATA_KEY);
  return data
    ? JSON.parse(data)
    : { totalWhitelisted: 0, lastUpdated: new Date().toISOString() };
}

async function saveWhitelistToRedis(whitelist) {
  await redis.set(MOBILE_WHITELIST_KEY, JSON.stringify(whitelist));
}

async function saveMetadataToRedis(metadata) {
  metadata.lastUpdated = new Date().toISOString();
  await redis.set(MOBILE_METADATA_KEY, JSON.stringify(metadata));
}

// === FILE FUNCTIONS (Fallback) ===
function getKeysDataFromFile() {
  try {
    if (!fs.existsSync(MOBILE_KEYS_FILE_PATH)) {
      // Create default mobile-keys.json if not exists
      const defaultData = {
        keys: {},
        whitelist: {},
        metadata: {
          totalWhitelisted: 0,
          lastUpdated: new Date().toISOString(),
        },
      };
      fs.writeFileSync(
        MOBILE_KEYS_FILE_PATH,
        JSON.stringify(defaultData, null, 2),
      );
      return defaultData;
    }
    const data = fs.readFileSync(MOBILE_KEYS_FILE_PATH, "utf8");
    return JSON.parse(data);
  } catch (error) {
    return {
      keys: {},
      whitelist: {},
      metadata: { totalWhitelisted: 0, lastUpdated: new Date().toISOString() },
    };
  }
}

function saveKeysDataToFile(data) {
  try {
    fs.writeFileSync(MOBILE_KEYS_FILE_PATH, JSON.stringify(data, null, 2));
    return true;
  } catch (error) {
    console.error("Failed to save mobile keys file:", error);
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

  const { method } = req;

  try {
    switch (method) {
      case "GET":
        return await handleGet(req, res, redisClient);
      case "POST":
        return await handlePost(req, res, redisClient);
      case "PUT":
        return await handlePut(req, res, redisClient);
      case "DELETE":
        return await handleDelete(req, res, redisClient);
      default:
        return res.status(405).json({ error: "Method not allowed" });
    }
  } catch (error) {
    console.error("Mobile Whitelist Manager Error:", error);
    return res
      .status(500)
      .json({ error: "Internal server error", message: error.message });
  }
}

// GET - List all mobile whitelisted users or get specific user
async function handleGet(req, res, redisClient) {
  const { userId, action } = req.query;

  // Get whitelist data
  let whitelist = {};
  let metadata = {};

  if (redisClient) {
    whitelist = await getWhitelistFromRedis();
    metadata = await getMetadataFromRedis();
  } else {
    const fileData = getKeysDataFromFile();
    whitelist = fileData.whitelist || {};
    metadata = fileData.metadata || {};
  }

  // Get specific user
  if (userId) {
    const user = whitelist[userId];
    if (!user) {
      return res.status(404).json({ error: "User not found", userId });
    }
    return res.status(200).json({ userId, ...user });
  }

  // Get stats
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
      platform: "mobile",
      total: totalUsers,
      active: activeUsers,
      suspended: suspendedUsers,
      expired: expiredUsers,
      lastUpdated: metadata.lastUpdated,
    });
  }

  // List all users
  const userList = Object.entries(whitelist).map(([id, data]) => ({
    userId: id,
    ...data,
  }));

  return res.status(200).json({
    platform: "mobile",
    total: userList.length,
    users: userList,
    metadata,
  });
}

// POST - Add new mobile user to whitelist
async function handlePost(req, res, redisClient) {
  const { userId, username, type, duration, maxDevices, note } = req.body;

  if (!userId || !username) {
    return res
      .status(400)
      .json({ error: "Missing required fields: userId, username" });
  }

  // Get current whitelist
  let whitelist = {};
  let metadata = {};

  if (redisClient) {
    whitelist = await getWhitelistFromRedis();
    metadata = await getMetadataFromRedis();
  } else {
    const fileData = getKeysDataFromFile();
    whitelist = fileData.whitelist || {};
    metadata = fileData.metadata || {};
  }

  // Check if user already exists
  if (whitelist[userId]) {
    return res.status(409).json({ error: "User already exists", userId });
  }

  // Calculate expiry date
  let expiresAt = null;
  if (duration && duration !== "LIFETIME") {
    const days = parseInt(duration);
    if (!isNaN(days)) {
      expiresAt = new Date(
        Date.now() + days * 24 * 60 * 60 * 1000,
      ).toISOString();
    }
  }

  // Create new user entry
  const newUser = {
    username,
    type: type || "MOBILE_VIP",
    status: "active",
    duration: duration || "LIFETIME",
    expiresAt,
    maxDevices: maxDevices || 2,
    addedAt: new Date().toISOString(),
    note: note || null,
    platform: "mobile",
  };

  whitelist[userId] = newUser;
  metadata.totalWhitelisted = Object.keys(whitelist).length;

  // Save to storage
  if (redisClient) {
    await saveWhitelistToRedis(whitelist);
    await saveMetadataToRedis(metadata);
  } else {
    const fileData = getKeysDataFromFile();
    fileData.whitelist = whitelist;
    fileData.metadata = metadata;
    saveKeysDataToFile(fileData);
  }

  return res.status(201).json({
    success: true,
    message: "Mobile user added to whitelist",
    user: { userId, ...newUser },
  });
}

// PUT - Update existing mobile user
async function handlePut(req, res, redisClient) {
  // Accept userId from query or body
  const userId = req.query.userId || req.body.userId;
  const updates = { ...req.body };
  delete updates.userId; // Remove userId from updates object

  if (!userId) {
    return res.status(400).json({ error: "Missing userId parameter" });
  }

  // Get current whitelist
  let whitelist = {};

  if (redisClient) {
    whitelist = await getWhitelistFromRedis();
  } else {
    const fileData = getKeysDataFromFile();
    whitelist = fileData.whitelist || {};
  }

  // Check if user exists
  if (!whitelist[userId]) {
    return res.status(404).json({ error: "User not found", userId });
  }

  // Update user data
  const currentUser = whitelist[userId];

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

  // Merge updates
  whitelist[userId] = {
    ...currentUser,
    ...updates,
    updatedAt: new Date().toISOString(),
  };

  // Save to storage
  if (redisClient) {
    await saveWhitelistToRedis(whitelist);
  } else {
    const fileData = getKeysDataFromFile();
    fileData.whitelist = whitelist;
    saveKeysDataToFile(fileData);
  }

  return res.status(200).json({
    success: true,
    message: "Mobile user updated",
    user: { userId, ...whitelist[userId] },
  });
}

// DELETE - Remove mobile user from whitelist
async function handleDelete(req, res, redisClient) {
  // Accept userId from query or body
  const userId = req.query.userId || req.body?.userId;

  if (!userId) {
    return res.status(400).json({ error: "Missing userId parameter" });
  }

  // Get current whitelist
  let whitelist = {};
  let metadata = {};

  if (redisClient) {
    whitelist = await getWhitelistFromRedis();
    metadata = await getMetadataFromRedis();
  } else {
    const fileData = getKeysDataFromFile();
    whitelist = fileData.whitelist || {};
    metadata = fileData.metadata || {};
  }

  // Check if user exists
  if (!whitelist[userId]) {
    return res.status(404).json({ error: "User not found", userId });
  }

  const deletedUser = whitelist[userId];
  delete whitelist[userId];
  metadata.totalWhitelisted = Object.keys(whitelist).length;

  // Save to storage
  if (redisClient) {
    await saveWhitelistToRedis(whitelist);
    await saveMetadataToRedis(metadata);
  } else {
    const fileData = getKeysDataFromFile();
    fileData.whitelist = whitelist;
    fileData.metadata = metadata;
    saveKeysDataToFile(fileData);
  }

  return res.status(200).json({
    success: true,
    message: "Mobile user removed from whitelist",
    deletedUser: { userId, ...deletedUser },
  });
}
