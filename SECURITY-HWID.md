# 🔐 HWID Security Protection

## Masalah Keamanan yang Diperbaiki

### ⚠️ Vulnerability (Sebelumnya):

User jahat bisa **mencuri akses VIP** dengan cara:

1. Download Loader.lua
2. Edit code untuk mengganti User ID:

```lua
-- User jahat mengganti ini:
local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
-- Menjadi ini (User ID VIP orang lain):
local userId = "933775691193"
```

3. Mereka bisa akses script menggunakan VIP orang lain! 💥

---

## ✅ Solusi: HWID Binding

### Cara Kerja:

1. **First Login**: VIP user login pertama kali → Server otomatis bind HWID mereka
2. **Next Login**: Server validate HWID → Hanya HWID yang terdaftar yang boleh akses
3. **Jika HWID berbeda**: Access DITOLAK ❌

### Flow Keamanan:

```
VIP User Login (Device A)
    ↓
Server: "HWID belum terdaftar, bind ke Device A"
    ↓
✅ Access Granted + HWID disimpan

---

User Jahat Login (Device B) dengan User ID curian
    ↓
Server: "HWID tidak match! Expected: Device A, Got: Device B"
    ↓
❌ ACCESS DENIED: Device Not Authorized
```

---

## 📋 Implementasi

### Client Side (Loader.lua)

- Deteksi HWID menggunakan executor functions:
  - `gethwid()` - Most executors
  - `syn.crypt.hash()` - Synapse X
  - `GenerateGUID()` - Fallback
- Kirim HWID ke server via query parameter

### Server Side (api/load.js)

- Validate HWID untuk setiap VIP request
- Auto-bind HWID pada first login
- Reject jika HWID mismatch
- Save HWID binding ke Redis

---

## 🛠️ Reset Device Binding

Jika VIP user ganti device, admin bisa reset HWID via:

1. Redis Manager
2. Whitelist Manager API
3. Manual: Hapus field `hwid` dari user data di Redis

---

## 🎯 Benefit

✅ **Prevent VIP Theft** - User tidak bisa fake User ID  
✅ **Device Binding** - 1 VIP = 1 Device (bisa diatur multi-device nanti)  
✅ **Auto Protection** - Tidak perlu setup manual  
✅ **Transparent** - VIP users tidak perlu konfigurasi apapun

---

## ⚙️ Configuration (Future Enhancement)

Bisa ditambahkan nanti:

- `maxDevices`: Allow multiple devices per VIP
- `allowDeviceReset`: User bisa reset sendiri setiap X hari
- `deviceWhitelist`: List HWID yang diizinkan per user
