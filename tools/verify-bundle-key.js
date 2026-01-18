/**
 * Verify Bundle Key Consistency
 * Checks if the bundle was generated with the key stored in bundle-key.txt
 * and helps diagnose decryption issues
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function xorDecrypt(base64Data, key) {
    try {
        const data = Buffer.from(base64Data, 'base64').toString('binary');
        let result = '';
        for (let i = 0; i < data.length; i++) {
            result += String.fromCharCode(data.charCodeAt(i) ^ key.charCodeAt(i % key.length));
        }
        return result;
    } catch (e) {
        return null;
    }
}

async function verifyBundle() {
    console.log("🔍 Bundle Key Verification Tool\n");
    console.log("═".repeat(60));

    const rootDir = path.join(__dirname, "..");
    const bundleFile = path.join(rootDir, "public", "b", "pc.json");
    const keyFile = path.join(rootDir, "cdn-bundle", "bundle-key.txt");

    // Check if bundle exists
    if (!fs.existsSync(bundleFile)) {
        console.log("❌ Bundle file not found:", bundleFile);
        console.log("\n👉 Run: node tools/generate-bundle.js");
        return;
    }

    // Check if key file exists
    if (!fs.existsSync(keyFile)) {
        console.log("❌ Key file not found:", keyFile);
        console.log("\n👉 Run: node tools/generate-bundle.js");
        return;
    }

    // Load bundle
    const bundleContent = fs.readFileSync(bundleFile, 'utf8');
    const bundle = JSON.parse(bundleContent);

    console.log("📦 Bundle Info:");
    console.log(`   Version: ${bundle.v}`);
    console.log(`   Generated: ${new Date(bundle.t).toLocaleString()}`);
    console.log(`   Modules: ${Object.keys(bundle.m || {}).length}`);
    console.log(`   Tabs: ${Object.keys(bundle.tabs || {}).length}`);

    // Load key
    const keyContent = fs.readFileSync(keyFile, 'utf8');
    const keyMatch = keyContent.match(/BUNDLE_KEY=([a-f0-9]+)/i);

    if (!keyMatch) {
        console.log("❌ Could not parse BUNDLE_KEY from key file");
        return;
    }

    const bundleKey = keyMatch[1];
    console.log("\n🔑 Bundle Key from file:");
    console.log(`   Key: ${bundleKey.substring(0, 8)}...${bundleKey.substring(bundleKey.length - 8)}`);
    console.log(`   Length: ${bundleKey.length} characters`);

    // Build decryption key (same as Lua: 'S' + key + 'X')
    const encKey = "S" + bundleKey + "X";

    // Try to decrypt first module
    console.log("\n🧪 Testing Decryption:");
    const firstModuleKey = "m1";
    if (bundle.m && bundle.m[firstModuleKey]) {
        const encrypted = bundle.m[firstModuleKey];
        const decrypted = xorDecrypt(encrypted, encKey);

        if (decrypted && decrypted.startsWith("--") || decrypted && decrypted.includes("return")) {
            console.log("   ✅ Module 1 decryption SUCCESS!");
            console.log(`   First 100 chars: ${decrypted.substring(0, 100).replace(/\n/g, '\\n')}...`);
        } else if (decrypted) {
            console.log("   ⚠️ Decrypted but content looks wrong");
            console.log(`   First 50 chars: ${decrypted.substring(0, 50).replace(/\n/g, '\\n').replace(/[^\x20-\x7E]/g, '?')}...`);
            console.log("\n   🔍 This usually means the BUNDLE_KEY doesn't match!");
        } else {
            console.log("   ❌ Decryption failed");
        }
    } else {
        console.log("   ⚠️ No module 'm1' found in bundle");
    }

    console.log("\n" + "═".repeat(60));
    console.log("📋 INSTRUCTIONS:");
    console.log("═".repeat(60));
    console.log("\n1. Make sure this key is set in Vercel Environment Variables:");
    console.log(`\n   BUNDLE_KEY = ${bundleKey}`);
    console.log("\n2. If the key was recently changed, redeploy on Vercel");
    console.log("\n3. If decryption still fails, regenerate the bundle:");
    console.log("   node tools/generate-bundle.js");
    console.log("\n4. Then copy the new key to Vercel and redeploy");
    console.log("\n" + "═".repeat(60));
}

verifyBundle().catch(console.error);
