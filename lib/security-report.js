import crypto from "crypto";
import { getClientIP } from "./ip-ban.js";

const CHALLENGE_TTL_MS = 90 * 1000;
const CHALLENGE_RATE_WINDOW_SECONDS = 60;
const CHALLENGE_IP_LIMIT = 12;
const CHALLENGE_USER_LIMIT = 6;
const REPORT_RATE_WINDOW_SECONDS = 5 * 60;
const REPORT_IP_LIMIT = 4;
const REPORT_USER_LIMIT = 3;
const MAX_BODY_BYTES = 12 * 1024;

let defaultRedisPromise = null;

async function defaultRedisProvider() {
  if (!defaultRedisPromise) {
    defaultRedisPromise = import("./redis.js")
      .then((module) => module.default || null)
      .catch(() => null);
  }
  return defaultRedisPromise;
}

function sanitizeText(value, maxLength, fallback = "Unknown") {
  if (typeof value !== "string") return fallback;

  const clean = value
    .replace(/[\u0000-\u001f\u007f]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  return clean ? clean.slice(0, maxLength) : fallback;
}

function escapeDiscordText(value) {
  return String(value).replace(/([\\`*_{}\[\]()#+\-.!|>~@])/g, "\\$1");
}

function isValidUserId(userId) {
  return typeof userId === "string" && /^\d{1,20}$/.test(userId);
}

function normalizeIP(ip) {
  return sanitizeText(ip, 80, "unknown");
}

function hashIdentifier(value, secret, label = "value", length = 32) {
  return crypto
    .createHmac("sha256", secret)
    .update(`${label}:${value}`)
    .digest("hex")
    .slice(0, length);
}

function encodeBase64Url(value) {
  return Buffer.from(value, "utf8").toString("base64url");
}

function decodeBase64Url(value) {
  return Buffer.from(value, "base64url").toString("utf8");
}

export function createChallenge({ userId, clientIP, secret, nowMs = Date.now(), nonce }) {
  if (!secret) throw new Error("STARSHIP_SECRET_KEY is required");
  if (!isValidUserId(userId)) throw new Error("INVALID_USER_ID");

  const payload = {
    v: 1,
    u: userId,
    i: hashIdentifier(normalizeIP(clientIP), secret, "ip"),
    n: nonce || crypto.randomBytes(18).toString("base64url"),
    t: nowMs,
    e: nowMs + CHALLENGE_TTL_MS,
  };
  const encodedPayload = encodeBase64Url(JSON.stringify(payload));
  const signature = crypto
    .createHmac("sha256", secret)
    .update(encodedPayload)
    .digest("hex");

  return `${encodedPayload}.${signature}`;
}

export function verifyChallenge({ challenge, userId, clientIP, secret, nowMs = Date.now() }) {
  try {
    if (!secret || typeof challenge !== "string" || challenge.length > 2048) {
      return { valid: false, error: "INVALID_CHALLENGE" };
    }
    if (!isValidUserId(userId)) {
      return { valid: false, error: "INVALID_USER_ID" };
    }

    const parts = challenge.split(".");
    if (parts.length !== 2 || !/^[a-f0-9]{64}$/i.test(parts[1])) {
      return { valid: false, error: "INVALID_CHALLENGE" };
    }

    const expectedSignature = crypto
      .createHmac("sha256", secret)
      .update(parts[0])
      .digest();
    const suppliedSignature = Buffer.from(parts[1], "hex");

    if (
      suppliedSignature.length !== expectedSignature.length ||
      !crypto.timingSafeEqual(suppliedSignature, expectedSignature)
    ) {
      return { valid: false, error: "INVALID_SIGNATURE" };
    }

    const payload = JSON.parse(decodeBase64Url(parts[0]));
    if (
      payload.v !== 1 ||
      payload.u !== userId ||
      payload.i !== hashIdentifier(normalizeIP(clientIP), secret, "ip") ||
      typeof payload.n !== "string" ||
      !/^[A-Za-z0-9_-]{16,64}$/.test(payload.n) ||
      !Number.isFinite(payload.t) ||
      !Number.isFinite(payload.e)
    ) {
      return { valid: false, error: "CHALLENGE_MISMATCH" };
    }
    if (payload.t > nowMs + 5000) {
      return { valid: false, error: "FUTURE_CHALLENGE" };
    }
    if (payload.e < nowMs || payload.e - payload.t > CHALLENGE_TTL_MS) {
      return { valid: false, error: "CHALLENGE_EXPIRED" };
    }

    return { valid: true, payload };
  } catch {
    return { valid: false, error: "INVALID_CHALLENGE" };
  }
}

function parseReport(body) {
  const userId = typeof body?.userId === "number" ? String(body.userId) : body?.userId;
  if (!isValidUserId(userId)) {
    return { valid: false, error: "INVALID_USER_ID" };
  }
  if (typeof body?.reason !== "string" || body.reason.trim().length === 0 || body.reason.length > 600) {
    return { valid: false, error: "INVALID_REASON" };
  }
  if (typeof body?.challenge !== "string") {
    return { valid: false, error: "MISSING_CHALLENGE" };
  }

  const placeId = typeof body.placeId === "number" ? String(body.placeId) : body.placeId;
  return {
    valid: true,
    data: {
      challenge: body.challenge,
      userId,
      username: sanitizeText(body.username, 32),
      displayName: sanitizeText(body.displayName, 50),
      executor: sanitizeText(body.executor, 100),
      hwid: sanitizeText(body.hwid, 256),
      reason: sanitizeText(body.reason, 500, "Security policy violation"),
      placeId: typeof placeId === "string" && /^\d{1,20}$/.test(placeId) ? placeId : "0",
    },
  };
}

export function buildDiscordPayload({ report, clientIP, secret, nowMs = Date.now() }) {
  const username = escapeDiscordText(report.username);
  const displayName = escapeDiscordText(report.displayName);
  const executor = escapeDiscordText(report.executor);
  const reason = escapeDiscordText(report.reason);
  const safeIP = escapeDiscordText(normalizeIP(clientIP));
  const hwidFingerprint =
    report.hwid && report.hwid !== "Unknown"
      ? hashIdentifier(report.hwid, secret, "hwid", 24)
      : "Unavailable";

  return {
    content: "🚨 **SECURITY VIOLATION DETECTED**",
    allowed_mentions: { parse: [] },
    embeds: [
      {
        title: "Starship Anti-Thief Logs",
        color: 0xff0000,
        fields: [
          { name: "Player", value: `**${displayName}** (@${username})`, inline: true },
          {
            name: "User ID",
            value: `[${report.userId}](https://www.roblox.com/users/${report.userId}/profile)`,
            inline: true,
          },
          { name: "Executor", value: executor, inline: true },
          { name: "HWID Fingerprint", value: `\`${hwidFingerprint}\``, inline: false },
          { name: "Detection Reason", value: reason, inline: false },
          { name: "Location", value: `Game ID: ${report.placeId}`, inline: true },
          { name: "Source IP", value: `\`${safeIP}\``, inline: true },
        ],
        footer: { text: "Starship Security System v4.0 • Server Relay" },
        timestamp: new Date(nowMs).toISOString(),
      },
    ],
  };
}

