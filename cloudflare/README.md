## Cloudflare Signed CDN (R2 + Worker)

Tujuan: file bundle **`/b/pc.json` tidak bisa diakses publik** tanpa token, tapi tetap cepat karena lewat CDN.

### Fitur Keamanan:
- ✅ **Signed Token** - Token di-sign dengan secret key
- ✅ **Token Expiry** - Token expired dalam 15 menit
- ✅ **Single-Use Token** - Token hanya bisa dipakai 1x (NEW!)

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
    - `UPSTASH_REDIS_REST_URL` (untuk single-use token) *
    - `UPSTASH_REDIS_REST_TOKEN` (untuk single-use token) *

> \* **Upstash Redis REST credentials** bisa didapat dari [Upstash Console](https://console.upstash.com/) → Database → REST API section.

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
- `CDN_PC_URL` = URL base worker kamu (contoh: `https://cdn.starship-core.my.id`)

Setelah itu deploy ulang.

### 4) Set Upstash Redis REST API di Worker

Untuk mengaktifkan **Single-Use Token**:

1. Buka [Upstash Console](https://console.upstash.com/)
2. Pilih database Redis yang sama dengan Vercel
3. Scroll ke **REST API** section
4. Copy:
   - `UPSTASH_REDIS_REST_URL` (contoh: `https://xxx-xxx.upstash.io`)
   - `UPSTASH_REDIS_REST_TOKEN` (contoh: `AXxxxx...`)
5. Tambahkan ke Cloudflare Worker **Settings** → **Variables**

### 5) Cara test cepat

- Pastikan `CDN_PC_URL` + `CDN_SECRET_KEY` sudah aktif di Vercel.
- Coba akses direct bundle:
  - `https://starship-core.my.id/b/pc.json`
  - Harus return `404 NOT_FOUND` (diblock).
- Lalu jalankan loader normal (Roblox). Jika auth sukses, loader akan fetch:
  - `${CDN_PC_URL}/b/pc.json?token=...` (dengan token yang valid)

### Single-Use Token Flow

```
1. User auth di Vercel → Generate token + simpan ke Redis
2. User download bundle dengan token
3. Worker cek Redis: token ada?
   - Ya → Serve bundle, HAPUS token dari Redis
   - Tidak → Reject (token sudah dipakai/invalid)
4. Hacker copy token dari HTTP spy
5. Hacker coba akses dengan token → GAGAL (token sudah dihapus)
```

### Behavior jika Redis tidak tersedia

Worker menggunakan **fail-open** policy - jika Redis tidak bisa dihubungi, request tetap diizinkan (untuk availability). Jika ingin **fail-close** (lebih secure tapi bisa down), ubah di worker code.
