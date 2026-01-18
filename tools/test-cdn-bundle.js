/**
 * Test decrypt bundle from CDN
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

const TABS = ["Dashboard.lua", "Tools.lua", "Warp.lua", "Helper.lua", "Fun.lua", "Emotes.lua", "ConfigTab.lua"];

async function testCDNBundle() {
    console.log("🔍 Testing CDN Bundle Decryption\n");

    // Use the bundle downloaded from CDN
    const bundlePath = path.join(__dirname, "..", "temp-cdn-bundle.json");
    const keyPath = path.join(__dirname, "..", "cdn-bundle", "bundle-key.txt");

    if (!fs.existsSync(bundlePath)) {
        console.log("❌ temp-cdn-bundle.json not found");
        console.log("   Run: npx wrangler r2 object get starship-pc-modules/b/pc.json --file=temp-cdn-bundle.json --remote");
        return;
    }

    const bundle = JSON.parse(fs.readFileSync(bundlePath, 'utf8'));
    const keyContent = fs.readFileSync(keyPath, 'utf8');
    const keyMatch = keyContent.match(/BUNDLE_KEY=([a-f0-9]+)/i);
    const bundleKey = keyMatch[1];

    console.log(`📦 Bundle timestamp: ${bundle.t}`);
    console.log(`📦 Bundle version: ${bundle.v}`);
    console.log(`🔑 Using key: ${bundleKey.substring(0, 8)}...${bundleKey.substring(bundleKey.length - 8)}`);

    const encKey = "S" + bundleKey + "X";

    console.log("\n🧪 Testing Tab Decryption:");
    for (let i = 0; i < TABS.length; i++) {
        const tabKey = "t" + (i + 1);
        if (bundle.tabs && bundle.tabs[tabKey]) {
            const decrypted = xorDecrypt(bundle.tabs[tabKey], encKey);
            if (decrypted && (decrypted.startsWith("--") || decrypted.includes("return"))) {
                console.log(`   ✅ Tab ${i + 1} (${TABS[i]}): OK - starts with: ${decrypted.substring(0, 50).replace(/\n/g, '\\n')}...`);
            } else {
                console.log(`   ❌ Tab ${i + 1} (${TABS[i]}): FAILED`);
                if (decrypted) {
                    console.log(`      First 50 chars: ${decrypted.substring(0, 50).replace(/[^\x20-\x7E]/g, '?')}`);
                }
            }
        } else {
            console.log(`   ⚠️ Tab ${i + 1} (${TABS[i]}): NOT FOUND in bundle`);
        }
    }
}

testCDNBundle().catch(console.error);
