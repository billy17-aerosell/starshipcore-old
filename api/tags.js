import fs from 'fs';
import path from 'path';

export default function handler(req, res) {
  // 1. Validasi Method (Hanya POST yang boleh agar bisa kirim banyak ID)
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  try {
    // 2. Ambil daftar ID dari request body
    const { userIds } = req.body;

    if (!userIds || !Array.isArray(userIds)) {
      return res.status(400).json({ error: 'Invalid userIds format. Must be an array.' });
    }

    // 3. Baca Database Whitelist
    const whitelistPath = path.join(process.cwd(), 'data', 'whitelist.json');
    const whitelistData = fs.readFileSync(whitelistPath, 'utf8');
    const whitelist = JSON.parse(whitelistData);

    // 4. Filter User yang Cocok
    const results = {};

    userIds.forEach(id => {
      const strId = String(id);
      if (whitelist[strId]) {
        // Hanya kirim Role/Tag. JANGAN kirim data sensitif lain.
        results[strId] = {
          role: whitelist[strId].role || "VIP",
          tag: whitelist[strId].tag || whitelist[strId].role || "VIP" // Custom tag support
        };
      }
    });

    // 5. Kirim Hasil
    res.status(200).json({
      status: 'success',
      tags: results
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
