# 🔐 Smart Key Authentication System

## Overview

This system provides **smart key-based authentication** for your Roblox loader script with:

- ✅ IP tracking and suspicious activity detection
- ✅ Device limit (max 3-5 IPs per day)
- ✅ Comprehensive logging
- ✅ Key management (create, revoke, monitor)
- ✅ Auto-blocking of shared/leaked keys

---

## 🚀 How It Works

### For Users:

Instead of accessing the public loader, users now need a valid key:

```lua
-- OLD (public access):
loadstring(game:HttpGet("https://www.starship-core.my.id/loader.lua"))()

-- NEW (with key):
loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?key=YOUR_KEY_HERE"))()
```

### Smart Protection Rules:

1. **0-3 IPs per day** → ✅ Allowed (normal usage)
2. **4-5 IPs per day** → ⚠️ Warning (but still allowed)
3. **6+ IPs per day** → 🚫 Blocked (suspicious activity)

---

## 📂 File Structure

```
VercelProject/
├── api/
│   ├── get-loader.js       # Main authentication endpoint
│   └── key-manager.js      # Key management API
├── data/
│   ├── keys.json          # Keys database
│   └── logs/              # Daily access logs
│       ├── 2024-12-14.json
│       └── 2024-12-15.json
└── public/
    └── loader.lua         # The obfuscated script
```

---

## 🔑 Managing Keys

### Environment Setup

First, set your admin secret in `.env.local`:

```env
ADMIN_SECRET=your_super_secret_password_here
```

### Create a New Key

```bash
curl -X POST https://www.starship-core.my.id/api/key-manager?action=create \
  -H "Content-Type: application/json" \
  -H "X-Admin-Secret: your_super_secret_password_here" \
  -d '{
    "owner": "Johan",
    "type": "premium",
    "expiresAt": null,
    "maxDevices": 3
  }'
```

**Response:**

```json
{
  "success": true,
  "key": "premium-a1b2c3d4",
  "data": {
    "owner": "Johan",
    "type": "premium",
    "status": "active",
    "createdAt": "2024-12-14T10:00:00Z",
    ...
  }
}
```

### List All Keys

```bash
curl https://www.starship-core.my.id/api/key-manager?action=list \
  -H "X-Admin-Secret: your_super_secret_password_here"
```

### Revoke a Key

```bash
curl -X POST https://www.starship-core.my.id/api/key-manager?action=revoke \
  -H "Content-Type: application/json" \
  -H "X-Admin-Secret: your_super_secret_password_here" \
  -d '{"key": "premium-a1b2c3d4"}'
```

### Get Key Statistics

```bash
curl "https://www.starship-core.my.id/api/key-manager?action=stats&key=premium-a1b2c3d4" \
  -H "X-Admin-Secret: your_super_secret_password_here"
```

---

## 📊 Monitoring & Logs

### Access Logs

Daily logs are saved in `data/logs/YYYY-MM-DD.json`:

```json
[
  {
    "timestamp": "2024-12-14T10:30:45Z",
    "ip": "103.147.xxx.xxx",
    "key": "premium-a1b2c3d4",
    "owner": "Johan",
    "keyType": "premium",
    "status": "success",
    "warning": false,
    "userAgent": "Roblox/WinInet",
    "responseTime": "45ms"
  },
  {
    "timestamp": "2024-12-14T10:35:20Z",
    "ip": "202.158.xxx.xxx",
    "key": "invalid-key",
    "status": "failed",
    "reason": "Invalid key"
  }
]
```

### Key Tracking

Each key stores IP tracking data:

```json
{
  "owner": "Johan",
  "ipTracking": {
    "2024-12-14": ["103.147.25.100", "114.125.88.55"],
    "2024-12-15": ["103.147.25.100"]
  },
  "totalRequests": 47,
  "lastUsed": "2024-12-14T15:30:00Z",
  "lastIP": "103.147.25.100"
}
```

---

## 🎯 Demo Keys (For Testing)

Two demo keys are pre-configured in `data/keys.json`:

1. **Premium Key**: `demo-premium-2024`

   - Type: premium
   - No expiration
   - Max 3 devices

2. **Trial Key**: `trial-test-123`
   - Type: trial
   - Expires: 7 days from now
   - Max 2 devices

**Test URL:**

```lua
loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?key=demo-premium-2024"))()
```

---

## 🔧 Advanced Configuration

### Adjust Protection Rules

Edit `api/get-loader.js` to customize the smart validation:

```javascript
// Current rules:
if (uniqueIPsToday <= 3) {
  return { valid: true, warning: false }; // OK
}
if (uniqueIPsToday <= 5) {
  return { valid: true, warning: true }; // Warning
}
// More than 5 = blocked!

// You can change these numbers to be more/less strict
```

### Key Types

You can create different key types:

- `premium` - Full access, no expiration
- `trial` - Limited time access
- `standard` - Regular user
- `vip` - Special privileges (custom type)

### Expiration

Set expiration dates in ISO format:

```json
{
  "expiresAt": "2024-12-31T23:59:59Z" // Expires Dec 31, 2024
}
```

---

## 🚨 Security Best Practices

1. **Change Admin Secret**

   - Never use the default `CHANGE_ME_PLEASE`
   - Use a strong, random password

2. **Monitor Logs Regularly**

   - Check `data/logs/` for suspicious activity
   - Look for keys with many failed attempts

3. **Rotate Keys**

   - Consider revoking and re-issuing keys periodically
   - Especially if you suspect a leak

4. **Backup Keys Database**
   - Regularly backup `data/keys.json`
   - Store securely

---

## 📱 Response Examples

### Successful Response:

```
HTTP/1.1 200 OK
Content-Type: text/plain

(obfuscated lua script content)
```

### Invalid Key:

```json
HTTP/1.1 403 Forbidden
{
  "error": "Invalid authentication key",
  "message": "The provided key is not valid. Please contact administrator."
}
```

### Too Many Devices:

```json
HTTP/1.1 429 Too Many Requests
{
  "error": "Too many devices detected",
  "message": "Too many devices (6 IPs). Possible key sharing detected.",
  "contact": "Please contact administrator if this is a mistake."
}
```

### Key Expired:

```json
HTTP/1.1 403 Forbidden
{
  "error": "Key expired",
  "message": "This key expired on Fri Dec 21 2024."
}
```

---

## 🎓 Quick Start Guide

1. **Deploy to Vercel**

   ```bash
   git add .
   git commit -m "Add smart key authentication"
   git push origin main
   ```

2. **Set Admin Secret**

   - Go to Vercel Dashboard → Settings → Environment Variables
   - Add: `ADMIN_SECRET` = `your_secret_password`

3. **Create Your First Key**

   ```bash
   # Use the create key curl command above
   ```

4. **Give Key to User**

   ```lua
   loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?key=YOUR_NEW_KEY"))()
   ```

5. **Monitor Usage**
   - Check `data/logs/` directory
   - Use key stats endpoint

---

## ❓ Troubleshooting

**Q: Key works on PC but not on phone**

- This is normal if user exceeded daily IP limit
- Check key stats to see IP count

**Q: Can I increase device limit?**

- Yes, edit the validation rules in `get-loader.js`
- Or set `maxDevices` when creating key

**Q: How to permanently block an IP?**

- You'll need to add IP blacklist feature
- Contact for custom implementation

---

## 📞 Support

For issues or custom features, check the logs first:

- `data/logs/YYYY-MM-DD.json` - Access logs
- Vercel Dashboard - Function logs

---

**Created**: 2024-12-14  
**Version**: 1.0.0  
**License**: Private Use Only
