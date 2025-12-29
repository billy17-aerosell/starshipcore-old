// api/cloud-store-x7k9.js - Secure Cloud Recording Storage via Cloudflare R2
// RENAMED from r2-recordings.js for security (old endpoint no longer works)
// Protected by EVENT_ENABLED toggle and EVENT_CODE verification
// Supports large files up to 5GB (vs GitHub Gist 1MB limit)
// WITH GZIP COMPRESSION for faster downloads

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
} from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import zlib from "zlib";
import { promisify } from "util";

// Promisified gzip
const gzip = promisify(zlib.gzip);

// ============================================
// USER ACCESS VALIDATION - Check Redis VIP or Google Sheets Event
// ============================================

// Event Code System API (from environment variable for security)
const EVENT_CODE_API_URL = process.env.EVENT_CODE_API_URL || "";

// Redis singleton
let redis = null;
let redisInitAttempted = false;

// Get Redis instance (lazy load)
async function getRedis() {
  if (!redisInitAttempted) {
    try {
      const redisModule = await import("../lib/redis.js");
      redis = redisModule.default;
      console.log("[R2] ✅ Redis module loaded");
    } catch (error) {
      console.error("[R2] ⚠️ Redis module load failed:", error.message);
      redis = null;
    }
    redisInitAttempted = true;
  }
  return redis;
}

// Check if userId has VIP access (exists in Redis whitelist)
async function checkVIPAccess(userId) {
  try {
    const redisClient = await getRedis();
    if (!redisClient) return false;
    
    // Check PC whitelist
    const pcWhitelist = await redisClient.get("starship:whitelist");
    if (pcWhitelist) {
      const pcData = JSON.parse(pcWhitelist);
      if (pcData[userId] && pcData[userId].status === "active") {
        return { hasAccess: true, source: "PC VIP" };
      }
    }
    
    // Check Mobile whitelist
    const mobileWhitelist = await redisClient.get("starship:mobile_whitelist");
    if (mobileWhitelist) {
      const mobileData = JSON.parse(mobileWhitelist);
      if (mobileData[userId] && mobileData[userId].status === "active") {
        return { hasAccess: true, source: "Mobile VIP" };
      }
    }
    
    return { hasAccess: false };
  } catch (error) {
    console.error("[R2] VIP check error:", error.message);
    return { hasAccess: false };
  }
}

// Check if userId has Event access (from Google Sheets)
async function checkEventAccessForUser(userId) {
  if (!EVENT_CODE_API_URL) {
    return { hasAccess: false };
  }
  
  try {
    const apiUrl = `${EVENT_CODE_API_URL}?action=check&userId=${userId}`;
    const response = await fetch(apiUrl);
    const data = await response.json();
    
    if (data.success && data.hasAccess) {
      return { hasAccess: true, source: "Event" };
    }
    return { hasAccess: false };
  } catch (error) {
    console.error("[R2] Event check error:", error.message);
    return { hasAccess: false };
  }
}

// Owner userId - always has access (bypass validation)
const OWNER_USER_ID = "9268011358";

// Main validation function - check if userId has ANY valid access
async function validateUserAccess(userId) {
  // Owner bypass - always has access
  if (userId === OWNER_USER_ID) {
    return { hasAccess: true, source: "OWNER" };
  }

  // Check VIP access first (faster - Redis)
  const vipResult = await checkVIPAccess(userId);
  if (vipResult.hasAccess) {
    return vipResult;
  }
  
  // Check Event access (slower - external API)
  const eventResult = await checkEventAccessForUser(userId);
  return eventResult;
}

