import fs from 'fs';
import path from 'path';

// GitHub API Configuration
const GITHUB_API = 'https://api.github.com';
const KEYS_PATH = 'data/keys.json'; // Changed from whitelist.json

/**
 * Update keys.json di GitHub Repository
 * @param {object} newKeysData - Complete keys.json data
 * @param {string} currentSha - SHA file saat ini (untuk update)
 */
async function updateKeysOnGitHub(newKeysData, currentSha) {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    console.error('GitHub credentials not configured');
    return false;
  }

  try {
    const content = Buffer.from(JSON.stringify(newKeysData, null, 2)).toString('base64');
    
    const response = await fetch(`${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`, {
      method: 'PUT',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28'
      },
      body: JSON.stringify({
        message: `[Auto] Activate license for user`,
        content: content,
        sha: currentSha
      })
    });

    if (!response.ok) {
      const errorData = await response.json();
      console.error('GitHub API Error:', errorData);
      return false;
    }

    return true;
  } catch (error) {
    console.error('GitHub Update Error:', error);
    return false;
  }
}

/**
 * Get current keys.json from GitHub (untuk dapat SHA terbaru)
 */
async function getKeysFromGitHub() {
  const token = process.env.GITHUB_TOKEN;
  const repo = process.env.GITHUB_REPO;

  if (!token || !repo) {
    return null;
  }

  try {
    const response = await fetch(`${GITHUB_API}/repos/${repo}/contents/${KEYS_PATH}`, {
      headers: {
        'Authorization': `Bearer ${token}`,
        'Accept': 'application/vnd.github.v3+json',
        'X-GitHub-Api-Version': '2022-11-28'
      }
    });

    if (!response.ok) {
      return null;
    }

    const data = await response.json();
    const content = Buffer.from(data.content, 'base64').toString('utf8');
    
    return {
      sha: data.sha,
      keysData: JSON.parse(content)
    };
  } catch (error) {
    console.error('GitHub Fetch Error:', error);
    return null;
  }
}

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    return res.status(405).json({ error: 'Method Not Allowed' });
  }

  const { user } = req.query;

  if (!user) {
    return res.status(400).json({ error: 'Missing User ID' });
  }

  try {
    // Baca keys.json dari file lokal (CONSOLIDATED)
    const keysPath = path.join(process.cwd(), 'data', 'keys.json');
    const keysFileData = fs.readFileSync(keysPath, 'utf8');
    let keysData = JSON.parse(keysFileData);
    
    // Get whitelist from keys.json
    const whitelist = keysData.whitelist || {};
    const userData = whitelist[user];

    if (!userData) {
      return res.status(403).json({ 
        status: 'denied',
        message: 'Not Whitelisted' 
      });
    }

    const now = Math.floor(Date.now() / 1000);

    // === ACTIVATION ON FIRST RUN ===
    // Jika expiry null DAN ada durationDays, ini adalah aktivasi pertama
    if (userData.expiry === null && userData.durationDays) {
      console.log(`Activating license for user ${user}...`);
      
      // Hitung expiry berdasarkan durationDays
      const durationSeconds = userData.durationDays * 24 * 60 * 60; // days to seconds
      const newExpiry = now + durationSeconds;
      
      // Update data user
      userData.expiry = newExpiry;
      userData.activatedAt = now;
      keysData.whitelist[user] = userData;

      // Update ke GitHub
      const githubData = await getKeysFromGitHub();
      
      if (githubData) {
        // Update whitelist dalam keys.json dari GitHub (untuk sinkronisasi)
        if (!githubData.keysData.whitelist) {
          githubData.keysData.whitelist = {};
        }
        githubData.keysData.whitelist[user] = userData;
        
        const updateSuccess = await updateKeysOnGitHub(githubData.keysData, githubData.sha);
        
        if (updateSuccess) {
          console.log(`License activated for user ${user}. Expiry: ${new Date(newExpiry * 1000).toISOString()}`);
        } else {
          console.error(`Failed to update GitHub for user ${user}`);
          // Tetap lanjutkan walaupun GitHub update gagal (pakai local)
        }
      } else {
        console.warn('Could not fetch GitHub data, using local keys.json');
      }
    }
    // === END ACTIVATION ===

    // Cek expiry (skip jika LIFETIME / tidak ada expiry)
    if (userData.expiry) {
      if (now > userData.expiry) {
        return res.status(403).json({
          status: 'denied',
          message: 'License Expired',
          expiredAt: new Date(userData.expiry * 1000).toISOString()
        });
      }
    }

    // === Load dan encrypt script ===
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

    // Hitung remaining time
    let remainingDays = null;
    if (userData.expiry) {
      remainingDays = Math.ceil((userData.expiry - now) / 86400);
    }

    res.status(200).json({
      status: 'success',
      role: userData.role || 'VIP',
      duration: userData.duration || 'LIFETIME',
      expiry: userData.expiry || null,
      remainingDays: remainingDays,
      activatedAt: userData.activatedAt || null,
      key: dynamicKey,
      blob: base64Blob
    });

  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Internal Server Error' });
  }
}
