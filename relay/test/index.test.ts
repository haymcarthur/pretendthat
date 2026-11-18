import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import worker, { CLAUDE_MODELS, IMAGE_MODELS, MAX_TOKENS, MODERATION_MODEL, REALTIME_MODEL, REALTIME_MODELS, sameToken, type Env } from "../src/index";

// Fake values only. No real keys anywhere in this repo.
const TOKEN = "test-app-token";

function limiter(allow = true) {
  return { limit: vi.fn(async (_: { key: string }) => ({ success: allow })) };
}

function makeEnv(overrides: Partial<Env> = {}): Env {
  return {
    APP_TOKEN: TOKEN,
    ANTHROPIC_API_KEY: "fake-anthropic",
    OPENAI_API_KEY: "fake-openai",
    CLAUDE_LIMIT: limiter(),
    IMAGE_LIMIT: limiter(),
    REALTIME_LIMIT: limiter(),
    MODERATION_LIMIT: limiter(),
    ...overrides,
  };
}

function post(path: string, body: unknown, headers: Record<string, string> = { "x-pt-token": TOKEN }) {
  return new Request(`https://relay.test${path}`, {
    method: "POST",
    headers: { "content-type": "application/json", "cf-connecting-ip": "203.0.113.7", ...headers },
    body: typeof body === "string" ? body : JSON.stringify(body),
  });
}

let fetchMock: ReturnType<typeof vi.fn>;
beforeEach(() => {
  fetchMock = vi.fn(async () => new Response(JSON.stringify({ ok: true }), { status: 200, headers: { "content-type": "application/json" } }));
  vi.stubGlobal("fetch", fetchMock);
});
afterEach(() => vi.unstubAllGlobals());

function sent() {
  const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
  return { url, headers: init.headers as Record<string, string>, body: JSON.parse(init.body as string) };
}

describe("auth and routing", () => {
  it("rejects a missing token", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }, {}), makeEnv());
    expect(r.status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("rejects a wrong token", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }, { "x-pt-token": "nope" }), makeEnv());
    expect(r.status).toBe(401);
  });

  it("rejects everything when APP_TOKEN is not set", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }, { "x-pt-token": "" }), makeEnv({ APP_TOKEN: "" }));
    expect(r.status).toBe(401);
  });

  it.each(["/", "/v1/models", "/v1/chat/completions", "/v1/messages/batches", "/v1/realtime"])("404s unknown path %s", async (path) => {
    const r = await worker.fetch(post(path, {}), makeEnv());
    expect(r.status).toBe(404);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("404s a GET on a real route", async () => {
    const r = await worker.fetch(new Request("https://relay.test/v1/messages", { headers: { "x-pt-token": TOKEN } }), makeEnv());
    expect(r.status).toBe(404);
  });

  it("compares tokens exactly", () => {
    expect(sameToken("abc", "abc")).toBe(true);
    expect(sameToken("abc", "abd")).toBe(false);
    expect(sameToken("abc", "abcd")).toBe(false);
    expect(sameToken("", "x")).toBe(false);
  });
});

describe("rate limits", () => {
  it("returns a friendly 429 and keys the limit by route and IP", async () => {
    const env = makeEnv({ CLAUDE_LIMIT: limiter(false) });
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }), env);
    expect(r.status).toBe(429);
    const body = (await r.json()) as { error: { type: string; message: string } };
    expect(body.error.type).toBe("rate_limited");
    expect(body.error.message).toMatch(/breather/);
    expect(r.headers.get("retry-after")).toBe("60");
    expect((env.CLAUDE_LIMIT.limit as ReturnType<typeof vi.fn>).mock.calls[0][0]).toEqual({ key: "CLAUDE_LIMIT:203.0.113.7" });
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("uses a separate limit per route", async () => {
    const env = makeEnv();
    await worker.fetch(post("/v1/images/generations", { model: IMAGE_MODELS[0], prompt: "x" }), env);
    expect(env.IMAGE_LIMIT.limit).toHaveBeenCalledOnce();
    expect(env.CLAUDE_LIMIT.limit).not.toHaveBeenCalled();
  });
});