// Helper: Send JSON response (GZIP only if client supports it)
async function sendGzipJson(req, res, data, statusCode = 200) {
  const jsonString = JSON.stringify(data);
  
  // Check if client supports GZIP
  const acceptEncoding = req?.headers?.['accept-encoding'] || '';
  const supportsGzip = acceptEncoding.includes('gzip');
  
  // For Roblox clients (usually no Accept-Encoding), send uncompressed
  // Only compress if client explicitly accepts GZIP and data is large enough
  if (supportsGzip && jsonString.length > 10000) {
    try {
      const compressed = await gzip(Buffer.from(jsonString, "utf-8"));
      
      res.setHeader("Content-Type", "application/json");
      res.setHeader("Content-Encoding", "gzip");
      res.setHeader("Vary", "Accept-Encoding");
      res.setHeader("X-Original-Size", jsonString.length);
      res.setHeader("X-Compressed-Size", compressed.length);
      
      const compressionRatio = ((1 - compressed.length / jsonString.length) * 100).toFixed(1);
      console.log(`[R2] GZIP: ${(jsonString.length/1024/1024).toFixed(2)}MB -> ${(compressed.length/1024/1024).toFixed(2)}MB (${compressionRatio}% reduction)`);
      
      return res.status(statusCode).send(compressed);
    } catch (error) {
      console.log("[R2] GZIP failed, sending uncompressed:", error.message);
    }
  }
  
  // Send uncompressed (for Roblox or small responses)
  console.log(`[R2] Sending uncompressed: ${(jsonString.length/1024/1024).toFixed(2)}MB`);
  return res.status(statusCode).json(data);
}

// R2 Configuration (SECURITY: All credentials must come from environment variables)
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "starship-recordings";

// Validate required environment variables
if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  console.error("[R2] CRITICAL: Missing R2 credentials in environment variables!");
}

// S3-compatible client for R2
const r2Client = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

// Helper: Sanitize name for use as filename (remove invalid characters)
function sanitizeName(name) {
  return name
    .replace(/[^a-zA-Z0-9\s\-_]/g, "") // Remove special characters
    .replace(/\s+/g, "_") // Replace spaces with underscore
    .substring(0, 100); // Limit length
}

// Helper: Convert stream to string (with better error handling)
async function streamToString(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  const buffer = Buffer.concat(chunks);
  
  // Check for GZIP magic bytes (1f 8b) - file might be accidentally compressed
  if (buffer[0] === 0x1f && buffer[1] === 0x8b) {
    console.log("[R2] Detected GZIP compressed file, decompressing...");
    const gunzip = promisify(zlib.gunzip);
    try {
      const decompressed = await gunzip(buffer);
      return decompressed.toString("utf-8");
    } catch (e) {
      console.error("[R2] GZIP decompression failed:", e.message);
      throw new Error("File appears to be corrupted (GZIP decompression failed)");
    }
  }
  
  // Check for null bytes or other binary characters that indicate corruption
  const str = buffer.toString("utf-8");
  if (str.includes('\0') || str.charCodeAt(0) === 0) {
    console.error("[R2] File contains null bytes - likely corrupted or binary");
    throw new Error("File appears to be corrupted (contains binary data)");
  }
  
  return str;
}

