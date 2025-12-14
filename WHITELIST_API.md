# 🎯 Whitelist Management API Documentation

API endpoint untuk mengelola VIP users dan whitelisted users di StarshipCore.

## 🔐 Authentication

Semua request memerlukan **admin secret key** di header:

```
X-Admin-Secret: YOUR_ADMIN_SECRET
```

⚠️ **PENTING**: Ganti `ADMIN_SECRET` di environment variables Anda!

---

## 📋 Available Endpoints

Base URL: `/api/whitelist-manager`

### 1️⃣ **List All Whitelisted Users**

Menampilkan semua user yang ada di whitelist.

**Request:**

```bash
GET /api/whitelist-manager?action=list
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
```

**Response:**

```json
{
  "whitelist": {
    "9268011358": {
      "userId": "9268011358",
      "username": "DEV/Owner",
      "type": "owner",
      "status": "active",
      "addedAt": "2024-12-14T11:05:00Z",
      "expiresAt": null,
      "restrictions": {
        "maxDevices": null,
        "ipTracking": false,
        "webhookNotify": false
      },
      "permissions": {
        "bypassAll": true,
        "unlimitedAccess": true,
        "noLogging": false
      },
      "notes": "Developer/Owner"
    }
  },
  "metadata": {
    "totalWhitelisted": 1,
    "lastUpdated": "2024-12-14T11:05:00Z"
  }
}
```

---

### 2️⃣ **Add New VIP User**

Menambahkan user baru ke whitelist.

**Request:**

```bash
POST /api/whitelist-manager?action=add
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
  Content-Type: application/json
Body:
{
  "userId": "123456789",
  "username": "VIP User 1",
  "type": "vip",
  "expiresAt": "2026-12-14T00:00:00Z",
  "maxDevices": 5,
  "ipTracking": true,
  "webhookNotify": true,
  "notes": "VIP Member - Annual subscription"
}
```

**Field Descriptions:**

- `userId` (required): Roblox User ID
- `username` (required): Username atau display name
- `type` (optional): Tipe user - `"vip"`, `"premium"`, `"owner"`, `"standard"` (default: `"vip"`)
- `expiresAt` (optional): Tanggal expired (ISO format) atau `null` untuk lifetime
- `maxDevices` (optional): Max device yang bisa digunakan (default: 5)
- `ipTracking` (optional): Track IP address? (default: true)
- `webhookNotify` (optional): Kirim notifikasi webhook? (default: true)
- `bypassAll` (optional): Bypass semua restrictions? (default: false)
- `unlimitedAccess` (optional): Unlimited access? (default: false)
- `noLogging` (optional): Disable logging? (default: false)
- `notes` (optional): Catatan tambahan

**Response:**

```json
{
  "success": true,
  "message": "User VIP User 1 (123456789) has been whitelisted",
  "data": {
    "userId": "123456789",
    "username": "VIP User 1",
    "type": "vip",
    "status": "active",
    "addedAt": "2025-12-14T18:16:00Z",
    "expiresAt": "2026-12-14T00:00:00Z",
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
    "notes": "VIP Member - Annual subscription"
  }
}
```

---

### 3️⃣ **Update Whitelisted User**

Update informasi user yang sudah ada di whitelist.

**Request:**

```bash
PUT /api/whitelist-manager?action=update
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
  Content-Type: application/json
Body:
{
  "userId": "123456789",
  "username": "VIP User Updated",
  "type": "premium",
  "expiresAt": "2027-01-01T00:00:00Z",
  "maxDevices": 10,
  "notes": "Upgraded to premium"
}
```

**Response:**

```json
{
  "success": true,
  "message": "User 123456789 has been updated",
  "data": {
    "userId": "123456789",
    "username": "VIP User Updated",
    "type": "premium",
    "status": "active",
    "addedAt": "2025-12-14T18:16:00Z",
    "updatedAt": "2025-12-14T18:20:00Z",
    "expiresAt": "2027-01-01T00:00:00Z",
    "restrictions": {
      "maxDevices": 10,
      "ipTracking": true,
      "webhookNotify": true
    },
    "permissions": {
      "bypassAll": false,
      "unlimitedAccess": false,
      "noLogging": false
    },
    "notes": "Upgraded to premium"
  }
}
```

