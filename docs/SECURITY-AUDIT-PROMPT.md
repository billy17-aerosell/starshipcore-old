# Prompt: Audit Keamanan Lengkap StarshipCore

Gunakan prompt di bawah ini di Cursor (Composer/Agent) atau di chat AI lain untuk melanjutkan audit keamanan proyek. Copy-paste seluruh blok **Prompt untuk AI**, lalu sesuaikan scope jika perlu.

---

## Prompt untuk AI

```
Saya ingin kamu melakukan audit keamanan menyeluruh pada proyek ini (StarshipCore: whitelist + encrypted script delivery untuk Roblox, backend Vercel serverless, Lua client).

Lakukan audit secara sistematis dan berikan output dalam bentuk: [Risiko: Tinggi/Sedang/Rendah] + deskripsi + rekomendasi per item. Jika sudah aman, tetap sebutkan dan beri catatan singkat.

Scope audit:

---

### 1. API & Backend (api/*.js, vercel.json, lib/)

- Autentikasi & otorisasi: Apakah setiap endpoint yang butuh auth benar-benar memeriksa ADMIN_SECRET / token / session? Apakah ada endpoint yang seharusnya protected tapi bisa diakses tanpa auth?
- Validasi input: Semua parameter (query, body, headers) yang dipakai untuk whitelist-manager, load, get-loader, get-module, mobile-load, dll. — apakah ada risiko injection (NoSQL/Redis, path traversal, prototype pollution)? Apakah action/parameter dibatasi allowlist?
- Secret & env: Apakah ADMIN_SECRET, REDIS_URL, DISCORD_WEBHOOK_URL, GITHUB_TOKEN, atau secret lain pernah dikirim ke client, tercetak di log, atau ter-expose lewat error message? Cek juga hardcoded string yang mirip secret.
- Rate limiting & abuse: Apakah ada rate limit atau throttling pada bootstrap, load, whitelist-manager, atau webhook? Risiko brute-force atau DoS?
- CORS & headers: Apakah header keamanan (X-Content-Type-Options, X-Frame-Options, CSP, dll.) sudah di-set di mana perlu? Apakah Cache-Control untuk API sudah sesuai (no-store untuk data sensitif)?
- Rewrites & routing: Cek vercel.json — apakah ada route yang mem-bypass proteksi (mis. /api/protected/* ke 404 sudah benar)? Apakah nama file obfuscated (pc-ld-q8r4, m-ui-v8x3q2, dll.) cukup atau ada info leak lewat path?
- Dependency: Apakah ada dependency di package.json yang punya CVE known atau outdated? (SCA)

---

### 2. Lua (data/*.lua, protected/*.lua, Loader*.lua)

- Eksposur kode: Apakah ada URL, credential, atau logic sensitif yang hardcoded di Lua yang di-serve ke client (StarshipCore.lua, MobileUI.lua, loader, modules)?
- loadstring / eval: Apakah ada pola yang bisa diexploit (mis. loadstring dari input user tanpa sanitasi) di sisi client atau di script yang di-generate server?
- Obfuscation: Apakah bootstrap/loader yang di-serve benar-benar obfuscated? Apakah ada komentar atau string debug yang terkirim ke production?
- Modul & require: Untuk file yang di-fetch lewat get-module atau serupa — apakah nama modul divalidasi (cegah path traversal seperti "../../etc")?
- Logic keamanan client: Apakah ada validasi license/whitelist yang hanya mengandalkan client (bisa di-bypass)? Pastikan semua keputusan kritis (boleh/tidak boleh akses script) ada di server.

---

### 3. Data & Storage (Redis, keys.json, mobile-keys.json)

- Akses Redis: Apakah koneksi Redis hanya dari serverless (bukan dari client)? Apakah query/user input di-sanitize sebelum dipakai di Redis?
- File fallback: Jika pakai keys.json / mobile-keys.json, apakah file itu tidak pernah di-deploy ke public atau ter-expose lewat static hosting?
- Data sensitif di response: Apakah response API (load, whitelist-manager, get-module) pernah mengembalikan field yang tidak perlu (mis. internal ID, secret, daftar user lengkap)?

---

### 4. Public & Static (public/*.html, panel, dashboard)

- Dashboard / panel: Apakah halaman admin (panel-*.html, vip-reset, verify, x7k9-ctrl, dll.) dilindungi dengan auth (secret key, session)? Apakah URL-nya predictable atau di-documentasi di repo public?
- XSS & injection: Untuk halaman yang menerima input (form, query string) — apakah output di-escape? Apakah ada penggunaan innerHTML/document.write dengan data user?
- Static asset: Apakah di public/ tidak ada file konfig atau backup yang berisi secret?

---

### 5. Webhook & Integrasi Eksternal (Discord, Saweria, GitHub, dll.)

- Webhook URL: Apakah webhook URL hanya di env dan tidak pernah di-log atau di-return ke client?
- Validasi payload: Untuk webhook inbound (saweria-webhook, dll.) — apakah signature/secret diverifikasi sebelum proses? Apakah ada idempotency atau replay protection?
- Outbound call: Untuk panggilan ke API eksternal (GitHub, Roblox, dll.) — apakah token/API key aman dan tidak ter-log?

---

### 6. Cloudflare Worker & R2 CDN (cloudflare/, api/cloud-*.js, scripts/, bulk-upload-r2.js)

- Token & auth Worker: Cek `cloudflare/pc-modules-worker.js` — apakah validasi token (signed, single-use) sudah benar dan tidak bisa di-forge? Apakah CDN_SECRET_KEY sinkron dengan Vercel dan tidak hardcoded di kode?
- CORS Worker: Worker memakai `Access-Control-Allow-Origin: *` — apakah ini terlalu lebar? Apakah bisa dibatasi ke domain Roblox saja?
- R2 bucket: Apakah bucket bersifat private (tidak ada public access)? Apakah hanya bisa diakses melalui Worker?
- Upload ke R2: Cek `api/cloud-chunk-m3p7.js`, `api/cloud-store-x7k9.js`, `scripts/upload-recording.js`, `scripts/local-upload-server.js`, `bulk-upload-r2.js` — apakah ada validasi ukuran file, tipe file, otorisasi upload? Apakah user biasa bisa upload file arbitrary?
- R2 blacklist: Cek `R2_BLACKLIST` env — apakah validasinya efektif dan tidak bisa di-bypass?

---

### 7. Hardcoded Credentials & Fallback Values (KRITIS)

- Cek SEMUA file .js (api/, scripts/, tools/, lib/, bulk-upload-r2.js, dll.) apakah ada credential/secret/API key yang hardcoded sebagai fallback value (mis. `process.env.X || "actual-secret-value"`). Khususnya:
  - `scripts/local-upload-server.js` — R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY yang hardcoded sebagai fallback
  - `.env.example` — berisi ADMIN_SECRET dan STARSHIP_SECRET_KEY dengan NILAI ASLI (bukan placeholder). Ini berarti siapa pun yang lihat repo bisa tahu secret-nya
- Untuk setiap credential hardcoded yang ditemukan: [Risiko: KRITIS] + rekomendasi ganti ke placeholder dan rotasi key yang sudah ter-expose.

---

### 8. Crypto & Enkripsi (lib/crypto-utils.js)

- RSA key management: Apakah RSA_PRIVATE_KEY dan RSA_PUBLIC_KEY di-set di production env? Jika tidak, server akan generate key pair baru setiap cold start (signature jadi tidak konsisten). Apakah fallback key generation bisa bocor ke production?
- Nonce / anti-replay: Nonce tracking pakai in-memory Map — di Vercel serverless, memory hilang tiap cold start. Apakah anti-replay ini efektif di production? Apakah sebaiknya pakai Redis untuk nonce store?
- Signature validity: SIGNATURE_VALIDITY_MS = 30 detik — apakah cukup ketat? Apakah bisa diperkecil?
- Key sinkronisasi: Apakah STARSHIP_SECRET_KEY (HMAC) yang dipakai server SAMA PERSIS dengan yang di-embed di Loader.lua dan mobile-loader.lua? Apa risikonya jika key ini bocor (mis. dari .env.example)?
- AES encryption: Apakah IV di-generate random per request (bukan static)? Apakah mode AES-256-CBC cocok atau sebaiknya pakai GCM (authenticated encryption)?

---

### 9. HWID / Device Fingerprint System

- Spoofing: Apakah HWID yang dikirim client bisa dipalsukan (karena dikirim oleh executor, bukan hardware secure element)? Apa mitigasinya?
- Reset HWID: Cek `public/vip-reset.html` — apakah ada rate limit untuk reset HWID? Berapa kali user boleh reset? Apakah butuh verifikasi tambahan (mis. email, Discord) sebelum reset diizinkan?
- Penyimpanan: Apakah HWID di-hash sebelum disimpan di Redis/keys.json, atau disimpan plain-text?
- Cross-reference: Apakah HWID tracking di `api/load.js`, `api/bootstrap.js`, `api/whitelist-manager.js` konsisten?

---

### 10. Watermark System

- Kekuatan enkripsi: Watermark pakai XOR dengan key statis (42), lalu hex encode. Ini sangat mudah di-reverse — `tools/decode-watermark.js` bahkan menunjukkan caranya. Apakah perlu enkripsi yang lebih kuat?
- Strippability: Apakah watermark bisa di-strip oleh user yang tahu polanya? Apakah ada detection jika watermark di-remove?
- Coverage: Apakah SEMUA script Lua yang di-serve ke client (StarshipCore, MobileUI, modules, loaders) di-watermark? Atau hanya sebagian?

---

### 11. Obfuscated vs Non-obfuscated Files

- Cek apakah file non-obfuscated (`Loader.lua`, `Loader.dev.lua`, `data/Modules/StarSpacePlayback.lua`) ikut ter-deploy/ter-serve ke production. Hanya file obfuscated (`protected/Loader-obfuscated.lua`, `data/Modules/StarSpacePlayback-obfuscated.lua`) yang boleh di-serve.
- Apakah `Loader.dev.lua` bisa diakses di production? Cek routing di vercel.json.
- Apakah ada komentar, debug print, atau URL internal yang tertinggal di file obfuscated?

---

### 12. Game Modules (data/SambungKata.lua, violence-district.lua, sawah-indo.lua, StarSpace.lua, TestAdminDetect.lua)

- Apakah `TestAdminDetect.lua` pernah di-serve ke user biasa? File ini seharusnya hanya untuk development — jika di-serve via get-module, user bisa scan admin di game.
- Apakah game modules memiliki HttpGet/HttpPost ke URL pihak ketiga? Jika ya, apakah URL tersebut aman dan bukan malicious?
- Apakah ada loadstring di dalam game modules yang bisa diexploit?
- Apakah nama modul di `api/get-module.js` divalidasi (hanya allowlist nama yang dikenal, bukan path arbitrary)?

---

### 13. Tools & Scripts Lokal (tools/, scripts/, *.bat, *.ps1)

- `scripts/local-upload-server.js` — server HTTP di port 4000 TANPA autentikasi. Siapa pun di jaringan lokal bisa POST upload ke R2. Apakah ini hanya untuk development? Apakah ada peringatan agar tidak dijalankan di production/public?
- `tools/generate-bundle.js`, `tools/update-bundle.js` — apakah bundle key atau encryption key ter-expose di output/log?
- `tools/cdn-bundle/pc-bundle.json`, `pc-bundle-mkj4zumcf25bfc53.json` — apakah file bundle ini berisi data sensitif? Apakah ikut ter-push ke repo?
- `.bat` dan `.ps1` scripts — apakah ada yang berisi credential, token, atau path sensitif?
- `tools/decode-watermark.js` — tool ini bisa decode watermark siapa pun. Apakah boleh ada di repo (jika repo bocor, leaker bisa menghapus watermark)?

---

### 14. DiscordGambleBot & DiscordPresence (sub-proyek)

- `DiscordGambleBot/index.js` — apakah ada Discord bot token, API key, atau credential yang hardcoded atau di config? Apakah `.env` termasuk di .gitignore?
- `DiscordPresence/` — set-status.js, presence.js, config files — apakah token Discord aman? Apakah `config.example.json` berisi nilai asli?
- `DiscordPresence/INSTALL-AUTOSTART.bat`, `UNINSTALL-AUTOSTART.bat` — apakah ada path atau credential yang ter-expose di batch scripts?

---

### 15. Recording System (upload, storage, playback)

- Upload flow: Cek `api/cloud-chunk-m3p7.js` dan `scripts/upload-recording.js` — apakah ada batasan siapa yang boleh upload recording? Apakah userId/auth dicek sebelum upload?
- File size & type: Apakah ada limit ukuran recording? Apakah validasi content type dilakukan (cegah upload file berbahaya)?
- Akses recording: Apakah recording bisa diakses oleh user lain? Apakah ada otorisasi saat download/playback?
- Data privacy: Recording berisi data gameplay — apakah ada kebijakan retensi atau penghapusan?

---

### 16. Ringkasan & Prioritas

Di akhir audit, berikan:
1. Daftar SEMUA temuan dengan [Risiko: Kritis/Tinggi/Sedang/Rendah] dan satu kalimat rekomendasi per item.
2. Top 5–10 action items yang harus diperbaiki duluan, diurutkan berdasarkan risiko.
3. Checklist "Sudah / Belum" untuk:
   - Auth pada semua endpoint sensitif
   - Validasi input pada semua input user
   - Tidak ada secret/credential di client/log/error/source code
   - Tidak ada hardcoded credential (fallback values)
   - Rate limit pada endpoint publik
   - Proteksi panel admin
   - Cloudflare Worker token validation benar
   - R2 bucket private, upload di-authorize
   - Nonce/anti-replay efektif di serverless
   - HWID tidak bisa di-abuse (rate limit reset)
   - File non-obfuscated/dev tidak ter-serve di production
   - TestAdminDetect.lua tidak ter-serve ke user biasa
   - Watermark tidak mudah di-strip
   - Recording upload di-authorize dan di-limit
   - DiscordBot/Presence token aman
```

