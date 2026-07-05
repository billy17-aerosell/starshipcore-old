# Security Fix Status - StarshipCore
**Tanggal Audit:** 12 Maret 2026  
**Terakhir Diupdate:** 12 Maret 2026

---

## Sudah Diperbaiki (Aman untuk Deploy)

### 1. Host Header Bypass — `cloud-chunk-m3p7.js` & `cloud-store-x7k9.js`
**Sebelum:**
```js
const IS_DEV = process.env.NODE_ENV === 'development' || req.headers.host?.includes('localhost');
```
**Sesudah:**
```js
const IS_DEV = process.env.NODE_ENV === 'development';
```
**File:** `api/cloud-chunk-m3p7.js`, `api/cloud-store-x7k9.js`

---

### 2. DEV_SECRET Hardcoded Fallback — `get-module.js`
**Sebelum:**
```js
const devSecret = process.env.DEV_SECRET || "starship-dev-2025";
const isLocalhost = req.headers.host?.includes("localhost") || ...;
const isDevMode = isLocalhost || dev === devSecret;
```
**Sesudah:**
```js
const isDevEnv = process.env.NODE_ENV === "development";
const isLocalhost = isDevEnv;
const devSecret = process.env.DEV_SECRET;
const isDevMode = isDevEnv || (devSecret && dev === devSecret);
```
**File:** `api/get-module.js`

---

### 3. VIP Duration Manipulation (Saweria) — `saweria-webhook.js`
**Masalah:** Hacker bisa buat pending order dengan amount 3 hari tapi claim durasi lifetime.  
**Fix:** Validasi `amount` vs `duration` berdasarkan `PRICING` config (toleransi 5%).  
**File:** `api/saweria-webhook.js`

---

### 4. VIP Timer UI Manipulation (Mobile) — `load.js` + `MobileUI.lua`
**Masalah:** Hacker intercept response auth, ubah `duration: "3 days"` jadi `"30 days"` → timer UI menampilkan durasi palsu.  
**Fix Server:** Tambah `vipExpiry` (timestamp absolut dari server) di response periodic check.  
**Fix Client:** `MobileUI.lua` sekarang prioritas `_G.StarshipServerExpiry` dari periodic check, bukan duration string.  
**File:** `api/load.js` (line ~733-740), `data/MobileUI.lua`

---

### 5. Honeypot Terlalu Obvious — `crypto-utils.js`
**Sebelum:**
```json
{
  "__debug_22341a9d": {
    "decryption_key": "...",
    "bypass_token": "...",
    "_warning": "TRAP_DETECTED"
  },
  "__trap_22341a9d": "TRAP_1773283400236_..."
}
```
**Sesudah:**
```json
{
  "_dk_1c2190a8": "8f88c781...",
  "_bt_1c2190a8": "2d2604e2...",
  "_sk": "1DNrIxR9..."
}
```
**Alasan:** Field lama terlalu obvious (ada tulisan "TRAP_DETECTED", "bypass_token") → hacker langsung tahu itu jebakan.  
**File:** `lib/crypto-utils.js`

---

### 6. STARSHIP_SECRET_KEY Hardcoded Fallback — `crypto-utils.js`
**Sebelum (3 tempat):**
```js
const secretKey = process.env.STARSHIP_SECRET_KEY || 'starship_default_secret_key_change_in_production';
```
**Sesudah:**
```js
const secretKey = process.env.STARSHIP_SECRET_KEY;
if (!secretKey) throw new Error('STARSHIP_SECRET_KEY environment variable is required');
```
**Syarat deploy:** `STARSHIP_SECRET_KEY` harus sudah di-set di Vercel env (sudah ✅).  
**File:** `lib/crypto-utils.js` (fungsi `createSecurePayload`, `verifySecurePayload`, `verifyTokenFromClient`)

---

## Pending — Perlu Update Loader (Deploy Bersamaan)

> **PENTING:** Semua fix di bawah ini membutuhkan update client (Loader/MobileUI). 
> Jangan deploy satu per satu — deploy **sekaligus** dalam satu update besar agar tidak break user aktif.

