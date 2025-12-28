/**
 * ═══════════════════════════════════════════════════════════════════
 * STARSHIP EVENT CODE SYSTEM - Google Apps Script
 * ═══════════════════════════════════════════════════════════════════
 * 
 * SETUP INSTRUCTIONS:
 * 1. Create a new Google Sheet
 * 2. Rename Sheet1 to "EventCodes" - for storing available codes
 * 3. Create Sheet2 named "Redeemed" - for tracking who redeemed
 * 4. Create Sheet3 named "Banned" - for blocked users
 * 5. Go to Extensions > Apps Script
 * 6. Paste this entire code
 * 7. Deploy as Web App (Execute as: Me, Access: Anyone)
 * 8. Copy the deployment URL to Vercel EVENT_CODE_API_URL
 * 
 * SHEET STRUCTURE:
 * 
 * EventCodes sheet (available event codes):
 * | A: Code | B: DurationDays | C: MaxUses | D: CurrentUses | E: Active |
 * | STAR24  | 30              | 100        | 5              | TRUE      |
 * 
 * Redeemed sheet (users who redeemed):
 * | A: UserId | B: Username | C: CodeUsed | D: RedeemedAt | E: ExpiresAt | F: Status |
 * | 123456    | player1     | STAR24      | 2024-12-28    | 2025-01-27   | active    |
 * 
 * Banned sheet (blocked users):
 * | A: UserId | B: Reason | C: BannedAt |
 * | 999999    | Hacker    | 2024-12-28  |
 */

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════
const SHEET_EVENT_CODES = "EventCodes";
const SHEET_REDEEMED = "Redeemed";
const SHEET_BANNED = "Banned";

// ═══════════════════════════════════════════════════════════════════
// MAIN HANDLER - Receives all requests
// ═══════════════════════════════════════════════════════════════════
function doGet(e) {
  try {
    const action = e.parameter.action;
    const userId = e.parameter.userId;
    const username = e.parameter.username || "unknown";
    const code = e.parameter.code;

    // Check if user is banned first
    if (userId && isUserBanned(userId)) {
      return jsonResponse({
        success: false,
        hasAccess: false,
        message: "Akun Anda telah diblokir",
        banned: true,
        isBanned: true,
        banReason: getBanReason(userId)
      });
    }

    switch (action) {
      case "check":
        return checkAccess(userId);
      
      case "redeem":
        return redeemCode(userId, username, code);
      
      case "status":
        return checkAccess(userId); // Same as check
      
      default:
        return jsonResponse({
          success: false,
          message: "Invalid action. Use: check, redeem, or status"
        });
    }
  } catch (error) {
    return jsonResponse({
      success: false,
      message: "Server error: " + error.message
    });
  }
}

// Also handle POST requests
function doPost(e) {
  return doGet(e);
}

// ═══════════════════════════════════════════════════════════════════
// CHECK ACCESS - Check if user has active event access
// ═══════════════════════════════════════════════════════════════════
function checkAccess(userId) {
  if (!userId) {
    return jsonResponse({
      success: false,
      message: "UserId required"
    });
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const redeemedSheet = ss.getSheetByName(SHEET_REDEEMED);
  
  if (!redeemedSheet) {
    return jsonResponse({
      success: false,
      hasAccess: false,
      message: "Sheet not configured"
    });
  }

  const data = redeemedSheet.getDataRange().getValues();
  
  // Find user in redeemed list
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const rowUserId = String(row[0]);
    const codeUsed = row[2];
    const expiresAt = row[4];
    const status = String(row[5]).toLowerCase();
    
    if (rowUserId === String(userId)) {
      // Check if suspended
      if (status === "suspended" || status === "banned") {
        return jsonResponse({
          success: false,
          hasAccess: false,
          isBanned: true,
          banReason: "Access suspended by administrator",
          message: "Access suspended"
        });
      }
      
      // Check expiry
      const expiryDate = new Date(expiresAt);
      const now = new Date();
      
      if (expiryDate < now) {
        // Update status to expired
        redeemedSheet.getRange(i + 1, 6).setValue("expired");
        
        return jsonResponse({
          success: false,
          hasAccess: false,
          message: "Access expired",
          expiredAt: formatDate(expiryDate)
        });
      }
      
      // Calculate remaining time
      const diffMs = expiryDate - now;
      const remainingDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));
      const remainingHours = Math.floor(diffMs / (1000 * 60 * 60));
      
      return jsonResponse({
        success: true,
        hasAccess: true,
        codeUsed: codeUsed,
        expiresAt: formatDate(expiryDate),
        remainingDays: remainingDays,
        remainingHours: remainingHours
      });
    }
  }
  
  // User not found - also check if they're in banned sheet
  const banned = isUserBanned(userId);
  return jsonResponse({
    success: false,
    hasAccess: false,
    isBanned: banned,
    banReason: banned ? getBanReason(userId) : null,
    message: banned ? "Akun Anda telah diblokir" : "No active event access"
  });
}

