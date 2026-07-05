# Security Audit Report - StarshipCore
**Tanggal:** 12 Maret 2026  
**Auditor:** Cursor AI Agent  
**Scope:** Full-stack audit (API, Lua, Crypto, Cloudflare, Public, Tools, Discord, Recording)

---

## Daftar Isi
1. [Ringkasan Eksekutif](#1-ringkasan-eksekutif)
2. [API & Backend](#2-api--backend)
3. [Lua Client](#3-lua-client)
4. [Data & Storage](#4-data--storage)
5. [Public & Static](#5-public--static)
6. [Webhook & Integrasi Eksternal](#6-webhook--integrasi-eksternal)
7. [Cloudflare Worker & R2 CDN](#7-cloudflare-worker--r2-cdn)
8. [Hardcoded Credentials](#8-hardcoded-credentials--kritis)
9. [Crypto & Enkripsi](#9-crypto--enkripsi)
10. [HWID / Device Fingerprint](#10-hwid--device-fingerprint)
11. [Watermark System](#11-watermark-system)
12. [Obfuscated vs Non-obfuscated](#12-obfuscated-vs-non-obfuscated)
13. [Game Modules](#13-game-modules)
14. [Tools & Scripts Lokal](#14-tools--scripts-lokal)
15. [DiscordGambleBot & DiscordPresence](#15-discordgamblebot--discordpresence)
16. [Recording System](#16-recording-system)
17. [Ringkasan & Prioritas](#17-ringkasan--prioritas)

---

## 1. Ringkasan Eksekutif

Audit ini menemukan **8 temuan KRITIS**, **10 temuan TINGGI**, **8 temuan SEDANG**, dan **6 temuan RENDAH**. 

Masalah paling mendesak:
- **Secret/credential asli** terekspos di `.env.example`, `scripts/local-upload-server.js`, dan `bulk-upload-r2.js`
- **Fail-open pattern** di CDN token verification (Redis down = akses diberikan)
- **DEV mode bypass** via spoofing `Host: localhost` header
- **Endpoint publik** mengekspos data sensitif tanpa autentikasi
- **`loadstring` dari URL GitHub pihak ketiga** di file Lua (supply chain attack risk)

---

## 2. API & Backend

### 2.1 `api/whitelist-manager.js`

**[Risiko: KRITIS]** ADMIN_SECRET memiliki fallback hardcoded:
```js
const ADMIN_SECRET = process.env.ADMIN_SECRET || "CHANGE_ME_PLEASE";
```
→ Jika env var tidak di-set, admin panel bisa diakses dengan password `CHANGE_ME_PLEASE`.  
**Rekomendasi:** Hapus fallback, throw error jika ADMIN_SECRET tidak di-set.

**[Risiko: TINGGI]** `self_verify` dan `self_reset_hwid` tidak memerlukan autentikasi. Siapa pun yang tahu userId bisa reset HWID orang lain.  
**Rekomendasi:** Tambahkan verifikasi tambahan (captcha, Discord OAuth, atau rate limit ketat per IP).

### 2.2 `api/get-module.js`

**[Risiko: KRITIS]** DEV_SECRET fallback hardcoded:
```js
const devSecret = process.env.DEV_SECRET || "starship-dev-2025";
```
→ Attacker yang tahu string ini bisa bypass auth dan mendapatkan modul tanpa enkripsi.  
**Rekomendasi:** Hapus fallback, disable dev mode di production.

**[Risiko: TINGGI]** Mobile platform mengembalikan modul sebagai plain text tanpa enkripsi.  
**Rekomendasi:** Terapkan enkripsi untuk mobile sama seperti PC.

**[Risiko: SEDANG]** Dev mode mengekspos path file server di response error: `{ error: "Module file not found", path: modulePath }`.  
**Rekomendasi:** Jangan kembalikan path internal di response.

### 2.3 `api/pc-ld-q8r4.js`

**[Risiko: KRITIS]** `verify_cdn_token` **fail-open** saat Redis down atau error:
```js
// Fail-open on error
return res.status(200).json({ valid: true, reason: "Verification error" });
```
Dan saat Redis unavailable:
```js
if (!redisClient) {
    return res.status(200).json({ valid: true, reason: "Redis unavailable" });
}
```
→ Jika Redis mati (DDoS, maintenance), semua CDN token dianggap valid tanpa verifikasi.  
**Rekomendasi:** Ubah ke **fail-closed** — tolak request jika tidak bisa verifikasi.

### 2.4 `api/cloud-chunk-m3p7.js` & `api/cloud-store-x7k9.js`

**[Risiko: KRITIS]** DEV mode bypass via `Host` header spoofing:
```js
const IS_DEV = process.env.NODE_ENV === 'development' || req.headers.host?.includes('localhost');
```
→ Attacker kirim `Host: localhost` → bypass seluruh autentikasi.  
**Rekomendasi:** Hapus pengecekan `Host` header. Hanya gunakan `NODE_ENV` env var.

**[Risiko: TINGGI]** `cloud-store-x7k9.js` DELETE endpoint tidak memvalidasi ownership — user dengan event code bisa menghapus recording user lain.  
**Rekomendasi:** Verifikasi bahwa `requestUserId === recording.userId` sebelum delete.

**[Risiko: SEDANG]** `recordingId` dari query string tidak di-sanitize — potensi path traversal di R2 key (`../../etc`).  
**Rekomendasi:** Sanitize recordingId, tolak karakter `../` dan non-alphanumerik.

### 2.5 `api/roblox-user.js`

**[Risiko: TINGGI]** Endpoint sepenuhnya publik tanpa autentikasi. Mengekspos:
- Status VIP user
- `purchaseHistory`, `addedAt`, `updatedAt`, `expiresAt`
- `daysRemaining`, `isLifetime`

→ Siapa pun bisa query `/api/roblox-user?checkVip=true&userId=XXX` untuk mengecek status VIP user mana pun.  
**Rekomendasi:** Tambahkan autentikasi atau batasi field yang dikembalikan.

**[Risiko: SEDANG]** `userId` di-interpolate langsung ke URL Roblox tanpa sanitasi — potensi SSRF:
```js
const response = await fetch(`https://users.roblox.com/v1/users/${userId}`);
```
**Rekomendasi:** Validasi userId hanya berisi digit.

### 2.6 `api/saweria-webhook.js`

**[Risiko: TINGGI]** `create-pending-order` action tidak memerlukan autentikasi. Siapa pun bisa membuat pending order.  
**Rekomendasi:** Tambahkan auth check (ADMIN_SECRET atau token).

**[Risiko: SEDANG]** Seluruh request body dilog ke console: `console.log('Body:', JSON.stringify(req.body, null, 2))`.  
**Rekomendasi:** Hapus logging body di production.

**[Risiko: SEDANG]** Toleransi harga 10% (`0.90 - 1.10`) bisa dimanipulasi jika attacker bisa membuat order dengan harga sedikit di bawah target.  
**Rekomendasi:** Perkecil toleransi atau gunakan exact matching.

### 2.7 `api/load.js`

**[Risiko: SEDANG]** `adminSecret` bisa dikirim via query parameter `?adminSecret=XXX` — akan terlog di access logs dan browser history.  
**Rekomendasi:** Hanya terima admin secret via header `X-Admin-Secret`.

**[Risiko: RENDAH]** BUNDLE_KEY preview (4 karakter pertama & terakhir) dilog ke console.  
**Rekomendasi:** Jangan log preview key.

### 2.8 `api/tags.js`

**[Risiko: TINGGI]** Batch VIP tag check tidak memerlukan autentikasi — siapa pun bisa cek status VIP banyak user sekaligus.  
**Rekomendasi:** Tambahkan auth atau rate limit ketat.

**[Risiko: RENDAH]** Discord Guild ID, Role IDs, Channel IDs, Client ID hardcoded. Ini bukan secret, tapi membantu attacker melakukan social engineering.  
**Rekomendasi:** Pindahkan ke environment variables.

### 2.9 `api/m-ui-v8x3q2.js` & `api/mobile-bootstrap.js`

**[Risiko: TINGGI]** R2 Event Code di-inject langsung ke script Lua yang dikirim ke client:
```js
const eventCodeInjection = `_G.StarshipEventCode = "${R2_EVENT_CODE}"\n`;
```
→ Semua VIP user bisa mengekstrak event code dari response.  
**Rekomendasi:** Jangan kirim event code ke client. Gunakan token-based system.

**[Risiko: SEDANG]** `mobile-bootstrap.js` — `statusMessage` dari Redis di-inject ke Lua tanpa escaping, potensi Lua injection jika attacker bisa memodifikasi Redis.  
**Rekomendasi:** Escape karakter khusus Lua (backslash, quote) pada statusMessage.

### 2.10 Rate Limiting & CORS

**[Risiko: SEDANG]** Tidak ada rate limiting global pada endpoint manapun. Hanya ada webhook cooldown parsial.  
**Rekomendasi:** Implementasikan rate limiting per IP menggunakan Vercel Edge Middleware atau Redis.

**[Risiko: RENDAH]** API headers sudah bagus: `Cache-Control: no-cache, no-store, must-revalidate` di-set via `vercel.json`. Route `/api/protected/*` di-redirect ke 404 ✓.

### 2.11 Dependencies

**[Risiko: RENDAH]** Package dependencies (`@aws-sdk/client-s3`, `ioredis`, `dotenv`) cukup standar dan umum. Tidak ditemukan CVE major yang diketahui saat ini. Namun disarankan menjalankan `npm audit` secara berkala.

---

## 3. Lua Client

### 3.1 `loadstring` dari URL Pihak Ketiga

**[Risiko: KRITIS]** Multiple file Lua melakukan `loadstring(game:HttpGet(...))()` dari URL GitHub pihak ketiga:

| File | URL |
|------|-----|
| `data/MobileUI.lua` | `https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua` |
| `data/StarSpace.lua` | `https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua` |
| `data/SambungKata.lua` | `https://raw.githubusercontent.com/Pixeluted/adoniscries/main/Source.lua` |
| `data/MobileUI.lua` | `https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal` |
| `data/MobileUI.lua` | `https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua` |

→ **Supply chain attack:** Jika repo pihak ketiga dikompromikan, kode berbahaya akan dieksekusi di semua client.  
**Rekomendasi:** Bundle semua library pihak ketiga di server sendiri. Jangan loadstring dari URL eksternal.

### 3.2 Hardcoded Secrets di Lua

**[Risiko: KRITIS]** `Loader.dev.lua` baris 4: `ENCRYPTION_KEY = "Starship_X7k9P2mQ_2025"` — kunci enkripsi hardcoded.  
**Rekomendasi:** Hapus file ini dari repository. Tambahkan ke `.gitignore`.

**[Risiko: TINGGI]** `data/StarSpace.lua` baris 594: XOR key `"SecretXorKey123"` terekspos dalam komentar.  
**Rekomendasi:** Hapus komentar yang mengandung secret.

### 3.3 Server URL Hardcoded

**[Risiko: RENDAH]** Beberapa file Lua memiliki `https://starship-core.my.id` hardcoded. Ini tidak kritis tapi membuat rotasi URL sulit.  
**Catatan:** `protected/mobile-loader.lua` menggunakan endpoint obfuscated names ✓ (baik).

---

## 4. Data & Storage

### 4.1 Redis

**[Risiko: SEDANG]** Koneksi Redis tanpa TLS (`lib/redis.js` komentar: "port 14973 is plain Redis").  
**Rekomendasi:** Aktifkan TLS jika provider mendukung.

**[Risiko: RENDAH]** Redis URL hanya dari env var ✓ (baik). Tidak ada hardcoded Redis credential.

### 4.2 File Fallback

**[Risiko: SEDANG]** `data/keys.json` dan `data/mobile-keys.json` ada di repo. Meskipun ada `.gitignore` untuk file sensitif, file ini sudah tercommit.  
**Rekomendasi:** Verifikasi bahwa file ini tidak berisi data sensitif production. Jika iya, hapus dari git history.

### 4.3 `data/private-access.json`

**[Risiko: SEDANG]** File bernama `private-access.json` ada di repo. Kemungkinan berisi data akses sensitif.  
**Rekomendasi:** Verifikasi isinya, hapus dari repo jika berisi credential.

---

## 5. Public & Static

### 5.1 Admin Dashboard (`public/x7k9-ctrl-m2p4.html`)

**[Risiko: SEDANG]** Dashboard admin dilindungi oleh ADMIN_SECRET via `X-Admin-Secret` header ✓. Login form ada ✓. URL obfuscated (`x7k9-ctrl-m2p4`) ✓.

**[Risiko: SEDANG]** Admin secret disimpan di `localStorage`:
```js
localStorage.setItem('starship_admin_secret', secret);
```
→ Rentan terhadap XSS — jika ada XSS vulnerability, attacker bisa mencuri admin secret.  
**Rekomendasi:** Gunakan session-based auth atau HTTP-only cookie.

**[Risiko: SEDANG]** Potensial XSS pada user table rendering:
```js
<div class="name">${user.username || 'Unknown'}</div>
```
→ Jika username mengandung HTML/JavaScript, bisa dieksekusi.  
**Rekomendasi:** Escape HTML entities pada semua data user sebelum rendering.

### 5.2 VIP Reset (`public/vip-reset.html`)

**[Risiko: RENDAH]** Cooldown 1 jam untuk reset HWID ✓. Confirmation modal ✓. Input validation dasar ✓.  
**Catatan:** Cooldown hanya di-enforce server-side (baik), tapi client-side timer hanya kosmetik.

### 5.3 Static Assets

**[Risiko: RENDAH]** `cdn-bundle/bundle-key.txt` berisi BUNDLE_KEY plain text (`a8876d9734798bd2b9c5a5758c27b7a9`). File ini ada di repo.  
**Rekomendasi:** Tambahkan ke `.gitignore` dan hapus dari repo. Generate key hanya lokal.

---

## 6. Webhook & Integrasi Eksternal

### 6.1 Saweria Webhook

**[Risiko: TINGGI]** Tidak ada signature verification untuk inbound webhook Saweria. Autentikasi hanya via token query param atau IP whitelist.  
**Rekomendasi:** Implementasikan signature verification jika Saweria menyediakan HMAC signing.

**[Risiko: SEDANG]** Tidak ada idempotency atau replay protection. Webhook yang sama bisa diproses berulang kali.  
**Rekomendasi:** Simpan order ID yang sudah diproses dan cek duplikasi.

### 6.2 Discord Webhook

**[Risiko: RENDAH]** Webhook URL hanya dari env var ✓. Tidak ditemukan di client-side code ✓.

### 6.3 GitHub Token

**[Risiko: RENDAH]** `GITHUB_TOKEN` hanya di env var. Tidak ditemukan hardcoded.

---

## 7. Cloudflare Worker & R2 CDN

### 7.1 Token Validation

**[Risiko: TINGGI]** Worker `pc-modules-worker.js` memiliki **fail-open** pada single-use token verification:
```js
// Fail-open for availability
return { valid: true, reason: 'API unavailable, allowing request' };
```
Dan pada error:
```js
// Fail-open: allow request if API is unreachable
return { valid: true, reason: 'Verification error, allowing request' };
```
→ Jika Vercel API down, semua token dianggap valid.  
**Rekomendasi:** Ubah ke fail-closed. Lebih baik downtime sementara daripada bypass keamanan.

### 7.2 CORS

**[Risiko: SEDANG]** Worker menggunakan `Access-Control-Allow-Origin: *`.  
**Rekomendasi:** Batasi ke domain yang diperlukan saja (misal domain Roblox).  
**Catatan:** Untuk Roblox `HttpService`, CORS tidak relevan (bukan browser), tapi tetap best practice membatasi.

### 7.3 R2 Bucket

**[Risiko: RENDAH]** Bucket diakses hanya melalui Worker yang memerlukan signed token ✓. Tidak ada public access langsung ✓.

### 7.4 File Path

**[Risiko: SEDANG]** Worker tidak memvalidasi `filePath` untuk path traversal:
```js
let filePath = path.startsWith('/') ? path.slice(1) : path;
const r2Path = `pc/${filePath}`;
```
→ Request ke `/../../other-bucket-key` mungkin bisa mengakses file di luar `pc/` prefix.  
**Rekomendasi:** Validasi filePath — tolak jika mengandung `..` atau karakter berbahaya.

---

## 8. Hardcoded Credentials (KRITIS)

### 8.1 `.env.example` — SECRET ASLI, BUKAN PLACEHOLDER

**[Risiko: KRITIS]** `.env.example` berisi nilai asli, bukan placeholder:
```
ADMIN_SECRET=932885a21f402ed282d420a55e742b52cf11eae0b3d4e6280fcb7647b4860049
STARSHIP_SECRET_KEY=538739a817cc0c94cefd894f83fd6e0e074d435d3153b85f345d461d55d2ec1c
```
→ Siapa pun yang melihat repo tahu secret production.  
**Rekomendasi:** **SEGERA** ganti ke placeholder. **Rotasi semua key** yang sudah terekspos.

### 8.2 `scripts/local-upload-server.js` — R2 Credentials Hardcoded

**[Risiko: KRITIS]** R2 credentials hardcoded sebagai fallback:
```js
const R2_ACCOUNT_ID = process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6";
const R2_ACCESS_KEY_ID = process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf";
const R2_SECRET_ACCESS_KEY = process.env.R2_SECRET_ACCESS_KEY || "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660";
```
→ **Credential R2 lengkap ada di source code.** Siapa pun bisa mengakses/memodifikasi bucket R2.  
**Rekomendasi:** **SEGERA** hapus fallback, rotasi R2 keys.

### 8.3 `bulk-upload-r2.js` — R2 Credentials JUGA Hardcoded

**[Risiko: KRITIS]** Credential R2 yang SAMA hardcoded di file kedua:
```js
ACCOUNT_ID: process.env.R2_ACCOUNT_ID || "17edbfea58c7f279f174bda25630eda6",
ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID || "a25acdab0d556ba383a4b5061c1dbddf",
SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY || "108e57502b737311b934d4d300996cb60e5a1dfd87f908c57e04d018dcea4660",
```
**Rekomendasi:** Sama — hapus fallback, rotasi keys.

### 8.4 `cdn-bundle/bundle-key.txt` — BUNDLE_KEY di Repo

**[Risiko: TINGGI]** File `cdn-bundle/bundle-key.txt` berisi BUNDLE_KEY plain text: `a8876d9734798bd2b9c5a5758c27b7a9`.  
**Rekomendasi:** Hapus dari repo, tambahkan ke `.gitignore`, rotasi key.

### 8.5 `api/whitelist-manager.js` — ADMIN_SECRET Fallback

**[Risiko: KRITIS]** (Diulang karena kritis): `ADMIN_SECRET || "CHANGE_ME_PLEASE"`

### 8.6 `api/get-module.js` — DEV_SECRET Fallback

**[Risiko: KRITIS]** `DEV_SECRET || "starship-dev-2025"` — bypass auth di production jika env tidak di-set.

### 8.7 `lib/crypto-utils.js` — HMAC Default Key

**[Risiko: TINGGI]** Default HMAC secret hardcoded:
```js
'starship_default_secret_key_change_in_production'
```
→ Jika env var tidak di-set, semua signature bisa di-forge.  
**Rekomendasi:** Throw error jika `STARSHIP_SECRET_KEY` tidak di-set.

---

## 9. Crypto & Enkripsi

### 9.1 RSA Key Management

**[Risiko: SEDANG]** Jika `RSA_PRIVATE_KEY` / `RSA_PUBLIC_KEY` tidak di-set, server auto-generate key pair baru setiap cold start. Signature menjadi tidak konsisten antar invocation.  
**Rekomendasi:** Wajibkan RSA keys di production env.

### 9.2 Nonce / Anti-Replay

**[Risiko: TINGGI]** Nonce tracking menggunakan in-memory `Map`. Di Vercel serverless, memory hilang setiap cold start.  
→ Anti-replay **tidak efektif** di production. Attacker bisa re-use nonce setelah cold start.  
**Rekomendasi:** Gunakan Redis untuk nonce storage.

### 9.3 Signature Validity

**[Risiko: RENDAH]** `SIGNATURE_VALIDITY_MS = 30000` (30 detik). Cukup ketat untuk use case ini.

### 9.4 AES Encryption

**[Risiko: RENDAH]** AES-256-CBC dengan random IV per request ✓.  
**Catatan:** GCM (authenticated encryption) lebih direkomendasikan daripada CBC untuk mencegah padding oracle attacks, tapi untuk use case ini CBC cukup.

### 9.5 XOR "Encryption" di Module Delivery

**[Risiko: TINGGI]** Module delivery ke PC menggunakan XOR dengan key yang dikirim bersamaan dalam response JSON. Ini **bukan enkripsi** — efektif plain text.  
**Rekomendasi:** Gunakan AES dengan key yang sudah ada di client (dari bundle decryption).

---

## 10. HWID / Device Fingerprint

### 10.1 Spoofing

**[Risiko: SEDANG]** HWID dikirim oleh Roblox executor (client-side), bukan hardware secure element. Bisa dipalsukan oleh user yang paham.  
**Mitigasi yang ada:** Multiple metode HWID (10+ di PC, 6+ di mobile) ✓. Ini memperberat spoofing tapi tidak mencegah sepenuhnya.

### 10.2 Reset HWID

**[Risiko: SEDANG]** Self-service reset HWID (`/api/whitelist-manager` action `self_reset_hwid`) hanya memerlukan userId — tanpa verifikasi identitas tambahan.  
**Rekomendasi:** Tambahkan verifikasi (Discord OAuth, email, atau admin approval).

**[Risiko: RENDAH]** Cooldown 1 jam untuk reset ✓. Server-side enforcement ✓.

### 10.3 Penyimpanan

**[Risiko: SEDANG]** HWID disimpan plain-text di Redis (berdasarkan review load.js dan whitelist-manager.js).  
**Rekomendasi:** Hash HWID sebelum disimpan (SHA-256). Bandingkan hash saat verifikasi.

---

## 11. Watermark System

### 11.1 Kekuatan Enkripsi

**[Risiko: TINGGI]** Watermark menggunakan XOR dengan key statis (42) lalu hex encode. `tools/decode-watermark.js` menunjukkan cara decode-nya.  
→ Trivial untuk di-reverse. Setiap user yang melihat source decode-watermark.js bisa decode watermark siapa pun.  
**Rekomendasi:** Gunakan enkripsi yang lebih kuat (AES) dan jangan sertakan decoder tool di repo publik.

### 11.2 Strippability

**[Risiko: TINGGI]** Watermark berupa variabel `_wm`, `_SWM`, `_cfg`, `_mcfg` yang bisa dicari dan dihapus.  
**Rekomendasi:** Embed watermark ke dalam logic code (steganography), bukan hanya sebagai variabel terpisah.

### 11.3 Coverage

**[Risiko: SEDANG]** Watermark diterapkan di Loader-obfuscated.lua dan mobile-loader.lua (5 lokasi). Namun, module individual (StarshipCore.lua, MobileUI.lua, game modules) **tidak di-watermark**.  
**Rekomendasi:** Watermark semua script yang di-serve ke client.

---

## 12. Obfuscated vs Non-obfuscated

### 12.1 File Non-obfuscated di Production

**[Risiko: KRITIS]** File-file berikut **TIDAK terobfuskasi** tapi di-serve ke client:

| File | Status | Di-serve? |
|------|--------|-----------|
| `data/StarshipCore.lua` | **TIDAK obfuscated** (~12K baris) | Ya, via load.js |
| `data/MobileUI.lua` | **TIDAK obfuscated** (~9K baris) | Ya, via m-ui-v8x3q2.js |
| `data/StarSpace.lua` | **TIDAK obfuscated** (~5.9K baris) | Ya, via get-module.js |
| `data/SambungKata.lua` | **TIDAK obfuscated** | Ya, via get-module.js |
| `data/sawah-indo.lua` | **TIDAK obfuscated** | Ya, via get-module.js |
| `data/Modules/*.lua` | Sebagian besar **TIDAK obfuscated** | Ya |
| `protected/mobile-loader.lua` | **TIDAK obfuscated** | Ya, via mobile-bootstrap.js |

Yang sudah obfuscated: `protected/Loader-obfuscated.lua` ✓, `data/Modules/StarSpacePlayback-obfuscated.lua` ✓

**Rekomendasi:** **Obfuskasi SEMUA file Lua** yang di-serve ke client.

### 12.2 `Loader.lua` dan `Loader.dev.lua`

**[Risiko: TINGGI]** Kedua file ada di root repo. `Loader.dev.lua` berisi encryption key hardcoded.  
**Rekomendasi:** Hapus `Loader.dev.lua`. Verifikasi `Loader.lua` tidak bisa diakses di production (sudah di-handle: hanya `Loader-obfuscated.lua` yang di-serve via bootstrap ✓).

**[Risiko: RENDAH]** vercel.json tidak mengekspos `Loader.lua` atau `Loader.dev.lua` via routing ✓.

---

## 13. Game Modules

### 13.1 `data/TestAdminDetect.lua`

**[Risiko: TINGGI]** Script ini memindai semua player untuk mendeteksi admin (ownership, group rank, tools). Jika di-serve ke user biasa, mereka bisa scan admin di game.  
**Catatan:** File ini tidak ada di `ALLOWED_MODULES` list di `get-module.js`. Namun perlu diverifikasi bahwa tidak ada rute lain yang bisa menyajikannya.  
**Rekomendasi:** Hapus dari repo production. Gunakan hanya lokal.

### 13.2 HttpGet/HttpPost di Game Modules

**[Risiko: SEDANG]** `SambungKata.lua` melakukan HttpGet ke 11 URL GitHub untuk kamus bahasa Indonesia. URL ini aman (raw.githubusercontent.com ke repo sendiri), tapi tetap risiko supply chain jika repo dimodifikasi.

### 13.3 loadstring di Game Modules

**[Risiko: TINGGI]** Hampir semua game module menggunakan `loadstring(game:HttpGet(...))()` untuk memuat library pihak ketiga. Lihat Bagian 3.1.

### 13.4 Module Name Validation

**[Risiko: RENDAH]** `get-module.js` memiliki `ALLOWED_MODULES` whitelist yang membatasi modul yang bisa di-fetch ✓. Ini mencegah path traversal via nama modul.

---

## 14. Tools & Scripts Lokal

### 14.1 `scripts/local-upload-server.js`

**[Risiko: KRITIS]** Server HTTP di port 4000 **TANPA autentikasi**. Siapa pun di jaringan lokal bisa POST upload ke R2.  
**[Risiko: KRITIS]** R2 credentials hardcoded (lihat Bagian 8.2).  
**Rekomendasi:** Tambahkan peringatan besar bahwa ini HANYA untuk development. Tambahkan auth token. Hapus hardcoded credentials.

### 14.2 `tools/decode-watermark.js`

**[Risiko: TINGGI]** Tool ini bisa decode watermark siapa pun. Jika repo bocor, leaker bisa menghapus watermark sebelum membagikan script.  
**Rekomendasi:** Hapus dari repo. Simpan terpisah di lokasi yang aman.

### 14.3 `tools/generate-bundle.js` & `tools/update-bundle.js`

**[Risiko: SEDANG]** Bundle key ditulis ke `cdn-bundle/bundle-key.txt` yang sudah ada di repo.  
**Rekomendasi:** Tambahkan `cdn-bundle/bundle-key.txt` ke `.gitignore`.

### 14.4 `.bat` Scripts

**[Risiko: RENDAH]** File `.bat` (`starship-manager.bat`, `START-DEV.bat`, dll.) berisi perintah untuk menjalankan Node.js scripts. Tidak ditemukan credential hardcoded di batch scripts.

---

## 15. DiscordGambleBot & DiscordPresence

### 15.1 `DiscordGambleBot/index.js`

**[Risiko: TINGGI]** Menggunakan `discord.js-selfbot-v13` — **selfbot melanggar Discord ToS** dan akun bisa di-ban.  
**[Risiko: SEDANG]** Token preview dilog ke console: `console.log(`Token Preview: ${TOKEN.substring(0, 5)}...`)`  
**Rekomendasi:** Hapus log token preview.

**[Risiko: RENDAH]** Token dan Channel ID dari `.env` ✓. `.env` ada di `.gitignore` ✓.

### 15.2 `DiscordPresence/config.example.json`

**[Risiko: RENDAH]** Berisi placeholder `YOUR_DISCORD_APPLICATION_ID` dan `YOUR_ADMIN_SECRET_HERE` ✓ (baik, bukan nilai asli).  
**[Risiko: RENDAH]** `DiscordPresence/config.json` ada di `.gitignore` ✓.

---

## 16. Recording System

### 16.1 Upload Authorization

**[Risiko: TINGGI]** `cloud-chunk-m3p7.js` memerlukan event code + userId untuk upload ✓, tapi DEV bypass via Host header (lihat 2.4) meng-override ini.  
**[Risiko: SEDANG]** Tidak ada validasi ownership saat delete (lihat 2.4).

### 16.2 File Size & Type

**[Risiko: SEDANG]** Tidak ada limit eksplisit pada ukuran recording. User bisa upload file sangat besar ke R2.  
**Rekomendasi:** Tambahkan max file size limit (misalnya 50MB per recording).

### 16.3 Akses Recording

**[Risiko: SEDANG]** Recording bisa diakses oleh user lain yang punya event code. Tidak ada otorisasi per-user.  
**Rekomendasi:** Tambahkan ownership check pada read/download.

### 16.4 Data Privacy

**[Risiko: RENDAH]** Tidak ditemukan kebijakan retensi atau auto-delete recording.  
**Rekomendasi:** Implementasikan auto-delete setelah X hari.

---

## 17. Ringkasan & Prioritas

### Semua Temuan

| # | Risiko | Area | Temuan | Rekomendasi |
|---|--------|------|--------|-------------|
| 1 | **KRITIS** | Credentials | `.env.example` berisi ADMIN_SECRET & STARSHIP_SECRET_KEY **asli** | Ganti ke placeholder, rotasi semua key |
| 2 | **KRITIS** | Credentials | R2 credentials hardcoded di `local-upload-server.js` & `bulk-upload-r2.js` | Hapus fallback, rotasi R2 keys |
| 3 | **KRITIS** | API | `whitelist-manager.js` ADMIN_SECRET fallback `CHANGE_ME_PLEASE` | Hapus fallback, throw error |
| 4 | **KRITIS** | API | `get-module.js` DEV_SECRET fallback `starship-dev-2025` | Hapus fallback, disable dev mode di prod |
| 5 | **KRITIS** | API | DEV bypass via `Host: localhost` header spoofing di cloud-chunk & cloud-store | Hapus Host header check |
| 6 | **KRITIS** | API | CDN token `verify_cdn_token` fail-open saat Redis down | Ubah ke fail-closed |
| 7 | **KRITIS** | Lua | `loadstring` dari URL GitHub pihak ketiga (supply chain risk) | Bundle library di server sendiri |
| 8 | **KRITIS** | Lua | `Loader.dev.lua` berisi encryption key `Starship_X7k9P2mQ_2025` | Hapus dari repo |
| 9 | **TINGGI** | API | `roblox-user.js` mengekspos VIP status + purchase history tanpa auth | Tambah auth atau batasi field |
| 10 | **TINGGI** | API | `saweria-webhook.js` `create-pending-order` tanpa auth | Tambah auth |
| 11 | **TINGGI** | API | `tags.js` batch VIP check tanpa auth | Tambah auth/rate limit |
| 12 | **TINGGI** | API | R2 Event Code leak ke VIP users via script injection | Gunakan token-based system |
| 13 | **TINGGI** | API | DELETE recording tanpa ownership check | Tambah ownership verification |
| 14 | **TINGGI** | Crypto | Nonce tracking in-memory, hilang saat cold start | Pindah ke Redis |
| 15 | **TINGGI** | Crypto | Default HMAC key hardcoded di crypto-utils.js | Throw error jika key tidak di-set |
| 16 | **TINGGI** | Crypto | XOR "encryption" untuk module delivery = plain text | Gunakan AES |
| 17 | **TINGGI** | Lua | XOR key terekspos di komentar StarSpace.lua | Hapus komentar |
| 18 | **TINGGI** | Watermark | XOR(42) + hex encode, trivial di-reverse | Gunakan enkripsi lebih kuat |
| 19 | **TINGGI** | Tools | `decode-watermark.js` bisa decode watermark siapa pun | Hapus dari repo |
| 20 | **TINGGI** | Discord | DiscordGambleBot menggunakan selfbot (ToS violation) | Ganti ke bot account biasa |
| 21 | **TINGGI** | Obfuscation | Mayoritas file Lua production TIDAK terobfuskasi | Obfuskasi semua file |
| 22 | **TINGGI** | Game Modules | TestAdminDetect.lua bisa scan admin jika ter-serve | Hapus dari repo prod |
| 23 | **SEDANG** | API | ADMIN_SECRET bisa dikirim via query parameter | Hanya terima via header |
| 24 | **SEDANG** | API | Potensial SSRF via userId di roblox-user.js | Validasi userId digit-only |
| 25 | **SEDANG** | API | Request body logging di saweria-webhook.js | Hapus di production |
| 26 | **SEDANG** | API | recordingId tidak di-sanitize (path traversal) | Sanitize input |
| 27 | **SEDANG** | API | Lua injection via Redis status message | Escape karakter Lua |
| 28 | **SEDANG** | Public | Admin secret di localStorage (rentan XSS) | Gunakan HTTP-only cookie |
| 29 | **SEDANG** | Public | Potensial XSS di admin dashboard (innerHTML) | Escape HTML entities |
| 30 | **SEDANG** | HWID | HWID disimpan plain-text di Redis | Hash sebelum simpan |
| 31 | **RENDAH** | API | Tidak ada rate limiting global | Implementasikan rate limiting |
| 32 | **RENDAH** | API | BUNDLE_KEY preview dilog | Hapus log |
| 33 | **RENDAH** | Credentials | `cdn-bundle/bundle-key.txt` di repo | Tambah ke .gitignore |
| 34 | **RENDAH** | Discord | Token preview dilog di GambleBot | Hapus log |
| 35 | **RENDAH** | Recording | Tidak ada max file size limit | Tambah limit |
| 36 | **RENDAH** | Recording | Tidak ada kebijakan retensi | Tambah auto-delete |

---

### Top 10 Action Items (Prioritas Tertinggi)

1. **ROTASI SEMUA SECRET** yang sudah terekspos di `.env.example`, `local-upload-server.js`, `bulk-upload-r2.js`, `cdn-bundle/bundle-key.txt` — termasuk ADMIN_SECRET, STARSHIP_SECRET_KEY, R2 keys, BUNDLE_KEY
2. **Hapus semua hardcoded fallback credentials** — `CHANGE_ME_PLEASE`, `starship-dev-2025`, `starship_default_secret_key_change_in_production`, R2 credentials
3. **Perbaiki DEV bypass** — hapus `Host` header check di `cloud-chunk-m3p7.js` dan `cloud-store-x7k9.js`
4. **Ubah fail-open ke fail-closed** di `pc-ld-q8r4.js` dan `pc-modules-worker.js`
5. **Hapus `loadstring` dari URL GitHub pihak ketiga** — bundle semua library sendiri
6. **Tambahkan autentikasi** ke `create-pending-order`, `roblox-user.js` VIP check, `tags.js` batch check
7. **Hapus `Loader.dev.lua`** dan `decode-watermark.js` dari repo
8. **Obfuskasi semua file Lua production** (StarshipCore.lua, MobileUI.lua, mobile-loader.lua, dll.)
9. **Pindahkan nonce tracking ke Redis** (anti-replay tidak efektif di serverless in-memory)
10. **Tambahkan ownership check** pada DELETE recording dan batasi event code exposure

---

### Checklist Keamanan

| Item | Status |
|------|--------|
| Auth pada semua endpoint sensitif | ❌ Belum — beberapa endpoint publik tanpa auth |
| Validasi input pada semua input user | ⚠️ Parsial — beberapa recordingId/userId tidak di-sanitize |
| Tidak ada secret/credential di client/log/error/source code | ❌ Belum — banyak hardcoded credentials |
| Tidak ada hardcoded credential (fallback values) | ❌ Belum — 6+ file dengan hardcoded fallback |
| Rate limit pada endpoint publik | ❌ Belum — tidak ada rate limiting global |
| Proteksi panel admin | ⚠️ Parsial — ada auth tapi admin secret di localStorage |
| Cloudflare Worker token validation benar | ❌ Belum — fail-open saat error |
| R2 bucket private, upload di-authorize | ⚠️ Parsial — private tapi DEV bypass |
| Nonce/anti-replay efektif di serverless | ❌ Belum — in-memory, hilang saat cold start |
| HWID tidak bisa di-abuse (rate limit reset) | ⚠️ Parsial — cooldown ada tapi tanpa verifikasi identitas |
| File non-obfuscated/dev tidak ter-serve di production | ❌ Belum — hampir semua file Lua non-obfuscated |
| TestAdminDetect.lua tidak ter-serve ke user biasa | ✅ Sudah — tidak ada di ALLOWED_MODULES |
| Watermark tidak mudah di-strip | ❌ Belum — XOR(42), trivial di-reverse |
| Recording upload di-authorize dan di-limit | ⚠️ Parsial — ada auth tapi DEV bypass dan no size limit |
| DiscordBot/Presence token aman | ⚠️ Parsial — dari env tapi selfbot violation |

---

*Setelah audit ini, disarankan juga menjalankan:*
- `npm audit` untuk SCA (Software Composition Analysis)
- Cycode MCP secret scan untuk mendeteksi secret yang mungkin terlewat
- luacheck/Luau LSP untuk static analysis pada file Lua