### 7. XOR Key di Response (PC Module Delivery)
**Masalah:** Response `get-module` mengirim `key` + `blob` bersamaan → siapa pun yang intercept bisa decrypt source code dengan Python/CyberChef dalam hitungan detik.  
**Bukti:** Script `tools/decrypt-module.py` bisa decrypt module hanya dari response JSON.  
**Solusi:**
- Server: Encrypt module pakai `BUNDLE_KEY` (sudah diketahui server + Loader)
- Server: Kirim **hanya `blob`** tanpa `key` di response
- Loader: Decrypt pakai `BUNDLE_KEY` yang sudah di-embed
- **Butuh update:** `api/get-module.js` + `protected/Loader-obfuscated.lua`

### 8. Mobile Module Plain Text
**Masalah:** Mobile module dikirim tanpa enkripsi (plain text Lua).  
**Solusi:**
- Server: Encrypt mobile module dengan XOR (atau AES)
- mobile-loader.lua: Tambah fungsi decrypt (sudah disiapkan `xorDecrypt` di mobile-loader.lua)
- **Butuh update:** `api/get-module.js` + `protected/mobile-loader.lua`

### 9. Periodic Check Tidak Di-sign
**Masalah:** Response periodic check (`/api/m-auth-k5r9z7?action=check`) berupa plain JSON tanpa signature:
```json
{"success":true,"isBanned":false,"isVIP":true,"vipExpiry":1773826579}
```
Bisa di-intercept dan diubah (hanya UI timer, bukan akses).  
**Solusi:**
- Server: Bungkus response periodic check dalam `createSecurePayload()` 
- Client: Update MobileUI.lua untuk parse format signed (`response.p.d.vipExpiry` bukan `response.vipExpiry`)
- **Dampak jika tidak fix:** Hanya UI manipulation (timer), akses tetap dikontrol server
- **Butuh update:** `api/load.js` + `data/MobileUI.lua`

~~### 10. Sign Periodic Check di PC~~ — **Tidak perlu**, hanya mobile yang perlu diubah.

---

## Tidak Bisa Dicegah (Nature of Roblox Executor)

### 11. loadstring / HttpGet Hook
**Masalah:** Hacker bisa hook `loadstring` atau `game.HttpGet` di executor untuk dump semua source code.  
**Realita:** Ini tidak bisa dicegah karena executor mengontrol environment Lua.  
**Mitigasi yang sudah ada:**
- ✅ Obfuscation (Loader-obfuscated.lua)
- ✅ Watermark system (bisa lacak leaker)
- ⚠️ Obfuscation belum diterapkan ke semua file (lihat audit report)

---

## Checklist Saat Siap Update Loader

Saat kamu siap update Loader + MobileUI ke production, lakukan semua ini **sekaligus:**

- [ ] Implement BUNDLE_KEY encryption di `get-module.js` (PC)
- [ ] Update PC Loader untuk decrypt pakai BUNDLE_KEY (tanpa key di response)
- [ ] Implement XOR/AES encryption untuk mobile module di `get-module.js`
- [ ] Update mobile-loader.lua untuk decrypt module (fungsi sudah disiapkan)
- [ ] Sign periodic check response di `load.js` pakai `createSecurePayload()`
- [ ] Update MobileUI.lua untuk parse format signed periodic check
- [ ] Obfuscate semua file Lua yang di-serve ke client
- [ ] Test semua flow: PC login, mobile login, periodic check, module loading
- [ ] Deploy server changes + update Loader script bersamaan

---

## Temuan Audit Lain yang Belum Diperbaiki

Lihat detail lengkap di `docs/SECURITY-AUDIT-2026-03-12.md`

