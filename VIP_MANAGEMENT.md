# 👑 VIP User Management System

Complete guide untuk mengelola VIP users di StarshipCore menggunakan web dashboard dan Redis database.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Web Dashboard](#web-dashboard)
4. [API Reference](#api-reference)
5. [User Types](#user-types)
6. [Technical Details](#technical-details)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

Sistem VIP Management memungkinkan Anda untuk:

- ✅ **Tambah** VIP users via web dashboard
- ✅ **Edit** user details, permissions, restrictions
- ✅ **Suspend/Reactivate** users tanpa menghapus data
- ✅ **Remove** users permanently
- ✅ **Monitor** semua VIP users dalam satu dashboard
- ✅ **Data persist** di Redis database (gratis, fast, reliable)

### 🔑 Key Features:

- **Owner Bypass**: Owner (User ID: 9268011358) hardcoded, tidak perlu database check
- **Redis Storage**: Data tersimpan permanent di Redis Labs
- **Zero File System**: Tidak pakai file JSON, full cloud-based
- **Secure**: Protected dengan ADMIN_SECRET
- **Real-time**: Changes langsung apply tanpa restart

---

## 🚀 Quick Start

### 1. Buka Dashboard

> ⚠️ **Security Note:** Dashboard URL disembunyikan untuk keamanan. Hubungi owner untuk akses.

### 2. Login

Masukkan **ADMIN_SECRET** Anda (sama dengan yang di environment variables).

💡 **Tip**: Check "Remember Secret Key" untuk auto-login next time!

### 3. Tambah VIP User

1. Click **"Add VIP User"** button
2. Isi form:
   - **User ID**: Roblox User ID (contoh: 123456789)
   - **Username**: Display name (contoh: JohnDoe_VIP)
   - **Type**: Pilih `vip`, `premium`, atau `standard`
   - **Max Devices**: Maksimal devices per hari (default: 5)
   - **Expires At**: (Optional) Tanggal expired, kosongkan untuk lifetime
   - **Notes**: Catatan tambahan
3. Click **"Add User"**
4. ✅ Done! User langsung bisa akses loader

---

## 💻 Web Dashboard

### URL:

> ⚠️ URL dashboard tidak dipublikasikan untuk keamanan. Simpan URL dengan aman setelah diberikan.

### 🎨 Features:

#### **1. View All Users**

- List semua VIP users
- Show: Username, User ID, Type, Status, Devices
- Color-coded status badges
- Quick action buttons

#### **2. Add New User**

- Modal form dengan semua fields
- Validation untuk User ID & Username
- Instant feedback

#### **3. Manage Users**

- **Suspend**: Temporarily disable user access
- **Reactivate**: Re-enable suspended user
- **Remove**: Permanently delete user
- **Refresh**: Reload latest data

#### **4. Auto-Remember Secret**

- Checkbox "Remember Secret Key"
- Auto-login on next visit
- "Forget Secret" button untuk logout

### 🎯 Dashboard Screenshots Flow:

**Login Screen** → **User List** → **Add User Modal** → **Success Notification**

---

## 🔌 API Reference

Base URL: `https://www.starship-core.my.id/api/whitelist-manager`

### Authentication

Semua endpoints require header:

```
X-Admin-Secret: YOUR_ADMIN_SECRET
```

---

### 📋 **1. List All Users**

**Endpoint**: `GET /api/whitelist-manager?action=list`

**Response**:

```json
{
  "whitelist": {
    "123456789": {
      "userId": "123456789",
      "username": "JohnDoe",
      "type": "vip",
      "status": "active",
      "addedAt": "2025-12-14T12:00:00Z",
      "expiresAt": null,
      "restrictions": {
        "maxDevices": 5,
        "ipTracking": true,
        "webhookNotify": true
      },
      "permissions": {
        "bypassAll": false,
        "unlimitedAccess": false,
        "noLogging": false
      },
      "notes": "VIP member"
    }
  },
  "metadata": {
    "totalWhitelisted": 1,
    "lastUpdated": "2025-12-14T12:00:00Z"
  }
}
```

---

### ➕ **2. Add User**

**Endpoint**: `POST /api/whitelist-manager?action=add`

**Body**:

```json
{
  "userId": "123456789",
  "username": "JohnDoe",
  "type": "vip",
  "maxDevices": 5,
  "expiresAt": null,
  "notes": "New VIP member"
}
```

**Response**:

```json
{
  "success": true,
  "message": "User JohnDoe (123456789) has been whitelisted",
  "data": {
    /* user object */
  }
}
```

---

### ✏️ **3. Update User**

**Endpoint**: `PUT /api/whitelist-manager?action=update`

**Body**:

```json
{
  "userId": "123456789",
  "username": "JohnDoe_Updated",
  "type": "premium",
  "maxDevices": 10,
  "notes": "Upgraded to premium"
}
```

**Response**:

```json
{
  "success": true,
  "message": "User 123456789 has been updated",
  "data": {
    /* updated user object */
  }
}
```

---

### 🗑️ **4. Remove User**

**Endpoint**: `DELETE /api/whitelist-manager?action=remove`

**Body**:

```json
{
  "userId": "123456789"
}
```

**Response**:

```json
{
  "success": true,
  "message": "User JohnDoe (123456789) has been removed from whitelist"
}
```

---

### 🔒 **5. Suspend User**

**Endpoint**: `POST /api/whitelist-manager?action=suspend`

**Body**:

```json
{
  "userId": "123456789"
}
```

**Response**:

```json
{
  "success": true,
  "message": "User 123456789 has been suspended",
  "data": {
    /* user object with status: "suspended" */
  }
}
```

---

### ✅ **6. Reactivate User**

**Endpoint**: `POST /api/whitelist-manager?action=reactivate`

**Body**:

```json
{
  "userId": "123456789"
}
```

**Response**:

```json
{
  "success": true,
  "message": "User 123456789 has been reactivated",
  "data": {
    /* user object with status: "active" */
  }
}
```

---

### ℹ️ **7. Get User Info**

**Endpoint**: `GET /api/whitelist-manager?action=info&userId=123456789`

**Response**:

```json
{
  "userId": "123456789",
  "username": "JohnDoe",
  "type": "vip",
  "status": "active"
  /* ... user details ... */
}
```

---

## 👥 User Types

### 🔴 **Owner**

- **User ID**: 9268011358 (hardcoded)
- **Access**: Unlimited, bypass all checks
- **Redis Commands**: 0 (tidak kena database check)
- **Whitelist**: Tidak perlu

### 💎 **VIP**

- **Access**: Full access to all features
- **Restrictions**: Configurable (maxDevices, IP tracking, etc)
- **Redis Commands**: 1 per login

### ⭐ **Premium**

- **Access**: Similar to VIP
- **Restrictions**: Customizable
- **Use Case**: Upgraded atau paid members

### 🟢 **Standard**

- **Access**: Basic access
- **Restrictions**: More limited
- **Use Case**: Trial atau basic members

---

## 🛠️ Technical Details

### Architecture

```
User Login
    ↓
Check if Owner (9268011358)
    ↓ NO
Check Redis Whitelist
    ↓ FOUND
Verify Status = 'active'
    ↓ YES
Grant Access ✅
```

### Redis Storage

**Key Structure**:

- `starship:whitelist` - All VIP users (JSON object)
- `starship:metadata` - Stats & metadata

**Example Data**:

```javascript
{
  "starship:whitelist": {
    "123456789": { /* user data */ },
    "987654321": { /* user data */ }
  },
  "starship:metadata": {
    "totalWhitelisted": 2,
    "lastUpdated": "2025-12-14T12:00:00Z"
  }
}
```

### Database: Redis Labs

- **Provider**: Redis Labs (via Vercel Marketplace)
- **Connection**: Non-TLS (port 14973)
- **Library**: ioredis v5.3.2
- **Commands**: GET, SET (simple, reliable)

### Environment Variables

Required in Vercel:

```env
ADMIN_SECRET=your_secret_here
REDIS_URL=redis://default:PASSWORD@redis-xxxxx.cloud.redislabs.com:14973
```

### Files

**API**:

- `api/whitelist-manager.js` - Main VIP management API
- `lib/redis.js` - Redis client initialization

**Frontend**:

- `public/panel-[hash].html` - Web dashboard (hidden/secured)

**Config**:

- `package.json` - Dependencies (ioredis)
- `vercel.json` - Deployment config

---

## 🔧 Troubleshooting

### ❌ "Redis not available"

**Problem**: Redis client failed to initialize

**Solution**:

1. Check `REDIS_URL` in Vercel environment variables
2. Verify Redis database is running (Vercel → Storage)
3. Check function logs for detailed error

---

### ❌ "Invalid admin credentials"

**Problem**: Wrong ADMIN_SECRET

**Solution**:

1. Check `ADMIN_SECRET` in Vercel environment variables
2. Use same secret in dashboard
3. Clear browser cache and try again

---

### ❌ "User already exists"

**Problem**: User ID sudah ada di whitelist

**Solution**:

1. Check existing users in dashboard
2. Use different User ID, atau
3. Update existing user instead of add new

---

### ❌ Dashboard tidak load users

**Problem**: CORS atau network issue

**Solution**:

1. Hard refresh: Ctrl+F5
2. Clear browser cache
3. Check browser console for errors
4. Verify deployment is complete (Vercel dashboard)

---

### ⚠️ Redis commands limit

**Current Usage**: ~20-50 commands/day (with owner bypass)

**Free Limit**: 10,000 commands/day

**Monitor**: Check Upstash/Redis Labs dashboard for usage stats

---

## ✅ Best Practices

### 1. **Security**

- ✅ Never share ADMIN_SECRET
- ✅ Use "Remember Secret" only on secure devices
- ✅ Regular audit of VIP users

### 2. **User Management**

- ✅ Set `expiresAt` for temporary access
- ✅ Use `Suspend` instead of Remove if you might reactive later
- ✅ Add notes untuk tracking purposes

### 3. **Performance**

- ✅ Owner bypass reduces Redis usage significantly
- ✅ Cache enabled in API (2 min TTL)
- ✅ Lazy loading for better response time

---

## 📊 Statistics & Monitoring

### Dashboard View:

- Total VIP users count
- Active vs Suspended users
- Recent additions
- Redis backend status

### Vercel Function Logs:

- Redis connection status
- API request logs
- Error tracking

### Redis Dashboard:

- Commands used today
- Memory usage
- Connection status

---

## 🎉 Success!

Sistem VIP Management Anda sudah **production-ready**!

### What You Can Do Now:

1. ✅ Add unlimited VIP users via dashboard
2. ✅ Manage users (edit, suspend, remove)
3. ✅ Monitor all users in one place
4. ✅ Data persists permanently
5. ✅ Owner bypass for zero Redis commands

---

## 📞 Support

Jika ada issues atau questions:

1. Check Vercel function logs
2. Check Redis Labs dashboard
3. Review this documentation
4. Check browser console for frontend errors

---

**Made with ❤️ for StarshipCore**  
**Powered by Redis Labs + Vercel + ioredis**

🚀 Happy VIP Managing!
