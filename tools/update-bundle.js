/**
 * Complete Bundle Update Script
 * Runs all steps needed to update the PC module bundle:
 * 1. Generate bundle (reuses existing BUNDLE_KEY)
 * 2. Upload to Cloudflare R2
 * 3. Commit and push to Git (triggers Vercel deploy)
 */

import { execSync } from 'child_process';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const rootDir = path.join(__dirname, '..');

function run(cmd, description) {
    console.log(`\n🔄 ${description}...`);
    try {
        execSync(cmd, { cwd: rootDir, stdio: 'inherit' });
        console.log(`✅ ${description} - Done!`);
        return true;
    } catch (error) {
        console.error(`❌ ${description} - Failed!`);
        return false;
    }
}

async function main() {
    console.log("═".repeat(50));
    console.log("🚀 STARSHIP BUNDLE UPDATE");
    console.log("═".repeat(50));

    // Step 1: Generate bundle
    if (!run('node tools/generate-bundle.js', 'Generate Bundle')) {
        process.exit(1);
    }

    // Step 2: Upload to R2
    if (!run(
        'npx wrangler r2 object put starship-pc-modules/pc/b/pc.json --file=public/b/pc.json --remote --content-type="application/json"',
        'Upload to Cloudflare R2'
    )) {
        console.log("⚠️ R2 upload failed, continuing with git push...");
    }

    // Step 3: Git commit and push
    const commitMsg = `update: Bundle update ${new Date().toISOString().split('T')[0]}`;
    run(`git add -A`, 'Stage changes');
    run(`git commit -m "${commitMsg}" --allow-empty`, 'Commit');
    run(`git push`, 'Push to GitHub');

    console.log("\n" + "═".repeat(50));
    console.log("✅ BUNDLE UPDATE COMPLETE!");
    console.log("═".repeat(50));
    console.log("\n📌 Wait ~30s for Vercel deploy, then test in Roblox.\n");
}

main().catch(console.error);