| # | Risiko | Temuan | Status |
|---|--------|--------|--------|
| 1 | KRITIS | `.env.example` berisi secret asli | ⚠️ Repo private, tapi tetap ganti ke placeholder |
| 2 | KRITIS | R2 credentials hardcoded di scripts | ⚠️ Sengaja untuk dev workflow |
| 3 | KRITIS | ADMIN_SECRET fallback `CHANGE_ME_PLEASE` | Belum diperbaiki |
| 4 | KRITIS | CDN token fail-open saat Redis down | Belum diperbaiki |
| 5 | KRITIS | loadstring dari URL GitHub pihak ketiga | Belum diperbaiki |
| 6 | TINGGI | roblox-user.js ekspos VIP status tanpa auth | Belum diperbaiki |
| 7 | TINGGI | Nonce tracking in-memory (hilang cold start) | Belum diperbaiki |
| 8 | TINGGI | Watermark XOR(42) trivial di-reverse | Belum diperbaiki |
| 9 | TINGGI | DELETE recording tanpa ownership check | Belum diperbaiki |
| 10 | TINGGI | R2 Event Code leak ke VIP users | Belum diperbaiki |

---

## Ide Pengembangan: Anti-HttpSpy Stealth System (Future)

Rencana untuk membuat komunikasi API benar-benar "tidak terlihat" atau tidak berguna bagi pengintip (HttpSpy):

### 1. Pure Lua Encryption (XOR/Modified XOR)
- **Konsep:** Menggunakan algoritme enkripsi yang ditulis murni dalam Lua (tanpa library `crypt` eksternal).
- **Keuntungan:** Support 100% di semua executor (Mobile & PC) tanpa perlu fitur library tinggi.
- **Target:** Mengacak semua payload request sebelum dikirim ke URL.

### 2. Request Wrapper (Global `request` usage) - STEALTH METHOD
- **Konsep:** Membungkus semua Http call menggunakan fungsi global `request()` (atau `syn.request`, `fluxus.request`) alih-alih `game:HttpGet`.
- **Keuntungan:** Fungsi-fungsi ini disuntikkan langsung oleh executor dan berada di luar "radar" engine Roblox. Mayoritas HttpSpy hanya memantau `game:HttpGet`, sehingga penggunaan fungsi global ini seringkali **tidak muncul sama sekali di log HttpSpy**.

### 3. Header-Based & Body Data Transmission
- **Konsep:** Memindahkan data sensitif (seperti `key`, `userId`, `action`) dari URL (Query String) ke dalam Custom Headers atau POST Body.
- **Keuntungan:** 
    - **Headers:** Menghindari log URL yang panjang dan eksplosif. Spy biasanya hanya menampilkan URL di layar utama; parameter di header tetap tersembunyi kecuali user sengaja menginspeksi detail request.
    - **POST Body:** Benar-benar menyembunyikan data di dalam "Payload", bukan di baris alamat. Sangat efektif dikombinasikan dengan enkripsi XOR.

### 4. Dynamic/Time-Based Encryption Keys
- **Konsep:** Kunci enkripsi berubah secara dinamis berdasarkan timestamp (misalnya per jam).
- **Keuntungan:** Mencegah Anti-Replay attack. Meskipun pengintip mendapatkan payload terenkripsi, kunci tersebut tidak akan berlaku lagi dalam waktu singkat.

### 5. Encrypted Response Body (Lua Stealth Load)
- **Konsep:** Server tidak lagi mengembalikan kode Lua mentah agar tidak terbaca saat di-intercept. Server mengembalikan "Encrypted Blob".
- **Keuntungan:** Di HttpSpy, hacker hanya melihat karakter acak/biner ("kotak-kotak"), bukan logic source code Anda. Script di klien akan men-decrypt blob ini di memori sebelum memanggil `loadstring()`.

### 6. Function Integrity & Hook Detection
- **Konsep:** Memeriksa integritas fungsi komunikasi menggunakan `debug.info` untuk mendeteksi apakah fungsi seperti `game.HttpGet` atau `loadstring` telah di-hook oleh script luar (seperti HttpSpy).
- **Keuntungan:** Script bisa mendeteksi jika sedang dipantau dan secara otomatis menghentikan proses, memberikan data palsu (fake data), atau mengubah jalur komunikasi ke mode stealth secara otomatis.

