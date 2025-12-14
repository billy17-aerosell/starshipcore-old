// Test script for Whitelist Management API
// Run: node test-whitelist-api.js

const BASE_URL = process.env.API_URL || 'http://localhost:3000';
const ADMIN_SECRET = process.env.ADMIN_SECRET || 'CHANGE_ME_PLEASE';

async function testAPI(action, method = 'GET', body = null) {
  const url = `${BASE_URL}/api/whitelist-manager?action=${action}${action === 'info' ? '&userId=123456789' : ''}`;
  
  const options = {
    method,
    headers: {
      'X-Admin-Secret': ADMIN_SECRET,
      'Content-Type': 'application/json'
    }
  };
  
  if (body) {
    options.body = JSON.stringify(body);
  }
  
  try {
    const response = await fetch(url, options);
    const data = await response.json();
    
    console.log(`\n✅ ${action.toUpperCase()} - Status: ${response.status}`);
    console.log(JSON.stringify(data, null, 2));
    return data;
  } catch (error) {
    console.error(`\n❌ ${action.toUpperCase()} - Error:`, error.message);
    return null;
  }
}

async function runTests() {
  console.log('🧪 Testing Whitelist Management API...\n');
  console.log(`📍 URL: ${BASE_URL}`);
  console.log(`🔑 Secret: ${ADMIN_SECRET.substring(0, 5)}...`);
  console.log('━'.repeat(50));
  
  // Test 1: List (should show only owner initially)
  await testAPI('list', 'GET');
  
  // Test 2: Add VIP User
  await testAPI('add', 'POST', {
    userId: '123456789',
    username: 'TestVIP_User',
    type: 'vip',
    expiresAt: '2026-12-31T23:59:59Z',
    maxDevices: 5,
    notes: 'Test VIP user'
  });
  
  // Test 3: Get User Info
  await testAPI('info', 'GET');
  
  // Test 4: Update User
  await testAPI('update', 'PUT', {
    userId: '123456789',
    username: 'TestVIP_Updated',
    type: 'premium',
    maxDevices: 10,
    notes: 'Updated to premium'
  });
  
  // Test 5: List (should show 2 users now)
  await testAPI('list', 'GET');
  
  // Test 6: Suspend User
  await testAPI('suspend', 'POST', {
    userId: '123456789'
  });
  
  // Test 7: Reactivate User
  await testAPI('reactivate', 'POST', {
    userId: '123456789'
  });
  
  // Test 8: Remove User
  await testAPI('remove', 'DELETE', {
    userId: '123456789'
  });
  
  // Test 9: List (should show only owner again)
  await testAPI('list', 'GET');
  
  console.log('\n━'.repeat(50));
  console.log('✨ All tests completed!\n');
}

// Run tests
runTests().catch(console.error);
