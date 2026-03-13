// api/cloud-chunk-m3p7.js - Secure Chunked Recording API for Streaming Large Files
// RENAMED from r2-chunked.js for security (old endpoint no longer works)
// Protected by EVENT_ENABLED toggle and EVENT_CODE verification
// Supports streaming download of large recordings for mobile optimization
// WITH GZIP COMPRESSION for faster downloads

import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
  DeleteObjectCommand,
} from "@aws-sdk/client-s3";
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
      console.log("[R2-Chunked] ✅ Redis module loaded");
    } catch (error) {
      console.error("[R2-Chunked] ⚠️ Redis module load failed:", error.message);
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
    if (!redisClient) return { hasAccess: false };

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
    console.error("[R2-Chunked] VIP check error:", error.message);
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
    console.error("[R2-Chunked] Event check error:", error.message);
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

  const vipResult = await checkVIPAccess(userId);
  if (vipResult.hasAccess) {
    return vipResult;
  }
  const eventResult = await checkEventAccessForUser(userId);
  return eventResult;
}

// R2 Configuration (SECURITY: All credentials must come from environment variables)
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID;
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID;
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY;
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "starship-recordings";

// Validate required environment variables
if (!R2_ACCOUNT_ID || !R2_ACCESS_KEY_ID || !R2_SECRET_ACCESS_KEY) {
  console.error("[R2-Chunked] CRITICAL: Missing R2 credentials in environment variables!");
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

// Configuration
const FRAMES_PER_CHUNK = 3000; // ~3000 frames per chunk (about 50 seconds at 60fps)
const MIN_CHUNK_SIZE_MB = 2; // Minimum chunk size in MB

// Helper: Convert stream to string
async function streamToString(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf-8");
}

// Helper: Send GZIP compressed JSON response
async function sendGzipJson(res, data, statusCode = 200) {
  try {
    const jsonString = JSON.stringify(data);
    const compressed = await gzip(Buffer.from(jsonString, "utf-8"));

    res.setHeader("Content-Type", "application/json");
    res.setHeader("Content-Encoding", "gzip");
    res.setHeader("Vary", "Accept-Encoding");
    res.setHeader("X-Original-Size", jsonString.length);
    res.setHeader("X-Compressed-Size", compressed.length);

    const compressionRatio = ((1 - compressed.length / jsonString.length) * 100).toFixed(1);
    console.log(`[R2-Chunked] GZIP: ${jsonString.length} -> ${compressed.length} bytes (${compressionRatio}% reduction)`);

    return res.status(statusCode).send(compressed);
  } catch (error) {
    // Fallback to uncompressed if gzip fails
    console.log("[R2-Chunked] GZIP failed, sending uncompressed:", error.message);
    return res.status(statusCode).json(data);
  }
}

// Helper: Get chunk info for a recording
async function getChunkInfo(recordingId) {
  try {
    // First, check if chunked metadata exists
    const metaKey = `recordings/${recordingId}_meta.json`;

    try {
      const metaResult = await r2Client.send(
        new GetObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: metaKey,
        })
      );
      const metaContent = await streamToString(metaResult.Body);
      const metadata = JSON.parse(metaContent);
      return {
        isChunked: true,
        ...metadata
      };
    } catch (e) {
      // No chunked metadata, check if original file exists
      const originalKey = `recordings/${recordingId}.json`;

      try {
        const headResult = await r2Client.send(
          new HeadObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: originalKey,
          })
        );

        return {
          isChunked: false,
          recordingId: recordingId,
          size: headResult.ContentLength,
          lastModified: headResult.LastModified,
        };
      } catch (e2) {
        return null; // Recording not found
      }
    }
  } catch (error) {
    console.error("[R2-Chunked] Error getting chunk info:", error);
    return null;
  }
}

// Helper: Create chunks from recording data
function createChunks(frames, framesPerChunk = FRAMES_PER_CHUNK) {
  const chunks = [];
  for (let i = 0; i < frames.length; i += framesPerChunk) {
    chunks.push(frames.slice(i, i + framesPerChunk));
  }
  return chunks;
}

