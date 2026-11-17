import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { beforeEach, describe, expect, it, vi } from "vitest";
import worker, { type Env } from "../src/index";
import {
  APPLE_ROOT_G3_SHA256, FREE_PREVIEW_SHOWS, b64urlEncode, countShow, countedFrom, ecdsaRaw, hashKey, makeTicket,
  monthWindow, parseCert, ticketValid, verifyStoreKitJWS, type KV,
} from "../src/shows";

// Round 38: anonymous show counts. A TEST chain (fixtures/make-test-chain.sh) stands in for Apple's: same shape
// (P-384 root → P-384 intermediate with Apple's WWDR marker → P-256 leaf with the App Store signing marker).

const fx = (name: string) => readFileSync(new URL(`./fixtures/${name}`, import.meta.url), "utf8");
const pemDer = (pem: string) => Buffer.from(pem.replace(/-----[^-]+-----/g, "").replace(/\s/g, ""), "base64");
const b64 = (pem: string) => pemDer(pem).toString("base64");
const ROOT = fx("root.pem"), INTER = fx("inter.pem"), LEAF = fx("leaf.pem"), PLAIN = fx("plain-leaf.pem");
const ROOT_SHA = createHash("sha256").update(pemDer(ROOT)).digest("hex");
const TOKEN = "test-app-token";
const SECRET = "test-shows-secret";
const NOW = Date.UTC(2026, 10, 17, 12);

