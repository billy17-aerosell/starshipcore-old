/**
 * ============================================
 * BULK UPLOAD RECORDINGS TO R2 CLOUD
 * ============================================
 * 
 * Script ini akan mengupload semua file recording (.json) 
 * dari folder lokal ke Cloudflare R2 Cloud Storage.
 * 
 * USAGE:
 *   node bulk-upload-r2.js [folder_path] [options]
 * 
 * EXAMPLES:
 *   node bulk-upload-r2.js                          # Upload dari './recordings-to-upload'
 *   node bulk-upload-r2.js ./my-recordings          # Upload dari folder custom
 *   node bulk-upload-r2.js ./recordings --dry-run   # Preview saja, tidak upload
 *   node bulk-upload-r2.js ./recordings --overwrite # Overwrite existing files
 * 
 * OPTIONS:
 *   --dry-run     : Preview files tanpa upload
 *   --overwrite   : Overwrite jika file sudah ada di cloud
 *   --verbose     : Show detailed logs
 *   --user=ID     : Set userId untuk semua recordings (default: 'bulk-upload')
 * 
 * FILE FORMAT:
 *   Files harus dalam format JSON dengan struktur:
 *   {
 *     "FPS": 60,
 *     "Mode": "Flexible",
 *     "Frames": [...]
 *   }
 * 
 *   Atau format wrapped:
 *   {
 *     "name": "Recording Name",
 *     "data": { "FPS": 60, "Frames": [...] }
 *   }
 */

import {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
  ListObjectsV2Command,
} from "@aws-sdk/client-s3";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

// Get dirname for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ============================================
// R2 CONFIGURATION
// ============================================
// You can also set these as environment variables
const R2_CONFIG = {
  ACCOUNT_ID: process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6",
  ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf",
  SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY || "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660",
  BUCKET_NAME: process.env.R2_BUCKET_NAME || "starship-recordings",
};

// ============================================
// HELPER FUNCTIONS
// ============================================

/**
 * Sanitize name for use as filename (remove invalid characters)
 */
function sanitizeName(name) {
  return name
    .replace(/[^a-zA-Z0-9\s\-_]/g, "") // Remove special characters
    .replace(/\s+/g, "_") // Replace spaces with underscore
    .substring(0, 100); // Limit length
}

/**
 * Format bytes to human readable
 */
function formatBytes(bytes) {
  if (bytes === 0) return "0 Bytes";
  const k = 1024;
  const sizes = ["Bytes", "KB", "MB", "GB"];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + " " + sizes[i];
}

/**
 * Format duration (seconds) to mm:ss
 */
function formatDuration(seconds) {
  const mins = Math.floor(seconds / 60);
  const secs = Math.floor(seconds % 60);
  return `${mins}:${secs.toString().padStart(2, "0")}`;
}

/**
 * Get all JSON files from directory recursively
 */
function getJsonFiles(dir, files = []) {
  if (!fs.existsSync(dir)) {
    return files;
  }
  
  const items = fs.readdirSync(dir);
  
  for (const item of items) {
    const fullPath = path.join(dir, item);
    const stat = fs.statSync(fullPath);
    
    if (stat.isDirectory()) {
      // Recurse into subdirectories
      getJsonFiles(fullPath, files);
    } else if (item.endsWith(".json")) {
      files.push(fullPath);
    }
  }
  
  return files;
}

/**
 * Parse command line arguments
 */
function parseArgs(args) {
  const options = {
    folder: "./recordings-to-upload",
    dryRun: false,
    overwrite: false,
    verbose: false,
    userId: "bulk-upload",
  };
  
  for (const arg of args) {
    if (arg === "--dry-run") {
      options.dryRun = true;
    } else if (arg === "--overwrite") {
      options.overwrite = true;
    } else if (arg === "--verbose") {
      options.verbose = true;
    } else if (arg.startsWith("--user=")) {
      options.userId = arg.split("=")[1];
    } else if (!arg.startsWith("--") && !arg.startsWith("-")) {
      options.folder = arg;
    }
  }
  
  return options;
}

/**
 * Validate recording data structure
 */
function validateRecording(data) {
  // Check if it's wrapped format
  if (data.data && data.data.Frames) {
    return {
      valid: true,
      name: data.name || null,
      recordingData: data.data,
    };
  }
  
  // Check if it's direct format
  if (data.Frames && Array.isArray(data.Frames)) {
    return {
      valid: true,
      name: null,
      recordingData: data,
    };
  }
  
  return {
    valid: false,
    error: "Missing 'Frames' array in recording data",
  };
}