// ═══════════════════════════════════════════════════════════════════
// REDEEM CODE - User redeems an event code
// ═══════════════════════════════════════════════════════════════════
function redeemCode(userId, username, code) {
  if (!userId || !code) {
    return jsonResponse({
      success: false,
      message: "UserId and code required"
    });
  }

  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const codesSheet = ss.getSheetByName(SHEET_EVENT_CODES);
  const redeemedSheet = ss.getSheetByName(SHEET_REDEEMED);
  
  if (!codesSheet || !redeemedSheet) {
    return jsonResponse({
      success: false,
      message: "Sheet not configured"
    });
  }

  // Check if user already has active access
  const existingAccess = checkAccessInternal(userId, redeemedSheet);
  if (existingAccess.hasAccess) {
    return jsonResponse({
      success: false,
      message: "Anda sudah memiliki akses aktif! Expires: " + existingAccess.expiresAt
    });
  }

  // Find the code
  const codesData = codesSheet.getDataRange().getValues();
  let codeRow = -1;
  let codeDuration = 0;
  let codeMaxUses = 0;
  let codeCurrentUses = 0;
  let codeActive = false;
  
  for (let i = 1; i < codesData.length; i++) {
    if (String(codesData[i][0]).toUpperCase() === code.toUpperCase()) {
      codeRow = i + 1;
      codeDuration = parseInt(codesData[i][1]) || 30;
      codeMaxUses = parseInt(codesData[i][2]) || 999999;
      codeCurrentUses = parseInt(codesData[i][3]) || 0;
      codeActive = codesData[i][4] === true || String(codesData[i][4]).toUpperCase() === "TRUE";
      break;
    }
  }
  
  // Code not found
  if (codeRow === -1) {
    return jsonResponse({
      success: false,
      message: "Kode tidak valid"
    });
  }
  
  // Code not active
  if (!codeActive) {
    return jsonResponse({
      success: false,
      message: "Kode sudah tidak aktif"
    });
  }
  
  // Check max uses
  if (codeCurrentUses >= codeMaxUses) {
    return jsonResponse({
      success: false,
      message: "Kode sudah mencapai batas maksimum penggunaan"
    });
  }
  
  // Calculate expiry date
  const now = new Date();
  const expiresAt = new Date(now.getTime() + (codeDuration * 24 * 60 * 60 * 1000));
  
  // Add to redeemed sheet
  redeemedSheet.appendRow([
    userId,
    username,
    code.toUpperCase(),
    formatDate(now),
    formatDate(expiresAt),
    "active"
  ]);
  
  // Update code usage count
  codesSheet.getRange(codeRow, 4).setValue(codeCurrentUses + 1);
  
  return jsonResponse({
    success: true,
    message: "Kode berhasil! Akses aktif selama " + codeDuration + " hari",
    duration: codeDuration,
    expiresAt: formatDate(expiresAt)
  });
}

// ═══════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

function isUserBanned(userId) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const bannedSheet = ss.getSheetByName(SHEET_BANNED);
  
  if (!bannedSheet) return false;
  
  const data = bannedSheet.getDataRange().getValues();
  
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]) === String(userId)) {
      return true;
    }
  }
  
  return false;
}

// Get ban reason from Banned sheet
function getBanReason(userId) {
  const ss = SpreadsheetApp.getActiveSpreadsheet();
  const bannedSheet = ss.getSheetByName(SHEET_BANNED);
  
  if (!bannedSheet) return "Banned by administrator";
  
  const data = bannedSheet.getDataRange().getValues();
  
  for (let i = 1; i < data.length; i++) {
    if (String(data[i][0]) === String(userId)) {
      return String(data[i][1]) || "Banned by administrator"; // Column B = Reason
    }
  }
  
  return "Banned by administrator";
}

function checkAccessInternal(userId, redeemedSheet) {
  const data = redeemedSheet.getDataRange().getValues();
  
  for (let i = 1; i < data.length; i++) {
    const row = data[i];
    const rowUserId = String(row[0]);
    const expiresAt = row[4];
    const status = String(row[5]).toLowerCase();
    
    if (rowUserId === String(userId) && status === "active") {
      const expiryDate = new Date(expiresAt);
      const now = new Date();
      
      if (expiryDate > now) {
        return {
          hasAccess: true,
          expiresAt: formatDate(expiryDate)
        };
      }
    }
  }
  
  return { hasAccess: false };
}

function formatDate(date) {
  return Utilities.formatDate(date, Session.getScriptTimeZone(), "yyyy-MM-dd HH:mm:ss");
}

function jsonResponse(data) {
  return ContentService
    .createTextOutput(JSON.stringify(data))
    .setMimeType(ContentService.MimeType.JSON);
}
