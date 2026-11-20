// Round 38: anonymous server-side show counts. The app proves its plan with StoreKit's own signed data (a JWS):
// the plan's transaction, or the AppTransaction for the Free Preview. The relay checks the signature chain up to
// Apple's root, reads only the fields it needs, and counts new shows under a one-way hash. Stored per subscriber:
// `c:<hash>:<window start>` → a number. No names, no kid data, no device IDs, no transaction IDs in the clear.

/** Apple Root CA - G3, SHA-256 of the certificate (https://www.apple.com/certificateauthority/). */
export const APPLE_ROOT_G3_SHA256 = "63343abfb89a6a03ebb57e9b3f5fa7be7c4f5c756f3017b3a8c488c3653e9179";
/** Apple's marker extensions: the WWDR intermediate and the App Store receipt-signing leaf. */
const OID_APPLE_INTERMEDIATE = "1.2.840.113635.100.6.2.1";
const OID_APPLE_LEAF = "1.2.840.113635.100.6.11.1";
const OID_ECDSA_SHA256 = "1.2.840.10045.4.3.2";
const OID_ECDSA_SHA384 = "1.2.840.10045.4.3.3";
const OID_P256 = "1.2.840.10045.3.1.7";
const OID_P384 = "1.3.132.0.34";

/** The App Store bundle ID (Crimson Foundry LLC team, 2026-11-17). */
export const BUNDLE_ID = "co.crimsonfoundry.pretendthat";
/** Accepted bundle IDs: the current one, plus the pre-App Store one during the transition (no store build ever used it). */
export const BUNDLE_IDS = [BUNDLE_ID, "app.pretendthat.ios"];
/** Product IDs (NutmegCore StoreProducts) → new games a month (plans 5/20, 2026-11-17). The Free Preview is 3 to try,
 *  once (never per month). */
export const PLAN_SHOWS: Record<string, number> = {
  "app.pretendthat.showpass.monthly": 5,
  "app.pretendthat.showpass.yearly": 5,
  "app.pretendthat.seasonpass.monthly": 20,
  "app.pretendthat.seasonpass.yearly": 20,
};
export const FREE_PREVIEW_SHOWS = 3;   // 2026-11-20 (Haylee): 3, was 2
/** How long a show ticket rides on that show's guide and kit calls. */
export const TICKET_SECONDS = 6 * 3600;
/** Store and App Review use Production and Sandbox. Xcode's local StoreKit data isn't signed by Apple anyway. */
const ENVIRONMENTS = ["Production", "Sandbox"];

// MARK: - Base64 / DER

