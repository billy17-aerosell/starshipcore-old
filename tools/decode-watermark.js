/**
 * ══════════════════════════════════════════════════════════════════
 * WATERMARK DECODER TOOL
 * Use this to decode watermarks from leaked scripts to identify leakers
 * ══════════════════════════════════════════════════════════════════
 * 
 * Usage:
 *   node decode-watermark.js <encoded_watermark>
 * 
 * Example:
 *   node decode-watermark.js "1b1017130c5f0d1a5f..."
 * 
 * The watermark signature format is:
 *   userId_timestamp_hwid8chars
 *   Each character XOR'd with 42, then hex encoded
 */

function decodeWatermark(encodedHex) {
    if (!encodedHex || encodedHex.length === 0) {
        console.error("Error: No watermark provided");
        return null;
    }

    // Remove any whitespace
    encodedHex = encodedHex.replace(/\s/g, '');

    // Decode: hex -> XOR with 42
    let decoded = '';
    for (let i = 0; i < encodedHex.length; i += 2) {
        const hexByte = encodedHex.substring(i, i + 2);
        const charCode = parseInt(hexByte, 16) ^ 42;
        decoded += String.fromCharCode(charCode);
    }

    // Parse the signature: userId_timestamp_hwid
    const parts = decoded.split('_');
    
    const result = {
        raw: decoded,
        userId: parts[0] || 'Unknown',
        timestamp: parts[1] || 'Unknown',
        hwid: parts[2] || 'Unknown',
        timestampDate: null,
        robloxProfileUrl: null
    };

    // Convert timestamp to human-readable date
    if (parts[1] && !isNaN(parseInt(parts[1]))) {
        const timestamp = parseInt(parts[1]);
        result.timestampDate = new Date(timestamp * 1000).toISOString();
    }

    // Generate Roblox profile URL
    if (parts[0] && !isNaN(parseInt(parts[0]))) {
        result.robloxProfileUrl = `https://www.roblox.com/users/${parts[0]}/profile`;
    }

    return result;
}

function printResult(result) {
    console.log('\n╔════════════════════════════════════════════════════════════╗');
    console.log('║                   WATERMARK DECODED                        ║');
    console.log('╠════════════════════════════════════════════════════════════╣');
    console.log(`║ Raw Signature:    ${result.raw.padEnd(40)}║`);
    console.log(`║ User ID:          ${result.userId.padEnd(40)}║`);
    console.log(`║ HWID (partial):   ${result.hwid.padEnd(40)}║`);
    console.log(`║ Timestamp:        ${result.timestamp.padEnd(40)}║`);
    console.log(`║ Date:             ${(result.timestampDate || 'N/A').padEnd(40)}║`);
    console.log('╠════════════════════════════════════════════════════════════╣');
    console.log(`║ Roblox Profile:   ${(result.robloxProfileUrl || 'N/A').padEnd(40)}║`);
    console.log('╚════════════════════════════════════════════════════════════╝\n');
}

// CLI Usage
const args = process.argv.slice(2);

if (args.length === 0) {
    console.log(`
╔════════════════════════════════════════════════════════════╗
║            STARSHIP WATERMARK DECODER                      ║
╠════════════════════════════════════════════════════════════╣
║ Usage:                                                     ║
║   node decode-watermark.js <encoded_watermark>             ║
║                                                            ║
║ How to find watermark in leaked script:                    ║
║   1. Search for _wm or _SWM in the script                  ║
║   2. Look for hex strings (e.g., "1b1017130c...")          ║
║   3. Check StarshipSession._wm value                       ║
║   4. Look for _cfg or _mcfg values in ReplicatedStorage    ║
║                                                            ║
║ Example:                                                   ║
║   node decode-watermark.js "1b1017130c5f0d1a5f4d4f42494c45"║
╚════════════════════════════════════════════════════════════╝
    `);
    process.exit(0);
}

const encoded = args[0];
const result = decodeWatermark(encoded);

if (result) {
    printResult(result);
    
    // Also output as JSON for programmatic use
    console.log('JSON Output:');
    console.log(JSON.stringify(result, null, 2));
}
