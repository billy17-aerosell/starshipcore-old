// api/r2-recordings.js - Cloud Recording Storage via Cloudflare R2
// Supports large files up to 5GB (vs GitHub Gist 1MB limit)

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
} from "@aws-sdk/client-s3";

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

// Helper: Generate short share code from name
function generateShareCode(name) {
  // Create 8 character code from name hash
  const sanitized = sanitizeName(name).toUpperCase();
  const hash = sanitized.split("").reduce((acc, char) => {
    return (acc << 5) - acc + char.charCodeAt(0);
  }, 0);
  const hashStr = Math.abs(hash).toString(36).toUpperCase();
  return (sanitized.substring(0, 4) + hashStr).substring(0, 8).padEnd(8, "X");
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
      const shareCode = generateShareCode(name);

      // Prepare recording object
      const recordingObject = {
        id: sanitizedName,
        shareCode: shareCode,
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
            shareCode: shareCode,
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
        shareCode: shareCode,
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
  // GET - Load recording by share code or ID
  // ============================================
  if (method === "GET") {
    const { shareCode, recordingId, list } = req.query;

    // LIST all recordings
    if (list === "all") {
      try {
        console.log("[R2] Listing all recordings...");

        const listResult = await r2Client.send(
          new ListObjectsV2Command({
            Bucket: R2_BUCKET_NAME,
            Prefix: "recordings/",
          }),
        );

        const recordings = [];

        if (listResult.Contents) {
          for (const item of listResult.Contents) {
            try {
              // Get object to read metadata
              const getResult = await r2Client.send(
                new GetObjectCommand({
                  Bucket: R2_BUCKET_NAME,
                  Key: item.Key,
                }),
              );

              const content = await streamToString(getResult.Body);
              const data = JSON.parse(content);

              // Extract filename from key for display
              const fileName = item.Key.replace("recordings/", "").replace(
                ".json",
                "",
              );

              recordings.push({
                recordingId: data.id || fileName,
                shareCode: data.shareCode,
                name: data.name || fileName,
                userId: data.userId,
                frameCount: data.frameCount,
                duration: data.duration,
                mode: data.mode,
                createdAt: data.createdAt,
                updatedAt: data.updatedAt,
                size: item.Size,
              });
            } catch (parseError) {
              console.error(
                `[R2] Error parsing ${item.Key}:`,
                parseError.message,
              );
            }
          }
        }

        // Sort by most recent first
        recordings.sort(
          (a, b) => new Date(b.updatedAt) - new Date(a.updatedAt),
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
    const targetId = recordingId || shareCode;

    if (!targetId) {
      return res.status(400).json({
        error: "Missing recordingId or shareCode",
        usage: "/api/r2-recordings?recordingId=xxx or ?shareCode=xxx",
      });
    }

    try {
      let key = null;

      // If it's a share code (8 chars) or short name, we need to search
      if (targetId.length <= 8) {
        console.log(`[R2] Searching for shareCode: ${targetId}`);

        const listResult = await r2Client.send(
          new ListObjectsV2Command({
            Bucket: R2_BUCKET_NAME,
            Prefix: "recordings/",
          }),
        );

        if (listResult.Contents) {
          for (const item of listResult.Contents) {
            // Extract ID from key: recordings/XXXXX-XXXXX.json
            const fileName = item.Key.replace("recordings/", "").replace(
              ".json",
              "",
            );
            // Match by shareCode prefix OR by filename
            if (
              fileName.toUpperCase().startsWith(targetId.toUpperCase()) ||
              fileName.toUpperCase().includes(targetId.toUpperCase())
            ) {
              key = item.Key;
              break;
            }
          }
        }

        if (!key) {
          return res.status(404).json({
            error: "Recording not found",
            shareCode: targetId,
          });
        }
      } else {
        // Full recording ID provided
        key = `recordings/${targetId}.json`;
      }

      console.log(`[R2] Loading recording: ${key}`);

      const getResult = await r2Client.send(
        new GetObjectCommand({
          Bucket: R2_BUCKET_NAME,
          Key: key,
        }),
      );

      const content = await streamToString(getResult.Body);
      const recordingData = JSON.parse(content);

      return res.status(200).json({
        success: true,
        recording: recordingData.data,
        name: recordingData.name,
        shareCode: recordingData.shareCode,
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
          recordingId: targetId,
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
      const { recordingId, shareCode, name, data } = req.body;
      const targetId = recordingId || shareCode;

      if (!targetId) {
        return res.status(400).json({
          error: "Missing recordingId or shareCode",
          message:
            "You must provide the recordingId or shareCode of the recording to update",
        });
      }

      if (!name && !data) {
        return res.status(400).json({
          error: "Nothing to update",
          message: "Provide at least 'name' or 'data' to update",
        });
      }

      // Find the recording
      let key = null;
      let existingData = null;

      if (targetId.length === 8) {
        // Search by share code
        const listResult = await r2Client.send(
          new ListObjectsV2Command({
            Bucket: R2_BUCKET_NAME,
            Prefix: "recordings/",
          }),
        );

        if (listResult.Contents) {
          for (const item of listResult.Contents) {
            const fileName = item.Key.replace("recordings/", "").replace(
              ".json",
              "",
            );
            if (fileName.toUpperCase().startsWith(targetId.toUpperCase())) {
              key = item.Key;
              break;
            }
          }
        }
      } else {
        key = `recordings/${targetId}.json`;
      }

      if (!key) {
        return res.status(404).json({
          error: "Recording not found",
          targetId: targetId,
        });
      }

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
          targetId: targetId,
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
        shareCode: existingData.shareCode,
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
    const { recordingId, shareCode } = req.query;
    const targetId = recordingId || shareCode;

    if (!targetId) {
      return res.status(400).json({
        error: "Missing recordingId or shareCode",
      });
    }

    try {
      let key = null;

      if (targetId.length === 8) {
        // Search by share code
        const listResult = await r2Client.send(
          new ListObjectsV2Command({
            Bucket: R2_BUCKET_NAME,
            Prefix: "recordings/",
          }),
        );

        if (listResult.Contents) {
          for (const item of listResult.Contents) {
            const fileName = item.Key.replace("recordings/", "").replace(
              ".json",
              "",
            );
            if (fileName.toUpperCase().startsWith(targetId.toUpperCase())) {
              key = item.Key;
              break;
            }
          }
        }
      } else {
        key = `recordings/${targetId}.json`;
      }

      if (!key) {
        return res.status(404).json({
          error: "Recording not found",
          targetId: targetId,
        });
      }

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
