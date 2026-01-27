import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Get filename from command line argument, or use default
const inputFileName = process.argv[2] || 'recordings_MT Aetheria CVIP.json';
const fileName = path.basename(inputFileName);
const dirName = path.dirname(inputFileName) === '.' ? '..' : path.dirname(inputFileName);

const filePath = path.isAbsolute(inputFileName)
    ? inputFileName
    : path.join(__dirname, dirName, fileName);

const outputFileName = fileName.replace('.json', '_fixed.json');
const outputPath = path.join(path.dirname(filePath), outputFileName);

console.log(`Reading file: ${filePath}`);

try {
    const content = fs.readFileSync(filePath, 'utf8');
    const data = JSON.parse(content);

    if (Array.isArray(data)) {
        console.log('Detected array format. Wrapping in object with Frames property...');
        const fixedData = {
            Frames: data,
            FPS: 60,
            Mode: "Flexible"
        };
        fs.writeFileSync(outputPath, JSON.stringify(fixedData));
        console.log(`✅ Fixed file saved to: ${outputPath}`);
        console.log(`You can now upload this file.`);
    } else if (data.Frames) {
        console.log('ℹ️ File already has Frames property. It should be valid.');
    } else {
        console.log('⚠️ Unknown format. It is not an array and does not have Frames property.');
        console.log('Keys:', Object.keys(data));
    }
} catch (err) {
    console.error('❌ Error processing file:', err.message);
}
