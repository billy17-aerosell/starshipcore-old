// api/r2-chunked.js - Chunked Recording API for Streaming Large Files
// Supports streaming download of large recordings for mobile optimization

import {
  S3Client,
  GetObjectCommand,
  PutObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
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

export default async function handler(req, res) {
  // Set CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader(
    "Access-Control-Allow-Methods",
    "GET, POST, OPTIONS"
  );
  res.setHeader("Access-Control-Allow-Headers", "Content-Type, X-User-Id");

  if (req.method === "OPTIONS") {
    return res.status(200).end();
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
            
            return res.status(200).json({
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
          
          return res.status(200).json({
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
  // POST - Convert existing recording to chunked format
  // ============================================
  if (method === "POST") {
    const { action: postAction } = req.query;
    const bodyRecordingId = req.body?.recordingId || recordingId;

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
