// PretendThat relay: a stateless Cloudflare Worker that holds the API keys so a fresh clone of the app works
// without its own keys. It checks the shared app token, rate-limits per IP, validates the request, adds the real
// key and forwards it. It never logs request or response bodies, stores nothing and uses no KV.

export interface RateLimit {
  limit(options: { key: string }): Promise<{ success: boolean }>;
}

export interface Env {
  APP_TOKEN: string;
  ANTHROPIC_API_KEY: string;
  OPENAI_API_KEY: string;
  CLAUDE_LIMIT: RateLimit;
  IMAGE_LIMIT: RateLimit;
  REALTIME_LIMIT: RateLimit;
  MODERATION_LIMIT: RateLimit;
}

/** Models the app uses (NutmegCore ClaudeClient / ImageClient / RealtimeProtocol). Anything else is refused. */
/** Round 35 prep: claude-sonnet-5-5 for the play guide and the per-prop weave (app flag PTSonnetGuide, off by default). */
export const CLAUDE_MODELS = ["claude-opus-5-5", "claude-sonnet-5-5"];
export const MAX_TOKENS = 16000;
export const IMAGE_MODELS = ["gpt-image-2.6-flare", "gpt-image-2.5-flare", "gpt-image-2"];
export const REALTIME_MODEL = "gpt-realtime-2.1";
/** Round 35 prep: the mini model for the scripted-lines session (app flag PTMiniLines, off by default). The app names
 *  the model in the body; anything not listed here gets REALTIME_MODEL. */
export const REALTIME_MODELS = [REALTIME_MODEL, "gpt-realtime-2.1-mini"];
/** An ephemeral secret only has to start a session (the app connects right after fetching it). */
export const REALTIME_SECRET_SECONDS = 120;
/** Round 19: kid-safety checks. The model is forced; inputs are short text only (no images). */
export const MODERATION_MODEL = "omni-moderation-latest";
export const MODERATION_MAX_INPUTS = 32;
export const MODERATION_MAX_CHARS = 4000;
export const ANTHROPIC_VERSION = "2026-10-21";
/** Bodies are text prompts; anything bigger is not from the app. */
export const MAX_BODY_BYTES = 256 * 1024;

const ANTHROPIC_URL = "https://api.anthropic.com/v1/messages";
const OPENAI_IMAGES_URL = "https://api.openai.com/v1/images/generations";
const OPENAI_MODERATIONS_URL = "https://api.openai.com/v1/moderations";
const OPENAI_CLIENT_SECRETS_URL = "https://api.openai.com/v1/realtime/client_secrets";

function json(status: number, body: unknown, extra: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json", "cache-control": "no-store", ...extra },
  });
}

function error(status: number, type: string, message: string, extra: Record<string, string> = {}): Response {
  return json(status, { error: { type, message } }, extra);
}

/** Constant-time string comparison, so the token can't be guessed byte by byte from timing. */
export function sameToken(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a), y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

async function readJSON(req: Request): Promise<Record<string, unknown> | Response> {
  const text = await req.text();
  if (new TextEncoder().encode(text).length > MAX_BODY_BYTES) return error(413, "too_large", "Request body too large.");
  try {
    const body = JSON.parse(text);
    if (body && typeof body === "object" && !Array.isArray(body)) return body as Record<string, unknown>;
  } catch {}
  return error(400, "invalid_request", "Body must be a JSON object.");
}

/** Pass the upstream answer through untouched (status and body), with only a content type. */
function passThrough(upstream: Response): Response {
  return new Response(upstream.body, {
    status: upstream.status,
    headers: { "content-type": upstream.headers.get("content-type") ?? "application/json", "cache-control": "no-store" },
  });
}

async function claude(req: Request, env: Env): Promise<Response> {
  const body = await readJSON(req);
  if (body instanceof Response) return body;
  if (typeof body.model !== "string" || !CLAUDE_MODELS.includes(body.model)) {
    return error(400, "model_not_allowed", "This relay only serves PretendThat's Claude model.");
  }
  if (body.stream === true) return error(400, "invalid_request", "Streaming is not supported by this relay.");
  const requested = typeof body.max_tokens === "number" ? body.max_tokens : MAX_TOKENS;
  body.max_tokens = Math.max(1, Math.min(requested, MAX_TOKENS));
  const headers: Record<string, string> = {
    "content-type": "application/json",
    "x-api-key": env.ANTHROPIC_API_KEY,
    "anthropic-version": req.headers.get("anthropic-version") ?? ANTHROPIC_VERSION,
  };
  const beta = req.headers.get("anthropic-beta");
  if (beta) headers["anthropic-beta"] = beta;
  return passThrough(await fetch(ANTHROPIC_URL, { method: "POST", headers, body: JSON.stringify(body) }));
}