describe("POST /v1/messages", () => {
  it("forwards to Anthropic with the key, version and beta headers", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0], max_tokens: 1000, messages: [] },
      { "x-pt-token": TOKEN, "anthropic-version": "2026-10-21", "anthropic-beta": "server-side-fallback-2026-07-01" }), makeEnv());
    expect(r.status).toBe(200);
    const s = sent();
    expect(s.url).toBe("https://api.anthropic.com/v1/messages");
    expect(s.headers["x-api-key"]).toBe("fake-anthropic");
    expect(s.headers["anthropic-version"]).toBe("2026-10-21");
    expect(s.headers["anthropic-beta"]).toBe("server-side-fallback-2026-07-01");
    expect(s.headers["x-pt-token"]).toBeUndefined();
    expect(s.body.max_tokens).toBe(1000);
  });

  it("caps max_tokens", async () => {
    await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0], max_tokens: 999999 }), makeEnv());
    expect(sent().body.max_tokens).toBe(MAX_TOKENS);
  });

  it("serves Sonnet 5.5 for the guide and the weave (round 35 prep)", async () => {
    expect(CLAUDE_MODELS).toEqual(["claude-opus-5-5", "claude-sonnet-5-5"]);
    const r = await worker.fetch(post("/v1/messages", { model: "claude-sonnet-5-5", max_tokens: 1000, messages: [] }), makeEnv());
    expect(r.status).toBe(200);
    expect(sent().body.model).toBe("claude-sonnet-5-5");
  });

  it("refuses other models", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: "claude-some-other-model" }), makeEnv());
    expect(r.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("refuses streaming and non-JSON bodies", async () => {
    expect((await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0], stream: true }), makeEnv())).status).toBe(400);
    expect((await worker.fetch(post("/v1/messages", "not json"), makeEnv())).status).toBe(400);
  });

  it("refuses oversized bodies", async () => {
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0], pad: "x".repeat(300 * 1024) }), makeEnv());
    expect(r.status).toBe(413);
  });

  it("passes the upstream status and body through", async () => {
    fetchMock.mockResolvedValueOnce(new Response('{"type":"error"}', { status: 529, headers: { "content-type": "application/json" } }));
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }), makeEnv());
    expect(r.status).toBe(529);
    expect(await r.text()).toBe('{"type":"error"}');
  });

  it("returns a generic 502 when the upstream can't be reached", async () => {
    fetchMock.mockRejectedValueOnce(new Error("network down"));
    const r = await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0] }), makeEnv());
    expect(r.status).toBe(502);
    expect(await r.text()).not.toContain("network down");
  });
});

function editForm(fields: Record<string, string>, image: Blob | null = new Blob([new Uint8Array([137, 80, 78, 71, 1, 2, 3])], { type: "image/png" })) {
  const f = new FormData();
  for (const [k, v] of Object.entries(fields)) f.set(k, v);
  if (image) f.set("image", image, "page.png");
  return f;
}
function postForm(path: string, form: FormData, headers: Record<string, string> = { "x-pt-token": TOKEN }) {
  return new Request(`https://relay.test${path}`, { method: "POST", headers: { "cf-connecting-ip": "203.0.113.7", ...headers }, body: form });
}

