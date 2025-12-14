// Quick VIP User Management Script
// This is the EASIEST way to add VIP users!
// Run: node test-add-vip.js

const fs = require('fs');
const path = require('path');

// ============================================
// 👉 EDIT THIS SECTION TO ADD NEW VIP USER
// ============================================
const NEW_VIP_USER = {
  userId: "999888777",        // ⬅️ CHANGE: Roblox User ID
  username: "NewVIP_Name",    // ⬅️ CHANGE: Username/Display name  
  type: "vip",                // Options: "vip", "premium", "standard"
  expiresAt: null,            // null = lifetime, or "2026-12-31T23:59:59Z"
  maxDevices: 5,              // Max devices per day
  notes: "Added via script"   // Your notes
};

function addVIPUser() {
  const keysPath = path.join(__dirname, 'data', 'keys.json');
  
  try {
    // Read current data
    const data = JSON.parse(fs.readFileSync(keysPath, 'utf8'));
    
    // Check if user already exists
    if (data.whitelist[NEW_VIP_USER.userId]) {
      console.log(`❌ User ${NEW_VIP_USER.userId} already exists!`);
      console.log('Current data:', data.whitelist[NEW_VIP_USER.userId]);
      return;
    }
    
    // Add new user
    data.whitelist[NEW_VIP_USER.userId] = {
      userId: NEW_VIP_USER.userId,
      username: NEW_VIP_USER.username,
      type: NEW_VIP_USER.type,
      status: "active",
      addedAt: new Date().toISOString(),
      expiresAt: NEW_VIP_USER.expiresAt,
      restrictions: {
        maxDevices: NEW_VIP_USER.maxDevices,
        ipTracking: true,
        webhookNotify: true
      },
      permissions: {
        bypassAll: false,
        unlimitedAccess: false,
        noLogging: false
      },
      notes: NEW_VIP_USER.notes
    };
    
    // Update metadata
    data.metadata.totalWhitelisted++;
    data.metadata.lastUpdated = new Date().toISOString();
    
    // Save back to file
    fs.writeFileSync(keysPath, JSON.stringify(data, null, 2));
    
    console.log('✅ SUCCESS! VIP user added:');
    console.log('─'.repeat(50));
    console.log(`User ID: ${NEW_VIP_USER.userId}`);
    console.log(`Username: ${NEW_VIP_USER.username}`);
    console.log(`Type: ${NEW_VIP_USER.type}`);
    console.log(`Max Devices: ${NEW_VIP_USER.maxDevices}`);
    console.log(`Expires: ${NEW_VIP_USER.expiresAt || 'Never (Lifetime)'}`);
    console.log('─'.repeat(50));
    console.log(`\nTotal whitelisted users: ${data.metadata.totalWhitelisted}`);
    
  } catch (error) {
    console.error('❌ ERROR:', error.message);
  }
}

// Run the function
addVIPUser();
