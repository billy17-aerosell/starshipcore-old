import fs from 'fs';
import path from 'path';

export default function handler(req, res) {
  // 1. Validasi Method (Hanya GET yang boleh)
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { user } = req.query;

  if (!user) {
    return res.status(400).json({ error: 'Missing User ID' });
  }

  try {
    // 2. Baca Database Whitelist
    const whitelistPath = path.join(process.cwd(), 'data', 'whitelist.json');
    const whitelistData = fs.readFileSync(whitelistPath, 'utf8');
    const whitelist = JSON.parse(whitelistData);

    // 3. Cek User di Whitelist
    const userData = whitelist[user];

    if (!userData) {
      // User tidak terdaftar
      return res.status(403).json({ 
        status: 'denied',
        message: 'Not Whitelisted' 
      });
    }

    // Cek Expiry (Jika ada)
    if (userData.expiry) {
      const now = Math.floor(Date.now() / 1000);
      if (now > userData.expiry) {
        return res.status(403).json({
          status: 'denied',
          message: 'License Expired'
        });
      }
    }

    // 4. Baca Script Asli (StarshipCore.lua)
    const scriptPath = path.join(process.cwd(), 'data', 'StarshipCore.lua');
    
    // Cek apakah file script ada
    if (!fs.existsSync(scriptPath)) {
      return res.status(500).json({ error: 'Script file missing on server' });
    }

    let scriptContent = fs.readFileSync(scriptPath, 'utf8');

    // Hapus BOM jika ada (Pembersihan ekstra)
    if (scriptContent.charCodeAt(0) === 0xFEFF) {
      scriptContent = scriptContent.slice(1);
    }

    // 5. Generate Dynamic Key (Kunci Sekali Pakai)
    // Kunci ini hanya berlaku untuk request DETIK INI saja.
    const generateKey = (length) => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+';
      let result = '';
      for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return result;
    };

    const dynamicKey = generateKey(64); // Kunci sangat panjang (64 karakter)

    // 6. Enkripsi Script dengan Kunci Dinamis
    const xorEncrypt = (text, key) => {
      let result = [];
      for (let i = 0; i < text.length; i++) {
        const charCode = text.charCodeAt(i);
        const keyCode = key.charCodeAt(i % key.length);
        result.push(String.fromCharCode(charCode ^ keyCode));
      }
      return result.join('');
    };

    const encryptedScript = xorEncrypt(scriptContent, dynamicKey);

    // 7. Encode ke Base64 (Agar aman dikirim lewat JSON)
    const base64Blob = Buffer.from(encryptedScript, 'binary').toString('base64');

    // 8. Kirim Response
    res.status(200).json({
      status: 'success',
      role: userData.role || 'VIP',
      duration: userData.duration || 'LIFETIME',
      key: dynamicKey, // Kunci untuk membuka gembok
      blob: base64Blob // Gemboknya
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
