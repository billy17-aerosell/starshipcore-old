// ══════════════════════════════════════════════════════════════════
// STARSHIPCORE CRYPTO UTILITIES v1.0
// Advanced Security: RSA Signature + AES Encryption + Anti-Replay
// ══════════════════════════════════════════════════════════════════

import crypto from 'crypto';

// ═══════════════════════════════════════════════════════════════════
// CONFIGURATION
// ═══════════════════════════════════════════════════════════════════

// Signature validity period (30 seconds)
const SIGNATURE_VALIDITY_MS = 30 * 1000;

// AES Configuration
const AES_ALGORITHM = 'aes-256-cbc';

// RSA Key Pair (Generated once, stored securely)
// In production, these should be stored in environment variables
const RSA_PRIVATE_KEY = process.env.RSA_PRIVATE_KEY || null;
const RSA_PUBLIC_KEY = process.env.RSA_PUBLIC_KEY || null;

// Fallback: Generate keys if not provided (for development)
let keyPair = null;

function getKeyPair() {
  if (RSA_PRIVATE_KEY && RSA_PUBLIC_KEY) {
    return {
      privateKey: RSA_PRIVATE_KEY,
      publicKey: RSA_PUBLIC_KEY
    };
  }
  
  // Generate new key pair if not set (development mode)
  if (!keyPair) {
    console.log('[Crypto] Generating new RSA key pair (dev mode)...');
    keyPair = crypto.generateKeyPairSync('rsa', {
      modulusLength: 2048,
      publicKeyEncoding: { type: 'spki', format: 'pem' },
      privateKeyEncoding: { type: 'pkcs8', format: 'pem' }
    });
    console.log('[Crypto] RSA key pair generated successfully');
  }
  
  return keyPair;
}

// ═══════════════════════════════════════════════════════════════════
// NONCE TRACKING (Anti-Replay Protection)
// ═══════════════════════════════════════════════════════════════════

const usedNonces = new Map();
const NONCE_EXPIRY_MS = 60 * 1000; // 1 minute

function generateNonce() {
  return crypto.randomBytes(16).toString('hex');
}

function isNonceValid(nonce) {
  // Check if nonce was already used
  if (usedNonces.has(nonce)) {
    return false;
  }
  return true;
}

