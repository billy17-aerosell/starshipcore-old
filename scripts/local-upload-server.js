#!/usr/bin/env node
/**
 * Local Upload Server for R2
 * 
 * This server runs locally and accepts upload requests from Roblox PC Script.
 * It then uploads directly to R2 without any size limits.
 * 
 * Usage:
 *   node local-upload-server.js
 * 
 * The server will run on http://localhost:4000
 * PC Script should POST to http://localhost:4000/upload
 */

import "dotenv/config";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import http from "http";
import zlib from "zlib";
import { promisify } from "util";

// Promisified gzip
const gzip = promisify(zlib.gzip);

// R2 Configuration
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6";
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf";
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY || "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660";
const R2_BUCKET_NAME = process.env.R2_BUCKET_NAME || "starship-recordings";

const r2Client = new S3Client({
  region: "auto",
  endpoint: `https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2_ACCESS_KEY_ID,
    secretAccessKey: R2_SECRET_ACCESS_KEY,
  },
});

// Sanitize name for filename
function sanitizeName(name) {
  return name
    .replace(/[^a-zA-Z0-9\s\-_]/g, "")
    .replace(/\s+/g, "_")
    .substring(0, 100);
}

// Parse request body
function parseBody(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", chunk => body += chunk);
    req.on("end", () => {
      try {
        resolve(JSON.parse(body));
      } catch (e) {
        reject(new Error("Invalid JSON"));
      }
    });
    req.on("error", reject);
  });
}

// Upload to R2 with GZIP compression
async function uploadToR2(name, data, userId, gameId, gameName) {
  const sanitizedName = sanitizeName(name);
  const timestamp = new Date().toISOString();

  // Prepare recording object
  const recordingObject = {
    id: sanitizedName,
    name: name,
    userId: userId || "local",
    gameId: gameId || null,
    gameName: gameName || null,
    frameCount: data.Frames ? data.Frames.length : 0,
    duration: data.Duration || (data.Frames && data.Frames.length > 0 ? data.Frames[data.Frames.length - 1].t : 0),
    mode: data.Mode || "Flexible",
    createdAt: timestamp,
    updatedAt: timestamp,
    data: data,
    _compressed: true, // Flag to indicate this is gzip compressed
  };

  const content = JSON.stringify(recordingObject);
  const originalSizeMB = (Buffer.byteLength(content, "utf-8") / 1024 / 1024).toFixed(2);

  // GZIP compress
  const compressed = await gzip(Buffer.from(content, "utf-8"));
  const compressedSizeMB = (compressed.length / 1024 / 1024).toFixed(2);
  const compressionRatio = ((1 - compressed.length / Buffer.byteLength(content, "utf-8")) * 100).toFixed(1);

  console.log(`📤 Uploading: ${name}`);
  console.log(`   Original: ${originalSizeMB} MB → Compressed: ${compressedSizeMB} MB (${compressionRatio}% saved)`);

  await r2Client.send(new PutObjectCommand({
    Bucket: R2_BUCKET_NAME,
    Key: `recordings/${sanitizedName}.json`,
    Body: compressed,
    ContentType: "application/json",
    ContentEncoding: "gzip",
  }));

  console.log(`✅ Uploaded: ${sanitizedName}`);

  return {
    success: true,
    recordingId: sanitizedName,
    originalSize: originalSizeMB,
    compressedSize: compressedSizeMB,
    compressionRatio: compressionRatio + "%",
    message: "Recording uploaded to cloud (GZIP compressed)!"
  };
}

// Create HTTP server
const server = http.createServer(async (req, res) => {
  // CORS headers
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");

  if (req.method === "OPTIONS") {
    res.writeHead(200);
    res.end();
    return;
  }

  // Health check
  if (req.method === "GET" && req.url === "/") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ status: "ok", message: "Local Upload Server is running" }));
    return;
  }

  // Upload endpoint
  if (req.method === "POST" && req.url === "/upload") {
    try {
      const body = await parseBody(req);

      if (!body.name || !body.data) {
        res.writeHead(400, { "Content-Type": "application/json" });
        res.end(JSON.stringify({ error: "Missing name or data" }));
        return;
      }

      const result = await uploadToR2(
        body.name,
        body.data,
        body.userId,
        body.gameId,
        body.gameName
      );

      res.writeHead(200, { "Content-Type": "application/json" });
      res.end(JSON.stringify(result));
    } catch (error) {
      console.error("❌ Error:", error.message);
      res.writeHead(500, { "Content-Type": "application/json" });
      res.end(JSON.stringify({ error: error.message }));
    }
    return;
  }

  // 404
  res.writeHead(404, { "Content-Type": "application/json" });
  res.end(JSON.stringify({ error: "Not found" }));
});

const PORT = 4000;

server.listen(PORT, () => {
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║          Local Upload Server for R2                           ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝");
  console.log("");
  console.log(`🚀 Server running at http://localhost:${PORT}`);
  console.log("");
  console.log("Endpoints:");
  console.log(`  GET  http://localhost:${PORT}/        - Health check`);
  console.log(`  POST http://localhost:${PORT}/upload  - Upload recording`);
  console.log("");
  console.log("📝 Set in Roblox: _G.StarshipLocalServer = \"http://localhost:4000\"");
  console.log("");
  console.log("Waiting for uploads...");
  console.log("════════════════════════════════════════════════════════════════");
});
