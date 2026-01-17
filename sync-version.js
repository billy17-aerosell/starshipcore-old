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
    mobileScript: path.join(rootDir, 'data', 'MobileUI.lua'),
    baruMd: path.join(rootDir, 'baru.md'),
    mergerFolder: 'C:/Users/Administrator/AppData/Local/seliware-workspace/StarshipCore/StarshipMerger'
};

function updateVersion(scriptPath, changelogPath, varName) {
    try {
        if (!fs.existsSync(changelogPath)) return;
        if (!fs.existsSync(scriptPath)) return;

        const changelog = JSON.parse(fs.readFileSync(changelogPath, 'utf8'));
        const version = changelog.currentVersion;
        let scriptContent = fs.readFileSync(scriptPath, 'utf8');
        const regex = new RegExp(`local ${varName} = "[^"]+"`);

        if (regex.test(scriptContent)) {
            const newContent = scriptContent.replace(regex, `local ${varName} = "${version}"`);
            if (scriptContent !== newContent) {
                fs.writeFileSync(scriptPath, newContent, 'utf8');
                console.log(`✅ Updated ${path.basename(scriptPath)} to v${version}`);
            }
        }
    } catch (e) { console.error(e); }
}

function generateBaruMd() {
    try {
        console.log("📝 Updating baru.md...");

        // 1. Get Map List
        let mapList = [];
        if (fs.existsSync(paths.mergerFolder)) {
            mapList = fs.readdirSync(paths.mergerFolder)
                .filter(f => f.endsWith('.json'))
                .map(f => f.replace('.json', ''));
        }

        // 2. Get Changelogs
        const pcData = JSON.parse(fs.readFileSync(paths.pcChangelog, 'utf8'));
        const mobileData = JSON.parse(fs.readFileSync(paths.mobileChangelog, 'utf8'));

        const latestPC = pcData.updates[0];
        const latestMobile = mobileData.updates[0];

        // 3. Build Content
        let content = `# ✦ STARSHIP CORE | MAP DIRECTORY\n`;
        content += `> **Premium Path Repository v${pcData.currentVersion}**\n`;
        content += `⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n`;

        content += `### 📂 DATABASE ENTRIES (${mapList.length})\n`;
        mapList.forEach(map => {
            content += `✦ ⎯ \`${map}\`\n`;
        });
        content += `\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n`;

        content += `### 🖥️ PC PLATFORM PREVIEW\n> **Desktop Optimized Interface**\n\n`;
        content += `**[ PC VERSION ]**\n*High-performance desktop experience with full feature access.*\n![PC Preview](PC.png)\n\n`;
        content += `⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n`;

        content += `### 📱 MOBILE PLATFORM PREVIEW\n> **Responsive Touch Interface**\n\n`;
        content += `**[ MOBILE VERSION ]**\n*Sleek UI tailored for mobile executors and touch controls.*\n![Mobile Preview](MOBILE.png)\n\n`;
        content += `⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n`;

        // PC Changelog
        content += `# ✦ STARSHIP CORE | CHANGELOG\n`;
        content += `@everyone **PC Version ${pcData.currentVersion}**\n`;
        content += `Download the latest update from the link below:\nhttps://dsc.gg/starshipcore\n\n`;
        content += `\`\`\`text\nSTARSHIP CORE UPDATE FOR version-${pcData.currentVersion}\n\n`;
        content += `Latest Changes\n`;
        latestPC.changes.forEach(change => {
            content += `- [+] ${change}\n`;
        });
        content += `\`\`\`\n\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n\n`;

        // Mobile Changelog
        content += `@everyone **Mobile Version ${mobileData.currentVersion}**\n`;
        content += `Join our community for mobile support:\nhttps://dsc.gg/starshipcore\n\n`;
        content += `\`\`\`text\nSTARSHIP MOBILE UPDATE FOR version-${mobileData.currentVersion}\n\n`;
        content += `Latest Changes\n`;
        latestMobile.changes.forEach(change => {
            content += `- [+] ${change}\n`;
        });
        content += `\`\`\`\n\n⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯⎯\n`;

        fs.writeFileSync(paths.baruMd, content, 'utf8');
        console.log(`✅ Successfully updated baru.md`);

    } catch (e) { console.error("❌ Error updating baru.md:", e.message); }
}

console.log("🔄 Syncing versions...");
updateVersion(paths.pcScript, paths.pcChangelog, "VERSION");
updateVersion(paths.mobileScript, paths.mobileChangelog, "VERSION");
generateBaruMd();
