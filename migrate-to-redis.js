// Migration Script: keys.json → Upstash Redis
// Run this ONCE after setting up Vercel KV database
// This will copy all whitelist data from keys.json to Redis

import fs from 'fs';
import path from 'path';
import redis from './lib/redis.js';

const WHITELIST_KEY = 'starship:whitelist';
const METADATA_KEY = 'starship:metadata';

async function migrateToRedis() {
  try {
    console.log('🚀 Starting migration from keys.json to Redis...\n');
    
    // Read keys.json
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const data = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
    
    console.log(`📄 Found ${Object.keys(data.whitelist || {}).length} users in keys.json`);
    
    // Clear existing Redis data (optional - comment out if you want to keep existing data)
    console.log('🗑️  Clearing existing Redis data...');
    await redis.del(WHITELIST_KEY);
    await redis.del(METADATA_KEY);
    
    // Migrate whitelist
    if (data.whitelist && Object.keys(data.whitelist).length > 0) {
      console.log('\n📤 Migrating whitelist to Redis...');
      
      for (const [userId, userData] of Object.entries(data.whitelist)) {
        await redis.hset(WHITELIST_KEY, userId, JSON.stringify(userData));
        console.log(`  ✅ Migrated: ${userData.username} (${userId})`);
      }
    }
    
    // Migrate metadata
    if (data.metadata) {
      console.log('\n📤 Migrating metadata to Redis...');
      await redis.set(METADATA_KEY, JSON.stringify(data.metadata));
      console.log(`  ✅ Metadata migrated`);
    }
    
    // Verify migration
    console.log('\n🔍 Verifying migration...');
    const migratedWhitelist = await redis.hgetall(WHITELIST_KEY);
    const migratedMetadata = await redis.get(METADATA_KEY);
    
    console.log(`  📊 Whitelist entries in Redis: ${Object.keys(migratedWhitelist || {}).length}`);
    console.log(`  📊 Metadata: ${migratedMetadata ? 'OK' : 'MISSING'}`);
    
    // Display summary
    console.log('\n━'.repeat(50));
    console.log('✨ Migration completed successfully!');
    console.log('━'.repeat(50));
    console.log('\n📋 Summary:');
    console.log(`  Total users migrated: ${Object.keys(migratedWhitelist || {}).length}`);
    console.log(`  Metadata: ` + (migratedMetadata ? '✅' : '❌'));
    
    console.log('\n🎯 Next steps:');
    console.log('  1. Test the dashboard: https://your-domain.vercel.app/vip-dashboard.html');
    console.log('  2. Try adding a new VIP user');
    console.log('  3. Verify the data persists');
    
    console.log('\n⚠️  Note: keys.json is now deprecated.');
    console.log('   All data is now stored in Redis/KV!');
    
  } catch (error) {
    console.error('\n❌ Migration failed:', error.message);
    console.error(error);
    process.exit(1);
  }
}

// Run migration
migrateToRedis()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