function createMemoryState() {
  return { rateLimits: new Map(), usedNonces: new Map() };
}

function pruneMemoryMap(map, nowMs) {
  for (const [key, entry] of map.entries()) {
    if (entry.expiresAt <= nowMs) map.delete(key);
  }
}

async function checkRateLimit({ redis, memory, key, limit, windowSeconds, nowMs }) {
  if (redis) {
    try {
      const count = Number(await redis.eval(
        "local c = redis.call('INCR', KEYS[1]); if c == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]); end; return c",
        1,
        key,
        windowSeconds,
      ));
      return { allowed: count <= limit, remaining: Math.max(0, limit - count) };
    } catch {
      // Use the per-instance limiter if Redis is temporarily unavailable.
    }
  }

  pruneMemoryMap(memory.rateLimits, nowMs);
  const current = memory.rateLimits.get(key);
  if (!current || current.expiresAt <= nowMs) {
    memory.rateLimits.set(key, { count: 1, expiresAt: nowMs + windowSeconds * 1000 });
    return { allowed: true, remaining: limit - 1 };
  }

  current.count += 1;
  return { allowed: current.count <= limit, remaining: Math.max(0, limit - current.count) };
}

async function consumeNonce({ redis, memory, nonceKey, ttlSeconds, nowMs }) {
  if (redis) {
    try {
      const result = await redis.set(nonceKey, "1", "NX", "EX", ttlSeconds);
      return result === "OK";
    } catch {
      // Use the per-instance replay guard if Redis is temporarily unavailable.
    }
  }

  pruneMemoryMap(memory.usedNonces, nowMs);
  if (memory.usedNonces.has(nonceKey)) return false;
  memory.usedNonces.set(nonceKey, { expiresAt: nowMs + ttlSeconds * 1000 });
  return true;
}

function parseRequestBody(req) {
  if (typeof req.body === "string") {
    if (Buffer.byteLength(req.body, "utf8") > MAX_BODY_BYTES) {
      throw new Error("PAYLOAD_TOO_LARGE");
    }
    return JSON.parse(req.body);
  }

  const serialized = JSON.stringify(req.body || {});
  if (Buffer.byteLength(serialized, "utf8") > MAX_BODY_BYTES) {
    throw new Error("PAYLOAD_TOO_LARGE");
  }
  return req.body || {};
}

function setSecurityHeaders(res) {
  res.setHeader("Cache-Control", "no-store, max-age=0");
  res.setHeader("X-Content-Type-Options", "nosniff");
}