function markNonceUsed(nonce) {
  usedNonces.set(nonce, Date.now());
  
  // Clean up old nonces
  const now = Date.now();
  for (const [key, timestamp] of usedNonces.entries()) {
    if (now - timestamp > NONCE_EXPIRY_MS) {
      usedNonces.delete(key);
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// RSA DIGITAL SIGNATURE
// ═══════════════════════════════════════════════════════════════════

/**
 * Sign data with RSA private key
 * @param {object} data - Data to sign
 * @returns {object} - Signed payload with signature, timestamp, nonce
 */
function signPayload(data) {
  const keys = getKeyPair();
  const timestamp = Date.now();
  const nonce = generateNonce();
  
  // Create payload with metadata
  const payload = {
    data: data,
    timestamp: timestamp,
    nonce: nonce,
    expiresAt: timestamp + SIGNATURE_VALIDITY_MS
  };
  
  // Create signature of the payload
  const payloadString = JSON.stringify(payload);
  const sign = crypto.createSign('SHA256');
  sign.update(payloadString);
  sign.end();
  
  const signature = sign.sign(keys.privateKey, 'base64');
  
  return {
    payload: payload,
    signature: signature,
    publicKeyHash: crypto.createHash('md5').update(keys.publicKey).digest('hex').substring(0, 8)
  };
}

/**
 * Verify signature of a payload
 * @param {object} signedData - Data containing payload and signature
 * @returns {object} - { valid: boolean, data: object|null, error: string|null }
 */
function verifyPayload(signedData) {
  try {
    const keys = getKeyPair();
    const { payload, signature } = signedData;
    
    // Check timestamp validity
    const now = Date.now();
    if (payload.timestamp > now + 5000) {
      return { valid: false, data: null, error: 'FUTURE_TIMESTAMP' };
    }
    if (now > payload.expiresAt) {
      return { valid: false, data: null, error: 'EXPIRED' };
    }
    
    // Check nonce (anti-replay)
    if (!isNonceValid(payload.nonce)) {
      return { valid: false, data: null, error: 'NONCE_REUSED' };
    }
    
    // Verify signature
    const payloadString = JSON.stringify(payload);
    const verify = crypto.createVerify('SHA256');
    verify.update(payloadString);
    verify.end();
    
    const isValid = verify.verify(keys.publicKey, signature, 'base64');
    
    if (isValid) {
      markNonceUsed(payload.nonce);
      return { valid: true, data: payload.data, error: null };
    } else {
      return { valid: false, data: null, error: 'INVALID_SIGNATURE' };
    }
  } catch (error) {
    return { valid: false, data: null, error: error.message };
  }
}

// ═══════════════════════════════════════════════════════════════════
// AES ENCRYPTION (Replaces XOR)
// ═══════════════════════════════════════════════════════════════════

/**
 * Generate a random AES key
 * @returns {string} - Hex-encoded 256-bit key
 */
function generateAESKey() {
  return crypto.randomBytes(32).toString('hex');
}

/**
 * Encrypt data with AES-256-CBC
 * @param {string} plaintext - Data to encrypt
 * @param {string} keyHex - Hex-encoded 256-bit key
 * @returns {object} - { encrypted: string, iv: string }
 */
function encryptAES(plaintext, keyHex) {
  const key = Buffer.from(keyHex, 'hex');
  const iv = crypto.randomBytes(16);
  const cipher = crypto.createCipheriv(AES_ALGORITHM, key, iv);
  
  let encrypted = cipher.update(plaintext, 'utf8', 'base64');
  encrypted += cipher.final('base64');
  
  return {
    encrypted: encrypted,
    iv: iv.toString('hex')
  };
}

/**
 * Decrypt data with AES-256-CBC
 * @param {string} encryptedBase64 - Base64-encoded encrypted data
 * @param {string} keyHex - Hex-encoded 256-bit key
 * @param {string} ivHex - Hex-encoded IV
 * @returns {string} - Decrypted plaintext
 */
function decryptAES(encryptedBase64, keyHex, ivHex) {
  const key = Buffer.from(keyHex, 'hex');
  const iv = Buffer.from(ivHex, 'hex');
  const decipher = crypto.createDecipheriv(AES_ALGORITHM, key, iv);
  
  let decrypted = decipher.update(encryptedBase64, 'base64', 'utf8');
  decrypted += decipher.final('utf8');
  
  return decrypted;
}

// ═══════════════════════════════════════════════════════════════════
// HONEYPOT / TRAP SYSTEM
// ═══════════════════════════════════════════════════════════════════

/**
 * Generate honeypot data to catch crackers
 * @returns {object} - Fake credentials that will trigger ban if used
 */
function generateHoneypot() {
  const trapId = crypto.randomBytes(4).toString('hex');
  return {
    [`_dk_${trapId}`]: crypto.randomBytes(16).toString('hex'),
    [`_bt_${trapId}`]: crypto.randomBytes(32).toString('hex'),
    [`_sk`]: crypto.randomBytes(24).toString('base64')
  };
}

/**
 * Check if request contains honeypot data (attempting bypass)
 * @param {object} requestData - Incoming request data
 * @returns {boolean} - True if honeypot was triggered
 */
function isHoneypotTriggered(requestData) {
  if (!requestData) return false;
  
  const requestString = JSON.stringify(requestData);
  
  if (requestString.includes('_dk_') || 
      requestString.includes('_bt_') ||
      requestString.includes('"_sk"')) {
    return true;
  }
  
  return false;
}

// ═══════════════════════════════════════════════════════════════════
// PUBLIC KEY EXPORT (For Lua Client)
// ═══════════════════════════════════════════════════════════════════

/**
 * Get the public key in a format usable by Lua
 * Since Lua can't do RSA verification natively, we'll use HMAC instead
 * @returns {string} - Public key or HMAC secret
 */
function getPublicKeyForClient() {
  const keys = getKeyPair();
  // Return a hash of the public key that can be used for simple verification
  return crypto.createHash('sha256').update(keys.publicKey).digest('hex');
}

/**
 * Create a secure payload with server-verifiable token
 * Client doesn't need secret key - just sends token back for verification
 * @param {object} data - Data to sign
 * @param {string} userId - User ID for token binding
 * @returns {object} - Signed data with verification token
 */
function createSecurePayload(data, userId = 'anonymous') {
  const timestamp = Date.now();
  const nonce = generateNonce();
  const secretKey = process.env.STARSHIP_SECRET_KEY;
  if (!secretKey) throw new Error('STARSHIP_SECRET_KEY environment variable is required');
  
  const payload = {
    d: data,  // Short key names to reduce payload size
    t: timestamp,
    n: nonce,
    e: timestamp + SIGNATURE_VALIDITY_MS,
    u: userId // Bind token to specific user
  };
  
  // Create HMAC signature (server-side only)
  const payloadString = JSON.stringify(payload);
  const hmac = crypto.createHmac('sha256', secretKey);
  hmac.update(payloadString);
  const signature = hmac.digest('hex');
  
  // Create verification token (short version for client to send back)
  const verifyToken = crypto.createHmac('sha256', secretKey)
    .update(`${userId}:${timestamp}:${nonce}`)
    .digest('hex')
    .substring(0, 32); // Shorter token for efficiency
  
  return {
    p: payload,
    s: signature,
    vt: verifyToken, // Verification token for client to validate with server
    v: 3  // Version number
  };
}

/**
 * Verify HMAC signature from client
 * @param {object} signedData - Data containing payload and signature
 * @returns {object} - { valid: boolean, data: object|null, error: string|null }
 */
function verifySecurePayload(signedData) {
  try {
    const secretKey = process.env.STARSHIP_SECRET_KEY;
    if (!secretKey) return { valid: false, data: null, error: 'SECRET_KEY_NOT_CONFIGURED' };
    const { p: payload, s: signature } = signedData;
    
    // Check timestamp
    const now = Date.now();
    if (payload.t > now + 5000) {
      return { valid: false, data: null, error: 'FUTURE_TIMESTAMP' };
    }
    if (now > payload.e) {
      return { valid: false, data: null, error: 'EXPIRED' };
    }
    
    // Check nonce
    if (!isNonceValid(payload.n)) {
      return { valid: false, data: null, error: 'NONCE_REUSED' };
    }
    
    // Verify HMAC
    const payloadString = JSON.stringify(payload);
    const hmac = crypto.createHmac('sha256', secretKey);
    hmac.update(payloadString);
    const expectedSignature = hmac.digest('hex');
    
    if (signature === expectedSignature) {
      markNonceUsed(payload.n);
      return { valid: true, data: payload.d, error: null };
    } else {
      return { valid: false, data: null, error: 'INVALID_SIGNATURE' };
    }
  } catch (error) {
    return { valid: false, data: null, error: error.message };
  }
}

/**
 * Verify token from client - NO SECRETS NEEDED ON CLIENT SIDE
 * Client sends: userId, timestamp, nonce, token
 * Server validates and returns: valid/invalid
 * @param {string} userId - User ID that was bound to token
 * @param {number} timestamp - Timestamp from original payload
 * @param {string} nonce - Nonce from original payload
 * @param {string} token - Verification token from client
 * @returns {object} - { valid: boolean, error: string|null }
 */
function verifyTokenFromClient(userId, timestamp, nonce, token) {
  try {
    const secretKey = process.env.STARSHIP_SECRET_KEY;
    if (!secretKey) return { valid: false, error: 'SECRET_KEY_NOT_CONFIGURED' };
    
    // Check timestamp validity (token expires after SIGNATURE_VALIDITY_MS)
    const now = Date.now();
    const expiresAt = timestamp + SIGNATURE_VALIDITY_MS;
    
    if (timestamp > now + 5000) {
      return { valid: false, error: 'FUTURE_TIMESTAMP' };
    }
    if (now > expiresAt) {
      return { valid: false, error: 'TOKEN_EXPIRED' };
    }
    
    // Recreate the expected token
    const expectedToken = crypto.createHmac('sha256', secretKey)
      .update(`${userId}:${timestamp}:${nonce}`)
      .digest('hex')
      .substring(0, 32);
    
    if (token === expectedToken) {
      return { valid: true, error: null };
    } else {
      return { valid: false, error: 'INVALID_TOKEN' };
    }
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

// ═══════════════════════════════════════════════════════════════════
// EXPORTS
// ═══════════════════════════════════════════════════════════════════

export {
  // RSA Functions
  signPayload,
  verifyPayload,
  getPublicKeyForClient,
  
  // AES Functions
  generateAESKey,
  encryptAES,
  decryptAES,
  
  // HMAC Functions (Lua-compatible)
  createSecurePayload,
  verifySecurePayload,
  verifyTokenFromClient,
  
  // Honeypot Functions
  generateHoneypot,
  isHoneypotTriggered,
  
  // Utility Functions
  generateNonce,
  isNonceValid,
  markNonceUsed,
  
  // Constants
  SIGNATURE_VALIDITY_MS
};
