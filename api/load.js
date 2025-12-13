import fs from 'fs';
import path from 'path';

export default function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { user } = req.query;

  if (!user) {
    return res.status(400).json({ error: 'Missing User ID' });
  }

  try {
    const whitelistPath = path.join(process.cwd(), 'data', 'whitelist.json');
    const whitelistData = fs.readFileSync(whitelistPath, 'utf8');
    const whitelist = JSON.parse(whitelistData);

    const userData = whitelist[user];

    if (!userData) {
      return res.status(403).json({ 
        status: 'denied',
        message: 'Not Whitelisted' 
      });
    }

    if (userData.expiry) {
      const now = Math.floor(Date.now() / 1000);
      if (now > userData.expiry) {
        return res.status(403).json({
          status: 'denied',
          message: 'License Expired'
        });
      }
    }

    const scriptPath = path.join(process.cwd(), 'data', 'StarshipCore.lua');
    
    if (!fs.existsSync(scriptPath)) {
      return res.status(500).json({ error: 'Script file missing on server' });
    }

    // BACA SEBAGAI BUFFER (PENTING!)
    let scriptBuffer = fs.readFileSync(scriptPath);

    // Hapus BOM jika ada (3 byte pertama: EF BB BF)
    if (scriptBuffer.length >= 3 && scriptBuffer[0] === 0xEF && scriptBuffer[1] === 0xBB && scriptBuffer[2] === 0xBF) {
      scriptBuffer = scriptBuffer.subarray(3);
    }

    // Generate Dynamic Key
    const generateKey = (length) => {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*()_+';
      let result = '';
      for (let i = 0; i < length; i++) {
        result += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      return result;
    };

    const dynamicKey = generateKey(64);
    const keyBuffer = Buffer.from(dynamicKey);

    // Enkripsi XOR (Buffer to Buffer)
    const encryptedBuffer = Buffer.alloc(scriptBuffer.length);
    for (let i = 0; i < scriptBuffer.length; i++) {
      encryptedBuffer[i] = scriptBuffer[i] ^ keyBuffer[i % keyBuffer.length];
    }

    // Encode ke Base64
    const base64Blob = encryptedBuffer.toString('base64');

    res.status(200).json({
      status: 'success',
      role: userData.role || 'VIP',
      duration: userData.duration || 'LIFETIME',
      expiry: userData.expiry || null, // Kirim timestamp expiry
      key: dynamicKey,
      blob: base64Blob
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
