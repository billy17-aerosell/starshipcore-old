/**
 * ══════════════════════════════════════════════════════════════════
 * WATERMARK DECODER TOOL
 * Decode watermarks from leaked scripts to identify leakers
 * ══════════════════════════════════════════════════════════════════
 * 
 * Supports 2 formats:
 *   1. Mobile Loader watermark: userId_timestamp_hwid (XOR 42 hex)
 *   2. Module watermark (from get-module.js): JSON {u,t,i} (XOR 42 hex)
 * 
 * Usage:
 *   node decode-watermark.js <encoded_watermark>
 *   node decode-watermark.js --scan <leaked_file.lua>
 */

function xorDecodeHex(encodedHex) {
    encodedHex = encodedHex.replace(/\s/g, '');
    let decoded = '';
    for (let i = 0; i < encodedHex.length; i += 2) {
        const hexByte = encodedHex.substring(i, i + 2);
        const charCode = parseInt(hexByte, 16) ^ 42;
        decoded += String.fromCharCode(charCode);
    }
    return decoded;
}

function decodeModuleWatermark(encodedHex) {
    const decoded = xorDecodeHex(encodedHex);
    try {
        const data = JSON.parse(decoded);
        return {
            type: "MODULE",
            raw: decoded,
            userId: data.u || "Unknown",
            timestamp: data.t || "Unknown",
            partialIP: data.i || "Unknown",
            timestampDate: data.t ? new Date(data.t).toISOString() : null,
            robloxProfileUrl: data.u && !isNaN(data.u) ? `https://www.roblox.com/users/${data.u}/profile` : null,
        };
    } catch (e) {
        return null;
    }
}

function decodeLoaderWatermark(encodedHex) {
    const decoded = xorDecodeHex(encodedHex);
    const parts = decoded.split('_');
    if (parts.length < 2) return null;
    return {
        type: "LOADER",
        raw: decoded,
        userId: parts[0] || 'Unknown',
        timestamp: parts[1] || 'Unknown',
        hwid: parts[2] || 'Unknown',
        timestampDate: parts[1] && !isNaN(parseInt(parts[1])) ? new Date(parseInt(parts[1]) * 1000).toISOString() : null,
        robloxProfileUrl: parts[0] && !isNaN(parseInt(parts[0])) ? `https://www.roblox.com/users/${parts[0]}/profile` : null,
    };
}

function decodeWatermark(encodedHex) {
    let result = decodeModuleWatermark(encodedHex);
    if (result) return result;
    result = decodeLoaderWatermark(encodedHex);
    return result;
}

function scanFile(filePath) {
    const fs = require('fs');
    if (!fs.existsSync(filePath)) {
        console.error(`File not found: ${filePath}`);
        return [];
    }
    const content = fs.readFileSync(filePath, 'utf8');
    const results = [];

    // Pattern: local _cXXXX="hex_encoded_data"
    const modulePattern = /local\s+_c[0-9a-f]{4}\s*=\s*"([0-9a-f]+)"/gi;
    let match;
    while ((match = modulePattern.exec(content)) !== null) {
        const decoded = decodeModuleWatermark(match[1]);
        if (decoded) {
            decoded.location = `Module watermark variable`;
            results.push(decoded);
        }
    }

    // Pattern: long hex strings in _SWM, _wm, _mcfg etc
    const loaderPattern = /"([0-9a-f]{20,})"/gi;
    while ((match = loaderPattern.exec(content)) !== null) {
        if (results.some(r => r.raw && content.includes(r.raw))) continue;
        const decoded = decodeLoaderWatermark(match[1]);
        if (decoded && decoded.userId !== 'Unknown') {
            decoded.location = `Loader watermark`;
            results.push(decoded);
        }
    }

    return results;
}

function printResult(result) {
    const typeLabel = result.type === "MODULE" ? "MODULE WATERMARK" : "LOADER WATERMARK";
    console.log(`\n╔════════════════════════════════════════════════════════════╗`);
    console.log(`║  ${typeLabel.padEnd(55)}║`);
    console.log(`╠════════════════════════════════════════════════════════════╣`);
    console.log(`║ User ID:          ${String(result.userId).padEnd(40)}║`);
    if (result.partialIP) {
        console.log(`║ Partial IP:       ${String(result.partialIP).padEnd(40)}║`);
    }
    if (result.hwid && result.hwid !== 'Unknown') {
        console.log(`║ HWID (partial):   ${String(result.hwid).padEnd(40)}║`);
    }
    console.log(`║ Date:             ${(result.timestampDate || 'N/A').padEnd(40)}║`);
    console.log(`╠════════════════════════════════════════════════════════════╣`);
    console.log(`║ Roblox Profile:   ${(result.robloxProfileUrl || 'N/A').padEnd(40)}║`);
    if (result.location) {
        console.log(`║ Found in:         ${result.location.padEnd(40)}║`);
    }
    console.log(`╚════════════════════════════════════════════════════════════╝`);
}

// CLI
const args = process.argv.slice(2);

if (args.length === 0) {
    console.log(`
╔════════════════════════════════════════════════════════════╗
║            STARSHIP WATERMARK DECODER                      ║
╠════════════════════════════════════════════════════════════╣
║ Decode a watermark:                                        ║
║   node decode-watermark.js <hex_encoded_watermark>         ║
║                                                            ║
║ Scan a leaked file:                                        ║
║   node decode-watermark.js --scan leaked_script.lua        ║
║                                                            ║
║ How to find watermark in leaked script:                    ║
║   1. Look for: local _cXXXX = "hex..."  (module wm)       ║
║   2. Search for _SWM or _wm  (loader wm)                  ║
║   3. Or just use --scan to auto-detect                     ║
╚════════════════════════════════════════════════════════════╝
    `);
    process.exit(0);
}

if (args[0] === '--scan' && args[1]) {
    console.log(`\nScanning: ${args[1]}...\n`);
    const results = scanFile(args[1]);
    if (results.length === 0) {
        console.log('No watermarks found in file.');
    } else {
        console.log(`Found ${results.length} watermark(s):`);
        results.forEach(r => printResult(r));
        console.log('\nJSON Output:');
        console.log(JSON.stringify(results, null, 2));
    }
} else {
    const result = decodeWatermark(args[0]);
    if (result) {
        printResult(result);
        console.log('\nJSON Output:');
        console.log(JSON.stringify(result, null, 2));
    } else {
        console.error('Failed to decode watermark. Check the input format.');
    }
}