export function b64urlDecode(s: string): Uint8Array {
  const b = s.replace(/-/g, "+").replace(/_/g, "/") + "===".slice((s.length + 3) % 4);
  return b64Decode(b);
}
export function b64Decode(s: string): Uint8Array {
  const bin = atob(s.replace(/\s/g, ""));
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}
export function b64urlEncode(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
function hex(bytes: ArrayBuffer | Uint8Array): string {
  return [...new Uint8Array(bytes)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

interface Node { tag: number; start: number; header: number; length: number; end: number }

function readNode(d: Uint8Array, at: number): Node {
  if (at + 2 > d.length) throw new Error("der: truncated");
  const tag = d[at];
  let len = d[at + 1], header = 2;
  if (len & 0x80) {
    const n = len & 0x7f;
    if (n === 0 || n > 4) throw new Error("der: bad length");
    len = 0;
    for (let i = 0; i < n; i++) len = (len * 256) + d[at + 2 + i];
    header += n;
  }
  const end = at + header + len;
  if (end > d.length) throw new Error("der: overrun");
  return { tag, start: at, header, length: len, end };
}

function children(d: Uint8Array, n: Node): Node[] {
  const out: Node[] = [];
  let at = n.start + n.header;
  while (at < n.end) { const c = readNode(d, at); out.push(c); at = c.end; }
  return out;
}

function body(d: Uint8Array, n: Node): Uint8Array { return d.subarray(n.start + n.header, n.end); }
function whole(d: Uint8Array, n: Node): Uint8Array { return d.subarray(n.start, n.end); }

function oid(bytes: Uint8Array): string {
  const parts = [Math.floor(bytes[0] / 40), bytes[0] % 40];
  let v = 0;
  for (let i = 1; i < bytes.length; i++) {
    v = v * 128 + (bytes[i] & 0x7f);
    if (!(bytes[i] & 0x80)) { parts.push(v); v = 0; }
  }
  return parts.join(".");
}

function derTime(d: Uint8Array, n: Node): number {
  const s = new TextDecoder().decode(body(d, n));
  const full = n.tag === 0x17 ? (Number(s.slice(0, 2)) >= 50 ? "19" : "20") + s : s;   // UTCTime → 4-digit year
  const m = /^(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})Z$/.exec(full);
  if (!m) throw new Error("der: bad time");
  return Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +m[6]);
}

export interface Cert {
  der: Uint8Array;
  tbs: Uint8Array;
  sigAlg: string;
  signature: Uint8Array;   // DER ECDSA-Sig-Value
  spki: Uint8Array;
  curve: string;
  notBefore: number;
  notAfter: number;
  extensions: string[];
}

export function parseCert(der: Uint8Array): Cert {
  const root = readNode(der, 0);
  const [tbsN, algN, sigN] = children(der, root);
  const tbsParts = children(der, tbsN);
  let i = tbsParts[0].tag === 0xa0 ? 1 : 0;   // [0] version
  i += 1;                                      // serialNumber
  i += 1;                                      // signature
  i += 1;                                      // issuer
  const validity = children(der, tbsParts[i++]);
  i += 1;                                      // subject
  const spkiN = tbsParts[i++];
  const spkiAlg = children(der, children(der, spkiN)[0]);
  const extensions: string[] = [];
  for (; i < tbsParts.length; i++) {
    if (tbsParts[i].tag !== 0xa3) continue;
    const seq = children(der, tbsParts[i])[0];
    for (const ext of children(der, seq)) extensions.push(oid(body(der, children(der, ext)[0])));
  }
  const sigBits = body(der, sigN);
  return {
    der,
    tbs: whole(der, tbsN),
    sigAlg: oid(body(der, children(der, algN)[0])),
    signature: sigBits.subarray(1),   // skip the unused-bits byte
    spki: whole(der, spkiN),
    curve: spkiAlg[1] ? oid(body(der, spkiAlg[1])) : "",
    notBefore: derTime(der, validity[0]),
    notAfter: derTime(der, validity[1]),
    extensions,
  };
}

/** DER ECDSA-Sig-Value (SEQUENCE { r, s }) → the raw r‖s WebCrypto wants. */
export function ecdsaRaw(sig: Uint8Array, size: number): Uint8Array {
  const seq = readNode(sig, 0);
  const [r, s] = children(sig, seq).map((n) => body(sig, n));
  const out = new Uint8Array(size * 2);
  const put = (v: Uint8Array, off: number) => {
    let x = v;
    while (x.length > size && x[0] === 0) x = x.subarray(1);
    if (x.length > size) throw new Error("ecdsa: integer too long");
    out.set(x, off + size - x.length);
  };
  put(r, 0); put(s, size);
  return out;
}

function curveInfo(curve: string): { name: string; size: number } {
  if (curve === OID_P256) return { name: "P-256", size: 32 };
  if (curve === OID_P384) return { name: "P-384", size: 48 };
  throw new Error("unsupported curve");
}

async function importKey(c: Cert) {
  const { name } = curveInfo(c.curve);
  return crypto.subtle.importKey("spki", c.spki, { name: "ECDSA", namedCurve: name }, false, ["verify"]);
}

/** `child` is signed by `issuer`. */
async function signedBy(child: Cert, issuer: Cert): Promise<boolean> {
  const hash = child.sigAlg === OID_ECDSA_SHA256 ? "SHA-256" : child.sigAlg === OID_ECDSA_SHA384 ? "SHA-384" : null;
  if (!hash) return false;
  const { size } = curveInfo(issuer.curve);
  return crypto.subtle.verify({ name: "ECDSA", hash }, await importKey(issuer), ecdsaRaw(child.signature, size), child.tbs);
}

// MARK: - JWS

/** Verifies a StoreKit JWS (ES256, x5c = leaf, intermediate, root) up to a trusted root; returns its payload. */
export async function verifyStoreKitJWS(jws: string, trustedRoots: string[], now = Date.now()): Promise<Record<string, unknown>> {
  const parts = jws.split(".");
  if (parts.length !== 3) throw new Error("jws: shape");
  const header = JSON.parse(new TextDecoder().decode(b64urlDecode(parts[0])));
  if (header.alg !== "ES256" || !Array.isArray(header.x5c) || header.x5c.length !== 3) throw new Error("jws: header");
  const [leaf, inter, root] = (header.x5c as string[]).map((c) => parseCert(b64Decode(c)));
  const rootHash = hex(await crypto.subtle.digest("SHA-256", root.der));
  if (!trustedRoots.map((r) => r.toLowerCase()).includes(rootHash)) throw new Error("jws: untrusted root");
  for (const c of [leaf, inter, root]) if (now < c.notBefore || now > c.notAfter) throw new Error("jws: certificate dates");
  if (!inter.extensions.includes(OID_APPLE_INTERMEDIATE)) throw new Error("jws: not an Apple intermediate");
  if (!leaf.extensions.includes(OID_APPLE_LEAF)) throw new Error("jws: not an App Store signing certificate");
  if (!(await signedBy(inter, root)) || !(await signedBy(leaf, inter))) throw new Error("jws: chain signature");
  if (leaf.curve !== OID_P256) throw new Error("jws: leaf curve");
  const ok = await crypto.subtle.verify({ name: "ECDSA", hash: "SHA-256" }, await importKey(leaf), b64urlDecode(parts[2]),
    new TextEncoder().encode(`${parts[0]}.${parts[1]}`));
  if (!ok) throw new Error("jws: signature");
  return JSON.parse(new TextDecoder().decode(b64urlDecode(parts[1])));
}

// MARK: - What to count

export interface Counted {
  /** The one-way hash of originalTransactionId (a plan) or appTransactionId (the Free Preview). */
  key: string;
  /** The window's start (ms): a plan's month, or 0 for the Free Preview (3 in total). */
  windowStart: number;
  windowEnd: number | null;
  allowance: number;
}

/** UTC calendar months from `anchor` (mirrors NutmegCore ShowWindow). */
export function monthWindow(anchor: number, now: number): { start: number; end: number } {
  const addMonths = (t: number, n: number) => {
    const d = new Date(t);
    const day = d.getUTCDate();
    const r = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth() + n, 1, d.getUTCHours(), d.getUTCMinutes(), d.getUTCSeconds(), d.getUTCMilliseconds()));
    const last = new Date(Date.UTC(r.getUTCFullYear(), r.getUTCMonth() + 1, 0)).getUTCDate();
    r.setUTCDate(Math.min(day, last));   // Jan 31 + 1 month = Feb 28/29 (like Foundation's Calendar)
    return r.getTime();
  };
  if (now <= anchor) return { start: anchor, end: addMonths(anchor, 1) };
  const a = new Date(anchor), n = new Date(now);
  let months = Math.max((n.getUTCFullYear() - a.getUTCFullYear()) * 12 + n.getUTCMonth() - a.getUTCMonth(), 0);
  while (months > 0 && addMonths(anchor, months) > now) months--;
  while (addMonths(anchor, months + 1) <= now) months++;
  return { start: addMonths(anchor, months), end: addMonths(anchor, months + 1) };
}

