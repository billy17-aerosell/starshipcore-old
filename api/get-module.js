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
  "StarSpacePlayback.lua",
  "violence-district.lua",
];

// Owner ID - always has access without whitelist check
const OWNER_ID = "9268011358";

export default async function handler(req, res) {
  // Only allow GET requests
  if (req.method !== "GET") {
    const platform = req.query.platform;
    if (platform === "mobile") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(405).send(`error("Method Not Allowed")`);
    }
    return res.status(405).json({ error: "Method Not Allowed" });
  }

  const { name, user: queryUser, userId, dev, bundle } = req.query;
  const user = queryUser || userId;
  const timestamp = new Date().toISOString();

  // ══════════════════════════════════════════════════════════════════
  // BUNDLE MODE - Return all modules in single encrypted response
  // SECURITY: Hides individual module names from HTTP spy tools
  // ══════════════════════════════════════════════════════════════════
  if (bundle === "true") {
    console.log(`[${timestamp}] 📦 Bundle requested | User: ${user || "unknown"}`);

    try {
      const modulesDir = path.join(process.cwd(), "data", "Modules");
      const tabsDir = path.join(modulesDir, "Tabs");

      const bundleData = {
        v: 1,
        t: Date.now(),
        m: {},
        tabs: {}
      };

      const moduleNames = [
        "Config.lua", "UI.lua", "Intro.lua", "Animations.lua",
        "Locale.lua", "CloudRecording.lua", "UIComponents.lua",
        "ConnectionManager.lua", "Changelog.lua"
      ];

      const tabNames = [
        "Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua",
        "Fun.lua", "Emotes.lua", "ConfigTab.lua"
      ];

      // XOR encrypt for bundle
      const encKey = "S" + bundleData.t.toString(36) + "X";

      function xorEncryptBundle(text, key) {
        let result = "";
        for (let i = 0; i < text.length; i++) {
          result += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
        }
        return Buffer.from(result, "binary").toString("base64");
      }

      // Load modules
      for (let i = 0; i < moduleNames.length; i++) {
        const filePath = path.join(modulesDir, moduleNames[i]);
        if (fs.existsSync(filePath)) {
          let content = fs.readFileSync(filePath, "utf8");
          if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);
          bundleData.m["m" + (i + 1)] = xorEncryptBundle(content, encKey);
        }
      }

      // Load tabs
      for (let i = 0; i < tabNames.length; i++) {
        const filePath = path.join(tabsDir, tabNames[i]);
        if (fs.existsSync(filePath)) {
          let content = fs.readFileSync(filePath, "utf8");
          if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);
          bundleData.tabs["t" + (i + 1)] = xorEncryptBundle(content, encKey);
        }
      }

      bundleData.k = bundleData.t.toString(36);

      console.log(`[${timestamp}] ✅ Bundle prepared: ${Object.keys(bundleData.m).length} modules, ${Object.keys(bundleData.tabs).length} tabs`);

      res.setHeader("Content-Type", "application/json");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      return res.status(200).json(bundleData);

    } catch (error) {
      console.error(`[${timestamp}] ❌ Bundle error:`, error);
      return res.status(500).json({ error: "BUNDLE_ERROR" });
    }
  }

  // ══════════════════════════════════════════════════════════════════
  // INDIVIDUAL MODULE MODE (original behavior)
  // ══════════════════════════════════════════════════════════════════

  // Validate module name
  if (!name) {
    const platform = req.query.platform;
    if (platform === "mobile") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(400).send(`error("Module name required")`);
    }
    return res.status(400).json({ error: "Module name required" });
  }

  // Security: Check if module is in allowed list (prevent path traversal)
  const normalizedName = name.replace(/\\/g, "/");
  if (!ALLOWED_MODULES.includes(normalizedName)) {
    console.log(`[${timestamp}] ❌ Invalid module requested: ${name}`);
    const platform = req.query.platform;
    if (platform === "mobile") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(403).send(`error("Module '${name}' not allowed or invalid")`);
    }
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
      if (normalizedName === "violence-district.lua") {
        modulePath = path.join(process.cwd(), "data", normalizedName);
      } else if (normalizedName.startsWith("Modules/")) {
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
      console.error(`[${timestamp}] ❌ [DEV] Error reading module:`, error.message);
      const platform = req.query.platform;
      if (platform === "mobile") {
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        return res.status(500).send(`error("Failed to read module in dev mode: ${error.message}")`);
      }
      return res.status(500).json({ error: "Failed to read module" });
    }
  }

  // === PRODUCTION MODE ===
  // Require user ID for production
  if (!user) {
    const platform = req.query.platform;
    if (platform === "mobile") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(400).send(`error("User ID required. Make sure userId parameter is included.")`);
    }
    return res.status(400).json({ error: "User ID required" });
  }

  const now = Math.floor(Date.now() / 1000);

  try {
    // OWNER BYPASS - Owner always has access
    if (user === OWNER_ID) {
      console.log(`[${timestamp}] 👑 [OWNER] Module requested: ${name}`);

      // Handle path mapping
      let modulePath;
      if (normalizedName === "violence-district.lua") {
        modulePath = path.join(process.cwd(), "data", normalizedName);
      } else if (normalizedName.startsWith("Modules/")) {
        modulePath = path.join(process.cwd(), "data", normalizedName);
      } else {
        modulePath = path.join(process.cwd(), "data", "Modules", normalizedName);
      }

      if (!fs.existsSync(modulePath)) {
        const platform = req.query.platform;
        if (platform === "mobile") {
          res.setHeader("Content-Type", "text/plain; charset=utf-8");
          return res.status(404).send(`error("Module '${name}' not found on server")`);
        }
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

      // Return module (Check platform for response format)
      const platform = req.query.platform;
      if (platform === "mobile") {
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
        return res.status(200).send(moduleBuffer.toString("utf8"));
      }

      // Default (PC): Return encrypted JSON
      return res.status(200).json({
        status: "success",
        module: normalizedName,
        key: dynamicKey,
        blob: base64Blob,
      });
    }

    // Check Redis whitelist first (PC)
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

    // Check Redis Mobile Whitelist if not found in PC whitelist
    if (!isWhitelisted) {
      try {
        const redisClient = await getRedis();
        if (redisClient) {
          const mobileData = await redisClient.get("starship:mobile_whitelist");
          const mobileWhitelist = mobileData ? JSON.parse(mobileData) : null;

          if (mobileWhitelist && mobileWhitelist[user]) {
            userData = mobileWhitelist[user];
            if (userData.status === "active") {
              if (userData.expiresAt) {
                const expiryDate = new Date(userData.expiresAt);
                if (expiryDate.getTime() / 1000 >= now) {
                  isWhitelisted = true;
                }
              } else {
                isWhitelisted = true;
              }
            }
          }
        }
      } catch (e) {
        console.error("Redis mobile whitelist check error:", e.message);
      }
    }

    // Fallback to file-based whitelist (PC)
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

    // Fallback to file-based whitelist (Mobile)
    if (!isWhitelisted) {
      try {
        const mobileKeysPath = path.join(process.cwd(), "data", "mobile-keys.json");
        if (fs.existsSync(mobileKeysPath)) {
          const mobileKeysData = JSON.parse(fs.readFileSync(mobileKeysPath, "utf8"));
          const mobileFileWhitelist = mobileKeysData.whitelist || {};

          if (mobileFileWhitelist[user]) {
            userData = mobileFileWhitelist[user];
            if (userData.status === "active") {
              if (userData.expiresAt) {
                const expiryDate = new Date(userData.expiresAt);
                if (expiryDate.getTime() / 1000 >= now) {
                  isWhitelisted = true;
                }
              } else {
                isWhitelisted = true;
              }
            }
          }
        }
      } catch (e) {
        console.error("File mobile whitelist check error:", e.message);
      }
    }

    // Check Event Access if not found in any whitelist
    if (!isWhitelisted) {
      try {
        const EVENT_CODE_API = process.env.EVENT_CODE_API_URL || "";
        const isEventSystemActive = process.env.EVENT_SYSTEM_ACTIVE !== "false";

        if (EVENT_CODE_API && isEventSystemActive) {
          const apiUrl = `${EVENT_CODE_API}?action=check&userId=${user}`;
          const response = await fetch(apiUrl);
          const eventData = await response.json();

          if (eventData.success && eventData.hasAccess) {
            isWhitelisted = true;
            console.log(`[${timestamp}] 🎟️ Event access granted for User: ${user} to Module: ${name}`);
          }
        }
      } catch (e) {
        console.error("Event access check error:", e.message);
      }
    }

    // Deny if not whitelisted
    if (!isWhitelisted) {
      console.log(
        `[${timestamp}] ❌ Module access denied - User: ${user}, Module: ${name}`,
      );

      const platform = req.query.platform;
      if (platform === "mobile") {
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        return res.status(403).send(`error("Not whitelisted for Mobile access. Purchase VIP to get access.")`);
      }

      return res.status(403).json({
        status: "denied",
        error: "Not authorized to access modules",
      });
    }

    // Read module file - handle Modules/ prefix
    if (normalizedName === "violence-district.lua") {
      modulePath = path.join(process.cwd(), "data", normalizedName);
    } else if (normalizedName.startsWith("Modules/")) {
      modulePath = path.join(process.cwd(), "data", normalizedName);
    } else {
      modulePath = path.join(process.cwd(), "data", "Modules", normalizedName);
    }

    if (!fs.existsSync(modulePath)) {
      const platform = req.query.platform;
      if (platform === "mobile") {
        res.setHeader("Content-Type", "text/plain; charset=utf-8");
        return res.status(404).send(`error("Module file '${name}' not found on server")`);
      }
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

    // Return module (Check platform for response format)
    const platform = req.query.platform;
    if (platform === "mobile") {
      // Mobile: Return plain text for direct execution
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      res.setHeader("Cache-Control", "no-cache, no-store, must-revalidate");
      return res.status(200).send(moduleBuffer.toString("utf8"));
    }

    // Default (PC): Return encrypted JSON
    return res.status(200).json({
      status: "success",
      module: normalizedName,
      key: dynamicKey,
      blob: base64Blob,
    });
  } catch (error) {
    console.error(`[${timestamp}] ❌ Error:`, error.message);
    const platform = req.query.platform;
    if (platform === "mobile") {
      res.setHeader("Content-Type", "text/plain; charset=utf-8");
      return res.status(500).send(`error("Internal Server Error: ${error.message}")`);
    }
    return res.status(500).json({ error: "Internal Server Error" });
  }
}
