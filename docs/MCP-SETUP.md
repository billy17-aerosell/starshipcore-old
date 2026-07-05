# Panduan MCP yang Ditambahkan

Proyek ini menggunakan 2 MCP tambahan selain Serena: **Cyber** dan **Cycode** (untuk keamanan/API security).

---

## Rekomendasi untuk proyek StarshipCore

Untuk **StarshipCore** (whitelist + encrypted script delivery, API Vercel, Lua Roblox):

| MCP | Cocok? | Alasan |
|-----|--------|--------|
| **Cycode** | ✅ **Sangat cocok** | Scan secret (ADMIN_SECRET, REDIS_URL, webhook, token), SAST untuk `api/*.js`, SCA untuk dependency. Proyek Anda banyak env rahasia dan endpoint sensitif. |
| **Crypto_MCP** (alternatif Cyber) | ✅ **Cocok** | Proyek pakai Base64 + XOR + AES di `api/load.js` dan bootstrap. Berguna untuk cek encode/decode atau hash saat develop/debug tanpa keluar dari Cursor. |
| **Serena** | ✅ Sudah dipakai | Workflow/agent. |
| **Cyber** (CyberChef) | ⏸️ Dinonaktifkan | Error skema di Cursor; gunakan Crypto_MCP sebagai pengganti. |
| **Lua/OpenResty Security** | ❌ Tidak prioritas | Lua di sini untuk Roblox client, bukan nginx/OpenResty. |
| **Lua security (cek kode Lua)** | ✅ Lihat bawah | Untuk cek kode Lua/Roblox: **Luau LSP** (extension) + **Checkstyle MCP** (luacheck). |