export async function hashKey(secret: string, value: string): Promise<string> {
  const k = await crypto.subtle.importKey("raw", new TextEncoder().encode(secret), { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return hex(await crypto.subtle.sign("HMAC", k, new TextEncoder().encode(value))).slice(0, 32);
}

/** Reads only what's needed from a verified payload. Throws for anything that isn't an active PretendThat plan / app. */
export async function countedFrom(kind: string, p: Record<string, unknown>, secret: string, now = Date.now()): Promise<Counted> {
  if (!BUNDLE_IDS.includes(String(p.bundleId))) throw new Error("wrong app");
  if (typeof p.environment === "string" && !ENVIRONMENTS.includes(p.environment)) throw new Error("environment");
  if (kind === "subscription") {
    const allowance = PLAN_SHOWS[String(p.productId)];
    if (!allowance) throw new Error("not a plan");
    if (p.revocationDate) throw new Error("revoked");
    const expires = Number(p.expiresDate), purchased = Number(p.purchaseDate);
    if (!expires || expires <= now || !purchased) throw new Error("expired");
    if (typeof p.originalTransactionId !== "string") throw new Error("no id");
    const w = monthWindow(purchased, now);
    return { key: await hashKey(secret, `sub:${p.originalTransactionId}`), windowStart: w.start, windowEnd: w.end, allowance };
  }
  if (kind === "preview") {
    // appTransactionId (iOS 18.4+); older systems: the original purchase date of the app (ms), much coarser.
    const id = typeof p.appTransactionId === "string" ? `app:${p.appTransactionId}`
      : p.originalPurchaseDate ? `opd:${p.originalPurchaseDate}:${p.originalApplicationVersion ?? ""}` : null;
    if (!id) throw new Error("no id");
    return { key: await hashKey(secret, id), windowStart: 0, windowEnd: null, allowance: FREE_PREVIEW_SHOWS };
  }
  throw new Error("kind");
}

// MARK: - Tickets (HMAC-signed, short-lived; ride on that show's guide and kit calls)

export async function makeTicket(secret: string, key: string, now = Date.now()): Promise<string> {
  const payload = b64urlEncode(new TextEncoder().encode(JSON.stringify({ k: key.slice(0, 12), exp: Math.floor(now / 1000) + TICKET_SECONDS })));
  return `${payload}.${await hashKey(`ticket:${secret}`, payload)}`;
}

export async function ticketValid(secret: string, ticket: string | null, now = Date.now()): Promise<boolean> {
  if (!ticket) return false;
  const [payload, mac] = ticket.split(".");
  if (!payload || !mac || mac !== (await hashKey(`ticket:${secret}`, payload))) return false;
  try {
    const p = JSON.parse(new TextDecoder().decode(b64urlDecode(payload)));
    return typeof p.exp === "number" && p.exp * 1000 > now;
  } catch { return false; }
}

// MARK: - The KV counter

export interface KV {
  get(key: string): Promise<string | null>;
  put(key: string, value: string, options?: { expirationTtl?: number }): Promise<void>;
}

/** Counts one new show unless the window's allowance is used up (and `enforce` is on). Workers KV is eventually
 *  consistent, so two shows started in the same second on two devices may both count as the last one: a soft cap. */
export async function countShow(kv: KV, c: Counted, enforce: boolean): Promise<{ allowed: boolean; used: number; remaining: number }> {
  const k = `c:${c.key}:${c.windowStart}`;
  const used = Number((await kv.get(k)) ?? "0") || 0;
  if (enforce && used >= c.allowance) return { allowed: false, used, remaining: 0 };
  const next = used + 1;
  // A month's count lives ~40 days; the Free Preview's ~13 months (then it would reset).
  await kv.put(k, String(next), { expirationTtl: c.windowEnd ? 40 * 86400 : 400 * 86400 });
  return { allowed: true, used: next, remaining: Math.max(c.allowance - next, 0) };
}
