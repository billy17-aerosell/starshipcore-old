import fs from "fs";
import path from "path";

// Get Redis client for whitelist check
let redis = null;
let redisInitAttempted = false;

async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
    } catch (error) {
      console.error("⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Check whitelist from Redis
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

// Check file-based whitelist as fallback
function getWhitelistFromFile() {
  try {
    const keysPath = path.join(process.cwd(), "data", "keys.json");
    const data = fs.readFileSync(keysPath, "utf8");
    const parsed = JSON.parse(data);
    return parsed.whitelist || {};
  } catch (error) {
    return {};
  }
}

// Generate random encryption key
function generateKey(length) {
  const chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+";
  let result = "";
  for (let i = 0; i < length; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

// XOR encrypt buffer
function xorEncrypt(buffer, key) {
  const keyBuffer = Buffer.from(key);
  const encrypted = Buffer.alloc(buffer.length);
  for (let i = 0; i < buffer.length; i++) {
    encrypted[i] = buffer[i] ^ keyBuffer[i % keyBuffer.length];
  }
  return encrypted;
}

// Valid module paths (whitelist of allowed modules)
const ALLOWED_MODULES = [
  "Config.lua",
  "UI.lua",
  "Intro.lua",
  "Animations.lua",
  "Locale.lua",
  "CloudRecording.lua",
  "UIComponents.lua",
  "ConnectionManager.lua",
  "Changelog.lua",
  "Modules/CloudRecording.lua",
  "PathEditor.lua",
  "PathEditorUI.lua",
  "Tabs/Dashboard.lua",
  "Tabs/Tools.lua",
  "Tabs/Warp.lua",
  "Tabs/Helper.lua",
  "Tabs/Fun.lua",
  "Tabs/Emotes.lua",
  "Tabs/ConfigTab.lua",
];

// Owner ID - always has access without whitelist check
const OWNER_ID = "9268011358";

export default async function handler(req, res) {
  // Only allow GET requests
  if (req.method !== "GET") {
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { name, user, dev } = req.query;
  const timestamp = new Date().toISOString();

  // Validate module name
  if (!name) {
    return res.status(400).json({ error: "Module name required" });
  }

  // Security: Check if module is in allowed list (prevent path traversal)
  const normalizedName = name.replace(/\\/g, "/");
  if (!ALLOWED_MODULES.includes(normalizedName)) {
    console.log(`[${timestamp}] ❌ Invalid module requested: ${name}`);
    return res.status(403).json({ error: "Module not found or not allowed" });
  }

  // === DEV MODE ===
  // Check if dev mode is enabled (localhost or dev=true with secret)
  const isLocalhost =
    req.headers.host?.includes("localhost") ||
    req.headers.host?.includes("127.0.0.1");
  const devSecret = process.env.DEV_SECRET || "starship-dev-2025";
  const isDevMode = isLocalhost || dev === devSecret;

  if (isDevMode) {
    // Dev mode: Return plain text without encryption or whitelist check
    console.log(`[${timestamp}] 🔧 [DEV] Module requested: ${name}`);

    try {
      // Handle path: if name starts with "Modules/", load from data/ directly
      // Otherwise, load from data/Modules/
      let modulePath;
      if (normalizedName.startsWith("Modules/")) {
        modulePath = path.join(process.cwd(), "data", normalizedName);
      } else {
        modulePath = path.join(process.cwd(), "data", "Modules", normalizedName);
      }

      if (!fs.existsSync(modulePath)) {
        console.log(`[${timestamp}] ❌ [DEV] Module not found at: ${modulePath}`);
        return res.status(404).json({ error: "Module file not found", path: modulePath });
      }

      const content = fs.readFileSync(modulePath, "utf8");

      // Return plain text for dev mode
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("X-Mode", "development");
      return res.status(200).send(content);
    } catch (error) {
      console.error(
        `[${timestamp}] ❌ [DEV] Error reading module:`,
        error.message,
      );
      return res.status(500).json({ error: "Failed to read module" });
    }
  }

  // === PRODUCTION MODE ===
  // Require user ID for production
  if (!user) {
    return res.status(400).json({ error: "User ID required" });
  }

  const now = Math.floor(Date.now() / 1000);

  try {
    // OWNER BYPASS - Owner always has access
    if (user === OWNER_ID) {
      console.log(`[${timestamp}] 👑 [OWNER] Module requested: ${name}`);

      // Handle path: if name starts with "Modules/", load from data/ directly
      let modulePath;
      if (normalizedName.startsWith("Modules/")) {
        modulePath = path.join(process.cwd(), "data", normalizedName);
      } else {
        modulePath = path.join(process.cwd(), "data", "Modules", normalizedName);
      }

      if (!fs.existsSync(modulePath)) {
        return res.status(404).json({ error: "Module file not found" });
      }

      let moduleBuffer = fs.readFileSync(modulePath);

      // Remove BOM if present
      if (
        moduleBuffer.length >= 3 &&
        moduleBuffer[0] === 0xef &&
        moduleBuffer[1] === 0xbb &&
        moduleBuffer[2] === 0xbf
      ) {
        moduleBuffer = moduleBuffer.subarray(3);
      }

      // Generate dynamic encryption key
      const dynamicKey = generateKey(32);

      // Encrypt module content
      const encryptedBuffer = xorEncrypt(moduleBuffer, dynamicKey);
      const base64Blob = encryptedBuffer.toString("base64");

      console.log(`[${timestamp}] 👑 [OWNER] Module delivered: ${name}`);

      // Return encrypted module
      return res.status(200).json({
        status: "success",
        module: normalizedName,
        key: dynamicKey,
        blob: base64Blob,
      });
    }

    // Check Redis whitelist first
    let isWhitelisted = false;
    let userData = null;

    const redisWhitelist = await getWhitelistFromRedis();

    if (redisWhitelist && redisWhitelist[user]) {
      userData = redisWhitelist[user];

      if (userData.status === "active") {
        // Check expiry
        if (userData.expiresAt) {
          const expiryDate = new Date(userData.expiresAt);
          const expiryTimestamp = Math.floor(expiryDate.getTime() / 1000);

          if (expiryTimestamp >= now) {
            isWhitelisted = true;
          }
        } else {
          // No expiry = lifetime
          isWhitelisted = true;
        }
      }
    }

    // Fallback to file-based whitelist
    if (!isWhitelisted) {
      const fileWhitelist = getWhitelistFromFile();

      if (fileWhitelist[user]) {
        userData = fileWhitelist[user];

        // Check expiry
        if (userData.expiry) {
          if (userData.expiry >= now) {
            isWhitelisted = true;
          }
        } else {
          isWhitelisted = true;
        }
      }
    }

    // Deny if not whitelisted
    if (!isWhitelisted) {
      console.log(
        `[${timestamp}] ❌ Module access denied - User: ${user}, Module: ${name}`,
      );
      return res.status(403).json({
        status: "denied",
        error: "Not authorized to access modules",
      });
    }

    // Read module file - handle Modules/ prefix
    let modulePath;
    if (normalizedName.startsWith("Modules/")) {
      modulePath = path.join(process.cwd(), "data", normalizedName);
    } else {
      modulePath = path.join(process.cwd(), "data", "Modules", normalizedName);
    }

    if (!fs.existsSync(modulePath)) {
      return res.status(404).json({ error: "Module file not found" });
    }

    let moduleBuffer = fs.readFileSync(modulePath);

    // Remove BOM if present
    if (
      moduleBuffer.length >= 3 &&
      moduleBuffer[0] === 0xef &&
      moduleBuffer[1] === 0xbb &&
      moduleBuffer[2] === 0xbf
    ) {
      moduleBuffer = moduleBuffer.subarray(3);
    }

    // Generate dynamic encryption key
    const dynamicKey = generateKey(32);

    // Encrypt module content
    const encryptedBuffer = xorEncrypt(moduleBuffer, dynamicKey);
    const base64Blob = encryptedBuffer.toString("base64");

    console.log(
      `[${timestamp}] ✅ Module delivered - User: ${user}, Module: ${name}`,
    );

    // Return encrypted module
    return res.status(200).json({
      status: "success",
      module: normalizedName,
      key: dynamicKey,
      blob: base64Blob,
    });
  } catch (error) {
    console.error(`[${timestamp}] ❌ Error:`, error.message);
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
