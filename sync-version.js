import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const rootDir = __dirname;

// Paths
const paths = {
    pcChangelog: path.join(rootDir, 'public', 'changelog.json'),
    mobileChangelog: path.join(rootDir, 'public', 'changelog-mobile.json'),
    pcScript: path.join(rootDir, 'data', 'StarshipCore.lua'),
    mobileScript: path.join(rootDir, 'data', 'MobileUI.lua')
};

function updateVersion(scriptPath, changelogPath, varName) {
    try {
        if (!fs.existsSync(changelogPath)) {
            console.error(`❌ Changelog not found: ${changelogPath}`);
            return;
        }
        if (!fs.existsSync(scriptPath)) {
            console.error(`❌ Script not found: ${scriptPath}`);
            return;
        }

        const changelog = JSON.parse(fs.readFileSync(changelogPath, 'utf8'));
        const version = changelog.currentVersion;

        let scriptContent = fs.readFileSync(scriptPath, 'utf8');

        // Regex to find 'local VERSION = "..."'
        const regex = new RegExp(`local ${varName} = "[^"]+"`);

        if (!regex.test(scriptContent)) {
            console.warn(`⚠️ Could not find version variable '${varName}' in ${path.basename(scriptPath)}`);
            return;
        }

        const newContent = scriptContent.replace(regex, `local ${varName} = "${version}"`);

        if (scriptContent !== newContent) {
            fs.writeFileSync(scriptPath, newContent, 'utf8');
            console.log(`✅ Updated ${path.basename(scriptPath)} to version ${version}`);
        } else {
            console.log(`ℹ️ ${path.basename(scriptPath)} is already at version ${version}`);
        }
    } catch (error) {
        console.error(`❌ Error updating ${path.basename(scriptPath)}:`, error.message);
    }
}

console.log("🔄 Syncing versions...");
updateVersion(paths.pcScript, paths.pcChangelog, "VERSION");
updateVersion(paths.mobileScript, paths.mobileChangelog, "VERSION");
