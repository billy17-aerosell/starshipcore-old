## Cloudflare Signed CDN (R2 + Worker)

Tujuan: file bundle **`/b/pc.json` tidak bisa diakses publik** tanpa token, tapi tetap cepat karena lewat CDN.

Repo ini sudah support mode ini:
- Vercel akan meng-inject `_G.StarshipCDN` (baseUrl + token) ke loader **setelah auth**.
- `Loader.lua` / `protected/Loader-obfuscated.lua` akan download bundle dari Cloudflare jika token tersedia.
- Akses langsung `https://starship-core.my.id/b/pc.json` akan **diblock** jika `CDN_PC_URL` + `CDN_SECRET_KEY` sudah di-set di Vercel.

### 1) Deploy Worker

Gunakan file: `cloudflare/pc-modules-worker.js`

Di Cloudflare Dashboard:
- **Workers & Pages** → **Create Worker**
- Paste kode worker tersebut
- Set **Bindings**:
  - **R2 Bucket**: bind sebagai `STARSHIP_BUCKET`
  - **Variables / Secrets**:
    - `CDN_SECRET_KEY` (harus sama persis dengan yang di Vercel)

### 2) Upload bundle ke R2

Worker akan membaca dari R2 path:
- `pc/b/pc.json`

Jadi upload file bundle kamu ke R2 dengan key:
- **`pc/b/pc.json`**

Catatan:
- Request ke worker yang akan dipakai loader: `GET /b/pc.json?token=...`

### 3) Set Environment Variables di Vercel

Di project Vercel:
- `CDN_SECRET_KEY` = secret yang sama dengan Worker
- `CDN_PC_URL` = URL base worker kamu (contoh: `https://starship-pc-modules.YOUR_SUBDOMAIN.workers.dev`)

Setelah itu deploy ulang.

### 4) Cara test cepat

- Pastikan `CDN_PC_URL` + `CDN_SECRET_KEY` sudah aktif di Vercel.
- Coba akses direct bundle:
  - `https://starship-core.my.id/b/pc.json`
  - Harus return `404 NOT_FOUND` (diblock oleh `/api/bundle-pc`).
- Lalu jalankan loader normal (Roblox). Jika auth sukses, loader akan fetch:
  - `${CDN_PC_URL}/b/pc.json?token=...` (dengan token yang valid)


