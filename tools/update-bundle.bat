@echo off
echo.
echo ═══════════════════════════════════════════════════════════════
echo   StarshipCore Bundle Updater
echo ═══════════════════════════════════════════════════════════════
echo.

echo [1/3] Generating new bundle...
call node tools/generate-bundle.js
if errorlevel 1 (
    echo ❌ Bundle generation failed!
    pause
    exit /b 1
)

echo.
echo ✅ Bundle generated successfully!
echo.

echo [2/3] Uploading to Cloudflare R2...
call wrangler r2 object put starship-pc-modules/pc/b/pc.json --file=public/b/pc.json
if errorlevel 1 (
    echo.
    echo ❌ R2 upload failed! Manual upload required.
    echo.
    echo 1. Go to Cloudflare Dashboard → R2 → starship-pc-modules
    echo 2. Upload: public/b/pc.json
    echo 3. Path: pc/b/pc.json
    echo.
)

echo.
echo [3/3] New Bundle Key:
echo.
echo ═══════════════════════════════════════════════════════════════
type cdn-bundle\bundle-key.txt
echo.
echo ═══════════════════════════════════════════════════════════════
echo.

echo ⚠️  IMPORTANT: Update BUNDLE_KEY in Vercel Environment Variables!
echo.
echo Steps:
echo 1. Go to Vercel Dashboard → Project → Settings → Environment Variables
echo 2. Update BUNDLE_KEY with the new value above
echo 3. Redeploy (or it will auto-deploy on next push)
echo.

pause

