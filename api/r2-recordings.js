// api/r2-recordings.js - Cloud Recording Storage via Cloudflare R2
// Supports large files up to 5GB (vs GitHub Gist 1MB limit)
// WITH GZIP COMPRESSION for faster downloads

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
} from "@aws-sdk/client-s3";
import zlib from "zlib";
import { promisify } from "util";

// Promisified gzip
const gzip = promisify(zlib.gzip);

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

// R2 Configuration
const R2_ACCOUNT_ID =
  process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6";
const R2_ACCESS_KEY_ID =
  process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf";
const R2_SECRET_ACCESS_KEY =
  process.env.R2_SECRET_ACCESS_KEY ||
  "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660";
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "starship-recordings";

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

// Helper: Convert stream to string
async function streamToString(stream) {
  const chunks = [];
  for await (const chunk of stream) {
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString("utf-8");
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

  const { method } = req;
  const userId = req.query.userId || req.body?.userId;

  // ============================================
  // POST - Save new recording to R2
  // ============================================
  if (method === "POST") {
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

      // Prepare recording object
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
        data: data,
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