---

### 4️⃣ **Get User Info**

Mendapatkan detail info user tertentu.

**Request:**

```bash
GET /api/whitelist-manager?action=info&userId=123456789
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
```

**Response:**

```json
{
  "userId": "123456789",
  "username": "VIP User 1",
  "type": "vip",
  "status": "active",
  "addedAt": "2025-12-14T18:16:00Z",
  "expiresAt": "2026-12-14T00:00:00Z",
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
  "notes": "VIP Member"
}
```

---

### 5️⃣ **Suspend User**

Suspend user tanpa menghapusnya dari whitelist (status jadi `suspended`).

**Request:**

```bash
POST /api/whitelist-manager?action=suspend
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
  Content-Type: application/json
Body:
{
  "userId": "123456789"
}
```

**Response:**

```json
{
  "success": true,
  "message": "User 123456789 has been suspended",
  "data": {
    "userId": "123456789",
    "status": "suspended",
    "suspendedAt": "2025-12-14T18:25:00Z"
  }
}
```

---

### 6️⃣ **Reactivate User**

Aktifkan kembali user yang di-suspend.

**Request:**

```bash
POST /api/whitelist-manager?action=reactivate
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
  Content-Type: application/json
Body:
{
  "userId": "123456789"
}
```

**Response:**

```json
{
  "success": true,
  "message": "User 123456789 has been reactivated",
  "data": {
    "userId": "123456789",
    "status": "active",
    "reactivatedAt": "2025-12-14T18:30:00Z"
  }
}
```

---

### 7️⃣ **Remove User**

Hapus user dari whitelist secara permanen.

**Request:**

```bash
DELETE /api/whitelist-manager?action=remove
Headers:
  X-Admin-Secret: YOUR_ADMIN_SECRET
  Content-Type: application/json
Body:
{
  "userId": "123456789"
}
```

**Response:**

```json
{
  "success": true,
  "message": "User VIP User 1 (123456789) has been removed from whitelist"
}
```

---

## 💡 Example Usage with cURL

### Add VIP User:

```bash
curl -X POST "https://your-domain.vercel.app/api/whitelist-manager?action=add" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "987654321",
    "username": "JohnDoe_VIP",
    "type": "vip",
    "expiresAt": "2026-12-31T23:59:59Z",
    "maxDevices": 3,
    "notes": "Premium member - Monthly subscription"
  }'
```

### List All:

```bash
curl -X GET "https://your-domain.vercel.app/api/whitelist-manager?action=list" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET"
```

### Suspend User:

```bash
curl -X POST "https://your-domain.vercel.app/api/whitelist-manager?action=suspend" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"userId": "987654321"}'
```

---

## 📊 User Types

- **`owner`**: Developer/Owner dengan full access
- **`vip`**: VIP member dengan akses premium
- **`premium`**: Premium member
- **`standard`**: User biasa

---

## 🔒 Security Notes

1. **Selalu gunakan HTTPS** di production
2. **Jangan share** admin secret key Anda
3. **Ganti default secret** `CHANGE_ME_PLEASE` dengan secret yang kuat
4. Set environment variable: `ADMIN_SECRET=your_super_secret_key`

---

## ✅ Testing

Test di localhost dulu sebelum deploy:

```bash
# Set environment variable
$env:ADMIN_SECRET = "test_secret_123"

# Start dev server
npm run dev

# Test endpoint
curl -X GET "http://localhost:3000/api/whitelist-manager?action=list" \
  -H "X-Admin-Secret: test_secret_123"
```

---

## 🚀 Next Steps

1. Set your `ADMIN_SECRET` in Vercel environment variables
2. Deploy the API
3. Test dengan Postman atau cURL
4. (Optional) Buat web dashboard untuk manage VIP users dengan UI

---

Made with ❤️ for StarshipCore
