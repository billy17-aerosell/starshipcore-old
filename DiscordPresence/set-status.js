/**
 * StarshipCore Status Manager CLI
 * 
 * Usage:
 *   node set-status.js <status> [message]
 * 
 * Status options:
 *   - online      : System is operational
 *   - maintenance : System under maintenance
 *   - offline     : System is offline
 *   - degraded    : Some features unavailable
 *   - updating    : New update being deployed
 * 
 * Examples:
 *   node set-status.js online
 *   node set-status.js maintenance "Scheduled maintenance until 10:00 AM"
 *   node set-status.js updating "Deploying v2.5.0"
 */

const https = require('https');
const fs = require('fs');
const path = require('path');

// Load config
const configPath = path.join(__dirname, 'config.json');
let config = {};

if (fs.existsSync(configPath)) {
    config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
}

// Parse arguments
const args = process.argv.slice(2);
const status = args[0];
const message = args.slice(1).join(' ') || null;

// Valid statuses
const VALID_STATUSES = ['online', 'maintenance', 'offline', 'degraded', 'updating'];

// Status display info
const STATUS_INFO = {
    online: { emoji: '🟢', label: 'Online' },
    maintenance: { emoji: '🟠', label: 'Maintenance' },
    offline: { emoji: '🔴', label: 'Offline' },
    degraded: { emoji: '🟡', label: 'Degraded' },
    updating: { emoji: '🔵', label: 'Updating' }
};

function printUsage() {
    console.log(`
╔═══════════════════════════════════════════════════════════╗
║            StarshipCore Status Manager                    ║
╚═══════════════════════════════════════════════════════════╝

Usage: node set-status.js <status> [message]

Available statuses:
  🟢 online       All systems operational
  🟠 maintenance  System under maintenance
  🔴 offline      System is offline
  🟡 degraded     Some features unavailable
  🔵 updating     New update being deployed

Examples:
  node set-status.js online
  node set-status.js maintenance "Scheduled maintenance"
  node set-status.js updating "Deploying v2.5.0"
    `);
}

async function setStatus(status, message) {
    // Use /api/tags endpoint with action: set_status
    const apiUrl = config.apiUrl || 'https://starship-core.my.id/api/tags';
    const adminSecret = config.adminSecret || process.env.ADMIN_SECRET;
    
    if (!adminSecret) {
        console.error('❌ Error: ADMIN_SECRET not found in config or environment');
        console.log('   Create config.json with adminSecret or set ADMIN_SECRET env var');
        process.exit(1);
    }
    
    const postData = JSON.stringify({ 
        action: 'set_status',
        status, 
        message 
    });
    
    const url = new URL(apiUrl);
    
    const options = {
        hostname: url.hostname,
        port: url.port || 443,
        path: url.pathname,
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(postData),
            'x-admin-secret': adminSecret
        }
    };
    
    return new Promise((resolve, reject) => {
        console.log(`\n⏳ Setting status to ${STATUS_INFO[status].emoji} ${status}...`);
        if (message) console.log(`   Message: "${message}"`);
        
        const req = https.request(options, (res) => {
            let data = '';
            
            res.on('data', (chunk) => {
                data += chunk;
            });
            
            res.on('end', () => {
                try {
                    const result = JSON.parse(data);
                    
                    if (result.success) {
                        console.log(`\n✅ Status updated successfully!`);
                        console.log(`   Status: ${result.emoji} ${result.label}`);
                        console.log(`   Message: ${result.message}`);
                        console.log(`   Discord: ${result.discordUpdated ? '✅ Updated' : '❌ Not configured'}`);
                        console.log(`   Updated: ${new Date(result.lastUpdated).toLocaleString()}\n`);
                        resolve(result);
                    } else {
                        console.error(`\n❌ Error: ${result.error}`);
                        reject(new Error(result.error));
                    }
                } catch (e) {
                    console.error(`\n❌ Error parsing response:`, data);
                    reject(e);
                }
            });
        });
        
        req.on('error', (e) => {
            console.error(`\n❌ Request error: ${e.message}`);
            reject(e);
        });
        
        req.write(postData);
        req.end();
    });
}

// Main
if (!status || !VALID_STATUSES.includes(status)) {
    printUsage();
    if (status) {
        console.error(`❌ Invalid status: "${status}"`);
        console.log(`   Valid options: ${VALID_STATUSES.join(', ')}\n`);
    }
    process.exit(status ? 1 : 0);
}

setStatus(status, message)
    .then(() => process.exit(0))
    .catch(() => process.exit(1));

