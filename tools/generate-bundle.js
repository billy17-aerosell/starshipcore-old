/**
 * Generate Pre-bundled Module File for CDN (v2 - Server-side Key)
 * Bundle contains encrypted content WITHOUT the key
 * Key is stored separately and sent via auth API
 */

import fs from 'fs';
import path from 'path';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const MODULES = [
    "Config.lua", "UI.lua", "Intro.lua", "Animations.lua",
    "Locale.lua", "CloudRecording.lua", "UIComponents.lua",
    "ConnectionManager.lua", "Changelog.lua"
];

const TABS = [
    "Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua",
    "Fun.lua", "Emotes.lua", "ConfigTab.lua"
];

function xorEncrypt(text, key) {
    let result = "";
    for (let i = 0; i < text.length; i++) {
        result += String.fromCharCode(text.charCodeAt(i) ^ key.charCodeAt(i % key.length));
    }
    return Buffer.from(result, "binary").toString("base64");
}

function generateBundleKey() {
    // Strong random key
    return crypto.randomBytes(16).toString('hex');
}

async function generateBundle() {
    console.log("🚀 Generating PC Module Bundle (Server-side Key)...\n");

    const rootDir = path.join(__dirname, "..");
    const modulesDir = path.join(rootDir, "data", "Modules");
    const tabsDir = path.join(modulesDir, "Tabs");
    const outputDir = path.join(rootDir, "cdn-bundle");
    const publicDir = path.join(rootDir, "public", "b");

    // Create directories
    if (!fs.existsSync(outputDir)) fs.mkdirSync(outputDir, { recursive: true });
    if (!fs.existsSync(publicDir)) fs.mkdirSync(publicDir, { recursive: true });

    // ══════════════════════════════════════════════════════════════════
    // REUSE EXISTING KEY - No need to update Vercel every time!
    // Priority: 1. ENV var  2. Existing file  3. Generate new
    // ══════════════════════════════════════════════════════════════════
    const keyFile = path.join(outputDir, "bundle-key.txt");
    let bundleKey = null;
    let keySource = "";

    // Priority 1: Check environment variable
    if (process.env.BUNDLE_KEY && process.env.BUNDLE_KEY.length === 32) {
        bundleKey = process.env.BUNDLE_KEY;
        keySource = "environment variable";
    }
    // Priority 2: Check existing key file
    else if (fs.existsSync(keyFile)) {
        const keyContent = fs.readFileSync(keyFile, "utf8");
        const match = keyContent.match(/BUNDLE_KEY=([a-f0-9]{32})/i);
        if (match) {
            bundleKey = match[1];
            keySource = "existing bundle-key.txt";
        }
    }
    // Priority 3: Generate new key (first time only)
    if (!bundleKey) {
        bundleKey = generateBundleKey();
        keySource = "newly generated (SET THIS IN VERCEL!)";
    }

    const encKey = "S" + bundleKey + "X";

    console.log(`🔐 Bundle Key: ${bundleKey}`);
    console.log(`   Source: ${keySource}\n`);

    const bundleData = {
        v: 3,  // Version 3 = Server-side key
        t: Date.now(),
        // NO KEY in bundle! Key is server-side only
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

            bundleData.m["m" + (i + 1)] = xorEncrypt(content, encKey);
            totalSize += content.length;
            moduleCount++;
            console.log(`   ✅ ${moduleName} (${(content.length / 1024).toFixed(1)} KB)`);
        } else {
            console.log(`   ❌ ${moduleName} - NOT FOUND!`);
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

            bundleData.tabs["t" + (i + 1)] = xorEncrypt(content, encKey);
            totalSize += content.length;
            tabCount++;
            console.log(`   ✅ ${tabName} (${(content.length / 1024).toFixed(1)} KB)`);
        } else {
            console.log(`   ❌ ${tabName} - NOT FOUND!`);
        }
    }

    // Write bundle file (NO KEY!)
    const bundleJson = JSON.stringify(bundleData);
    const bundleFile = path.join(publicDir, "pc.json");
    fs.writeFileSync(bundleFile, bundleJson);

    // Save key to separate file (for backup/reference)
    // keyFile already declared above, just reuse it
    fs.writeFileSync(keyFile, `BUNDLE_KEY=${bundleKey}\n\nThis key should match your Vercel Environment Variable.`);

    console.log("\n" + "═".repeat(50));
    console.log("📊 Bundle Statistics:");
    console.log(`   Modules: ${moduleCount}/${MODULES.length}`);
    console.log(`   Tabs: ${tabCount}/${TABS.length}`);
    console.log(`   Total Source Size: ${(totalSize / 1024).toFixed(1)} KB`);
    console.log(`   Bundle Size: ${(bundleJson.length / 1024).toFixed(1)} KB`);
    console.log("═".repeat(50));

    console.log("\n✅ Bundle generated successfully!");
    console.log(`📁 Bundle: ${bundleFile}`);
    console.log(`🔑 Key: ${keyFile}`);

    // Only show warning if key was newly generated
    if (keySource.includes("newly generated")) {
        console.log("\n" + "⚠️".repeat(25));
        console.log("⚠️  FIRST TIME SETUP: Add this to Vercel Environment Variables:");
        console.log(`    BUNDLE_KEY = ${bundleKey}`);
        console.log("⚠️".repeat(25));
    } else {
        console.log("\n✅ Using existing BUNDLE_KEY - No Vercel update needed!");
    }
}

generateBundle().catch(console.error);