**Saran singkat:** Aktifkan **Cycode** (isi `CYCODE_CLIENT_ID` & `CYCODE_CLIENT_SECRET` di `mcp.json`). Kalau butuh tools encode/decode/hash saat coding, tambah **Crypto_MCP** (clone + build sekali, lalu path di `mcp.json`). Untuk **cek kode Lua** (StarshipCore.lua, MobileUI.lua, loader), pakai **Luau LSP** (extension) dan/atau **Checkstyle MCP** — detail di bagian [Lua Security & Cek Kode Lua](#lua-security--cek-kode-lua).

---

## 1. Cyber (CyberChef MCP) — sementara dinonaktifkan

**Sumber:** [doublegate/CyberChef-MCP](https://github.com/doublegate/CyberChef-MCP)  
Menyediakan 463+ operasi CyberChef sebagai tools MCP: enkripsi, encoding, kompresi, dan analisis data forensik.

**Mengapa dinonaktifkan:** Cursor memvalidasi semua tool MCP dan mensyaratkan `inputSchema.type === "object"`. Banyak tool di CyberChef MCP (termasuk 471–482) tidak memenuhi ini, sehingga Cursor menampilkan error `Invalid input: expected "object"` dan menolak server. Ini bug di sisi CyberChef-MCP. Entry **cyber** telah dihapus dari `mcp.json` agar Cursor tidak error. Setelah upstream memperbaiki skema, tambahkan lagi konfigurasi Cyber di `~/.cursor/mcp.json` (lihat contoh di bawah).

**Konfigurasi (untuk diaktifkan lagi nanti):** `"cyber": { "command": "docker", "args": ["run", "-i", "--rm", "parobek/cyberchef-mcp"] }` — pastikan Docker Desktop berjalan.

### Persyaratan (bila diaktifkan)
- **Docker** terpasang dan **sedang berjalan** (Docker Desktop di Windows harus dalam keadaan running).

### Setup (bila Cyber diaktifkan)
- Konfigurasi memakai image Docker: **`parobek/cyberchef-mcp`**. Tidak perlu clone atau build.
- Pastikan Docker Desktop berjalan, lalu restart Cursor.

### Jika tetap Error

**Pesan: `Invalid input: expected "object"` (tools 471, 472, … / Auth error in listOfferingsForUI)**  
Penyebab: Banyak tool CyberChef MCP punya `inputSchema` tanpa `type: "object"`; Cursor menolak server. Sementara ini **cyber** sudah dinonaktifkan di konfigurasi (lihat atas). Untuk mengaktifkan lagi, tunggu perbaikan dari [doublegate/CyberChef-MCP](https://github.com/doublegate/CyberChef-MCP) atau buka issue di sana.

**Pesan: `failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine`**  
Penyebab: **Docker Desktop tidak berjalan** (atau belum terpasang) di Windows.

- **Opsi A – Tetap pakai Cyber:** Install [Docker Desktop for Windows](https://www.docker.com/products/docker-desktop/) bila belum, lalu **jalankan Docker Desktop** dari Start menu. Tunggu sampai status “Running” (ikon di system tray). Setelah itu restart Cursor.
- **Opsi B – Tidak pakai Docker:** Matikan toggle MCP **cyber** di Cursor (Settings → MCP), atau hapus entry `"cyber"` dari `~/.cursor/mcp.json`. Error akan hilang; Cyber tidak aktif sampai Anda mengaktifkannya lagi dengan Docker sudah jalan.

1. Klik **"Show Output"** di panel MCP untuk melihat pesan error pasti.
2. Pastikan Docker Desktop terpasang dan **running** (ikon Docker di system tray).
3. Di terminal coba: `docker run -i --rm parobek/cyberchef-mcp` — kalau gagal, pesan di sana penyebabnya (mis. Docker tidak jalan atau jaringan).
4. (Opsional) Jika ingin build sendiri dari sumber: clone repo [doublegate/CyberChef-MCP](https://github.com/doublegate/CyberChef-MCP), jalankan `docker build -f Dockerfile.mcp -t cyberchef-mcp .`, lalu di `mcp.json` ganti `parobek/cyberchef-mcp` menjadi `cyberchef-mcp`.

### Tools utama
- `cyberchef_bake` – menjalankan resep CyberChef (mis. Decode Base64 → Gunzip → JSON)
- `cyberchef_to_base64` / `cyberchef_from_base64`
- `cyberchef_aes_decrypt`, `cyberchef_sha2`, `cyberchef_yara_rules`
- `cyberchef_search` – cari operasi yang tersedia

---

## Alternatif Cyber (enkripsi / encoding / hash)

Jika Anda butuh fungsi mirip Cyber (encode/decode, enkripsi, hash) dan ingin MCP yang **kompatibel dengan Cursor** (tanpa error skema), bisa pakai salah satu di bawah.

### Opsi 1: Crypto_MCP (disarankan)

**Sumber:** [1595901624/crypto-mcp](https://github.com/1595901624/crypto-mcp)  
MCP khusus crypto/encoding: lebih sedikit tool daripada CyberChef, skema kemungkinan besar lolos validasi Cursor.

**Fitur:** Enkripsi/dekripsi AES & DES (berbagai mode), Base64/hex encode-decode, hash MD5, SHA1, SHA224, SHA256, SHA384, SHA512.

**Cara pakai:**
1. Clone dan build (butuh Node.js + pnpm):
   ```bash
   git clone https://github.com/1595901624/crypto-mcp.git
   cd crypto-mcp
   pnpm install
   pnpm run build
   ```
2. Tambahkan ke `~/.cursor/mcp.json` (ganti `C:\path\to\crypto-mcp` dengan path hasil clone):
   ```json
   "crypto-mcp": {
     "command": "node",
     "args": ["C:\\path\\to\\crypto-mcp\\build\\index.js"]
   }
   ```
3. Restart Cursor.

**Tools:** `aes_encrypt`, `aes_decrypt`, `des_encrypt`, `des_decrypt`, `base64_encode`, `base64_decode`, `hex_encode`, `hex_decode`, `md5`, `sha1`, `sha256`, `sha384`, `sha512`, `sha224`.

### Opsi 2: Hashing MCP Server

**Sumber:** [kanad13/MCP-Server-for-Hashing](https://github.com/kanad13/MCP-Server-for-Hashing)  
Fokus ke hash (MD5, SHA-256). Cocok bila hanya butuh hashing.

- Clone repo, install dependensi, lalu jalankan dengan `node` (lihat README di repo). Tambahkan entry di `mcp.json` dengan `command`: `node` dan `args`: path ke file utama server.

### Opsi 3: Base64 + gambar (khusus base64/image)

**Package:** `@cloudwerxlab/all-your-base64-mcp`  
Untuk konversi base64 dan URL gambar ke markdown. Jalankan dengan:
```json
"all-your-base64": {
  "command": "npx",
  "args": ["-y", "@cloudwerxlab/all-your-base64-mcp"]
}
```

### Opsi 4: Shell MCP + openssl

MCP yang menjalankan perintah shell (mis. [tumf/mcp-shell-server](https://github.com/tumf/mcp-shell-server)) bisa di-allowlist agar hanya boleh menjalankan `openssl`. Dengan itu Anda bisa minta AI menjalankan perintah seperti `openssl enc -base64` atau `openssl dgst -sha256` lewat MCP. Lebih fleksibel tapi butuh konfigurasi allowlist dan keamanan.

---

## Lua Security & Cek Kode Lua

Untuk **cek kode Lua** Anda (termasuk Roblox Luau: `StarshipCore.lua`, `MobileUI.lua`, `protected/loader.lua`, dll.), yang paling cocok kombinasi berikut.

### Opsi 1: Luau Language Server (extension) — paling disarankan

**Bukan MCP**, tapi extension Cursor/VS Code yang memberi **diagnostics, type check, dan lint** langsung di editor untuk Luau/Roblox.

- **Extension:** [Luau Language Server](https://marketplace.visualstudio.com/items?itemName=JohnnyMorganz.luau-lsp) (JohnnyMorganz).
- **Cara pakai:** Di Cursor buka Extensions (Ctrl+Shift+X), cari **Luau** atau **JohnnyMorganz.luau-lsp**, lalu Install.
- **Fungsi:** Error & peringatan di file `.lua`, autocomplete, hover docs, type checking. Cocok untuk Roblox Luau dan file Lua biasa.
- **Kelebihan:** Tidak perlu MCP, jalan di semua file Lua yang dibuka; paling praktis untuk cek kode Lua sehari-hari.

### Opsi 2: Checkstyle MCP (luacheck + stylua) — AI bisa jalankan pengecekan

**MCP** yang mengintegrasikan **luacheck** (lint/static analysis) dan **stylua** (format) untuk Lua. AI di Cursor bisa memanggil tool ini untuk mengecek dan memperbaiki kode Lua.

- **Sumber:** [liuhua1307/checkstyle_mcp](https://github.com/liuhua1307/checkstyle_mcp)
- **Persyaratan:** Go 1.21+ (untuk build), dan **luacheck** + **stylua** terpasang di sistem (PATH).
- **Install luacheck di Windows:** Mis. pakai [LuaRocks](https://luarocks.org/) (`luarocks install luacheck`) atau [Chocolatey](https://chocolatey.org/) (`choco install luacheck`). Bisa juga pakai [lunarmodules/luacheck](https://github.com/lunarmodules/luacheck) (build dari sumber).
- **Install stylua:** `cargo install stylua` (Rust) atau lihat [stylua](https://github.com/JohnnyMorganz/StyLua).
- **Build & konfigurasi:**
  ```bash
  git clone https://github.com/liuhua1307/checkstyle_mcp.git
  cd checkstyle_mcp
  go build -o checkstyle-mcp cmd/server/*.go
  ```
  Di `~/.cursor/mcp.json` tambahkan (ganti path dengan lokasi `checkstyle-mcp` Anda):
  ```json
  "checkstyle-mcp": {
    "command": "C:\\path\\to\\checkstyle_mcp\\checkstyle-mcp.exe",
    "args": []
  }
  ```
- **Fungsi:** AI bisa menjalankan luacheck (dan stylua) pada file/folder Lua Anda dan mencoba perbaikan otomatis. Bisa pakai konfigurasi per proyek (mis. `.luacheckrc`).

### Opsi 3: Hanya luacheck di terminal (tanpa MCP)

- Pasang **luacheck** (lihat Opsi 2). Di root proyek atau folder `data/`/`protected/` jalankan:
  ```bash
  luacheck data/ protected/ --config .luacheckrc
  ```
- Buat `.luacheckrc` untuk aturan (standar globals Roblox, dll.). Ini tidak terintegrasi dengan AI; berguna untuk CI atau cek manual.

### Rekomendasi singkat untuk StarshipCore

- **Wajib:** Pasang **Luau Language Server** (extension) agar semua file Lua Anda dapat diagnostics dan type check di Cursor.
- **Opsional:** Jika ingin AI bisa “menjalankan luacheck dan memperbaiki” dari dalam Cursor, tambahkan **Checkstyle MCP** (Opsi 2) setelah luacheck & stylua terpasang dan proyek sudah di-build.

---

## 2. Cycode (Security & API Security)

**Sumber:** [cycodehq/cycode-cli](https://github.com/cycodehq/cycode-cli)  
MCP untuk keamanan siklus development: SAST, SCA, pemindaian secret & IaC. Berguna untuk keamanan kode dan API.

### Persyaratan
- Python 3.10+ atau `uvx` (biasanya dari Cursor/uv).
- Akun [Cycode](https://cycode.com) dan kredensial (Client ID + Secret).

### Setup
1. Daftar/ login di [Cycode](https://app.cycode.com) dan ambil **Client ID** dan **Client Secret**.
2. Edit `~/.cursor/mcp.json` dan isi env untuk server `cycode`:
   ```json
   "cycode": {
     "command": "uvx",
     "args": ["cycode", "mcp"],
     "env": {
       "CYCODE_CLIENT_ID": "isi-client-id-anda",
       "CYCODE_CLIENT_SECRET": "isi-client-secret-anda",
       "CYCODE_API_URL": "https://api.cycode.com",
       "CYCODE_APP_URL": "https://app.cycode.com"
     }
   }
   ```
3. (Opsional) Jika pakai region EU, ganti URL ke:
   - `CYCODE_API_URL`: `https://api.eu.cycode.com`
   - `CYCODE_APP_URL`: `https://app.eu.cycode.com`
4. Restart Cursor agar MCP **cycode** terbaca.

### Tools utama
- `cycode_secret_scan` – pemindaian secret
- `cycode_sca_scan` – Software Composition Analysis
- `cycode_iac_scan` – pemindaian Infrastructure as Code
- `cycode_sast_scan` – Static Application Security Testing
- `cycode_status` – status pemindaian

---

## Tentang "Lua Security (OpenResty) and API Security"

- **API Security:** Dicakup oleh **Cycode** (SAST, SCA, secret, IaC) di atas. Alternatif lain: [42Crunch MCP Server](https://github.com/poguuniverse/42crunch-mcp-server) (perlu clone repo dan jalankan `python main.py` dengan token 42Crunch).
- **Lua Security (OpenResty):** Tidak dipakai di proyek ini (Lua untuk Roblox client). Untuk **cek kode Lua/Roblox** (kualitas & keamanan), gunakan [Lua Security & Cek Kode Lua](#lua-security--cek-kode-lua) di atas: **Luau LSP** (extension) + **Checkstyle MCP** (luacheck).

---

## Lokasi konfigurasi

- **Cursor (user):** `C:\Users\<User>\.cursor\mcp.json`  
Setelah mengisi env Cycode dan/atau build image Cyber, **restart Cursor** agar perubahan MCP aktif.
