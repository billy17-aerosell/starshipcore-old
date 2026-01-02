/**
 * Discord Rich Presence - Always Running
 * Berjalan di background tanpa perlu VS Code
 */

const RPC = require('discord-rpc');
const config = require('./config.json');

// Validasi config
if (config.clientId === 'PASTE_YOUR_APPLICATION_ID_HERE') {
    console.error('❌ ERROR: Silakan paste Application ID Anda di config.json!');
    console.log('\n📝 Cara mendapatkan Application ID:');
    console.log('1. Buka https://discord.com/developers/applications');
    console.log('2. Klik "New Application" dan beri nama');
    console.log('3. Copy Application ID');
    console.log('4. Paste di config.json pada field "clientId"');
    process.exit(1);
}

const clientId = config.clientId;
RPC.register(clientId);

const rpc = new RPC.Client({ transport: 'ipc' });
const startTimestamp = new Date();

// Set activity ke Discord
async function setActivity() {
    if (!rpc) return;

    const activity = {
        details: config.details || 'Online',
        state: config.state || '',
        startTimestamp: startTimestamp,
        largeImageKey: config.largeImageKey || 'logo',
        largeImageText: config.largeImageText || '',
        instance: false
    };

    // Tambahkan small image jika ada
    if (config.smallImageKey) {
        activity.smallImageKey = config.smallImageKey;
        activity.smallImageText = config.smallImageText || '';
    }

    // Tambahkan buttons jika ada (maksimal 2)
    if (config.buttons && config.buttons.length > 0) {
        activity.buttons = config.buttons.slice(0, 2);
    }

    try {
        await rpc.setActivity(activity);
    } catch (error) {
        // Silent error untuk background mode
    }
}

// Event ketika terhubung ke Discord
rpc.on('ready', () => {
    console.log('✅ Discord Presence Connected!');
    console.log(`👤 User: ${rpc.user.username}`);
    console.log('🔄 Running in background...');
    console.log('⏹️  Close this window to stop\n');

    setActivity();
    // Update setiap 15 detik
    setInterval(setActivity, 15000);
});

// Reconnect logic
let reconnectAttempts = 0;
const maxReconnectAttempts = 10;

async function reconnect() {
    if (reconnectAttempts >= maxReconnectAttempts) {
        console.log('❌ Max reconnect attempts reached. Exiting...');
        process.exit(1);
    }
    
    reconnectAttempts++;
    console.log(`🔄 Reconnecting... (${reconnectAttempts}/${maxReconnectAttempts})`);
    
    try {
        await rpc.login({ clientId });
        reconnectAttempts = 0; // Reset on success
    } catch (error) {
        setTimeout(reconnect, 10000);
    }
}

rpc.on('disconnected', () => {
    console.log('⚠️ Disconnected. Reconnecting...');
    reconnect();
});

// Login
console.log('🔌 Connecting to Discord...\n');

rpc.login({ clientId }).catch((error) => {
    console.error('❌ Failed to connect:', error.message);
    console.log('💡 Pastikan Discord sudah terbuka!');
    console.log('🔄 Retry in 10 seconds...');
    setTimeout(reconnect, 10000);
});

// Handle shutdown
process.on('SIGINT', () => {
    console.log('\n👋 Stopping Discord Presence...');
    rpc.destroy();
    process.exit(0);
});
