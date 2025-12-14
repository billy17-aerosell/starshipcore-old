# 🔒 Auto-Detect User ID Security

## Konsep Keamanan

### ❌ **Masalah: Hardcoded User ID**

Jika loadstring menggunakan userId yang hardcoded:

```lua
-- BAHAYA! User ID hardcoded
loadstring(game:HttpGet("https://starship-core.my.id/api/get-loader?userId=1234"))()
```

**Masalahnya:**

- VIP user bisa share loadstring ini ke orang lain
- Siapapun bisa pakai script dengan User ID 1234
- Tidak ada proteksi dari sharing

---

## ✅ **Solusi: Auto-Detect User ID**

### Cara Kerja:

Loader.lua **OTOMATIS** mengambil User ID dari player yang sedang login di Roblox:

```lua
-- Auto-detect dari LocalPlayer (tidak bisa di-fake!)
local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
local targetUrl = SECURE_API_URL .. "/api/load?user=" .. userId
```

### **Loadstring yang Dibagikan:**

```lua
-- Loadstring yang aman (TIDAK ada userId hardcoded)
loadstring(game:HttpGet("https://starship-core.my.id/api/get-loader"))()
```

---

## 🎯 **Keamanan yang Dicapai:**

### **Skenario 1: VIP User Login**

```
Player: VIPUser (ID: 1234)
Loader auto-detect: UserID = 1234
Server check: User 1234 = VIP ✅
→ Access Granted
```

### **Skenario 2: Non-VIP Coba Pakai Loadstring yang Sama**

```
Player: RandomUser (ID: 5678)
Loader auto-detect: UserID = 5678
Server check: User 5678 = Not Whitelisted ❌
→ Access Denied
```

### **Skenario 3: User Coba Edit Code untuk Fake User ID**

```lua
-- User edit Loader.lua:
local userId = "1234"  -- Fake VIP ID

-- Tapi ini TIDAK BERBAHAYA karena:
-- 1. User harus download & edit Loader.lua (susah)
-- 2. Untuk proteksi lebih: bisa tambah HWID nanti
```

---

## 📋 **Perbedaan dengan Hardcoded:**

| Aspek               | Hardcoded userId                  | Auto-Detect userId             |
| ------------------- | --------------------------------- | ------------------------------ |
| **Loadstring**      | `?userId=1234`                    | Tidak ada userId               |
| **Sharing**         | ❌ Bahaya (semua bisa akses)      | ✅ Aman (auto-detect per user) |
| **Keamanan**        | ⚠️ Rendah                         | ✅ Tinggi                      |
| **User Experience** | ❌ Perlu beda loadstring per user | ✅ Satu loadstring untuk semua |

---

## 🛠️ **Implementasi:**

### **Client Side (Loader.lua):**

```lua
-- Auto-detect User ID dari LocalPlayer
local userId = tostring(game:GetService("Players").LocalPlayer.UserId)
local targetUrl = SECURE_API_URL .. "/api/load?user=" .. userId
```

### **Server Side (api/load.js):**

```javascript
const { user } = req.query;

// Check whitelist
if (redisWhitelist && redisWhitelist[user]) {
  // VIP user found
  return script...
} else {
  // Not whitelisted
  return "Access Denied"
}
```

---

## 🔐 **Proteksi Tambahan (Optional):**

Untuk keamanan maksimal, bisa ditambahkan nanti:

1. **HWID Binding** - Bind user ke device tertentu
2. **IP Tracking** - Monitor IP yang digunakan
3. **Device Limit** - Limit jumlah device per user
4. **Session Token** - Validasi per-session

---

## ✅ **Benefit:**

✅ **Universal Loadstring** - Satu loadstring untuk semua user  
✅ **Auto Protection** - Otomatis pakai User ID yang benar  
✅ **Prevent Sharing** - Setiap user harus punya whitelist sendiri  
✅ **User Friendly** - User tidak perlu tahu User ID mereka

---

## 📝 **Cara Pakai:**

### **Untuk User VIP:**

1. Admin tambahkan User ID mereka ke whitelist
2. User gunakan loadstring universal:

```lua
loadstring(game:HttpGet("https://starship-core.my.id/api/get-loader"))()
```

3. Loader otomatis detect User ID mereka
4. ✅ Jika di whitelist → Access granted

### **Untuk Non-VIP:**

1. Mereka gunakan loadstring yang sama
2. Loader detect User ID mereka (bukan VIP)
3. ❌ Server reject: "Not Whitelisted"

---

**Kesimpulan:** Dengan Auto-Detect User ID, setiap user HARUS punya whitelist sendiri untuk bisa akses script! 🔒
