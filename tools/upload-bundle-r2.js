/**
 * Upload PC Bundle to Cloudflare R2
 * This uploads the pc.json bundle file to the CDN
 */

import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// R2 Configuration - PC Modules bucket
const R2_CONFIG = {
    ACCOUNT_ID: process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6",
    ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf",
    SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY || "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660",
    BUCKET_NAME: process.env.R2_BUNDLE_BUCKET || "starship-pc-modules", // Bundle bucket
};

async function uploadBundle() {
    console.log("🚀 Uploading PC Bundle to Cloudflare R2...\n");

    const bundlePath = path.join(__dirname, "..", "public", "b", "pc.json");
    const keyPath = path.join(__dirname, "..", "cdn-bundle", "bundle-key.txt");

    // Check files exist
    if (!fs.existsSync(bundlePath)) {
        console.error("❌ Bundle file not found:", bundlePath);
        console.log("👉 Run: node tools/generate-bundle.js first");
        process.exit(1);
    }

    // Read bundle
    const bundleContent = fs.readFileSync(bundlePath, "utf8");
    const bundleSize = Buffer.byteLength(bundleContent, "utf8");

    console.log(`📦 Bundle file: ${bundlePath}`);
    console.log(`📊 Size: ${(bundleSize / 1024).toFixed(1)} KB`);

    // Read key for reference
    if (fs.existsSync(keyPath)) {
        const keyContent = fs.readFileSync(keyPath, "utf8");
        const keyMatch = keyContent.match(/BUNDLE_KEY=([a-f0-9]+)/i);
        if (keyMatch) {
            console.log(`🔑 Bundle Key: ${keyMatch[1].substring(0, 8)}...${keyMatch[1].substring(keyMatch[1].length - 8)}`);
        }
    }

    // Initialize R2 client
    const r2Client = new S3Client({
        region: "auto",
        endpoint: `https://${R2_CONFIG.ACCOUNT_ID}.r2.cloudflarestorage.com`,
        credentials: {
            accessKeyId: R2_CONFIG.ACCESS_KEY_ID,
            secretAccessKey: R2_CONFIG.SECRET_ACCESS_KEY,
        },
    });

    try {
        // Upload to R2
        console.log(`\n📤 Uploading to bucket: ${R2_CONFIG.BUCKET_NAME}`);
        console.log(`   Path: b/pc.json`);

        await r2Client.send(
            new PutObjectCommand({
                Bucket: R2_CONFIG.BUCKET_NAME,
                Key: "b/pc.json",
                Body: bundleContent,
                ContentType: "application/json",
                CacheControl: "no-cache, no-store, must-revalidate", // Don't cache, always get fresh
            })
        );

        console.log("\n✅ Bundle uploaded successfully to R2 CDN!");
        console.log("\n⚠️  IMPORTANT: Make sure Vercel BUNDLE_KEY matches the key shown above");

    } catch (error) {
        console.error("\n❌ Upload failed:", error.message);
        process.exit(1);
    }
}

uploadBundle().catch(console.error);
