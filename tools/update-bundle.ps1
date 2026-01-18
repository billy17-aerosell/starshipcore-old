# ═══════════════════════════════════════════════════════════════════
# StarshipCore Bundle Update Script
# Generates new bundle and uploads to Cloudflare R2
# ═══════════════════════════════════════════════════════════════════

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  StarshipCore Bundle Updater" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Step 1: Generate bundle
Write-Host "[1/3] Generating new bundle..." -ForegroundColor Yellow
node tools/generate-bundle.js

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Bundle generation failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Bundle generated successfully!" -ForegroundColor Green
Write-Host ""

# Step 2: Upload to R2
Write-Host "[2/3] Uploading to Cloudflare R2..." -ForegroundColor Yellow

# Check if wrangler is installed
$wranglerInstalled = Get-Command wrangler -ErrorAction SilentlyContinue
if (-not $wranglerInstalled) {
    Write-Host "⚠️  Wrangler not installed. Installing..." -ForegroundColor Yellow
    npm install -g wrangler
}

# Upload to R2
# Replace 'starship-pc-modules' with your actual bucket name if different
wrangler r2 object put starship-pc-modules/pc/b/pc.json --file=public/b/pc.json

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ R2 upload failed!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Manual upload required:" -ForegroundColor Yellow
    Write-Host "1. Go to Cloudflare Dashboard → R2 → starship-pc-modules"
    Write-Host "2. Upload: public/b/pc.json"
    Write-Host "3. Path: pc/b/pc.json"
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "✅ Bundle uploaded to R2!" -ForegroundColor Green
    Write-Host ""
}

# Step 3: Display new key
Write-Host "[3/3] New Bundle Key:" -ForegroundColor Yellow
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Get-Content cdn-bundle/bundle-key.txt
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

Write-Host "⚠️  IMPORTANT: Update BUNDLE_KEY in Vercel Environment Variables!" -ForegroundColor Red
Write-Host ""
Write-Host "Steps:" -ForegroundColor Yellow
Write-Host "1. Go to Vercel Dashboard → Project → Settings → Environment Variables"
Write-Host "2. Update BUNDLE_KEY with the new value above"
Write-Host "3. Redeploy (or it will auto-deploy on next push)"
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Done! Test your changes in Roblox." -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

