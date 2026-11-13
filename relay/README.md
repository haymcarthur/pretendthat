# PretendThat relay (post-hackathon, not deployed)

**Status:** plan and stub only. The demo build calls Anthropic and OpenAI directly with keys from the git-ignored `Secrets.xcconfig`. See `thinking/decisions/stateless-relay.md`.

**Why:** keep API keys off the iPad. The relay is stateless: it checks a shared app token, adds the real key, forwards the body, and returns the response untouched. No logging of bodies or headers, no KV, no storage.

**Routes** (POST only; anything else → 405; wrong `x-nutmeg-token` → 401):
- `/v1/messages` → `https://api.anthropic.com/v1/messages` with `x-api-key`, passing through `anthropic-version` and `anthropic-beta`.
- `/v1/images/generations` → `https://api.openai.com/v1/images/generations` with `Authorization: Bearer`.

**App side:** already supported. If `RELAY_HOST` (no `https://`; xcconfig treats `//` as a comment) and `RELAY_TOKEN` are set in `Secrets.xcconfig`, `ClaudeConfig`/`ImageClient` use the relay instead of direct keys.

## Stub `worker.js`

```js
export default {
  async fetch(req, env) {
    if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });
    if (req.headers.get("x-nutmeg-token") !== env.NUTMEG_TOKEN) return new Response("Unauthorized", { status: 401 });
    const path = new URL(req.url).pathname;
    let url, headers = { "content-type": "application/json" };
    if (path === "/v1/messages") {
      url = "https://api.anthropic.com/v1/messages";
      headers["x-api-key"] = env.ANTHROPIC_API_KEY;
      for (const h of ["anthropic-version", "anthropic-beta"]) { const v = req.headers.get(h); if (v) headers[h] = v; }
    } else if (path === "/v1/images/generations") {
      url = "https://api.openai.com/v1/images/generations";
      headers["authorization"] = `Bearer ${env.OPENAI_API_KEY}`;
    } else return new Response("Not found", { status: 404 });
    const upstream = await fetch(url, { method: "POST", headers, body: req.body });
    return new Response(upstream.body, { status: upstream.status, headers: { "content-type": upstream.headers.get("content-type") ?? "application/json" } });
  },
};
```

## Deploy later (needs a Cloudflare account)

1. `npm create cloudflare@latest pretendthat-relay` (Worker, plain JS), replace `src/index.js` with the stub.
2. `npx wrangler secret put ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `NUTMEG_TOKEN` (any long random string).
3. `npx wrangler deploy`, then set `RELAY_HOST` and `RELAY_TOKEN` in `Secrets.xcconfig`, remove the direct keys, rebuild.
4. Check: right token → 200 JSON; wrong token → 401; GET → 405.