// ============================================
// TOKEN-BASED ACCESS VALIDATION (Fixes [Risiko: TINGGI])
// ============================================
async function validateCloudToken(token, userId) {
  if (!token || !userId) return false;

  try {
    const crypto = await import("crypto");
    const SECRET_KEY = process.env.STARSHIP_SECRET_KEY || process.env.ADMIN_SECRET || "starship-fallback-secret-2025";

    // Decode from base64
    const decoded = Buffer.from(token, "base64").toString("utf-8");
    const parts = decoded.split(":");
    if (parts.length < 4) return false;

    const [tokenUserId, expiry, platform, signature] = parts;

    // 1. Check if token belongs to the requesting user
    if (tokenUserId !== String(userId)) {
      console.log(`[R2 Auth] ❌ Token user mismatch: ${tokenUserId} vs ${userId}`);
      return false;
    }

    // 2. Check if token has expired
    if (Date.now() > parseInt(expiry)) {
      console.log(`[R2 Auth] ❌ Token expired: ${new Date(parseInt(expiry)).toISOString()}`);
      return false;
    }

    // 3. Verify signature
    const tokenData = `${tokenUserId}:${expiry}:${platform}`;
    const expectedSignature = crypto
      .createHmac("sha256", SECRET_KEY)
      .update(tokenData)
      .digest("hex")
      .substring(0, 32);

    if (signature !== expectedSignature) {
      console.log(`[R2 Auth] ❌ Invalid token signature`);
      return false;
    }

    return true;
  } catch (error) {
    console.error("[R2 Auth] Token validation error:", error.message);
    return false;
  }
}

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader(
    "Access-Control-Allow-Methods",
    "GET, POST, OPTIONS",
  );
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-User-Id, X-Event-Code, X-Cloud-Token");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
  }

  // ============================================
  // SECURITY UPDATE: Token-based Access
  // ============================================
  const EVENT_ENABLED = process.env.R2_EVENT_ENABLED === "true";
  const requestUserId = req.query.userId || req.body?.userId || req.headers["x-user-id"];
  const cloudToken = req.query.cloudToken || req.body?.cloudToken || req.headers["x-cloud-token"];

  // BLACKLIST - Add userIds here that should be blocked
  const BLACKLIST_RAW = process.env.R2_BLACKLIST || "";
  const BLACKLIST = BLACKLIST_RAW.split(",").map(id => id.trim()).filter(id => id);

  // OWNER & DEV BYPASS
  const OWNER_USER_ID = "9268011358";
  const IS_DEV = process.env.NODE_ENV === "development";

  if (IS_DEV) {
    console.log(`[R2-Chunked] 🔧 DEV MODE BYPASS GRANTED - UserId: ${requestUserId}`);
  } else if (requestUserId === OWNER_USER_ID) {
    console.log(`[R2-Chunked] 👑 OWNER BYPASS GRANTED - UserId: ${requestUserId}`);
  } else {
    // 1. Check if event mode is enabled
    if (!EVENT_ENABLED) {
      return res.status(403).json({ error: "Event tidak aktif", message: "Cloud storage sedang tidak tersedia" });
    }

    // 2. Check if user provided a token
    if (!cloudToken) {
      return res.status(403).json({ error: "Token tidak ditemukan", message: "Silakan Re-Execute script untuk mendapatkan akses Cloud" });
    }

    // 3. Validate Token
    const isTokenValid = await validateCloudToken(cloudToken, requestUserId);
    if (!isTokenValid) {
      return res.status(403).json({ error: "Token tidak valid", message: "Akses ditolak. Token kadaluarsa atau tidak sah." });
    }

    // 4. Blacklist check
    if (BLACKLIST.includes(String(requestUserId))) {
      return res.status(403).json({ error: "Akses ditolak", message: "Akun Anda telah diblokir" });
    }

    console.log(`[R2-Chunked] ✅ Token-Access granted - User: ${requestUserId}`);
  }

  const { method } = req;
  const { recordingId, action, chunk } = req.query;

  // ============================================
  // GET - Retrieve chunk info or specific chunk
  // ============================================
  if (method === "GET") {

    // GET /api/r2-chunked?recordingId=xxx&action=info
    // Returns metadata about the recording (chunk info, total frames, etc.)
    if (action === "info" && recordingId) {
      try {
        console.log(`[R2-Chunked] Getting info for: ${recordingId}`);

        const info = await getChunkInfo(recordingId);

        if (!info) {
          return res.status(404).json({
            error: "Recording not found",
            recordingId: recordingId,
          });
        }

        if (info.isChunked) {
          // Already chunked, return metadata
          return res.status(200).json({
            success: true,
            isChunked: true,
            recordingId: recordingId,
            name: info.name,
            totalFrames: info.totalFrames,
            totalChunks: info.totalChunks,
            framesPerChunk: info.framesPerChunk,
            duration: info.duration,
            mode: info.mode,
            chunkSizes: info.chunkSizes || [],
            createdAt: info.createdAt,
          });
        } else {
          // Not chunked - need to load and check if it's large enough to chunk
          const originalKey = `recordings/${recordingId}.json`;

          // For large files (>10MB), recommend chunking
          const sizeMB = info.size / (1024 * 1024);

          if (sizeMB > 10) {
            // Load the recording to get accurate info
            const getResult = await r2Client.send(
              new GetObjectCommand({
                Bucket: R2_BUCKET_NAME,
                Key: originalKey,
              })
            );

            const content = await streamToString(getResult.Body);
            const recordingData = JSON.parse(content);
            const frames = recordingData.data?.Frames || [];
            const totalChunks = Math.ceil(frames.length / FRAMES_PER_CHUNK);

            return res.status(200).json({
              success: true,
              isChunked: false,
              needsChunking: true,
              recordingId: recordingId,
              name: recordingData.name,
              totalFrames: frames.length,
              suggestedChunks: totalChunks,
              framesPerChunk: FRAMES_PER_CHUNK,
              duration: recordingData.duration,
              mode: recordingData.mode || recordingData.data?.Mode,
              sizeMB: sizeMB.toFixed(2),
            });
          } else {
            // Small file, no chunking needed
            return res.status(200).json({
              success: true,
              isChunked: false,
              needsChunking: false,
              recordingId: recordingId,
              sizeMB: sizeMB.toFixed(2),
              message: "File is small enough to load directly",
            });
          }
        }
      } catch (error) {
        console.error("[R2-Chunked] Info error:", error);
        return res.status(500).json({
          error: "Failed to get recording info",
          message: error.message,
        });
      }
    }

    // GET /api/r2-chunked?recordingId=xxx&chunk=0
    // Returns the specified chunk of frames
    if (chunk !== undefined && recordingId) {
      const chunkIndex = parseInt(chunk);

      try {
        console.log(`[R2-Chunked] Getting chunk ${chunkIndex} for: ${recordingId}`);

        const info = await getChunkInfo(recordingId);

        if (!info) {
          return res.status(404).json({
            error: "Recording not found",
            recordingId: recordingId,
          });
        }

        if (info.isChunked) {
          // Load chunk file directly
          const chunkKey = `recordings/${recordingId}_chunk_${chunkIndex}.json`;

          try {
            const chunkResult = await r2Client.send(
              new GetObjectCommand({
                Bucket: R2_BUCKET_NAME,
                Key: chunkKey,
              })
            );

            const chunkContent = await streamToString(chunkResult.Body);
            const chunkData = JSON.parse(chunkContent);

            // Use GZIP compression for faster transfer
            return sendGzipJson(res, {
              success: true,
              chunkIndex: chunkIndex,
              totalChunks: info.totalChunks,
              frames: chunkData.frames,
              startFrame: chunkData.startFrame,
              endFrame: chunkData.endFrame,
              isLast: chunkIndex === info.totalChunks - 1,
            });
          } catch (e) {
            return res.status(404).json({
              error: "Chunk not found",
              recordingId: recordingId,
              chunkIndex: chunkIndex,
            });
          }
        } else {
          // Not chunked - extract chunk from original file
          const originalKey = `recordings/${recordingId}.json`;

          const getResult = await r2Client.send(
            new GetObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: originalKey,
            })
          );

          const content = await streamToString(getResult.Body);
          const recordingData = JSON.parse(content);
          const frames = recordingData.data?.Frames || [];

          const startIdx = chunkIndex * FRAMES_PER_CHUNK;
          const endIdx = Math.min(startIdx + FRAMES_PER_CHUNK, frames.length);

          if (startIdx >= frames.length) {
            return res.status(404).json({
              error: "Chunk index out of range",
              recordingId: recordingId,
              chunkIndex: chunkIndex,
              totalFrames: frames.length,
            });
          }

          const chunkFrames = frames.slice(startIdx, endIdx);
          const totalChunks = Math.ceil(frames.length / FRAMES_PER_CHUNK);

          // Use GZIP compression for faster transfer
          return sendGzipJson(res, {
            success: true,
            chunkIndex: chunkIndex,
            totalChunks: totalChunks,
            frames: chunkFrames,
            startFrame: startIdx,
            endFrame: endIdx - 1,
            isLast: chunkIndex === totalChunks - 1,
            // Include metadata in first chunk
            ...(chunkIndex === 0 ? {
              name: recordingData.name,
              mode: recordingData.mode || recordingData.data?.Mode,
              duration: recordingData.duration,
              totalFrames: frames.length,
              framesPerChunk: FRAMES_PER_CHUNK,
            } : {}),
          });
        }
      } catch (error) {
        console.error("[R2-Chunked] Chunk error:", error);
        return res.status(500).json({
          error: "Failed to get chunk",
          message: error.message,
        });
      }
    }

    // GET /api/r2-chunked?recordingId=xxx&action=metadata
    // Returns only the recording info without frame data (for quick preview)
    if (action === "metadata" && recordingId) {
      try {
        console.log(`[R2-Chunked] Getting metadata for: ${recordingId}`);

        // Check for chunked metadata first
        const metaKey = `recordings/${recordingId}_meta.json`;

        try {
          const metaResult = await r2Client.send(
            new GetObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: metaKey,
            })
          );
          const metaContent = await streamToString(metaResult.Body);
          const metadata = JSON.parse(metaContent);

          return res.status(200).json({
            success: true,
            isChunked: true,
            ...metadata,
          });
        } catch (e) {
          // Fallback to original file
          const originalKey = `recordings/${recordingId}.json`;

          const getResult = await r2Client.send(
            new GetObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: originalKey,
            })
          );

          const content = await streamToString(getResult.Body);
          const recordingData = JSON.parse(content);
          const frames = recordingData.data?.Frames || [];

          return res.status(200).json({
            success: true,
            isChunked: false,
            recordingId: recordingId,
            name: recordingData.name,
            totalFrames: frames.length,
            duration: recordingData.duration,
            mode: recordingData.mode || recordingData.data?.Mode,
            framesPerChunk: FRAMES_PER_CHUNK,
            totalChunks: Math.ceil(frames.length / FRAMES_PER_CHUNK),
          });
        }
      } catch (error) {
        console.error("[R2-Chunked] Metadata error:", error);
        return res.status(500).json({
          error: "Failed to get metadata",
          message: error.message,
        });
      }
    }

    return res.status(400).json({
      error: "Invalid request",
      usage: {
        info: "/api/r2-chunked?recordingId=xxx&action=info",
        chunk: "/api/r2-chunked?recordingId=xxx&chunk=0",
        metadata: "/api/r2-chunked?recordingId=xxx&action=metadata",
        convert: "POST /api/r2-chunked?recordingId=xxx&action=convert",
      },
    });
  }

  // ============================================
  // POST - Upload chunks and merge, or convert
  // ============================================
  if (method === "POST") {
    const { action: postAction } = req.query;
    const bodyRecordingId = req.body?.recordingId || recordingId;

    // POST /api/r2-chunked?action=upload_chunk
    // Upload a single chunk of a recording
    if (postAction === "upload_chunk") {
      const { recordingId, chunkIndex, chunkData } = req.body;

      if (!recordingId || chunkIndex === undefined || !chunkData) {
        return res.status(400).json({ error: "Missing parameters: recordingId, chunkIndex, chunkData" });
      }

      try {
        const chunkKey = `recordings/${recordingId}_chunk_${chunkIndex}.json`;

        // Ensure chunkData is stringified if it's an object
        const bodyContent = typeof chunkData === 'string' ? chunkData : JSON.stringify(chunkData);

        await r2Client.send(
          new PutObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: chunkKey,
            Body: bodyContent,
            ContentType: "application/json",
          })
        );

        console.log(`[R2-Chunked] Uploaded chunk ${chunkIndex} for ${recordingId}`);
        return res.status(200).json({ success: true, chunkIndex });
      } catch (error) {
        console.error("[R2-Chunked] Upload chunk error:", error);
        return res.status(500).json({ error: "Failed to upload chunk", details: error.message });
      }
    }

    // POST /api/r2-chunked?action=save_meta
    // Save metadata file ONLY (no merge - chunks stay separate)
    // This is fast and won't timeout even for huge files
    if (postAction === "save_meta") {
      const { recordingId, metadata } = req.body;

      if (!recordingId || !metadata) {
        return res.status(400).json({ error: "Missing parameters: recordingId, metadata" });
      }

      try {
        console.log(`[R2-Chunked] Saving metadata for ${recordingId} (${metadata.totalChunks} chunks)...`);

        // Just save the metadata file - NO MERGE
        const metaKey = `recordings/${recordingId}_meta.json`;

        await r2Client.send(new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: metaKey,
          Body: JSON.stringify(metadata),
          ContentType: "application/json",
        }));

        console.log(`[R2-Chunked] Metadata saved: ${metaKey}`);

        return res.status(200).json({
          success: true,
          recordingId,
          isChunked: true,
          totalChunks: metadata.totalChunks,
          message: "Chunked recording saved successfully!"
        });

      } catch (error) {
        console.error("[R2-Chunked] Save metadata error:", error);
        return res.status(500).json({ error: "Failed to save metadata", details: error.message });
      }
    }

    // POST /api/r2-chunked?action=upload_meta
    // Finalize upload by merging chunks into a single file (LEGACY - may timeout on large files)
    if (postAction === "upload_meta") {
      const { recordingId, metadata } = req.body;

      if (!recordingId || !metadata) {
        return res.status(400).json({ error: "Missing parameters: recordingId, metadata" });
      }

      try {
        console.log(`[R2-Chunked] Merging ${metadata.totalChunks} chunks for ${recordingId}...`);

        // 1. Download all chunks
        const chunkPromises = [];
        for (let i = 0; i < metadata.totalChunks; i++) {
          chunkPromises.push(
            r2Client.send(new GetObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: `recordings/${recordingId}_chunk_${i}.json`
            })).then(res => streamToString(res.Body))
              .then(str => JSON.parse(str))
          );
        }

        const chunks = await Promise.all(chunkPromises);

        // 2. Merge frames
        let allFrames = [];
        chunks.sort((a, b) => (a.chunkIndex || 0) - (b.chunkIndex || 0));

        chunks.forEach(chunk => {
          if (chunk && chunk.frames) {
            allFrames = allFrames.concat(chunk.frames);
          }
        });

        console.log(`[R2-Chunked] Merged ${allFrames.length} frames.`);

        // 3. Create final object (same structure as normal upload)
        const finalRecording = {
          id: recordingId,
          name: metadata.name,
          userId: metadata.userId,
          gameId: metadata.gameId,
          gameName: metadata.gameName,
          frameCount: allFrames.length,
          duration: metadata.duration,
          mode: metadata.mode,
          createdAt: metadata.createdAt,
          updatedAt: new Date().toISOString(),
          data: {
            Frames: allFrames,
            Mode: metadata.mode,
            FPS: 60
          }
        };

        // 4. Upload final file with correct name (recordingId is already sanitized)
        await r2Client.send(new PutObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: `recordings/${recordingId}.json`,
          Body: JSON.stringify(finalRecording),
          ContentType: "application/json",
          Metadata: {
            name: metadata.name,
            userId: metadata.userId,
            framecount: allFrames.length.toString(),
            mode: metadata.mode
          }
        }));

        console.log(`[R2-Chunked] Final file saved: recordings/${recordingId}.json`);

        // 5. Delete temporary chunks
        const deletePromises = [];
        for (let i = 0; i < metadata.totalChunks; i++) {
          deletePromises.push(
            r2Client.send(new DeleteObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: `recordings/${recordingId}_chunk_${i}.json`
            }))
          );
        }
        await Promise.all(deletePromises);
        console.log(`[R2-Chunked] Cleaned up ${metadata.totalChunks} temporary chunks.`);

        return res.status(200).json({ success: true, recordingId, message: "Large recording uploaded and merged successfully!" });

      } catch (error) {
        console.error("[R2-Chunked] Merge error:", error);
        return res.status(500).json({ error: "Failed to merge chunks", details: error.message });
      }
    }

    // POST /api/r2-chunked?action=convert
    // Convert an existing large recording to chunked format
    if (postAction === "convert" && bodyRecordingId) {
      try {
        console.log(`[R2-Chunked] Converting: ${bodyRecordingId}`);

        const originalKey = `recordings/${bodyRecordingId}.json`;

        // Load original recording
        const getResult = await r2Client.send(
          new GetObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: originalKey,
          })
        );

        const content = await streamToString(getResult.Body);
        const recordingData = JSON.parse(content);
        const frames = recordingData.data?.Frames || [];

        if (frames.length === 0) {
          return res.status(400).json({
            error: "Recording has no frames",
          });
        }

        // Create chunks
        const chunks = createChunks(frames, FRAMES_PER_CHUNK);
        const chunkSizes = [];

        // Upload each chunk
        for (let i = 0; i < chunks.length; i++) {
          const chunkData = {
            chunkIndex: i,
            startFrame: i * FRAMES_PER_CHUNK,
            endFrame: Math.min((i + 1) * FRAMES_PER_CHUNK - 1, frames.length - 1),
            frames: chunks[i],
          };

          const chunkContent = JSON.stringify(chunkData);
          const chunkSize = Buffer.byteLength(chunkContent, "utf-8");
          chunkSizes.push(Math.round(chunkSize / 1024)); // Size in KB

          const chunkKey = `recordings/${bodyRecordingId}_chunk_${i}.json`;

          await r2Client.send(
            new PutObjectCommand({
              Bucket: R2_BUCKET_NAME,
              Key: chunkKey,
              Body: chunkContent,
              ContentType: "application/json",
            })
          );

          console.log(`[R2-Chunked] Uploaded chunk ${i + 1}/${chunks.length}`);
        }

        // Create and upload metadata
        const metadata = {
          recordingId: bodyRecordingId,
          name: recordingData.name,
          totalFrames: frames.length,
          totalChunks: chunks.length,
          framesPerChunk: FRAMES_PER_CHUNK,
          duration: recordingData.duration,
          mode: recordingData.mode || recordingData.data?.Mode,
          chunkSizes: chunkSizes,
          createdAt: recordingData.createdAt || new Date().toISOString(),
          convertedAt: new Date().toISOString(),
        };

        const metaKey = `recordings/${bodyRecordingId}_meta.json`;

        await r2Client.send(
          new PutObjectCommand({
            Bucket: R2_BUCKET_NAME,
            Key: metaKey,
            Body: JSON.stringify(metadata),
            ContentType: "application/json",
          })
        );

        console.log(`[R2-Chunked] Conversion complete: ${bodyRecordingId}`);

        return res.status(200).json({
          success: true,
          message: "Recording converted to chunked format",
          recordingId: bodyRecordingId,
          totalChunks: chunks.length,
          totalFrames: frames.length,
          chunkSizes: chunkSizes,
        });
      } catch (error) {
        console.error("[R2-Chunked] Convert error:", error);

        if (error.name === "NoSuchKey") {
          return res.status(404).json({
            error: "Recording not found",
            recordingId: bodyRecordingId,
          });
        }

        return res.status(500).json({
          error: "Failed to convert recording",
          message: error.message,
        });
      }
    }

    return res.status(400).json({
      error: "Invalid POST action",
      usage: {
        convert: "POST /api/r2-chunked?action=convert with body { recordingId: 'xxx' }",
      },
    });
  }

  return res.status(405).json({
    error: "Method not allowed",
    allowed: ["GET", "POST"],
  });
}