async function images(req: Request, env: Env): Promise<Response> {
  const body = await readJSON(req);
  if (body instanceof Response) return body;
  if (typeof body.model !== "string" || !IMAGE_MODELS.includes(body.model)) {
    // 400 + model_not_found lets the app fall through to its next model, the same as OpenAI's answer.
    return error(400, "model_not_found", "This relay only serves PretendThat's image models.");
  }
  body.n = 1;
  body.moderation = "auto";   // round 19: OpenAI's image moderation always stays on its standard setting
  return passThrough(await fetch(OPENAI_IMAGES_URL, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: JSON.stringify(body),
  }));
}

/** Round 19: the app's kid-safety check (OpenAI Moderation). Text only, the model forced, inputs capped. The app
 *  fails safe to its local filter if this errors, so a refusal here never blocks a game. */
async function moderations(req: Request, env: Env): Promise<Response> {
  const body = await readJSON(req);
  if (body instanceof Response) return body;
  const raw = body.input;
  const inputs = typeof raw === "string" ? [raw] : Array.isArray(raw) ? raw : null;
  if (!inputs || inputs.length === 0 || inputs.length > MODERATION_MAX_INPUTS
      || !inputs.every((t) => typeof t === "string" && t.length <= MODERATION_MAX_CHARS)) {
    return error(400, "invalid_request", "input must be 1 to 32 short text strings.");
  }
  return passThrough(await fetch(OPENAI_MODERATIONS_URL, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: JSON.stringify({ model: MODERATION_MODEL, input: inputs }),
  }));
}

/** The session model the app asked for, if it's one of REALTIME_MODELS; otherwise REALTIME_MODEL. Only `model` is
 *  read from the body (an empty or bad body is fine). */
export async function realtimeModel(req: Request): Promise<string> {
  try {
    const text = await req.text();
    if (text.length > 1024) return REALTIME_MODEL;
    const body = JSON.parse(text);
    if (body && typeof body.model === "string" && REALTIME_MODELS.includes(body.model)) return body.model;
  } catch {}
  return REALTIME_MODEL;
}

/** Mints a short-lived Realtime client secret for one of the app's models. The app configures voice and instructions
 *  itself with session.update once connected. */
async function realtimeSecret(req: Request, env: Env): Promise<Response> {
  const model = await realtimeModel(req);
  const upstream = await fetch(OPENAI_CLIENT_SECRETS_URL, {
    method: "POST",
    headers: { "content-type": "application/json", authorization: `Bearer ${env.OPENAI_API_KEY}` },
    body: JSON.stringify({
      expires_after: { anchor: "created_at", seconds: REALTIME_SECRET_SECONDS },
      session: { type: "realtime", model },
    }),
  });
  if (!upstream.ok) return passThrough(upstream);
  const data = (await upstream.json().catch(() => null)) as { value?: unknown; expires_at?: unknown } | null;
  if (!data || typeof data.value !== "string") return error(502, "bad_upstream", "OpenAI returned no client secret.");
  // Only the secret and its expiry go back to the app, never the session echo.
  return json(200, { value: data.value, expires_at: data.expires_at ?? null, model });
}

type Route = { handler: (req: Request, env: Env) => Promise<Response>; limiter: keyof Pick<Env, "CLAUDE_LIMIT" | "IMAGE_LIMIT" | "REALTIME_LIMIT" | "MODERATION_LIMIT"> };

const ROUTES: Record<string, Route> = {
  "/v1/messages": { handler: claude, limiter: "CLAUDE_LIMIT" },
  "/v1/images/generations": { handler: images, limiter: "IMAGE_LIMIT" },
  "/v1/realtime/client_secrets": { handler: realtimeSecret, limiter: "REALTIME_LIMIT" },
  "/v1/moderations": { handler: moderations, limiter: "MODERATION_LIMIT" },
};

export default {
  async fetch(req: Request, env: Env): Promise<Response> {
    const route = ROUTES[new URL(req.url).pathname];
    if (!route || req.method !== "POST") return error(404, "not_found", "Not found.");
    const token = req.headers.get("x-pt-token") ?? "";
    if (!env.APP_TOKEN || !sameToken(token, env.APP_TOKEN)) return error(401, "unauthorized", "Missing or wrong app token.");
    const limiter = env[route.limiter];
    if (!limiter) return error(500, "misconfigured", "Relay rate limits are not configured.");
    const ip = req.headers.get("cf-connecting-ip") ?? "unknown";
    const { success } = await limiter.limit({ key: `${route.limiter}:${ip}` });
    if (!success) {
      return error(429, "rate_limited", "Nutmeg needs a little breather! Too many requests from here; try again in a minute.",
        { "retry-after": "60" });
    }
    try {
      return await route.handler(req, env);
    } catch {
      // No details: an error message could echo part of a request.
      return error(502, "upstream_unreachable", "Couldn't reach the AI service. Try again soon.");
    }
  },
};