// ============================================
// MAIN UPLOAD CLASS
// ============================================

class BulkUploader {
  constructor(options) {
    this.options = options;
    this.stats = {
      total: 0,
      uploaded: 0,
      skipped: 0,
      failed: 0,
      totalBytes: 0,
    };
    
    // Initialize R2 client
    this.r2Client = new S3Client({
      region: "auto",
      endpoint: `https://${R2_CONFIG.ACCOUNT_ID}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: R2_CONFIG.ACCESS_KEY_ID,
        secretAccessKey: R2_CONFIG.SECRET_ACCESS_KEY,
      },
    });
    
    this.existingFiles = new Set();
  }
  
  /**
   * Get list of existing recordings in R2
   */
  async loadExistingFiles() {
    try {
      console.log("📂 Checking existing files in R2...");
      
      const result = await this.r2Client.send(
        new ListObjectsV2Command({
          Bucket: R2_CONFIG.BUCKET_NAME,
          Prefix: "recordings/",
        })
      );
      
      if (result.Contents) {
        for (const item of result.Contents) {
          const name = item.Key.replace("recordings/", "").replace(".json", "");
          this.existingFiles.add(name);
        }
      }
      
      console.log(`   Found ${this.existingFiles.size} existing recordings\n`);
    } catch (error) {
      console.error("⚠️  Warning: Could not list existing files:", error.message);
    }
  }
  
  /**
   * Upload a single recording file
   */
  async uploadFile(filePath) {
    const fileName = path.basename(filePath, ".json");
    const sanitizedName = sanitizeName(fileName);
    
    try {
      // Read file content
      const content = fs.readFileSync(filePath, "utf-8");
      const data = JSON.parse(content);
      
      // Validate recording
      const validation = validateRecording(data);
      if (!validation.valid) {
        console.log(`   ❌ INVALID: ${fileName} - ${validation.error}`);
        this.stats.failed++;
        return false;
      }
      
      const recordingData = validation.recordingData;
      const recordingName = validation.name || fileName;
      
      // Check if already exists
      if (this.existingFiles.has(sanitizedName) && !this.options.overwrite) {
        if (this.options.verbose) {
          console.log(`   ⏭️  SKIP: ${fileName} (already exists)`);
        }
        this.stats.skipped++;
        return false;
      }
      
      // Calculate metadata
      const frameCount = recordingData.Frames.length;
      const duration = recordingData.Frames[recordingData.Frames.length - 1]?.t || 0;
      const mode = recordingData.Mode || "Standard";
      const timestamp = new Date().toISOString();
      
      // Prepare upload object
      const uploadObject = {
        id: sanitizedName,
        name: recordingName,
        userId: this.options.userId,
        gameId: recordingData.GameId || null,
        gameName: recordingData.GameName || null,
        frameCount: frameCount,
        duration: duration,
        mode: mode,
        createdAt: timestamp,
        updatedAt: timestamp,
        data: recordingData,
      };
      
      const uploadContent = JSON.stringify(uploadObject);
      const contentSize = Buffer.byteLength(uploadContent, "utf-8");
      
      if (this.options.dryRun) {
        console.log(`   📋 WOULD UPLOAD: ${fileName}`);
        console.log(`      → Name: ${recordingName}`);
        console.log(`      → Frames: ${frameCount}, Duration: ${formatDuration(duration)}`);
        console.log(`      → Size: ${formatBytes(contentSize)}`);
        this.stats.uploaded++;
        this.stats.totalBytes += contentSize;
        return true;
      }
      
      // Upload to R2
      const key = `recordings/${sanitizedName}.json`;
      
      await this.r2Client.send(
        new PutObjectCommand({
          Bucket: R2_CONFIG.BUCKET_NAME,
          Key: key,
          Body: uploadContent,
          ContentType: "application/json",
          Metadata: {
            name: recordingName,
            userId: this.options.userId,
            frameCount: frameCount.toString(),
            createdAt: timestamp,
          },
        })
      );
      
      console.log(`   ✅ UPLOADED: ${fileName} (${formatBytes(contentSize)})`);
      if (this.options.verbose) {
        console.log(`      → Frames: ${frameCount}, Duration: ${formatDuration(duration)}, Mode: ${mode}`);
      }
      
      this.stats.uploaded++;
      this.stats.totalBytes += contentSize;
      return true;
      
    } catch (error) {
      console.log(`   ❌ FAILED: ${fileName} - ${error.message}`);
      this.stats.failed++;
      return false;
    }
  }
  
  /**
   * Run the bulk upload process
   */
  async run() {
    console.log("\n╔══════════════════════════════════════════════════════════╗");
    console.log("║        🚀 STARSHIP BULK UPLOAD TO R2 CLOUD 🚀            ║");
    console.log("╚══════════════════════════════════════════════════════════╝\n");
    
    // Check folder exists
    const folderPath = path.resolve(this.options.folder);
    if (!fs.existsSync(folderPath)) {
      console.error(`❌ Error: Folder not found: ${folderPath}`);
      console.log(`\n💡 Create the folder and add your .json recording files, then run again.`);
      process.exit(1);
    }
    
    console.log(`📁 Source folder: ${folderPath}`);
    console.log(`👤 User ID: ${this.options.userId}`);
    console.log(`🔧 Options: ${this.options.dryRun ? "DRY-RUN " : ""}${this.options.overwrite ? "OVERWRITE " : ""}${this.options.verbose ? "VERBOSE" : ""}\n`);
    
    // Get all JSON files
    const files = getJsonFiles(folderPath);
    this.stats.total = files.length;
    
    if (files.length === 0) {
      console.log("⚠️  No .json files found in the folder!");
      console.log(`\n💡 Add your recording .json files to: ${folderPath}`);
      process.exit(0);
    }
    
    console.log(`📊 Found ${files.length} JSON files to process\n`);
    
    // Load existing files (to check for duplicates)
    if (!this.options.overwrite) {
      await this.loadExistingFiles();
    }
    
    // Process each file
    console.log("🔄 Processing files...\n");
    
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const progress = `[${i + 1}/${files.length}]`;
      
      if (this.options.verbose) {
        console.log(`${progress} Processing: ${path.relative(folderPath, file)}`);
      }
      
      await this.uploadFile(file);
    }
    
    // Print summary
    console.log("\n╔══════════════════════════════════════════════════════════╗");
    console.log("║                    📊 UPLOAD SUMMARY                      ║");
    console.log("╚══════════════════════════════════════════════════════════╝");
    console.log(`   Total files found:    ${this.stats.total}`);
    console.log(`   ✅ Uploaded:          ${this.stats.uploaded}`);
    console.log(`   ⏭️  Skipped:           ${this.stats.skipped}`);
    console.log(`   ❌ Failed:            ${this.stats.failed}`);
    console.log(`   📦 Total size:        ${formatBytes(this.stats.totalBytes)}`);
    
    if (this.options.dryRun) {
      console.log("\n⚠️  DRY-RUN MODE: No files were actually uploaded!");
      console.log("   Remove --dry-run flag to perform actual upload.");
    }
    
    console.log("\n✨ Done!\n");
  }
}

// ============================================
// RUN SCRIPT
// ============================================

async function main() {
  const args = process.argv.slice(2);
  
  // Show help
  if (args.includes("--help") || args.includes("-h")) {
    console.log(`
╔══════════════════════════════════════════════════════════╗
║        🚀 STARSHIP BULK UPLOAD TO R2 CLOUD 🚀            ║
╚══════════════════════════════════════════════════════════╝

USAGE:
  node bulk-upload-r2.js [folder_path] [options]

EXAMPLES:
  node bulk-upload-r2.js                          # Upload from './recordings-to-upload'
  node bulk-upload-r2.js ./my-recordings          # Upload from custom folder
  node bulk-upload-r2.js ./recordings --dry-run   # Preview only, no upload
  node bulk-upload-r2.js ./recordings --overwrite # Overwrite existing files

OPTIONS:
  --dry-run     Preview files without uploading
  --overwrite   Overwrite if file already exists in cloud
  --verbose     Show detailed logs
  --user=ID     Set userId for all recordings (default: 'bulk-upload')
  --help, -h    Show this help message

FILE FORMAT:
  Files must be JSON with structure:
  {
    "FPS": 60,
    "Mode": "Flexible",
    "Frames": [...]
  }
`);
    process.exit(0);
  }
  
  const options = parseArgs(args);
  const uploader = new BulkUploader(options);
  await uploader.run();
}

main().catch(console.error);
