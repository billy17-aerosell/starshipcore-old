# 🚀 Setup Cloudflare R2 + Worker untuk PC Modules

## Overview

Arsitektur ini memindahkan traffic download PC modules dari Vercel ke Cloudflare, mengurangi bandwidth Vercel secara signifikan.

```
User → Vercel (Auth Check) → Inject CDN Token → User gets loader with token
                                                     ↓
                              Cloudflare Worker ← Request dengan token
                                     ↓
                              R2 Bucket (PC Modules)
```

---

## 📋 Prerequisites

1. Akun Cloudflare (gratis)
2. R2 bucket sudah aktif (Anda sudah punya untuk recordings)

---

## Step 1: Buat R2 Bucket Baru (Opsional) atau Gunakan yang Sudah Ada

Anda bisa menggunakan bucket `starship-recordings` yang sudah ada, atau buat bucket baru khusus untuk modules.

**Rekomendasi:** Gunakan bucket yang sama agar lebih simple.

### Upload Struktur Folder:

```
starship-recordings/
├── recordings/          (existing)
│   └── ...
└── pc/                  (NEW - untuk modules)
    ├── StarshipCore.lua  (obfuscated version)
    └── Modules/
        ├── Animations.lua
        ├── Changelog.lua
        ├── CloudRecording.lua
        ├── Config.lua
        ├── ConnectionManager.lua
        ├── Intro.lua
        ├── Locale.lua
        ├── UI.lua
        ├── UIComponents.lua
        └── Tabs/
            ├── ConfigTab.lua
            ├── Dashboard.lua
            ├── Emotes.lua
            ├── Fun.lua
            ├── Helper.lua
            ├── Tools.lua
            └── Warp.lua
```

---

## Step 2: Buat Cloudflare Worker

1. Buka https://dash.cloudflare.com
2. Klik **Workers & Pages** di sidebar
3. Klik **Create application** → **Create Worker**
4. Nama: `starship-pc-modules`
5. Klik **Deploy**
6. Klik **Edit code**
7. Copy-paste isi file: `cloudflare/pc-modules-worker.js`
8. Klik **Save and deploy**

---

## Step 3: Bind R2 ke Worker

1. Di Worker settings, klik **Settings**
2. Scroll ke **Bindings** → klik **Add**
3. Pilih **R2 Bucket**
4. Variable name: `STARSHIP_BUCKET`
5. R2 bucket: pilih bucket Anda (misal `starship-recordings`)
6. Klik **Save**

---

## Step 4: Set Environment Variables di Worker

1. Di Worker settings → **Settings** → **Variables**
2. Klik **Add variable** di **Environment Variables**
3. Tambahkan:
   - Name: `CDN_SECRET_KEY`
   - Value: Generate random string panjang (32+ karakter)
   - Contoh: `StarshipPCModules2026!@#$SecretKey`
   - ⚠️ Klik **Encrypt** untuk keamanan
4. Klik **Save**

---

## Step 5: Set Environment Variables di Vercel

1. Buka Vercel Dashboard → Project Settings → Environment Variables
2. Tambahkan 2 variable baru:

| Name | Value |
|------|-------|
| `CDN_SECRET_KEY` | (SAMA dengan yang di Cloudflare Worker) |
| `CDN_PC_URL` | `https://starship-pc-modules.YOUR_SUBDOMAIN.workers.dev` |

**Catatan:** Ganti `YOUR_SUBDOMAIN` dengan subdomain Cloudflare Anda. 
URL Worker bisa dilihat di dashboard Worker setelah deploy.

---

## Step 6: Upload Modules ke R2

### Via Cloudflare Dashboard:
1. Buka R2 → bucket Anda
2. Klik **Create folder** → nama: `pc`
3. Masuk ke folder `pc`
4. Upload `StarshipCore-obfuscated.lua` dan rename jadi `StarshipCore.lua`
5. Buat folder `Modules` di dalam `pc`
6. Upload semua file dari `data/Modules/` ke `pc/Modules/`

### Struktur Akhir di R2:
```
bucket/
└── pc/
    ├── StarshipCore.lua
    └── Modules/
        ├── Animations.lua
        ├── Changelog.lua
        ├── CloudRecording.lua
        ├── Config.lua
        ├── ConnectionManager.lua
        ├── Intro.lua
        ├── Locale.lua
        ├── UI.lua
        ├── UIComponents.lua
        └── Tabs/
            ├── ConfigTab.lua
            ├── Dashboard.lua
            ├── Emotes.lua
            ├── Fun.lua
            ├── Helper.lua
            ├── Tools.lua
            └── Warp.lua
```

---

## Step 7: Update StarshipCore.lua untuk Menggunakan CDN

StarshipCore.lua lokal perlu diupdate untuk menggunakan CDN URL jika tersedia.

**PENTING:** Ini memerlukan update logic di StarshipCore.lua untuk:
1. Check apakah `_G.StarshipCDN` ada (diinject oleh loader)
2. Jika ada, gunakan CDN URL + token untuk load modules
3. Jika tidak ada, fallback ke Vercel URL yang lama

Contoh kode yang perlu ditambahkan di StarshipCore.lua:

```lua
-- Check CDN availability
local function getModuleURL(moduleName)
  if _G.StarshipCDN and _G.StarshipCDN.enabled then
    -- Use Cloudflare CDN
    local baseUrl = _G.StarshipCDN.url
    local token = _G.StarshipCDN.token
    return baseUrl .. "/Modules/" .. moduleName .. ".lua?token=" .. token
  else
    -- Fallback to Vercel
    return SERVER_URL .. "/Modules/" .. moduleName .. ".lua"
  end
end

-- Load module with CDN support
local function loadModuleFromCDN(moduleName)
  local url = getModuleURL(moduleName)
  local success, result = pcall(function()
    return game:HttpGet(url)
  end)
  
  if success and result then
    local fn, err = loadstring(result)
    if fn then
      return fn()
    else
      warn("Failed to parse module " .. moduleName .. ": " .. tostring(err))
    end
  else
    warn("Failed to fetch module " .. moduleName .. ": " .. tostring(result))
  end
  
  return nil
end
```

---

## Step 8: Redeploy Vercel

```bash
cd c:\Users\Administrator\Documents\for pc & mobile\My real Project FOR PC lengkap dengan recording\VercelProject
vercel --prod
```

---

## Step 9: Testing

1. Jalankan script PC dari executor
2. Di Vercel logs, cari: `[CDN] Token injected for PC user: xxxxx`
3. Module seharusnya diload dari Cloudflare (cek Worker logs di Cloudflare)

---

## 🔒 Keamanan

| Aspek | Status |
|-------|--------|
| Direct R2 Access | ❌ Tidak bisa (token required) |
| Token Expiry | 1 jam |
| Token Forgery | ❌ HMAC-SHA256 signed |
| Platform Lock | ✅ Token locked ke PC only |
| Mobile | ✅ Tidak terpengaruh |

---

## 📊 Bandwidth Savings

| Before | After |
|--------|-------|
| Vercel: 100% (auth + modules) | Vercel: ~5% (auth only) |
| Cloudflare: 0% | Cloudflare: ~95% (modules) |

---

## ⚠️ Catatan Penting

1. **Mobile tidak terpengaruh** - Mobile tetap menggunakan flow yang sama
2. **CDN opsional** - Jika `CDN_SECRET_KEY` atau `CDN_PC_URL` tidak diset, sistem fallback ke Vercel
3. **Token valid 1 jam** - User harus re-execute script setiap jam (jarang terjadi)
4. **Update modules** - Setiap kali update modules, upload ulang ke R2
