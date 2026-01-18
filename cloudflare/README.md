## Cloudflare Signed CDN (R2 + Worker)

Tujuan: file bundle **`/b/pc.json` tidak bisa diakses publik** tanpa token, tapi tetap cepat karena lewat CDN.

### Fitur Keamanan:
- ✅ **Signed Token** - Token di-sign dengan secret key
- ✅ **Token Expiry** - Token expired dalam 15 menit
- ✅ **Single-Use Token** - Token hanya bisa dipakai 1x

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
    - `VERCEL_API_URL` (URL Vercel, contoh: `https://starship-core.my.id`)

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

### 4) Cara test cepat

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
3. Worker panggil Vercel API: /api/pc-ld-q8r4?action=verify_cdn_token
4. Vercel cek Redis: token ada?
   - Ya → Hapus token, return valid=true
   - Tidak → Return valid=false (token sudah dipakai)
5. Worker serve bundle (jika valid) atau reject (jika invalid)
6. Hacker copy token → Worker verify → Redis: token tidak ada → REJECT
```

### Environment Variables Summary

**Cloudflare Worker:**
| Variable | Value |
|----------|-------|
| `CDN_SECRET_KEY` | Secret key (sama dengan Vercel) |
| `VERCEL_API_URL` | `https://starship-core.my.id` |

**Vercel:**
| Variable | Value |
|----------|-------|
| `CDN_SECRET_KEY` | Secret key (sama dengan Worker) |
| `CDN_PC_URL` | `https://cdn.starship-core.my.id` |
| `BUNDLE_KEY` | Key untuk decrypt bundle |

### Behavior jika API tidak tersedia

Worker menggunakan **fail-open** policy - jika Vercel API tidak bisa dihubungi, request tetap diizinkan (untuk availability). Jika ingin **fail-close** (lebih secure tapi bisa down), ubah di worker code.
