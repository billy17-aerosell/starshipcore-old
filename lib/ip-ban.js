// lib/ip-ban.js - Centralized IP ban / strike / trust system
// Reduces false positives via:
//  - 3-strike system before ban (NAT user / probe error tolerance)
//  - TTL ban (auto-unban after 7 days, no permanent lockout)
//  - Trusted IP cache (user yang pernah sukses auth = whitelist 30 hari)
//  - Crawler/link-preview bot detection (Discord/WA/TG bot fetch link → 403 tanpa ban)
//  - Expanded mobile executor patterns

// ═══════════════════════════════════════════════════════════════════
// CONFIG
// ═══════════════════════════════════════════════════════════════════
export const OWNER_IPS = ["36.80.245.122"];

// Legacy key (set) - tetap dicek untuk backward compat dengan ban yang udah ada
export const BANNED_IPS_KEY = "starship:banned_ips";

// New TTL-based ban: starship:ban:<ip> = "1" with EX 7 days
const BAN_KEY_PREFIX = "starship:ban:";
const BAN_TTL_SECONDS = 60 * 60 * 24 * 7; // 7 days

// Strike counter: starship:strike:<ip> = N with EX 1 hour
const STRIKE_KEY_PREFIX = "starship:strike:";
const STRIKE_TTL_SECONDS = 60 * 60; // 1 hour rolling window
const STRIKE_THRESHOLD = 3; // ban after 3 strikes within window

// Trusted IP: starship:trusted:<ip> = "1" with EX 30 days
const TRUSTED_KEY_PREFIX = "starship:trusted:";
const TRUSTED_TTL_SECONDS = 60 * 60 * 24 * 30; // 30 days

// ═══════════════════════════════════════════════════════════════════
// REDIS LAZY LOADER
// ═══════════════════════════════════════════════════════════════════
let _redis = null;
let _redisAttempted = false;

async function getRedis() {
  if (!_redisAttempted) {
    try {
      const mod = await import("./redis.js");
      _redis = mod.default;
    } catch (e) {
      _redis = null;
    }
    _redisAttempted = true;
  }
  return _redis;
}

// ═══════════════════════════════════════════════════════════════════
// CLIENT IP
// ═══════════════════════════════════════════════════════════════════
export function getClientIP(req) {
  return (
    req.headers["x-forwarded-for"]?.split(",")[0]?.trim() ||
    req.headers["x-real-ip"] ||
    req.connection?.remoteAddress ||
    "unknown"
  );
}

// ═══════════════════════════════════════════════════════════════════
// USER-AGENT CLASSIFICATION
// ═══════════════════════════════════════════════════════════════════

// Known crawler / link-preview / search bot UA fragments.
// These access lo punya endpoint karena URL di-share di chat/social,
// BUKAN karena attacker. Block 403 tapi JANGAN ban (IP-nya datacenter
// shared, bisa false positive massive ke user yg share link).
const CRAWLER_PATTERNS = [
  "discordbot",
  "telegrambot",
  "whatsapp",
  "facebookexternalhit",
  "twitterbot",
  "slackbot",
  "linkedinbot",
  "googlebot",
  "bingbot",
  "yandexbot",
  "duckduckbot",
  "applebot",
  "embedly",
  "skypeuripreview",
  "preview",
  "redditbot",
  "pinterest",
  "vkshare",
  "tumblr",
  "okhttp", // Android default HTTP client (sering dipake link preview)
  "python-requests",
  "curl/",
  "wget/",
  "headlesschrome",
  "phantomjs",
];

export function isCrawler(userAgent) {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return CRAWLER_PATTERNS.some((p) => ua.includes(p));
}

// Roblox executor patterns - harus di-allow walaupun UA-nya browser-like
const ROBLOX_EXECUTOR_PATTERNS = [
  "roblox",
  "robloxapp",
  "robloxstudio",
  "robloxplayer",
  "gameclient",
  // Desktop executors
  "synapse",
  "synapse_http",
  "krnl",
  "fluxus",
  "scriptware",
  "script-ware",
  "sentinel",
  "wave",
  "swift",
  "solara",
  "xeno",
  "zorara",
  "potassium",
  // Mobile executors (sering false positive!)
  "arceus",
  "delta",
  "hydrogen",
  "evon",
  "vegax",
  "comet",
  "codex",
  "electron",
  "fury",
  "trigon",
  "cryptic",
  "ronix",
  "kraken",
  "awp",
  "nezur",
  "macsploit",
  "valyse",
  "argon",
];

