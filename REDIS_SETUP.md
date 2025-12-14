# 🚀 Redis/KV Migration Setup Guide

## ✅ Step 1: Create Upstash Redis Database (DONE!)

Jika Anda membaca ini, database sudah dibuat! Sekarang lanjut ke step berikutnya.

---

## 📋 Step 2: Connect Database to Vercel Project

1. **Di Vercel Dashboard**, setelah database dibuat:

   - Klik **"Connect to Project"** atau **"Add Integration"**
   - Pilih project: **StarshipCore**
   - Klik **"Connect"**

2. **Verifikasi Environment Variables**:

   - Go to: Project → Settings → Environment Variables
   - Pastikan ada variables ini (otomatis ditambahkan):
     - `KV_REST_API_URL` atau `UPSTASH_REDIS_REST_URL`
     - `KV_REST_API_TOKEN` atau `UPSTASH_REDIS_REST_TOKEN`

3. **Redeploy Project**:
   - Setelah environment variables ditambahkan
   - Vercel akan otomatis redeploy
   - **Tunggu sampai deployment selesai** (~1-2 menit)

---

## 💻 Step 3: Deploy Code Changes

Dari directory project, jalankan:

```bash
# Add all new files
git add .

# Commit changes
git commit -m "Migrate to Upstash Redis for VIP whitelist management"

# Push to GitHub (will trigger Vercel deployment)
git push origin main
```

Tunggu Vercel deployment selesai!

---

## 🔄 Step 4: Migrate Data from keys.json to Redis

**IMPORTANT**: Ini harus dilakukan **SETELAH** deployment selesai!

### Option A: Via Vercel CLI (Recommended if you have it)

```bash
vercel env pull .env.local  # Download environment variables
node migrate-to-redis.js     # Run migration
```

### Option B: Manual Copy (Easier!)

Karena Anda sudah punya data di `keys.json`, kita bisa langsung add via dashboard setelah deployment:

1. Buka: `https://www.starship-core.my.id/vip-dashboard.html`
2. Login dengan admin secret
3. Add users yang ada di `keys.json`:
   - **User 1**: 9268011358 (Owner) - sudah hardcoded, skip
   - **User 2**: 123456789 (TestVIP_User) - add via dashboard

Atau lebih mudah, kita bisa buat API endpoint khusus untuk migration!

---

## ✅ Step 5: Test Everything

1. **Test Dashboard**:

   ```
   https://www.starship-core.my.id/vip-dashboard.html
   ```

   - Login dengan admin secret
   - Coba add VIP user baru
   - Refresh page - user masih ada? ✅

2. **Test API**:

   ```
   https://www.starship-core.my.id/api-test.html
   ```

   - Test "List Whitelist"
   - Test "Add VIP User"
   - Data persists? ✅

3. **Test Loader**:
   ```lua
   -- Di Roblox, test loader dengan VIP user ID
   loadstring(game:HttpGet("https://www.starship-core.my.id/api/get-loader?userId=123456789"))()
   ```

---

## 🎯 Expected Results

### ✅ Success Indicators:

- Dashboard dapat add/remove VIP users
- Data **tetap ada** setelah refresh
- VIP users dapat akses loader tanpa key
- Owner (Anda) tetap bisa akses

### ❌ Common Issues:

**Issue 1: "Cannot connect to Redis"**

- Solution: Environment variables belum di-set di Vercel
- Go to: Settings → Environment Variables
- Redeploy project

**Issue 2: "Data hilang setelah refresh"**

- Solution: Masih menggunakan old code (file-based)
- Pastikan latest code sudah di-deploy
- Clear browser cache

**Issue 3: Migration script tidak jalan**

- Solution: Environment variables tidak ada di local
- Gunakan Option B (manual via dashboard)

---

## 📊 Monitoring

### View Redis Data (Vercel Dashboard):

1. Go to: Storage tab
2. Click your Redis database
3. View data, commands usage, etc.

### Commands Usage:

- Check di Upstash dashboard berapa commands terpakai
- Should be very low with caching enabled!

---

## 🎉 Success!

Setelah semua step selesai:

- ✅ VIP management via dashboard works perfectly
- ✅ Data persists in Redis cloud storage
- ✅ No file system limitations
- ✅ Super fast with caching
- ✅ Owner hardcoded bypass (0 commands)

---

**Made with ❤️ for StarshipCore**  
\*\*Powered by Upstash Redis + Vercel