async function sign(payload: Record<string, unknown>, chain = [LEAF, INTER, ROOT]): Promise<string> {
  const key = await crypto.subtle.importKey("pkcs8", pemDer(fx("leaf.pk8.pem")), { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const enc = (o: unknown) => b64urlEncode(new TextEncoder().encode(JSON.stringify(o)));
  const head = enc({ alg: "ES256", x5c: chain.map(b64) });
  const body = enc(payload);
  const sig = new Uint8Array(await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(`${head}.${body}`)));
  return `${head}.${body}.${b64urlEncode(sig)}`;
}

const sub = (o: Record<string, unknown> = {}) => ({
  bundleId: "app.pretendthat.ios", productId: "app.pretendthat.showpass.monthly", originalTransactionId: "2000000123456789",
  purchaseDate: Date.UTC(2026, 10, 3), expiresDate: Date.UTC(2026, 11, 3), environment: "Sandbox",
  type: "Auto-Renewable Subscription", ...o,
});

class MemKV implements KV {
  data = new Map<string, string>();
  async get(k: string) { return this.data.get(k) ?? null; }
  async put(k: string, v: string) { this.data.set(k, v); }
}

const limiter = () => ({ limit: vi.fn(async () => ({ success: true })) });
function env(o: Partial<Env> = {}): Env {
  return {
    APP_TOKEN: TOKEN, ANTHROPIC_API_KEY: "fake", OPENAI_API_KEY: "fake",
    CLAUDE_LIMIT: limiter(), IMAGE_LIMIT: limiter(), REALTIME_LIMIT: limiter(), MODERATION_LIMIT: limiter(), SHOWS_LIMIT: limiter(),
    SHOW_LIMITS: "enforce", SHOWS: new MemKV(), SHOWS_SECRET: SECRET, TEST_ROOT_SHA256: ROOT_SHA, ...o,
  };
}
const post = (path: string, body: unknown, headers: Record<string, string> = {}) => new Request(`https://relay.test${path}`, {
  method: "POST", headers: { "content-type": "application/json", "x-pt-token": TOKEN, "cf-connecting-ip": "203.0.113.9", ...headers },
  body: JSON.stringify(body),
});

beforeEach(() => {
  vi.useRealTimers();
  vi.stubGlobal("fetch", vi.fn(async () => new Response("{}", { status: 200, headers: { "content-type": "application/json" } })));
});

describe("StoreKit JWS verification", () => {
  it("accepts a JWS signed by the chain and returns the payload", async () => {
    const p = await verifyStoreKitJWS(await sign(sub()), [ROOT_SHA], NOW);
    expect(p.originalTransactionId).toBe("2000000123456789");
  });

  it("pins Apple's root by default (the test root is not trusted)", async () => {
    await expect(verifyStoreKitJWS(await sign(sub()), [APPLE_ROOT_G3_SHA256], NOW)).rejects.toThrow(/untrusted root/);
  });

  it("refuses a tampered payload", async () => {
    const [h, , s] = (await sign(sub())).split(".");
    const forged = b64urlEncode(new TextEncoder().encode(JSON.stringify(sub({ productId: "app.pretendthat.seasonpass.monthly" }))));
    await expect(verifyStoreKitJWS(`${h}.${forged}.${s}`, [ROOT_SHA], NOW)).rejects.toThrow(/signature/);
  });

  it("refuses a leaf without the App Store signing marker", async () => {
    await expect(verifyStoreKitJWS(await sign(sub(), [PLAIN, INTER, ROOT]), [ROOT_SHA], NOW)).rejects.toThrow(/App Store signing/);
  });

  it("refuses a chain in the wrong order", async () => {
    await expect(verifyStoreKitJWS(await sign(sub(), [LEAF, ROOT, INTER]), [ROOT_SHA], NOW)).rejects.toThrow();
  });

  it("refuses junk", async () => {
    await expect(verifyStoreKitJWS("a.b", [ROOT_SHA], NOW)).rejects.toThrow();
    await expect(verifyStoreKitJWS("e30.e30.e30", [ROOT_SHA], NOW)).rejects.toThrow();
  });

  it("parses the test certificates like Apple's (curves, markers)", () => {
    const leaf = parseCert(pemDer(LEAF)), inter = parseCert(pemDer(INTER));
    expect(leaf.curve).toBe("1.2.840.10045.3.1.7");
    expect(inter.curve).toBe("1.3.132.0.34");
    expect(leaf.extensions).toContain("1.2.840.113635.100.6.11.1");
    expect(inter.extensions).toContain("1.2.840.113635.100.6.2.1");
  });

  it("converts DER ECDSA signatures to raw r||s", () => {
    const der = new Uint8Array([0x30, 0x08, 0x02, 0x02, 0x00, 0x81, 0x02, 0x02, 0x01, 0x02]);
    expect([...ecdsaRaw(der, 4)]).toEqual([0, 0, 0, 0x81, 0, 0, 1, 2]);
  });
});

describe("what gets counted", () => {
  it("a plan: a one-way hash of the original transaction, this month's window, the plan's allowance", async () => {
    const c = await countedFrom("subscription", sub(), SECRET, NOW);
    expect(c.allowance).toBe(10);
    expect(c.key).toMatch(/^[0-9a-f]{32}$/);
    expect(c.key).not.toContain("2000000123456789");
    expect(c.key).toBe(await hashKey(SECRET, "sub:2000000123456789"));
    expect(c.windowStart).toBe(Date.UTC(2026, 10, 3));
    expect((await countedFrom("subscription", sub({ productId: "app.pretendthat.seasonpass.yearly", expiresDate: Date.UTC(2027, 10, 3) }), SECRET, NOW)).allowance).toBe(30);
  });

  it("refuses other apps, unknown products, revoked or expired plans and Xcode data", async () => {
    await expect(countedFrom("subscription", sub({ bundleId: "com.other" }), SECRET, NOW)).rejects.toThrow();
    await expect(countedFrom("subscription", sub({ productId: "x" }), SECRET, NOW)).rejects.toThrow();
    await expect(countedFrom("subscription", sub({ revocationDate: NOW - 1 }), SECRET, NOW)).rejects.toThrow();
    await expect(countedFrom("subscription", sub({ expiresDate: NOW - 1 }), SECRET, NOW)).rejects.toThrow();
    await expect(countedFrom("subscription", sub({ environment: "Xcode" }), SECRET, NOW)).rejects.toThrow();
  });

  it("the Free Preview: the app transaction id, 2 in total", async () => {
    const c = await countedFrom("preview", { bundleId: "app.pretendthat.ios", appTransactionId: "705", environment: "Production" }, SECRET, NOW);
    expect(c.allowance).toBe(FREE_PREVIEW_SHOWS);
    expect(c.windowStart).toBe(0);
    expect(c.windowEnd).toBeNull();
    const old = await countedFrom("preview", { bundleId: "app.pretendthat.ios", originalPurchaseDate: 1700000000000 }, SECRET, NOW);
    expect(old.key).not.toBe(c.key);
  });

  it("monthly windows follow the purchase date (yearly plans too) and clamp month ends", () => {
    const a = Date.UTC(2026, 0, 31);
    expect(monthWindow(a, Date.UTC(2026, 1, 15))).toEqual({ start: a, end: Date.UTC(2026, 1, 28) });
    expect(monthWindow(a, Date.UTC(2026, 2, 5)).start).toBe(Date.UTC(2026, 1, 28));
    for (let d = 0; d < 400; d += 7) {
      const t = a + d * 86400000 + 3600000, w = monthWindow(a, t);
      expect(w.start <= t && t < w.end).toBe(true);
    }
  });

  it("the KV counter stops at the allowance only when enforcing", async () => {
    const kv = new MemKV();
    const c = await countedFrom("subscription", sub(), SECRET, NOW);
    for (let i = 0; i < 10; i++) expect((await countShow(kv, c, true)).allowed).toBe(true);
    expect(await countShow(kv, c, true)).toEqual({ allowed: false, used: 10, remaining: 0 });
    expect((await countShow(kv, c, false)).allowed).toBe(true);   // count mode never blocks
    // Stored: only the hash, the window and a number.
    expect([...kv.data.keys()]).toEqual([`c:${c.key}:${c.windowStart}`]);
    expect([...kv.data.values()]).toEqual(["11"]);
  });

  it("tickets are signed and expire", async () => {
    const t = await makeTicket(SECRET, "abc", NOW);
    expect(await ticketValid(SECRET, t, NOW + 1000)).toBe(true);
    expect(await ticketValid(SECRET, t, NOW + 7 * 3600 * 1000)).toBe(false);
    expect(await ticketValid("other", t, NOW)).toBe(false);
    expect(await ticketValid(SECRET, t.replace(/^./, "x"), NOW)).toBe(false);
    expect(await ticketValid(SECRET, null, NOW)).toBe(false);
  });
});

describe("POST /v1/shows/start and the ticket on paid calls", () => {
  const future = () => sub({ purchaseDate: Date.now() - 86400000, expiresDate: Date.now() + 20 * 86400000 });

  it("404s while the feature is off (the app then allows), and needs the token", async () => {
    expect((await worker.fetch(post("/v1/shows/start", {}), env({ SHOW_LIMITS: "off" }))).status).toBe(404);
    expect((await worker.fetch(post("/v1/shows/start", {}), env({ SHOWS: undefined }))).status).toBe(404);
    expect((await worker.fetch(post("/v1/shows/start", {}), env({ SHOWS_SECRET: undefined }))).status).toBe(404);
    expect((await worker.fetch(post("/v1/shows/start", {}, { "x-pt-token": "nope" }), env())).status).toBe(401);
  });

  it("counts a Show Pass to 10 a month, then 402 limit_reached", async () => {
    const e = env();
    const jws = await sign(future());
    for (let i = 9; i >= 0; i--) {
      const r = await worker.fetch(post("/v1/shows/start", { kind: "subscription", jws }), e);
      expect(r.status).toBe(200);
      const b = await r.json() as { ticket: string; remaining: number; allowance: number };
      expect(b.remaining).toBe(i);
      expect(b.allowance).toBe(10);
      expect(typeof b.ticket).toBe("string");
    }
    const over = await worker.fetch(post("/v1/shows/start", { kind: "subscription", jws }), e);
    expect(over.status).toBe(402);
    expect(((await over.json()) as { error: { type: string } }).error.type).toBe("limit_reached");
  });

  it("the Free Preview gets 2", async () => {
    const e = env();
    const jws = await sign({ bundleId: "app.pretendthat.ios", appTransactionId: "42", environment: "Production" });
    expect((await worker.fetch(post("/v1/shows/start", { kind: "preview", jws }), e)).status).toBe(200);
    expect((await worker.fetch(post("/v1/shows/start", { kind: "preview", jws }), e)).status).toBe(200);
    expect((await worker.fetch(post("/v1/shows/start", { kind: "preview", jws }), e)).status).toBe(402);
  });

  it("count mode counts but never blocks", async () => {
    const e = env({ SHOW_LIMITS: "count" });
    const jws = await sign({ bundleId: "app.pretendthat.ios", appTransactionId: "43" });
    for (let i = 0; i < 4; i++) expect((await worker.fetch(post("/v1/shows/start", { kind: "preview", jws }), e)).status).toBe(200);
    // ...and doesn't require tickets on paid calls.
    expect((await worker.fetch(post("/v1/messages", { model: "claude-opus-5-5" }), e)).status).toBe(200);
  });

  it("refuses an unverifiable proof with a generic 403 (and bad bodies with 400)", async () => {
    const r = await worker.fetch(post("/v1/shows/start", { kind: "subscription", jws: await sign(future(), [PLAIN, INTER, ROOT]) }), env());
    expect(r.status).toBe(403);
    expect(JSON.stringify(await r.json())).not.toContain("2000000123456789");
    expect((await worker.fetch(post("/v1/shows/start", { kind: "other", jws: "x" }), env())).status).toBe(400);
    expect((await worker.fetch(post("/v1/shows/start", { kind: "preview" }), env())).status).toBe(400);
  });

  it("enforce: Claude and image calls need this show's ticket; realtime and moderation don't", async () => {
    const e = env();
    const noTicket = await worker.fetch(post("/v1/messages", { model: "claude-opus-5-5" }), e);
    expect(noTicket.status).toBe(402);
    expect(((await noTicket.json()) as { error: { type: string } }).error.type).toBe("show_ticket_required");
    expect((await worker.fetch(post("/v1/images/generations", { model: "gpt-image-2" }), e)).status).toBe(402);
    const start = await worker.fetch(post("/v1/shows/start", { kind: "subscription", jws: await sign(future()) }), e);
    const { ticket } = await start.json() as { ticket: string };
    expect((await worker.fetch(post("/v1/messages", { model: "claude-opus-5-5" }, { "x-pt-show": ticket }), e)).status).toBe(200);
    expect((await worker.fetch(post("/v1/images/generations", { model: "gpt-image-2" }, { "x-pt-show": ticket }), e)).status).toBe(200);
    expect((await worker.fetch(post("/v1/messages", { model: "claude-opus-5-5" }, { "x-pt-show": "forged.ticket" }), e)).status).toBe(402);
    expect((await worker.fetch(post("/v1/moderations", { input: "hi" }), e)).status).toBe(200);
    expect((await worker.fetch(post("/v1/realtime/client_secrets", {}), e)).status).not.toBe(402);
  });

  it("off: paid calls work exactly as before (no ticket needed)", async () => {
    expect((await worker.fetch(post("/v1/messages", { model: "claude-opus-5-5" }), env({ SHOW_LIMITS: "off" }))).status).toBe(200);
  });
});