export function isRobloxExecutor(userAgent) {
  if (!userAgent) return false;
  const ua = userAgent.toLowerCase();
  return ROBLOX_EXECUTOR_PATTERNS.some((p) => ua.includes(p));
}

// Browser detection - hanya match kalau BUKAN executor
const BROWSER_PATTERNS = [
  "Mozilla",
  "Chrome",
  "Safari",
  "Firefox",
  "Edge",
  "Opera",
  "MSIE",
  "Trident",
  "WebKit",
  "Gecko",
];

export function isBrowserUA(userAgent) {
  // Empty UA = allow (banyak executor gak set UA)
  if (!userAgent) return false;
  if (isRobloxExecutor(userAgent)) return false;
  if (isCrawler(userAgent)) return false; // crawler ditangani terpisah
  return BROWSER_PATTERNS.some((p) => userAgent.includes(p));
}

// ═══════════════════════════════════════════════════════════════════
// BAN STATE
// ═══════════════════════════════════════════════════════════════════

export async function isIPBanned(ip) {
  if (!ip || ip === "unknown") return false;
  if (OWNER_IPS.includes(ip)) {
    // Auto-unban owner kalau kepleset
    try {
      const r = await getRedis();
      if (r) {
        await r.srem(BANNED_IPS_KEY, ip);
        await r.del(BAN_KEY_PREFIX + ip);
      }
    } catch {}
    return false;
  }

  try {
    const r = await getRedis();
    if (!r) return false;

    // Check new TTL ban first
    const ttlBan = await r.get(BAN_KEY_PREFIX + ip);
    if (ttlBan) return true;

    // Fallback: legacy permanent set
    const legacy = await r.sismember(BANNED_IPS_KEY, ip);
    return legacy === 1;
  } catch (e) {
    console.error("[IP Ban] check error:", e.message);
    return false;
  }
}

export async function banIP(ip, reason, ttlSeconds = BAN_TTL_SECONDS) {
  if (!ip || ip === "unknown") return false;
  if (OWNER_IPS.includes(ip)) {
    console.log(`[IP Ban] 👑 cannot ban owner IP: ${ip}`);
    return false;
  }

  try {
    const r = await getRedis();
    if (!r) return false;

    await r.set(BAN_KEY_PREFIX + ip, "1", "EX", ttlSeconds);
    // Tambah ke legacy set juga untuk konsistensi (tapi bisa kita stop pake nanti)
    await r.sadd(BANNED_IPS_KEY, ip);
    // Hapus strike counter (udah ke-promote ke ban)
    await r.del(STRIKE_KEY_PREFIX + ip);

    const days = Math.round(ttlSeconds / 86400);
    console.log(`[IP Ban] 🚫 BANNED ${ip} for ${days}d - ${reason}`);
    return true;
  } catch (e) {
    console.error("[IP Ban] ban error:", e.message);
    return false;
  }
}

