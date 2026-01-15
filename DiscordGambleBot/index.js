const { Client } = require('discord.js-selfbot-v13');
require('dotenv').config();

const client = new Client();
let TOKEN = process.env.DISCORD_TOKEN;
const CHANNEL_ID = process.env.CHANNEL_ID;

if (!TOKEN || !CHANNEL_ID) {
    console.error('Error: Harap isi DISCORD_TOKEN dan CHANNEL_ID di file .env');
    process.exit(1);
}

// Bersihkan token dari tanda kutip atau spasi yang tidak sengaja ikut
TOKEN = TOKEN.replace(/['"]/g, '').trim();

console.log(`Token Length: ${TOKEN.length}`);
console.log(`Token Preview: ${TOKEN.substring(0, 5)}...`);


client.on('ready', async () => {
    console.log(`Logged in as ${client.user.tag}!`);
    console.log(`Target Channel ID: ${CHANNEL_ID}`);
    console.log('Starting auto-gamble loop every 25 seconds...');

    const channel = await client.channels.fetch(CHANNEL_ID);
    if (!channel) {
        console.error('Error: Channel tidak ditemukan! Pastikan ID benar dan akun memiliki akses.');
        process.exit(1);
    }

    // Send immediately on start
    sendGamble(channel);

    // Loop every 25 seconds (25000 ms)
    setInterval(() => {
        sendGamble(channel);
    }, 25000);
});

async function sendGamble(channel) {
    try {
        await channel.send('!!gamble');
        console.log(`[${new Date().toLocaleTimeString()}] Sent: !!gamble`);
    } catch (error) {
        console.error(`[${new Date().toLocaleTimeString()}] Error sending message:`, error.message);
    }
}

client.login(TOKEN);
