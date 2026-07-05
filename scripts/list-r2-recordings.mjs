import { S3Client, ListObjectsV2Command } from "@aws-sdk/client-s3";
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

// Load .env manually (no dotenv dep required)
function loadEnv(file) {
  try {
    const txt = fs.readFileSync(file, "utf-8");
    for (const line of txt.split(/\r?\n/)) {
      const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/i);
      if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^['"]|['"]$/g, "");
    }
  } catch {}
}
loadEnv(path.resolve(__dirname, "..", ".env"));
loadEnv(path.resolve(__dirname, "..", ".env.local"));

const R2 = {
  ACCOUNT_ID: process.env.R2_ACCOUNT_ID,
  ACCESS_KEY_ID: process.env.R2_ACCESS_KEY_ID,
  SECRET_ACCESS_KEY: process.env.R2_SECRET_ACCESS_KEY,
  BUCKET_NAME: process.env.R2_BUCKET_NAME || "starship-recordings",
};

const client = new S3Client({
  region: "auto",
  endpoint: `https://${R2.ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: R2.ACCESS_KEY_ID,
    secretAccessKey: R2.SECRET_ACCESS_KEY,
  },
});

async function listAll() {
  const names = [];
  let ContinuationToken;
  do {
    const res = await client.send(new ListObjectsV2Command({
      Bucket: R2.BUCKET_NAME,
      Prefix: "recordings/",
      ContinuationToken,
    }));
    if (res.Contents) {
      for (const it of res.Contents) {
        const n = it.Key.replace(/^recordings\//, "").replace(/\.json$/i, "");
        if (n) names.push(n);
      }
    }
    ContinuationToken = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (ContinuationToken);
  return names;
}

// Load private map list (maps gated per user) so they are excluded from the public listing
function loadPrivateMaps() {
  const privatePath = path.resolve(__dirname, "..", "data", "private-access.json");
  const set = new Set();
  try {
    const raw = JSON.parse(fs.readFileSync(privatePath, "utf-8"));
    for (const userId of Object.keys(raw)) {
      const arr = raw[userId];
      if (Array.isArray(arr)) {
        for (const m of arr) if (m) set.add(m);
      }
    }
  } catch (e) {
    console.warn(`[warn] could not read private-access.json: ${e.message}`);
  }
  return set;
}

const allNames = await listAll();
allNames.sort((a, b) => a.localeCompare(b));

const privateSet = loadPrivateMaps();
const publicNames = allNames.filter((n) => !privateSet.has(n));
const hiddenNames = allNames.filter((n) => privateSet.has(n));

const outPath = path.resolve(__dirname, "..", "recording_ids_all.txt");
fs.writeFileSync(outPath, publicNames.join("\n") + "\n", "utf-8");

const privateOutPath = path.resolve(__dirname, "..", "recording_ids_private.txt");
fs.writeFileSync(privateOutPath, hiddenNames.join("\n") + (hiddenNames.length ? "\n" : ""), "utf-8");

console.log(`Total in R2:      ${allNames.length}`);
console.log(`Public (written): ${publicNames.length} -> ${outPath}`);
console.log(`Private (hidden): ${hiddenNames.length} -> ${privateOutPath}`);
if (hiddenNames.length) {
  console.log(`Hidden maps: ${hiddenNames.join(", ")}`);
}