---

## Cara pakai

1. **Di Cursor:** Buka Composer/Agent, paste prompt di atas. Agent akan baca kode (api/, data/, protected/, public/, lib/, vercel.json, .env.example) dan menjalankan audit.
2. **Scope lebih sempit:** Jika mau fokus satu area dulu, ganti scope — mis. hanya "### 1. API & Backend" atau hanya "### 2. Lua".
3. **Follow-up:** Setelah dapat hasil, bisa minta: "Jelaskan detail untuk temuan [X]" atau "Buatkan patch untuk temuan risiko tinggi nomor 1 dan 2".
4. **Simpan hasil:** Simpan output audit ke file mis. `docs/SECURITY-AUDIT-YYYY-MM-DD.md` dan gunakan sebagai checklist perbaikan.

---

## Referensi singkat proyek

- **Backend (Vercel):** Entry point `api/bootstrap.js`, `api/mobile-bootstrap.js`; auth & delivery lewat `api/load.js`; whitelist `api/whitelist-manager.js`; modul `api/get-module.js`; mobile UI `api/m-ui-v8x3q2.js`; PC bundle `api/pc-ld-q8r4.js`; rewrites di `vercel.json`.
- **Cloudflare:** Worker `cloudflare/pc-modules-worker.js` (R2 CDN + signed token).
- **Cloud storage (R2):** Upload lewat `api/cloud-chunk-m3p7.js`, `api/cloud-store-x7k9.js`, `scripts/upload-recording.js`, `scripts/local-upload-server.js`, `bulk-upload-r2.js`.
- **Crypto:** `lib/crypto-utils.js` (RSA signing, AES-256-CBC, nonce anti-replay, HMAC).
- **Lua:** `data/StarshipCore.lua`, `data/MobileUI.lua`, `protected/Loader-obfuscated.lua`, `protected/mobile-loader.lua`, modul di `data/Modules/`, game modules `data/SambungKata.lua`, `data/violence-district.lua`, `data/sawah-indo.lua`, `data/StarSpace.lua`, `data/TestAdminDetect.lua`.
- **Tools:** `tools/generate-bundle.js`, `tools/update-bundle.js`, `tools/decode-watermark.js`, `tools/cdn-bundle/`.
- **Sub-proyek:** `DiscordGambleBot/index.js`, `DiscordPresence/` (presence, set-status, config).
- **Scripts:** `scripts/local-upload-server.js` (HTTP port 4000), `.bat` dan `.ps1` scripts.
- **Env:** `ADMIN_SECRET`, `STARSHIP_SECRET_KEY`, `BUNDLE_KEY`, `REDIS_URL`, `DISCORD_WEBHOOK_URL`, `DISCORD_STATUS_WEBHOOK_URL`, `DISCORD_STATUS_CHANNEL_ID`, `GITHUB_TOKEN`, `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`, `RSA_PRIVATE_KEY`, `RSA_PUBLIC_KEY`, `CDN_SECRET_KEY` (lihat `.env.example`).
- **Public:** `public/index.html`, `public/verify.html`, `public/vip-reset.html`, `public/x7k9-ctrl-m2p4.html`, panel admin (nama obfuscated).

Setelah audit, pertimbangkan untuk menjalankan juga: Cycode MCP (secret scan, SAST, SCA) dan luacheck/Luau LSP untuk Lua, sesuai `docs/MCP-SETUP.md`.
