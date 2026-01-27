#!/usr/bin/env node
/**
 * Upload Recording to R2 Cloud (with GZIP compression)
 * 
 * Usage:
 *   node upload-recording.js <file.json> [name]
 * 
 * Examples:
 *   node upload-recording.js recording.json
 *   node upload-recording.js recording.json "My Recording Name"
 *   node upload-recording.js ./recordings/*.json  (upload multiple files)
 * 
 * The script uploads directly to R2, bypassing Vercel limits.
 * Files are GZIP compressed for smaller storage (typically 70-90% smaller).
 */

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import fs from "fs";
import path from "path";
import zlib from "zlib";
import { promisify } from "util";

// Promisified gzip
const gzip = promisify(zlib.gzip);

// R2 Configuration (same as api/r2-recordings.js)
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

// Upload a single file with GZIP compression
async function uploadFile(filePath, customName) {
  console.log(`\n📤 Uploading: ${filePath}`);
  
  // Read file
  if (!fs.existsSync(filePath)) {
    console.error(`❌ File not found: ${filePath}`);
    return false;
  }
  
  const content = fs.readFileSync(filePath, "utf-8");
  const originalSizeMB = (Buffer.byteLength(content, "utf-8") / 1024 / 1024).toFixed(2);
  console.log(`   Original size: ${originalSizeMB} MB`);
  
  // Parse to get metadata
  let recordingData;
  try {
    recordingData = JSON.parse(content);
  } catch (e) {
    console.error(`❌ Invalid JSON file: ${filePath}`);
    return false;
  }
  
  // Determine name
  const fileName = path.basename(filePath, ".json");
  const name = customName || recordingData.name || fileName;
  const sanitizedName = sanitizeName(name);
  
  console.log(`   Name: ${name}`);
  console.log(`   Key: recordings/${sanitizedName}.json`);
  
  // Prepare recording object
  const timestamp = new Date().toISOString();
  
  // Check if it's already in the correct format
  let finalObject;
  if (recordingData.data && recordingData.data.Frames) {
    // Already wrapped format from Roblox
    finalObject = {
      id: sanitizedName,
      name: name,
      userId: recordingData.userId || "local",
      gameId: recordingData.gameId || null,
      gameName: recordingData.gameName || null,
      frameCount: recordingData.data.Frames.length,
      duration: recordingData.data.Duration || recordingData.data.Frames[recordingData.data.Frames.length - 1]?.t || 0,
      mode: recordingData.data.Mode || "Flexible",
      createdAt: recordingData.createdAt || timestamp,
      updatedAt: timestamp,
      data: recordingData.data,
      _compressed: true,
    };
  } else if (recordingData.Frames) {
    // Raw recording format
    finalObject = {
      id: sanitizedName,
      name: name,
      userId: "local",
      gameId: null,
      gameName: null,
      frameCount: recordingData.Frames.length,
      duration: recordingData.Duration || recordingData.Frames[recordingData.Frames.length - 1]?.t || 0,
      mode: recordingData.Mode || "Flexible",
      createdAt: timestamp,
      updatedAt: timestamp,
      data: recordingData,
      _compressed: true,
    };
  } else {
    // Unknown format, upload as-is
    finalObject = recordingData;
    finalObject.id = sanitizedName;
    finalObject.name = name;
    finalObject.updatedAt = timestamp;
    finalObject._compressed = true;
  }
  
  const finalContent = JSON.stringify(finalObject);
  const finalSizeMB = (Buffer.byteLength(finalContent, "utf-8") / 1024 / 1024).toFixed(2);
  
  // GZIP compress
  const compressed = await gzip(Buffer.from(finalContent, "utf-8"));
  const compressedSizeMB = (compressed.length / 1024 / 1024).toFixed(2);
  const compressionRatio = ((1 - compressed.length / Buffer.byteLength(finalContent, "utf-8")) * 100).toFixed(1);
  
  // Upload to R2
  try {
    await r2Client.send(new PutObjectCommand({
      Bucket: R2_BUCKET_NAME,
      Key: `recordings/${sanitizedName}.json`,
      Body: compressed,
      ContentType: "application/json",
      ContentEncoding: "gzip",
      Metadata: {
        name: name,
        framecount: (finalObject.frameCount || 0).toString(),
        mode: finalObject.mode || "Flexible",
      }
    }));
    
    console.log(`✅ Uploaded successfully!`);
    console.log(`   Original: ${originalSizeMB} MB → Compressed: ${compressedSizeMB} MB (${compressionRatio}% saved)`);
    console.log(`   Recording ID: ${sanitizedName}`);
    return true;
  } catch (error) {
    console.error(`❌ Upload failed: ${error.message}`);
    return false;
  }
}

// Main
async function main() {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.log(`
╔═══════════════════════════════════════════════════════════════╗
║          Upload Recording to R2 Cloud                         ║
╚═══════════════════════════════════════════════════════════════╝

Usage:
  node upload-recording.js <file.json> [name]

Examples:
  node upload-recording.js recording.json
  node upload-recording.js recording.json "My Recording Name"
  node upload-recording.js ./recordings/file1.json ./recordings/file2.json

The script uploads directly to R2, bypassing all size limits!
`);
    process.exit(1);
  }
  
  console.log("╔═══════════════════════════════════════════════════════════════╗");
  console.log("║          Upload Recording to R2 Cloud                         ║");
  console.log("╚═══════════════════════════════════════════════════════════════╝");
  
  let successCount = 0;
  let failCount = 0;
  
  // Check if last arg is a custom name (not a file)
  let customName = null;
  let files = args;
  
  if (args.length >= 2) {
    const lastArg = args[args.length - 1];
    if (!lastArg.endsWith(".json") && !fs.existsSync(lastArg)) {
      customName = lastArg;
      files = args.slice(0, -1);
    }
  }
  
  for (const file of files) {
    const success = await uploadFile(file, customName);
    if (success) successCount++;
    else failCount++;
  }
  
  console.log("\n════════════════════════════════════════════════════════════════");
  console.log(`✅ Success: ${successCount}  ❌ Failed: ${failCount}`);
  console.log("════════════════════════════════════════════════════════════════");
}

main().catch(console.error);