// Helper: Send Discord Log
async function sendDiscordLog(logData) {
  const webhookUrl = process.env.DISCORD_WEBHOOK_URL;
  if (!webhookUrl) return;

  try {
    const colors = {
      upload: 0x22c55e, // Green
      delete: 0xef4444, // Red
      update: 0x3b82f6, // Blue
      warning: 0xeab308, // Yellow
    };

    const embed = {
      title: logData.title || "Cloud Storage Activity",
      color: colors[logData.type] || 0x808080,
      fields: [
        { name: "👤 User ID", value: `\`${logData.userId || "Unknown"}\``, inline: true },
        { name: "📂 File", value: `\`${logData.fileName || "Unknown"}\``, inline: true },
        { name: "🔧 Action", value: logData.action || "Unknown", inline: true },
      ],
      timestamp: new Date().toISOString(),
      footer: { text: "☁️ StarshipCore R2 Cloud" },
    };

    if (logData.details) {
      embed.description = logData.details;
    }

    await fetch(webhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ embeds: [embed] }),
    });
  } catch (error) {
    console.error("[Discord] Error sending log:", error.message);
  }
}

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader(
    "Access-Control-Allow-Methods",
    "GET, POST, DELETE, PATCH, OPTIONS",
  );
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-User-Id");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  // ============================================
  // EVENT PROTECTION - Check if event is enabled and code is valid
  // + User-specific validation and blacklist system
  // ============================================
  const EVENT_ENABLED = process.env.R2_EVENT_ENABLED === "true";
  const EVENT_CODE = process.env.R2_EVENT_CODE || "";
  const requestCode = req.query.eventCode || req.body?.eventCode || req.headers["x-event-code"];
  const requestUserId = req.query.userId || req.body?.userId || req.headers["x-user-id"];
  
  // BLACKLIST - Add userIds here that should be blocked (comma-separated in env)
  // Example: R2_BLACKLIST="123456789,987654321,111222333"
  const BLACKLIST_RAW = process.env.R2_BLACKLIST || "";
  const BLACKLIST = BLACKLIST_RAW.split(",").map(id => id.trim()).filter(id => id);
  
  // Check if event mode is enabled
  if (!EVENT_ENABLED) {
    console.log(`[R2] ❌ Event mode disabled - access denied`);
    return res.status(403).json({ 
      error: "Event tidak aktif",
      message: "Cloud storage sedang tidak tersedia"
    });
  }
  
  // Check event code
  if (!requestCode || requestCode !== EVENT_CODE) {
    console.log(`[R2] ❌ Invalid event code: ${requestCode ? "wrong code" : "no code"} | UserId: ${requestUserId || "none"}`);
    return res.status(403).json({ 
      error: "Kode event tidak valid",
      message: "Masukkan kode event yang benar untuk mengakses cloud storage"
    });
  }
  
  // Check userId is provided
  if (!requestUserId) {
    console.log(`[R2] ❌ No userId provided with event code`);
    return res.status(403).json({ 
      error: "UserId tidak ditemukan",
      message: "Autentikasi tidak valid"
    });
  }
  
  // Check if user is blacklisted
  if (BLACKLIST.includes(requestUserId.toString())) {
    console.log(`[R2] 🚫 BLACKLISTED USER BLOCKED - UserId: ${requestUserId}`);
    return res.status(403).json({ 
      error: "Akses ditolak",
      message: "Akun Anda telah diblokir dari layanan ini"
    });
  }
  
  // ============================================
  // CRITICAL: Validate userId has ACTUAL access (VIP or Event)
  // This prevents hackers with stolen event codes from accessing R2
  // ============================================
  const accessResult = await validateUserAccess(requestUserId);
  if (!accessResult.hasAccess) {
    console.log(`[R2] ❌ NO VALID ACCESS - UserId: ${requestUserId} (not VIP, not Event)`);
    return res.status(403).json({ 
      error: "Akses tidak valid",
      message: "UserId tidak memiliki akses VIP atau Event"
    });
  }
  
  console.log(`[R2] ✅ Access granted - UserId: ${requestUserId} (${accessResult.source})`);

  const { method } = req;
  const userId = req.query.userId || req.body?.userId;

  // ============================================
  // POST - Generate Presigned URL or Save recording
  // ============================================
  if (method === "POST") {
    const { action } = req.query;
    
    // Generate Presigned URL for direct upload to R2
    if (action === "get_upload_url") {
      try {
        const { name, userId, gameId, gameName, frameCount, duration, mode } = req.body;
        
        if (!name || !userId) {
          return res.status(400).json({ error: "Missing name or userId" });
        }
        
        // Sanitize name for filename
        const sanitizedName = name
          .replace(/[^a-zA-Z0-9\s\-_]/g, "")
          .replace(/\s+/g, "_")
          .substring(0, 100);
        
        const key = `recordings/${sanitizedName}.json`;
        const timestamp = new Date().toISOString();
        
        // Generate presigned PUT URL (valid for 1 hour)
        const command = new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
          ContentType: "application/json",
          Metadata: {
            name: name,
            userid: userId,
            gameid: gameId?.toString() || "",
            gamename: gameName || "",
            framecount: frameCount?.toString() || "0",
            duration: duration?.toString() || "0",
            mode: mode || "Flexible",
            createdat: timestamp,
          }
        });
        
        const uploadUrl = await getSignedUrl(r2Client, command, { expiresIn: 3600 });
        
        console.log(`[R2] Generated presigned upload URL for: ${sanitizedName}`);
        
        // Log to Discord
        await sendDiscordLog({
          title: "📤 Upload Started (Presigned URL)",
          type: "upload",
          userId: userId,
          fileName: sanitizedName,
          action: "Generated Upload URL",
          details: `User requested upload URL for **${name}**\nSize: Large File (Direct Upload)`
        });
        
        return res.status(200).json({
          success: true,
          uploadUrl: uploadUrl,
          recordingId: sanitizedName,
          key: key,
          expiresIn: 3600,
          message: "Upload directly to this URL with PUT request"
        });
      } catch (error) {
        console.error("[R2] Presigned URL error:", error);
        return res.status(500).json({ error: "Failed to generate upload URL", details: error.message });
      }
    }
    
    // Normal POST - Save recording (for small files)
    try {
      const { name, data, gameId, gameName } = req.body;

      if (!userId || !name || !data) {
        return res.status(400).json({
          error: "Missing required fields",
          required: ["userId", "name", "data"],
        });
      }

      // Validate data has frames
      if (!data.Frames || data.Frames.length === 0) {
        return res.status(400).json({
          error: "Invalid recording data",
          message: "Recording must have frames",
        });
      }

      const timestamp = new Date().toISOString();
      const frameCount = data.Frames.length;
      const duration = data.Frames[data.Frames.length - 1]?.t || 0;
      const mode = data.Mode || "Standard";
      const sanitizedName = sanitizeName(name);

      // ============================================
      // OPTIMIZE: Reduce float precision to 6 digits
      // This reduces file size by ~40-50% with imperceptible quality loss
      // ============================================
      function optimizeValue(val, precision = 6) {
        if (typeof val === 'number') {
          // Round to specified decimal places
          const multiplier = Math.pow(10, precision);
          return Math.round(val * multiplier) / multiplier;
        }
        return val;
      }

      function optimizeObject(obj, precision = 6) {
        if (obj === null || obj === undefined) return obj;
        if (typeof obj === 'number') return optimizeValue(obj, precision);
        if (typeof obj !== 'object') return obj;
        if (Array.isArray(obj)) {
          return obj.map(item => optimizeObject(item, precision));
        }
        const result = {};
        for (const key in obj) {
          result[key] = optimizeObject(obj[key], precision);
        }
        return result;
      }

      // Optimize the recording data (4 decimal places = ~0.0001 stud precision, imperceptible)
      const optimizedData = optimizeObject(data, 4);
      
      console.log(`[R2] Optimizing recording with 4 decimal precision...`);

      // Prepare recording object with optimized data
      const recordingObject = {
        id: sanitizedName,
        name: name,
        userId: userId,
        gameId: gameId || null,
        gameName: gameName || null,
        frameCount: frameCount,
        duration: duration,
        mode: mode,
        createdAt: timestamp,
        updatedAt: timestamp,
        data: optimizedData,  // Use optimized data
        _optimized: true,     // Flag to indicate this is optimized
        _precision: 6,        // Precision used
      };

      const content = JSON.stringify(recordingObject);
      const contentSize = Buffer.byteLength(content, "utf-8");
      const contentSizeKB = Math.round(contentSize / 1024);
      const contentSizeMB = (contentSize / (1024 * 1024)).toFixed(2);

      console.log(
        `[R2] Uploading recording: ${name} (${contentSizeKB}KB / ${contentSizeMB}MB)`,
      );

      // Upload to R2 - use sanitized name as filename
      const key = `recordings/${sanitizedName}.json`;

      await r2Client.send(
        new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
          Body: content,
          ContentType: "application/json",
          Metadata: {
            name: name,
            userId: userId,
            frameCount: frameCount.toString(),
            createdAt: timestamp,
          },
        }),
      );

      console.log(`[R2] Upload successful: ${sanitizedName}`);

      // Log to Discord
      await sendDiscordLog({
        title: "📤 New Recording Uploaded",
        type: "upload",
        userId: userId,
        fileName: name,
        action: "Upload Success",
        details: `Size: **${contentSizeKB} KB**\nFrames: **${frameCount}**\nGame: ${gameName || "Unknown"}`
      });

      return res.status(200).json({
        success: true,
        message: "Recording saved to cloud!",
        recordingId: sanitizedName,
        size: contentSizeKB,
        sizeMB: contentSizeMB,
      });
    } catch (error) {
      console.error("[R2] Save recording error:", error);
      return res.status(500).json({
        error: "Failed to save recording",
        message: error.message,
      });
    }
  }

  // ============================================
  // GET - Load recording by ID
  // ============================================
  if (method === "GET") {
    const { recordingId, list } = req.query;

    // LIST all recordings (OPTIMIZED: Use metadata only, don't read full files)
    if (list === "all") {
      try {
        console.log("[R2] Listing all recordings (optimized)...");

        const listResult = await r2Client.send(
          new ListObjectsV2Command({
            Bucket: R2_BUCKET_NAME,
            Prefix: "recordings/",
          }),
        );

        const recordings = [];

        if (listResult.Contents) {
          // Process in parallel with Promise.all for speed
          const promises = listResult.Contents.map(async (item) => {
            try {
              // Extract filename from key for display
              const fileName = item.Key.replace("recordings/", "").replace(
                ".json",
                "",
              );

              // Return basic info from listing (no file read needed!)
              return {
                recordingId: fileName,
                name: fileName.replace(/_/g, " "), // Convert underscores to spaces for display
                size: item.Size,
                lastModified: item.LastModified,
                // Estimate duration/frameCount from file size (rough approximation)
                // Average frame is ~4KB, so frameCount ≈ size / 4000
                estimatedFrameCount: Math.round(item.Size / 4000),
                estimatedDuration: Math.round(item.Size / 4000 / 60), // Assuming 60 FPS
              };
            } catch (parseError) {
              console.error(
                `[R2] Error processing ${item.Key}:`,
                parseError.message,
              );
              return null;
            }
          });

          const results = await Promise.all(promises);
          
          // Filter out nulls and add to recordings
          for (const rec of results) {
            if (rec) {
              recordings.push(rec);
            }
          }
        }

        // Sort by most recent first (using lastModified from R2)
        recordings.sort(
          (a, b) => new Date(b.lastModified) - new Date(a.lastModified),
        );

        console.log(`[R2] Found ${recordings.length} recordings`);

        return res.status(200).json({
          success: true,
          recordings: recordings,
          count: recordings.length,
        });
      } catch (error) {
        console.error("[R2] List recordings error:", error);
        return res.status(500).json({
          error: "Failed to list recordings",
          message: error.message,
        });
      }
    }

    // GET specific recording
    if (!recordingId) {
      return res.status(400).json({
        error: "Missing recordingId",
        usage: "/api/r2-recordings?recordingId=xxx",
      });
    }

    try {
      const key = `recordings/${recordingId}.json`;

      console.log(`[R2] Loading recording: ${key}`);

      // Check size first
      const head = await r2Client.send(new HeadObjectCommand({ Bucket: R2_BUCKET_NAME, Key: key }));
      const size = head.ContentLength;

      // If large (> 3.5MB to be safe), return Presigned URL
      if (size > 3.5 * 1024 * 1024) {
          console.log(`[R2] File is large (${(size/1024/1024).toFixed(2)}MB). Generating Presigned URL...`);
          const url = await getSignedUrl(r2Client, new GetObjectCommand({ Bucket: R2_BUCKET_NAME, Key: key }), { expiresIn: 3600 });
          
          return res.status(200).json({
              success: true,
              downloadUrl: url,
              recordingId: recordingId,
              size: size,
              name: head.Metadata?.name || recordingId,
              frameCount: parseInt(head.Metadata?.framecount || "0"),
          });
      }

      const getResult = await r2Client.send(
        new GetObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
        }),
      );

      const content = await streamToString(getResult.Body);
      const recordingData = JSON.parse(content);

      // Use GZIP compression for faster download (only if client supports it)
      return sendGzipJson(req, res, {
        success: true,
        recording: recordingData.data,
        name: recordingData.name,
        recordingId: recordingData.id,
        frameCount: recordingData.frameCount,
        duration: recordingData.duration,
        mode: recordingData.mode,
      });
    } catch (error) {
      console.error("[R2] Load recording error:", error);

      if (error.name === "NoSuchKey") {
        return res.status(404).json({
          error: "Recording not found",
          recordingId: recordingId,
        });
      }

      // Handle JSON parse errors (corrupted file)
      if (error.name === "SyntaxError" || error.message.includes("corrupted")) {
        console.error(`[R2] File corrupted or invalid JSON: ${recordingId}`);
        return res.status(500).json({
          error: "Recording file is corrupted",
          message: "The recording file appears to be damaged or in an invalid format. It may need to be re-uploaded.",
          recordingId: recordingId,
          technicalDetails: error.message,
        });
      }

      return res.status(500).json({
        error: "Failed to load recording",
        message: error.message,
      });
    }
  }

  // ============================================
  // PATCH - Update existing recording
  // ============================================
  if (method === "PATCH") {
    try {
      const { recordingId, name, data } = req.body;

      if (!recordingId) {
        return res.status(400).json({
          error: "Missing recordingId",
          message:
            "You must provide the recordingId of the recording to update",
        });
      }

      if (!name && !data) {
        return res.status(400).json({
          error: "Nothing to update",
          message: "Provide at least 'name' or 'data' to update",
        });
      }

      const key = `recordings/${recordingId}.json`;
      let existingData = null;

      // Get existing recording
      try {
        const getResult = await r2Client.send(
          new GetObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: key,
          }),
        );
        const content = await streamToString(getResult.Body);
        existingData = JSON.parse(content);
      } catch (getError) {
        return res.status(404).json({
          error: "Recording not found",
          recordingId: recordingId,
        });
      }

      // Update fields
      const updatedName = name || existingData.name;
      const updatedRecordingData = data || existingData.data;
      const timestamp = new Date().toISOString();

      // Validate new data if provided
      if (data && (!data.Frames || data.Frames.length === 0)) {
        return res.status(400).json({
          error: "Invalid recording data",
          message: "Recording must have frames",
        });
      }

      const frameCount = updatedRecordingData.Frames
        ? updatedRecordingData.Frames.length
        : 0;
      const duration =
        updatedRecordingData.Frames?.[updatedRecordingData.Frames.length - 1]
          ?.t || 0;

      // Prepare updated object
      const updatedObject = {
        ...existingData,
        name: updatedName,
        data: updatedRecordingData,
        frameCount: frameCount,
        duration: duration,
        updatedAt: timestamp,
      };

      const content = JSON.stringify(updatedObject);
      const contentSizeKB = Math.round(
        Buffer.byteLength(content, "utf-8") / 1024,
      );

      console.log(
        `[R2] Updating recording: ${existingData.id} (${contentSizeKB}KB)`,
      );

      // Upload updated version
      await r2Client.send(
        new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
          Body: content,
          ContentType: "application/json",
        }),
      );

      console.log(`[R2] Update successful: ${existingData.id}`);

      // Log to Discord
      await sendDiscordLog({
        title: "📝 Recording Updated",
        type: "update",
        userId: userId,
        fileName: updatedName,
        action: "Update Success",
        details: `Updated recording **${existingData.id}**\nNew Size: ${contentSizeKB} KB`
      });

      return res.status(200).json({
        success: true,
        message: "Recording updated successfully!",
        recordingId: existingData.id,
        updatedAt: timestamp,
        size: contentSizeKB,
      });
    } catch (error) {
      console.error("[R2] Update recording error:", error);
      return res.status(500).json({
        error: "Failed to update recording",
        message: error.message,
      });
    }
  }

  // ============================================
  // DELETE - Delete recording
  // ============================================
  if (method === "DELETE") {
    const { recordingId } = req.query;

    if (!recordingId) {
      return res.status(400).json({
        error: "Missing recordingId",
      });
    }

    try {
      const key = `recordings/${recordingId}.json`;

      console.log(`[R2] Deleting recording: ${key}`);

      await r2Client.send(
        new DeleteObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
        }),
      );

      console.log(`[R2] Delete successful: ${key}`);

      // Log to Discord (CRITICAL ALERT)
      await sendDiscordLog({
        title: "🗑️ Recording DELETED",
        type: "delete",
        userId: userId,
        fileName: recordingId,
        action: "Delete Success",
        details: `User **${userId}** deleted recording **${recordingId}**\n⚠️ Check if this was authorized.`
      });

      return res.status(200).json({
        success: true,
        message: "Recording deleted",
      });
    } catch (error) {
      console.error("[R2] Delete recording error:", error);
      return res.status(500).json({
        error: "Failed to delete recording",
        message: error.message,
      });
    }
  }

  return res.status(405).json({
    error: "Method not allowed",
    allowed: ["GET", "POST", "PATCH", "DELETE"],
  });
}
