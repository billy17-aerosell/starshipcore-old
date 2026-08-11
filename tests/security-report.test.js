import { describe, it, expect, vi } from "vitest";
import {
  buildDiscordPayload,
  createChallenge,
  createSecurityReportHandler,
  securityReportConstants,
  verifyChallenge,
} from "../lib/security-report.js";

const SECRET = "test-secret-that-is-long-enough-for-security-report-tests";
const IP = "203.0.113.10";
const USER_ID = "9268011358";
const NOW = 1_750_000_000_000;

function createResponse() {
  return {
    statusCode: 200,
    headers: {},
    body: null,
    setHeader(name, value) {
      this.headers[name] = value;
    },
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

function createRequest({ method = "GET", query = {}, body, ip = IP } = {}) {
  return {
    method,
    query,
    body,
    headers: { "x-forwarded-for": ip },
    connection: {},
  };
}

function createHarness({ nowMs = NOW, fetchImpl } = {}) {
  let nonceCounter = 0;
  const fetchMock = fetchImpl || vi.fn(async () => ({ ok: true, status: 204 }));
  const handler = createSecurityReportHandler({
    env: {
      STARSHIP_SECRET_KEY: SECRET,
      DISCORD_SECURITY_WEBHOOK_URL: "https://discord.invalid/security-test",
    },
    redisProvider: async () => null,
    fetchImpl: fetchMock,
    now: () => nowMs,
    nonceFactory: () => `nonce_for_report_${String(++nonceCounter).padStart(4, "0")}`,
  });

  return { handler, fetchMock };
}

async function issueChallenge(handler, userId = USER_ID, ip = IP) {
  const response = createResponse();
  await handler(
    createRequest({
      method: "GET",
      query: { action: "challenge", userId },
      ip,
    }),
    response,
  );
  expect(response.statusCode).toBe(200);
  return response.body.challenge;
}

function validReport(challenge, overrides = {}) {
  return {
    challenge,
    userId: USER_ID,
    username: "Billy17",
    displayName: "Billy",
    executor: "Test Executor",
    hwid: "raw-sensitive-device-identifier",
    reason: "Competitor HttpGet detected (motioncore.web.id)",
    placeId: "1234567890",
    ...overrides,
  };
}

describe("security report challenges", () => {
  it("accepts an untampered challenge", () => {
    const challenge = createChallenge({
      userId: USER_ID,
      clientIP: IP,
      secret: SECRET,
      nowMs: NOW,
      nonce: "nonce_for_direct_test_001",
    });

    expect(
      verifyChallenge({ challenge, userId: USER_ID, clientIP: IP, secret: SECRET, nowMs: NOW + 1000 }),
    ).toMatchObject({ valid: true });
  });

  it("rejects a modified signature", () => {
    const challenge = createChallenge({
      userId: USER_ID,
      clientIP: IP,
      secret: SECRET,
      nowMs: NOW,
      nonce: "nonce_for_direct_test_002",
    });
    const tampered = `${challenge.slice(0, -1)}${challenge.endsWith("a") ? "b" : "a"}`;

    expect(
      verifyChallenge({ challenge: tampered, userId: USER_ID, clientIP: IP, secret: SECRET, nowMs: NOW }),
    ).toMatchObject({ valid: false, error: "INVALID_SIGNATURE" });
  });

  it("rejects expired challenges", () => {
    const challenge = createChallenge({
      userId: USER_ID,
      clientIP: IP,
      secret: SECRET,
      nowMs: NOW,
      nonce: "nonce_for_direct_test_003",
    });

    expect(
      verifyChallenge({
        challenge,
        userId: USER_ID,
        clientIP: IP,
        secret: SECRET,
        nowMs: NOW + securityReportConstants.CHALLENGE_TTL_MS + 1,
      }),
    ).toMatchObject({ valid: false, error: "CHALLENGE_EXPIRED" });
  });

  it("rejects a different user or source IP", () => {
    const challenge = createChallenge({
      userId: USER_ID,
      clientIP: IP,
      secret: SECRET,
      nowMs: NOW,
      nonce: "nonce_for_direct_test_004",
    });

    expect(
      verifyChallenge({ challenge, userId: "12345", clientIP: IP, secret: SECRET, nowMs: NOW }),
    ).toMatchObject({ valid: false, error: "CHALLENGE_MISMATCH" });
    expect(
      verifyChallenge({ challenge, userId: USER_ID, clientIP: "198.51.100.7", secret: SECRET, nowMs: NOW }),
    ).toMatchObject({ valid: false, error: "CHALLENGE_MISMATCH" });
  });
});

describe("security report endpoint", () => {
  it("accepts a challenge exactly once", async () => {
    const { handler, fetchMock } = createHarness();
    const challenge = await issueChallenge(handler);
    const requestBody = validReport(challenge);

    const first = createResponse();
    await handler(createRequest({ method: "POST", body: requestBody }), first);
    expect(first.statusCode).toBe(200);
    expect(first.body).toEqual({ accepted: true, delivered: true });
    expect(fetchMock).toHaveBeenCalledTimes(1);

    const replay = createResponse();
    await handler(createRequest({ method: "POST", body: requestBody }), replay);
    expect(replay.statusCode).toBe(409);
    expect(replay.body).toEqual({ error: "CHALLENGE_ALREADY_USED" });
    expect(fetchMock).toHaveBeenCalledTimes(1);
  });

  it("returns a delivery error when Discord rejects the webhook", async () => {
    const fetchMock = vi.fn(async () => ({ ok: false, status: 404 }));
    const { handler } = createHarness({ fetchImpl: fetchMock });
    const challenge = await issueChallenge(handler);
    const response = createResponse();

    await handler(createRequest({ method: "POST", body: validReport(challenge) }), response);

    expect(response.statusCode).toBe(502);
    expect(response.body).toEqual({
      error: "DISCORD_REJECTED_REPORT",
      delivered: false,
      discordStatus: 404,
    });
  });

  it("rejects invalid and oversized report bodies", async () => {
    const { handler } = createHarness();
    const challenge = await issueChallenge(handler);

    const invalid = createResponse();
    await handler(
      createRequest({ method: "POST", body: validReport(challenge, { reason: "x".repeat(601) }) }),
      invalid,
    );
    expect(invalid.statusCode).toBe(400);
    expect(invalid.body).toEqual({ error: "INVALID_REASON" });

    const oversized = createResponse();
    await handler(
      createRequest({ method: "POST", body: JSON.stringify({ padding: "x".repeat(13 * 1024) }) }),
      oversized,
    );
    expect(oversized.statusCode).toBe(413);
    expect(oversized.body).toEqual({ error: "PAYLOAD_TOO_LARGE" });
  });

  it("sanitizes Discord text, disables mentions, and never forwards raw HWID", async () => {
    const { handler, fetchMock } = createHarness();
    const challenge = await issueChallenge(handler);
    const rawHwid = "raw-sensitive-device-identifier";
    const response = createResponse();

    await handler(
      createRequest({
        method: "POST",
        body: validReport(challenge, {
          username: "@everyone",
          reason: "@everyone MotionCore detected",
          hwid: rawHwid,
        }),
      }),
      response,
    );

    const discordPayload = JSON.parse(fetchMock.mock.calls[0][1].body);
    expect(discordPayload.allowed_mentions).toEqual({ parse: [] });
    expect(JSON.stringify(discordPayload)).not.toContain(rawHwid);
    expect(discordPayload.embeds[0].fields.find((field) => field.name === "HWID Fingerprint").value)
      .toMatch(/^`[a-f0-9]{24}`$/);
  });

  it("rate-limits excessive challenge requests", async () => {
    const { handler } = createHarness();
    let response;

    for (let index = 0; index <= securityReportConstants.CHALLENGE_USER_LIMIT; index += 1) {
      response = createResponse();
      await handler(
        createRequest({
          method: "GET",
          query: { action: "challenge", userId: USER_ID },
        }),
        response,
      );
    }

    expect(response.statusCode).toBe(429);
    expect(response.body).toEqual({ error: "RATE_LIMITED" });
    expect(response.headers["Retry-After"]).toBe("60");
  });
});

describe("Discord payload helper", () => {
  it("does not expose the raw HWID when built directly", () => {
    const rawHwid = "device-id-that-must-not-appear";
    const payload = buildDiscordPayload({
      report: validReport("unused", { hwid: rawHwid }),
      clientIP: IP,
      secret: SECRET,
      nowMs: NOW,
    });

    expect(payload.allowed_mentions.parse).toEqual([]);
    expect(JSON.stringify(payload)).not.toContain(rawHwid);
  });
});