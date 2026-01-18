/**
 * Generate Pre-bundled Module File for CDN
 * This script bundles all PC modules into a single encrypted file
 * Run this after updating any module, then upload to Cloudflare R2
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Module lists (must match Loader.lua)
const MODULES = [
    "Config.lua",
    "UI.lua",
    "Intro.lua",
    "Animations.lua",
    "Locale.lua",
    "CloudRecording.lua",
    "UIComponents.lua",
    "ConnectionManager.lua",
    "Changelog.lua"
];

const TABS = [
    "Dashboard.lua",
    "Tools.lua",
    "Warp.lua",
    "Helper.lua",
    "Fun.lua",
    "Emotes.lua",
    "ConfigTab.lua"
];

// XOR encrypt function (same as server)
function xorEncrypt(text, key) {
    let result = "";
    for (let i = 0; i < text.length; i++) {
        result += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return Buffer.from(result, "binary").toString("base64");
}

// Generate random bundle key
function generateBundleKey() {
    const timestamp = Date.now().toString(36);
    const random = crypto.randomBytes(4).toString('hex');
    return timestamp + random;
}

async function generateBundle() {
    console.log("🚀 Generating PC Module Bundle...\n");

    // Path to project root (one level up from tools/)
    const rootDir = path.join(__dirname, "..");
    const modulesDir = path.join(rootDir, "data", "Modules");
    const tabsDir = path.join(modulesDir, "Tabs");
    const outputDir = path.join(rootDir, "cdn-bundle");

    console.log("📂 Modules Dir:", modulesDir);

    // Create output directory
    if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
    }

    // Generate encryption key
    const bundleKey = generateBundleKey();
    const encKey = "S" + bundleKey + "X";

    console.log(`📦 Bundle Key: ${bundleKey}`);
    console.log(`🔐 Encryption Key: ${encKey}\n`);

    const bundleData = {
        v: 2,
        t: Date.now(),
        k: bundleKey,
        m: {},
        tabs: {}
    };

    let totalSize = 0;
    let moduleCount = 0;
    let tabCount = 0;

    // Bundle modules
    console.log("📁 Bundling Modules:");
    for (let i = 0; i < MODULES.length; i++) {
        const moduleName = MODULES[i];
        const filePath = path.join(modulesDir, moduleName);

        if (fs.existsSync(filePath)) {
            let content = fs.readFileSync(filePath, "utf8");
            if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);

            const encrypted = xorEncrypt(content, encKey);
            bundleData.m["m" + (i + 1)] = encrypted;

            totalSize += content.length;
            moduleCount++;
            console.log(`   ✅ ${moduleName} (${(content.length / 1024).toFixed(1)} KB)`);
        } else {
            console.log(`   ❌ ${moduleName} - NOT FOUND at ${filePath}`);
        }
    }

    // Bundle tabs
    console.log("\n📁 Bundling Tabs:");
    for (let i = 0; i < TABS.length; i++) {
        const tabName = TABS[i];
        const filePath = path.join(tabsDir, tabName);

        if (fs.existsSync(filePath)) {
            let content = fs.readFileSync(filePath, "utf8");
            if (content.charCodeAt(0) === 0xFEFF) content = content.slice(1);

            const encrypted = xorEncrypt(content, encKey);
            bundleData.tabs["t" + (i + 1)] = encrypted;

            totalSize += content.length;
            tabCount++;
            console.log(`   ✅ ${tabName} (${(content.length / 1024).toFixed(1)} KB)`);
        } else {
            console.log(`   ❌ ${tabName} - NOT FOUND at ${filePath}`);
        }
    }

    // Write bundle file
    const bundleJson = JSON.stringify(bundleData);
    const bundleFile = path.join(outputDir, "pc-bundle.json");
    fs.writeFileSync(bundleFile, bundleJson);

    console.log("\n" + "═".repeat(50));
    console.log("📊 Bundle Statistics:");
    console.log(`   Modules: ${moduleCount}/${MODULES.length}`);
    console.log(`   Tabs: ${tabCount}/${TABS.length}`);
    console.log(`   Total Source Size: ${(totalSize / 1024).toFixed(1)} KB`);
    console.log(`   Bundle Size: ${(bundleJson.length / 1024).toFixed(1)} KB`);
    console.log("═".repeat(50));

    console.log("\n✅ Bundle generated successfully!");
    console.log(`📁 Output: ${bundleFile}`);

    console.log("\n📤 Next Steps:");
    console.log("1. Upload pc-bundle.json to Cloudflare R2 bucket");
    console.log("2. Configure CDN Worker to serve this bundle");
}

generateBundle().catch(console.error);