describe("POST /v1/images/edits (printables draw-once)", () => {
  it("forwards one image as multipart to OpenAI's edits endpoint with the key, n = 1 and moderation auto", async () => {
    const r = await worker.fetch(postForm("/v1/images/edits", editForm({ model: IMAGE_MODELS[0], prompt: "color it in", size: "1024x1536",
      quality: "low", output_format: "png", n: "4", moderation: "low", input_fidelity: "high" })), makeEnv());
    expect(r.status).toBe(200);
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(url).toBe("https://api.openai.com/v1/images/edits");
    expect((init.headers as Record<string, string>).authorization).toBe("Bearer fake-openai");
    const body = init.body as FormData;
    expect(body.get("model")).toBe(IMAGE_MODELS[0]);
    expect(body.get("prompt")).toBe("color it in");
    expect(body.get("size")).toBe("1024x1536");
    expect(body.get("quality")).toBe("low");
    expect(body.get("n")).toBe("1");
    expect(body.get("moderation")).toBe("auto");
    expect(body.has("input_fidelity")).toBe(false);   // unknown fields are dropped (the model rejects it anyway)
    expect(((body.get("image")) as File).size).toBe(7);
  });

  it("needs the token and uses the image rate limit", async () => {
    expect((await worker.fetch(postForm("/v1/images/edits", editForm({ model: IMAGE_MODELS[0], prompt: "x" }), {}), makeEnv())).status).toBe(401);
    const r = await worker.fetch(postForm("/v1/images/edits", editForm({ model: IMAGE_MODELS[0], prompt: "x" })), makeEnv({ IMAGE_LIMIT: limiter(false) }));
    expect(r.status).toBe(429);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("refuses other models, a missing prompt or image, two images, masks and JSON bodies", async () => {
    const bad = [
      editForm({ model: "dall-e-2", prompt: "x" }),
      editForm({ model: IMAGE_MODELS[0] }),
      editForm({ model: IMAGE_MODELS[0], prompt: "x" }, null),
      (() => { const f = editForm({ model: IMAGE_MODELS[0], prompt: "x" }); f.append("image", new Blob([new Uint8Array([1])], { type: "image/png" }), "b.png"); return f; })(),
      (() => { const f = editForm({ model: IMAGE_MODELS[0], prompt: "x" }); f.set("mask", new Blob([new Uint8Array([1])], { type: "image/png" }), "m.png"); return f; })(),
      editForm({ model: IMAGE_MODELS[0], prompt: "x" }, new Blob(["hello"], { type: "text/plain" })),
    ];
    for (const f of bad) expect((await worker.fetch(postForm("/v1/images/edits", f), makeEnv())).status).toBe(400);
    expect((await worker.fetch(post("/v1/images/edits", { model: IMAGE_MODELS[0], prompt: "x" }), makeEnv())).status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("refuses a body over 8 MB", async () => {
    const big = new Blob([new Uint8Array(8 * 1024 * 1024 + 1)], { type: "image/png" });
    const r = await worker.fetch(postForm("/v1/images/edits", editForm({ model: IMAGE_MODELS[0], prompt: "x" }, big)), makeEnv());
    expect([400, 413]).toContain(r.status);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("POST /v1/images/generations", () => {
  it("forwards to OpenAI with the key and forces n = 1", async () => {
    await worker.fetch(post("/v1/images/generations", { model: IMAGE_MODELS[0], prompt: "line art", n: 8 }), makeEnv());
    const s = sent();
    expect(s.url).toBe("https://api.openai.com/v1/images/generations");
    expect(s.headers.authorization).toBe("Bearer fake-openai");
    expect(s.body.n).toBe(1);
    expect(s.body.prompt).toBe("line art");
    expect(s.body.moderation).toBe("auto");   // round 19: never turned down
  });

  it("forces image moderation back to auto", async () => {
    await worker.fetch(post("/v1/images/generations", { model: IMAGE_MODELS[0], prompt: "x", moderation: "low" }), makeEnv());
    expect(sent().body.moderation).toBe("auto");
  });

  it.each(IMAGE_MODELS)("allows %s", async (model) => {
    expect((await worker.fetch(post("/v1/images/generations", { model, prompt: "x" }), makeEnv())).status).toBe(200);
  });

  it("refuses other models with model_not_found (the app falls through)", async () => {
    const r = await worker.fetch(post("/v1/images/generations", { model: "dall-e-3", prompt: "x" }), makeEnv());
    expect(r.status).toBe(400);
    expect(((await r.json()) as { error: { type: string } }).error.type).toBe("model_not_found");
    expect(fetchMock).not.toHaveBeenCalled();
  });
});

describe("POST /v1/realtime/client_secrets", () => {
  it("mints a short-lived secret for the app's model and returns only the secret", async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify({
      value: "ek_test123", expires_at: 1763200000, session: { type: "realtime", model: REALTIME_MODEL, instructions: "" },
    }), { status: 200, headers: { "content-type": "application/json" } }));
    const r = await worker.fetch(post("/v1/realtime/client_secrets", { model: "something-expensive" }), makeEnv());
    expect(r.status).toBe(200);
    expect(await r.json()).toEqual({ value: "ek_test123", expires_at: 1763200000, model: REALTIME_MODEL });
    const s = sent();
    expect(s.url).toBe("https://api.openai.com/v1/realtime/client_secrets");
    expect(s.headers.authorization).toBe("Bearer fake-openai");
    expect(s.body.session).toEqual({ type: "realtime", model: REALTIME_MODEL });
    expect(s.body.expires_after.anchor).toBe("created_at");
    expect(s.body.expires_after.seconds).toBeLessThanOrEqual(600);
  });

  it("mints a mini-model secret when the app asks for the scripted-lines session (round 35 prep)", async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify({ value: "ek_mini", expires_at: 1 }), { status: 200 }));
    const r = await worker.fetch(post("/v1/realtime/client_secrets", { model: "gpt-realtime-2.1-mini" }), makeEnv());
    expect(r.status).toBe(200);
    expect(await r.json()).toEqual({ value: "ek_mini", expires_at: 1, model: "gpt-realtime-2.1-mini" });
    expect(sent().body.session).toEqual({ type: "realtime", model: "gpt-realtime-2.1-mini" });
    expect(REALTIME_MODELS).toEqual(["gpt-realtime-2.1", "gpt-realtime-2.1-mini"]);
  });

  it("accepts an empty body", async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify({ value: "ek_x", expires_at: 1 }), { status: 200 }));
    const r = await worker.fetch(post("/v1/realtime/client_secrets", ""), makeEnv());
    expect(r.status).toBe(200);
  });

  it("passes an OpenAI error through", async () => {
    fetchMock.mockResolvedValueOnce(new Response('{"error":{"code":"insufficient_quota"}}', { status: 429 }));
    const r = await worker.fetch(post("/v1/realtime/client_secrets", {}), makeEnv());
    expect(r.status).toBe(429);
  });

  it("502s when OpenAI returns no secret", async () => {
    fetchMock.mockResolvedValueOnce(new Response("{}", { status: 200 }));
    expect((await worker.fetch(post("/v1/realtime/client_secrets", {}), makeEnv())).status).toBe(502);
  });
});