export async function unbanIP(ip) {
  if (!ip) return false;
  try {
    const r = await getRedis();
    if (!r) return false;
    await r.del(BAN_KEY_PREFIX + ip);
    await r.srem(BANNED_IPS_KEY, ip);
    await r.del(STRIKE_KEY_PREFIX + ip);
    console.log(`[IP Ban] 🔓 unbanned ${ip}`);
    return true;
  } catch (e) {
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════
// STRIKE SYSTEM (record offense, ban kalau threshold tercapai)
// ═══════════════════════════════════════════════════════════════════

/**
 * Record a soft offense for an IP.
 * Returns { strikes, banned, threshold }.
 *
 * - strike 1-2: cuma warning, gak ban
 * - strike 3+: auto-ban dengan TTL
 * - trusted IP: bypass total (gak nambah strike, gak ban)
 */
export async function recordStrike(ip, reason) {
  if (!ip || ip === "unknown") return { strikes: 0, banned: false, threshold: STRIKE_THRESHOLD };
  if (OWNER_IPS.includes(ip)) return { strikes: 0, banned: false, threshold: STRIKE_THRESHOLD };

  // Trusted IPs bypass strike sepenuhnya
  if (await isIPTrusted(ip)) {
    console.log(`[IP Ban] ✅ trusted IP ${ip} - skip strike (${reason})`);
    return { strikes: 0, banned: false, threshold: STRIKE_THRESHOLD, trusted: true };
  }

  try {
    const r = await getRedis();
    if (!r) return { strikes: 0, banned: false, threshold: STRIKE_THRESHOLD };

    const key = STRIKE_KEY_PREFIX + ip;
    const strikes = await r.incr(key);
    if (strikes === 1) {
      await r.expire(key, STRIKE_TTL_SECONDS);
    }

    if (strikes >= STRIKE_THRESHOLD) {
      await banIP(ip, `${reason} (${strikes} strikes in ${STRIKE_TTL_SECONDS / 60}min)`);
      return { strikes, banned: true, threshold: STRIKE_THRESHOLD };
    }

    console.log(`[IP Ban] ⚠️ strike ${strikes}/${STRIKE_THRESHOLD} for ${ip} - ${reason}`);
    return { strikes, banned: false, threshold: STRIKE_THRESHOLD };
  } catch (e) {
    console.error("[IP Ban] strike error:", e.message);
    return { strikes: 0, banned: false, threshold: STRIKE_THRESHOLD };
  }
}

// ═══════════════════════════════════════════════════════════════════
// TRUSTED IP CACHE
// ═══════════════════════════════════════════════════════════════════

export async function isIPTrusted(ip) {
  if (!ip || ip === "unknown") return false;
  if (OWNER_IPS.includes(ip)) return true;
  try {
    const r = await getRedis();
    if (!r) return false;
    const v = await r.get(TRUSTED_KEY_PREFIX + ip);
    return v === "1";
  } catch {
    return false;
  }
}

/**
 * Mark IP sebagai trusted - panggil ini setelah user sukses auth/load script.
 * IP yang trusted gak akan kena strike/ban sampai TTL expired (30 hari).
 * Kalau user buka link di browser dari device yg sama → gak ke-ban.
 */
export async function markIPTrusted(ip) {
  if (!ip || ip === "unknown") return false;
  if (OWNER_IPS.includes(ip)) return true;
  try {
    const r = await getRedis();
    if (!r) return false;
    await r.set(TRUSTED_KEY_PREFIX + ip, "1", "EX", TRUSTED_TTL_SECONDS);
    return true;
  } catch {
    return false;
  }
}

// ═══════════════════════════════════════════════════════════════════
// HIGH-LEVEL: handle browser/crawler hit di endpoint
// ═══════════════════════════════════════════════════════════════════

/**
 * One-shot helper buat dipake di handler.
 *
 * Returns:
 *   { action: "allow" }                                 - lanjutkan request
 *   { action: "block_crawler" }                         - 403 tanpa ban
 *   { action: "block_trusted", reason }                 - 403 tapi gak ban (trusted)
 *   { action: "warn", strikes, threshold, reason }      - 403, dapet strike tapi belum ban
 *   { action: "ban", reason }                           - 403, baru di-ban
 *   { action: "already_banned" }                        - 403, udah ke-ban sebelumnya
 *
 * Caller cukup cek `action !== "allow"` untuk tau harus return early.
 */
export async function evaluateRequest(req, opts = {}) {
  const ip = getClientIP(req);
  const ua = req.headers["user-agent"] || "";
  const { skipStrike = false } = opts;

  // 1. Owner bypass
  if (OWNER_IPS.includes(ip)) return { action: "allow", ip, ua, owner: true };

  // 2. Already banned?
  if (await isIPBanned(ip)) {
    return { action: "already_banned", ip, ua };
  }

  // 3. Crawler bot? Block tapi gak ban (sumber false positive utama)
  if (isCrawler(ua)) {
    return { action: "block_crawler", ip, ua, reason: "Crawler/link-preview bot" };
  }

  // 4. Browser detected
  if (isBrowserUA(ua)) {
    // Trusted IP? Block tapi gak ban (user lo buka link sendiri di browser)
    if (await isIPTrusted(ip)) {
      return {
        action: "block_trusted",
        ip,
        ua,
        reason: "Browser access from trusted IP (no ban)",
      };
    }

    if (skipStrike) {
      return { action: "warn", ip, ua, strikes: 0, threshold: STRIKE_THRESHOLD, reason: "Browser UA" };
    }

    const result = await recordStrike(ip, `Browser UA: ${ua.substring(0, 60)}`);
    if (result.banned) {
      return { action: "ban", ip, ua, reason: `Browser UA (3 strikes)`, strikes: result.strikes };
    }
    return {
      action: "warn",
      ip,
      ua,
      strikes: result.strikes,
      threshold: result.threshold,
      reason: "Browser UA",
    };
  }

  return { action: "allow", ip, ua };
}