export function createSecurityReportHandler(options = {}) {
  const memory = createMemoryState();
  const redisProvider = options.redisProvider || defaultRedisProvider;
  const fetchImpl = options.fetchImpl || globalThis.fetch;
  const now = options.now || (() => Date.now());
  const nonceFactory = options.nonceFactory || (() => crypto.randomBytes(18).toString("base64url"));
  const env = options.env || process.env;

  return async function securityReportHandler(req, res) {
    setSecurityHeaders(res);

    const secret = env.STARSHIP_SECRET_KEY;
    if (!secret) {
      console.error("[Security Report] STARSHIP_SECRET_KEY is not configured");
      return res.status(503).json({ error: "SERVICE_UNAVAILABLE" });
    }

    const clientIP = getClientIP(req);
    const nowMs = now();
    const ipKey = hashIdentifier(normalizeIP(clientIP), secret, "rate-ip");
    let redis = null;
    try {
      redis = await redisProvider();
    } catch {
      redis = null;
    }

    if (req.method === "GET") {
      const rawUserId = req.query?.userId;
      const userId = typeof rawUserId === "number" ? String(rawUserId) : rawUserId;
      if (req.query?.action !== "challenge" || !isValidUserId(userId)) {
        return res.status(400).json({ error: "INVALID_REQUEST" });
      }

      const userKey = hashIdentifier(userId, secret, "rate-user");
      const ipLimit = await checkRateLimit({
        redis,
        memory,
        key: `starship:security-report:challenge:ip:${ipKey}`,
        limit: CHALLENGE_IP_LIMIT,
        windowSeconds: CHALLENGE_RATE_WINDOW_SECONDS,
        nowMs,
      });
      const userLimit = await checkRateLimit({
        redis,
        memory,
        key: `starship:security-report:challenge:user:${userKey}`,
        limit: CHALLENGE_USER_LIMIT,
        windowSeconds: CHALLENGE_RATE_WINDOW_SECONDS,
        nowMs,
      });

      if (!ipLimit.allowed || !userLimit.allowed) {
        res.setHeader("Retry-After", String(CHALLENGE_RATE_WINDOW_SECONDS));
        return res.status(429).json({ error: "RATE_LIMITED" });
      }

      const challenge = createChallenge({
        userId,
        clientIP,
        secret,
        nowMs,
        nonce: nonceFactory(),
      });
      return res.status(200).json({ challenge, expiresIn: Math.floor(CHALLENGE_TTL_MS / 1000) });
    }

    if (req.method !== "POST") {
      res.setHeader("Allow", "GET, POST");
      return res.status(405).json({ error: "METHOD_NOT_ALLOWED" });
    }

    let body;
    try {
      body = parseRequestBody(req);
    } catch (error) {
      const tooLarge = error.message === "PAYLOAD_TOO_LARGE";
      return res.status(tooLarge ? 413 : 400).json({ error: tooLarge ? "PAYLOAD_TOO_LARGE" : "INVALID_JSON" });
    }

    const parsed = parseReport(body);
    if (!parsed.valid) {
      return res.status(400).json({ error: parsed.error });
    }

    const challengeResult = verifyChallenge({
      challenge: parsed.data.challenge,
      userId: parsed.data.userId,
      clientIP,
      secret,
      nowMs,
    });
    if (!challengeResult.valid) {
      return res.status(403).json({ error: challengeResult.error });
    }

    const userKey = hashIdentifier(parsed.data.userId, secret, "rate-user");
    const ipLimit = await checkRateLimit({
      redis,
      memory,
      key: `starship:security-report:submit:ip:${ipKey}`,
      limit: REPORT_IP_LIMIT,
      windowSeconds: REPORT_RATE_WINDOW_SECONDS,
      nowMs,
    });
    const userLimit = await checkRateLimit({
      redis,
      memory,
      key: `starship:security-report:submit:user:${userKey}`,
      limit: REPORT_USER_LIMIT,
      windowSeconds: REPORT_RATE_WINDOW_SECONDS,
      nowMs,
    });

    if (!ipLimit.allowed || !userLimit.allowed) {
      res.setHeader("Retry-After", String(REPORT_RATE_WINDOW_SECONDS));
      return res.status(429).json({ error: "RATE_LIMITED" });
    }

    const nonceKey = `starship:security-report:nonce:${hashIdentifier(challengeResult.payload.n, secret, "nonce")}`;
    const nonceAccepted = await consumeNonce({
      redis,
      memory,
      nonceKey,
      ttlSeconds: Math.ceil(CHALLENGE_TTL_MS / 1000),
      nowMs,
    });
    if (!nonceAccepted) {
      return res.status(409).json({ error: "CHALLENGE_ALREADY_USED" });
    }

    const discordPayload = buildDiscordPayload({ report: parsed.data, clientIP, secret, nowMs });
    const webhookUrl = env.DISCORD_SECURITY_WEBHOOK_URL;

    if (!webhookUrl || typeof fetchImpl !== "function") {
      console.warn("[Security Report] Webhook not configured; report accepted without delivery");
      return res.status(202).json({ accepted: true });
    }

    try {
      const response = await fetchImpl(webhookUrl, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(discordPayload),
      });
      if (!response?.ok) {
        console.error(`[Security Report] Discord rejected report with status ${response?.status || "unknown"}`);
      }
    } catch (error) {
      console.error("[Security Report] Discord delivery failed:", error.message);
    }

    return res.status(202).json({ accepted: true });
  };
}

export const securityReportConstants = {
  CHALLENGE_TTL_MS,
  CHALLENGE_USER_LIMIT,
  REPORT_USER_LIMIT,
};