# 🚀 Quick Start - VIP Management

## Cara Tercepat Menambahkan VIP User

### Opsi 1: Menggunakan Web Dashboard (RECOMMENDED) ⭐

1. **Buka Dashboard**

   - URL: `https://www.starship-core.my.id/vip-dashboard.html`

2. **Login dengan Admin Secret**

   - Masukkan `ADMIN_SECRET` Anda di field yang tersedia
   - Klik "Connect & Load Users"

3. **Tambah VIP User**

   - Isi form:
     - **User ID**: Roblox User ID (contoh: `123456789`)
     - **Username**: Username user (contoh: `JohnDoe_VIP`)
     - **Type**: Pilih `vip`, `premium`, atau `standard`
     - **Expires At**: Tanggal expired (kosongkan untuk lifetime)
     - **Max Devices**: Maksimal device (default: 5)
     - **Notes**: Catatan tambahan
   - Klik "Add VIP User"

4. **Done!** ✅
   - User langsung bisa akses tanpa key

---

### Opsi 2: Manual Edit File (Cepat tapi Risky)

1. Buka file: `data/keys.json`

2. Tambahkan di bagian `"whitelist"`:

```json
{
  "keys": {},
  "whitelist": {
    "9268011358": {
      // ... (existing owner)
    },
    "123456789": {
      "userId": "123456789",
      "username": "NewVIP_User",
      "type": "vip",
      "status": "active",
      "addedAt": "2025-12-14T18:15:00Z",
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
      "notes": "VIP Member"
    }
  },
  "metadata": {
    "totalKeys": 0,
    "activeKeys": 0,
    "totalWhitelisted": 2, // Update ini!
    "lastUpdated": "2025-12-14T18:15:00Z"
  }
}
```

3. **PENTING**: Update `totalWhitelisted` di metadata!

---

### Opsi 3: Menggunakan cURL / API

```bash
curl -X POST "https://www.starship-core.my.id/api/whitelist-manager?action=add" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "123456789",
    "username": "NewVIP_User",
    "type": "vip",
    "expiresAt": null,
    "maxDevices": 5,
    "notes": "VIP Member - Monthly subscription"
  }'
```

---

## 📋 Common Operations

### Melihat Semua VIP Users

**Via Dashboard:**

- Buka dashboard → Login → Otomatis tampil semua users

**Via API:**

```bash
curl "https://www.starship-core.my.id/api/whitelist-manager?action=list" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET"
```

---

### Suspend VIP User (Sementara)

**Via Dashboard:**

- Klik tombol "⏸️ Suspend" pada user card

**Via API:**

```bash
curl -X POST "https://www.starship-core.my.id/api/whitelist-manager?action=suspend" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"userId": "123456789"}'
```

---

### Aktifkan Kembali User

**Via Dashboard:**

- Klik tombol "▶️ Reactivate" pada user card

**Via API:**

```bash
curl -X POST "https://www.starship-core.my.id/api/whitelist-manager?action=reactivate" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"userId": "123456789"}'
```

---

### Hapus VIP User (Permanent)

**Via Dashboard:**

- Klik tombol "🗑️ Remove" pada user card
- Confirm dialog

**Via API:**

```bash
curl -X DELETE "https://www.starship-core.my.id/api/whitelist-manager?action=remove" \
  -H "X-Admin-Secret: YOUR_ADMIN_SECRET" \
  -H "Content-Type: application/json" \
  -d '{"userId": "123456789"}'
```

---

## 🎯 Tipe-Tipe User

| Type       | Deskripsi       | Use Case                                |
| ---------- | --------------- | --------------------------------------- |
| `owner`    | Developer/Owner | Full unlimited access, bypass all rules |
| `vip`      | VIP Member      | Premium features, higher device limit   |
| `premium`  | Premium User    | Paid subscription users                 |
| `standard` | Standard User   | Basic whitelisted users                 |

---

## ⚙️ Field Explanations

### `expiresAt`

- `null` = Lifetime access (tidak pernah expired)
- `"2026-12-31T23:59:59Z"` = Expired di tanggal tertentu (ISO format)

### `maxDevices`

- Maksimal jumlah device/IP yang bisa digunakan per hari
- `5` = Default (recommended)
- `null` = Unlimited (untuk owner)

### `status`

- `active` = User bisa akses
- `suspended` = User tidak bisa akses sementara
- System otomatis cek status ini

### `permissions`

- `bypassAll`: Skip semua validations
- `unlimitedAccess`: Unlimited device
- `noLogging`: Jangan log aktivitas user ini

---

## 🔒 Security Tips

1. **Jangan share `ADMIN_SECRET`** dengan siapapun
2. **Gunakan HTTPS** untuk semua API calls
3. **Regular monitoring** - Check dashboard secara berkala
4. **Backup `keys.json`** secara rutin

---

## ❓ FAQ

**Q: Bagaimana cara mendapatkan Roblox User ID?**

- Kunjungi profile user di Roblox
- Lihat di URL: `roblox.com/users/[USER_ID]/profile`

**Q: Apakah VIP user masih bisa menggunakan key?**

- Ya! Whitelist dan key system berjalan bersamaan
- User bisa akses dengan salah satu: whitelisted UserID ATAU valid key

**Q: Bagaimana caranya upgrade user dari VIP ke Premium?**

- Via Dashboard: Update type field
- Via API: Gunakan action `update` dengan type baru

**Q: Apakah ada limit jumlah VIP users?**

- Tidak ada limit! Tambahkan sebanyak yang Anda mau

---

## 📚 Full Documentation

Untuk dokumentasi lengkap, lihat:

- [`WHITELIST_API.md`](./WHITELIST_API.md) - Complete API reference
- [`KEY_AUTH_README.md`](./KEY_AUTH_README.md) - Full system documentation

---

**Last Updated**: 2025-12-14  
**Made with ❤️ for StarshipCore**
