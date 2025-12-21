# 🚀 StarshipCore - PC & Mobile Whitelist System

A secure, dual-platform whitelist authentication system for Roblox scripts with separate licensing for PC and Mobile users.

---

## 📋 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [Quick Start](#-quick-start)
- [Loadstring Scripts](#-loadstring-scripts)
- [Architecture](#-architecture)
- [API Endpoints](#-api-endpoints)
- [VIP Dashboard](#-vip-dashboard)
- [Whitelist Management](#-whitelist-management)
- [Security Features](#-security-features)
- [File Structure](#-file-structure)
- [Environment Variables](#-environment-variables)
- [Discord Webhook](#-discord-webhook)
- [Troubleshooting](#-troubleshooting)

---

## 🌟 Overview

StarshipCore is a comprehensive whitelist authentication system that provides:

- **Separate licensing** for PC and Mobile platforms
- **Cross-platform detection** to prevent license misuse
- **Secure script delivery** with obfuscation and encryption
- **Real-time Discord notifications** for all access attempts
- **VIP Dashboard** for easy user management

---

## ✨ Features

| Feature | PC | Mobile |
|---------|:--:|:------:|
| Whitelist Authentication | ✅ | ✅ |
| Encrypted Script Delivery | ✅ | ✅ |
| Device Tracking | ✅ | ✅ |
| Expiry Management | ✅ | ✅ |
| Discord Logging | ✅ | ✅ |
| Cross-Platform Detection | ✅ | ✅ |
| Browser Access Block | ✅ | ✅ |
| Obfuscated Bootstrap | ✅ | ✅ |

---

## 🚀 Quick Start

### For PC Users (Desktop/Laptop):

```lua
loadstring(game:HttpGet("https://starship-core.my.id/api/bootstrap"))()
```

### For Mobile Users (Phone/Tablet/Emulator):

```lua
loadstring(game:HttpGet("https://starship-core.my.id/api/mobile-bootstrap"))()
```

---

## 📜 Loadstring Scripts

### 💻 PC Execution

**Full Loadstring:**
```lua
loadstring(game:HttpGet("https://starship-core.my.id/api/bootstrap"))()
```

**Flow:**
1. `api/bootstrap` → Returns obfuscated loader
2. `api/get-loader` → Authenticates & serves loader script
3. `api/load` → Returns encrypted main script
4. `StarshipCore.lua` → Main UI executes

---

### 📱 Mobile Execution

**Full Loadstring:**
```lua
loadstring(game:HttpGet("https://starship-core.my.id/api/mobile-bootstrap"))()
```

**Flow:**
1. `api/mobile-bootstrap` → Returns obfuscated loader
2. `api/get-mobile-loader` → Authenticates & serves mobile loader
3. `api/mobile-load` → Validates license & creates session
4. `api/get-mobile-ui` → Serves Mobile UI (WindUI)
5. `MobileUI.lua` → Mobile UI executes

---

## 🛠️ Development Mode

When testing locally with `vercel dev`, use these endpoints:

### 💻 PC Development:
```lua
loadstring(game:HttpGet("http://localhost:3000/api/dev-pc-script"))()
```

### 📱 Mobile Development:
```lua
loadstring(game:HttpGet("http://localhost:3000/api/dev-mobile-ui"))()
```

### Running Local Server:
```bash
cd VercelProject
vercel dev
```

> ⚠️ **Note:** Development endpoints only work on localhost. In production, they will return an error.

---

### 📋 Supported Executors

| Platform | Executors |
|----------|-----------|
| **PC** | Synapse X, Script-Ware, KRNL, Fluxus, Hydrogen, Evon, Comet |
| **Mobile** | Delta, Arceus X, Fluxus Mobile, Hydrogen Mobile, VegaX |
| **Emulator** | MuMu, BlueStacks, LDPlayer, Nox (with mobile executors) |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         USER DEVICE                              │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   💻 PC User                          📱 Mobile User             │
│   loadstring(bootstrap)               loadstring(mobile-bootstrap)│
│         │                                    │                   │
│         ▼                                    ▼                   │
│   ┌─────────────┐                     ┌──────────────┐          │
│   │ /api/       │                     │ /api/        │          │
│   │ bootstrap   │                     │ mobile-      │          │
│   │             │                     │ bootstrap    │          │
│   └──────┬──────┘                     └──────┬───────┘          │
│          │                                   │                   │
│          ▼                                   ▼                   │
│   ┌─────────────┐                     ┌──────────────┐          │
│   │ /api/       │                     │ /api/get-    │          │
│   │ get-loader  │                     │ mobile-loader│          │
│   └──────┬──────┘                     └──────┬───────┘          │
│          │                                   │                   │
│          ▼                                   ▼                   │
│   ┌─────────────┐                     ┌──────────────┐          │
│   │ /api/load   │                     │ /api/        │          │
│   │ (encrypted) │                     │ mobile-load  │          │
│   └──────┬──────┘                     └──────┬───────┘          │
│          │                                   │                   │
│          ▼                                   ▼                   │
│   ┌─────────────┐                     ┌──────────────┐          │
│   │ StarshipCore│                     │ /api/get-    │          │
│   │ .lua (PC UI)│                     │ mobile-ui    │          │
│   └─────────────┘                     └──────┬───────┘          │
│                                              │                   │
│                                              ▼                   │
│                                       ┌──────────────┐          │
│                                       │ MobileUI.lua │          │
│                                       │ (WindUI)     │          │
│                                       └──────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔌 API Endpoints

### Public Endpoints (Entry Points)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/bootstrap` | GET | PC entry point (obfuscated) |
| `/api/mobile-bootstrap` | GET | Mobile entry point (obfuscated) |

### Authentication Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/get-loader` | GET | Serve PC loader after auth |
| `/api/get-mobile-loader` | GET | Serve Mobile loader after auth |
| `/api/load` | GET | PC script encryption & delivery |
| `/api/mobile-load` | GET | Mobile authentication & session |
| `/api/get-mobile-ui` | GET | Serve Mobile UI after auth |

### Management Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/whitelist-manager` | GET/POST/PUT/DELETE | PC whitelist CRUD |
| `/api/mobile-whitelist-manager` | GET/POST/PUT/DELETE | Mobile whitelist CRUD |

---

## 🎛️ VIP Dashboard

Access the web-based management dashboard:

```
https://starship-core.my.id/vip-dashboard.html
```

### Features:
- 🔐 Admin authentication with secret key
- 💻 Manage PC whitelist
- 📱 Manage Mobile whitelist
- ➕ Add new VIP users
- ⏸️ Suspend/Reactivate users
- 🗑️ Remove users
- 📊 View statistics (Total, Active, Suspended, Expired)

### Usage:
1. Enter your Admin Secret Key
2. Click "Connect & Load Users"
3. Switch between PC/Mobile tabs
4. Manage users as needed

---

## 👥 Whitelist Management

### Adding Users via Dashboard

1. Open VIP Dashboard
2. Select platform (PC or Mobile)
3. Fill in:
   - User ID (Roblox UserId)
   - Username
   - Type (VIP/Premium/Standard)
   - Duration
   - Max Devices
4. Click "Add User"

### Adding Users via API

**PC User:**
```bash
curl -X POST "https://starship-core.my.id/api/whitelist-manager?action=add" \
  -H "X-Admin-Secret: YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "123456789",
    "username": "PlayerName",
    "type": "VIP",
    "expiresAt": null,
    "maxDevices": 3
  }'
```

**Mobile User:**
```bash
curl -X POST "https://starship-core.my.id/api/mobile-whitelist-manager" \
  -H "X-Admin-Secret: YOUR_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "123456789",
    "username": "PlayerName",
    "type": "MOBILE_VIP",
    "duration": "30",
    "maxDevices": 2
  }'
```

### Whitelist Data Structure

**PC Whitelist (keys.json / Redis):**
```json
{
  "whitelist": {
    "123456789": {
      "username": "PlayerName",
      "type": "VIP",
      "status": "active",
      "addedAt": "2025-01-01T00:00:00.000Z",
      "expiresAt": null,
      "restrictions": {
        "maxDevices": 3
      }
    }
  }
}
```

**Mobile Whitelist (mobile-keys.json / Redis):**
```json
{
  "whitelist": {
    "123456789": {
      "username": "PlayerName",
      "type": "MOBILE_VIP",
      "status": "active",
      "duration": "LIFETIME",
      "expiresAt": null,
      "maxDevices": 2,
      "addedAt": "2025-01-01T00:00:00.000Z",
      "platform": "mobile"
    }
  }
}
```

---

## 🔒 Security Features

### 1. Browser Detection & Blocking
- Detects browser User-Agent patterns
- Returns 403 Forbidden page for browser access
- Allows Roblox executors through

### 2. Cross-Platform Detection
- Detects when PC user tries Mobile script (and vice versa)
- Sends Discord alert
- Returns helpful error message

### 3. URL Obfuscation
- Bootstrap scripts encode API URLs in Base64
- Source code not visible to end users

### 4. Script Encryption (PC)
- Dynamic XOR encryption key per request
- Base64 encoded payload
- Key rotates on every execution

### 5. Device Tracking
- Tracks IP addresses per user
- Limits devices based on license
- 30-day device memory

### 6. Discord Logging
All events logged to Discord:
- ✅ Successful access
- ❌ Access denied
- 🔀 Cross-platform attempts
- 🚨 Suspicious browser access
- 📱 New device registrations

---

## 📁 File Structure

```
VercelProject/
├── api/                          # Serverless API functions
│   ├── bootstrap.js              # PC entry point
│   ├── mobile-bootstrap.js       # Mobile entry point
│   ├── get-loader.js             # Serve PC loader
│   ├── get-mobile-loader.js      # Serve Mobile loader
│   ├── load.js                   # PC auth & encryption
│   ├── mobile-load.js            # Mobile auth
│   ├── get-mobile-ui.js          # Serve Mobile UI
│   ├── whitelist-manager.js      # PC whitelist CRUD
│   └── mobile-whitelist-manager.js # Mobile whitelist CRUD
│
├── data/                         # Protected data (not public)
│   ├── StarshipCore.lua          # PC Main UI Script
│   ├── MobileUI.lua              # Mobile UI (WindUI)
│   ├── keys.json                 # PC whitelist (file fallback)
│   ├── mobile-keys.json          # Mobile whitelist (file fallback)
│   └── Modules/                  # Script modules
│
├── protected/                    # Protected loader scripts
│   ├── loader.lua                # PC loader
│   └── mobile-loader.lua         # Mobile loader
│
├── public/                       # Public static files
│   ├── vip-dashboard.html        # Admin dashboard
│   └── ...                       # Other public assets
│
├── lib/                          # Shared libraries
│   └── redis.js                  # Redis client
│
└── vercel.json                   # Vercel configuration
```

---

## ⚙️ Environment Variables

Set these in Vercel Dashboard → Settings → Environment Variables:

| Variable | Required | Description |
|----------|:--------:|-------------|
| `ADMIN_SECRET` | ✅ | Secret key for admin authentication |
| `REDIS_URL` | ✅ | Redis connection URL (Upstash recommended) |
| `DISCORD_WEBHOOK_URL` | ❌ | Discord webhook for logging |
| `GITHUB_TOKEN` | ❌ | GitHub token for file sync |
| `GITHUB_REPO` | ❌ | GitHub repository (owner/repo) |

### Example:
```env
ADMIN_SECRET=your-super-secret-key-here
REDIS_URL=redis://default:xxx@xxx.upstash.io:6379
DISCORD_WEBHOOK_URL=https://discord.com/api/webhooks/xxx/xxx
```

---

## 📨 Discord Webhook

### Webhook Message Types:

| Icon | Event |
|------|-------|
| ✅ | Successful access |
| ❌ | Access denied |
| 🔀 | Cross-platform attempt |
| 🚨 | Suspicious browser access |
| 📱 | New mobile device registered |
| ⏸️ | User suspended |
| 🚫 | Expired license attempt |

### Sample Webhook:

```
🔀 Cross-Platform Access Attempt Detected!

👤 User: PlayerName
🎫 Current License: 📱 MOBILE
🚫 Attempted Access: 💻 PC
🌐 IP Address: xxx.xxx.xxx.xxx
📅 License Type: MOBILE_VIP
⏰ Timestamp: 2025-01-15T10:30:00.000Z

⚠️ PlayerName has a MOBILE license but tried to access PC script!
💡 Consider offering a bundle upgrade or separate PC license.
```

---

## 🔧 Troubleshooting

### Common Issues:

#### 1. "Not Whitelisted" Error
- **Cause:** User ID not in whitelist
- **Solution:** Add user via VIP Dashboard or API

#### 2. "You have a PC license, not Mobile" (or vice versa)
- **Cause:** User trying wrong platform script
- **Solution:** Use correct loadstring for their license, or add to both whitelists

#### 3. "Mobile VIP access expired"
- **Cause:** License duration ended
- **Solution:** Renew via VIP Dashboard (update expiry date)

#### 4. "Device limit reached"
- **Cause:** Too many IPs/devices used
- **Solution:** Increase maxDevices or reset devices

#### 5. Script not executing on emulator
- **Cause:** Executor User-Agent might be blocked
- **Solution:** Use supported executor (Delta, Arceus X, Fluxus)

#### 6. "Connection Failed"
- **Cause:** Network issue or server down
- **Solution:** Check internet connection, try again later

### Debug Steps:

1. **Check Vercel Logs:**
   - Vercel Dashboard → Project → Logs
   - Look for error messages

2. **Check Discord Webhook:**
   - See what events are being logged
   - Check for denied access reasons

3. **Verify Whitelist:**
   - Open VIP Dashboard
   - Confirm user exists in correct platform tab

4. **Test API Directly:**
   ```bash
   curl "https://starship-core.my.id/api/mobile-load?userId=YOUR_USER_ID"
   ```

---

## 📞 Support

For issues or questions:
- Check Vercel logs for error details
- Review Discord webhook for access attempts
- Verify whitelist configuration

---

## 📄 License

Private/Proprietary - All rights reserved.

---

## 🔄 Version History

| Version | Date | Changes |
|---------|------|---------|
| 2.0.0 | 2025-01 | Added Mobile platform support |
| 2.1.0 | 2025-01 | Added Cross-Platform Detection |
| 2.2.0 | 2025-01 | Protected all script files |
| 2.3.0 | 2025-01 | Added VIP Dashboard |

---

Made with ❤️ by Starship Team