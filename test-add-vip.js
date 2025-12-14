// Quick test script to add VIP user directly to keys.json
// This bypasses the API and adds user directly to file
// Run: node test-add-vip.js

const fs = require('fs');
const path = require('path');

// Configuration - EDIT THIS!
const NEW_VIP_USER = {
  userId: "123456789",        // Change this to actual User ID
  username: "TestVIP_User",   // Change this to username
  type: "vip",
  expiresAt: null,            // null = lifetime, or use "2026-12-31T23:59:59Z"
  maxDevices: 5,
  notes: "Test VIP user added via script"
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