describe("POST /v1/moderations (round 19)", () => {
  it("forwards text to OpenAI with the key and forces the model", async () => {
    const r = await worker.fetch(post("/v1/moderations", { model: "text-moderation-stable", input: ["a pirate ship"] }), makeEnv());
    expect(r.status).toBe(200);
    const s = sent();
    expect(s.url).toBe("https://api.openai.com/v1/moderations");
    expect(s.headers.authorization).toBe("Bearer fake-openai");
    expect(s.body).toEqual({ model: MODERATION_MODEL, input: ["a pirate ship"] });
  });

  it("accepts a single string", async () => {
    await worker.fetch(post("/v1/moderations", { input: "a bakery" }), makeEnv());
    expect(sent().body.input).toEqual(["a bakery"]);
  });

  it("passes OpenAI's answer through", async () => {
    fetchMock.mockResolvedValueOnce(new Response(JSON.stringify({ results: [{ flagged: true }] }), { status: 200 }));
    const r = await worker.fetch(post("/v1/moderations", { input: ["x"] }), makeEnv());
    expect(await r.json()).toEqual({ results: [{ flagged: true }] });
  });

  it.each([
    ["no input", {}],
    ["empty list", { input: [] }],
    ["an image part", { input: [{ type: "image_url", image_url: { url: "https://x.test/a.png" } }] }],
    ["too many", { input: Array(33).fill("x") }],
    ["too long", { input: ["x".repeat(4001)] }],
  ])("refuses %s", async (_name, body) => {
    const r = await worker.fetch(post("/v1/moderations", body), makeEnv());
    expect(r.status).toBe(400);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("needs the app token", async () => {
    const r = await worker.fetch(post("/v1/moderations", { input: ["x"] }, {}), makeEnv());
    expect(r.status).toBe(401);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("is rate limited per IP on its own binding", async () => {
    const env = makeEnv({ MODERATION_LIMIT: limiter(false) });
    const r = await worker.fetch(post("/v1/moderations", { input: ["x"] }), env);
    expect(r.status).toBe(429);
    expect((env.MODERATION_LIMIT.limit as ReturnType<typeof vi.fn>).mock.calls[0][0].key).toBe("MODERATION_LIMIT:203.0.113.7");
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("never logs kid text", async () => {
    const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
    await worker.fetch(post("/v1/moderations", { input: ["my secret words"] }), makeEnv());
    for (const s of spies) expect(s).not.toHaveBeenCalled();
  });
});

describe("statelessness", () => {
  it("never logs", async () => {
    const spies = (["log", "info", "warn", "error", "debug"] as const).map((m) => vi.spyOn(console, m));
    await worker.fetch(post("/v1/messages", { model: CLAUDE_MODELS[0], messages: [{ role: "user", content: "secret" }] }), makeEnv());
    fetchMock.mockRejectedValueOnce(new Error("boom"));
    await worker.fetch(post("/v1/images/generations", { model: IMAGE_MODELS[0], prompt: "x" }), makeEnv());
    for (const s of spies) expect(s).not.toHaveBeenCalled();
  });
});
