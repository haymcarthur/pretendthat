# PretendThat relay

A tiny, stateless [Cloudflare Worker](https://developers.cloudflare.com/workers/) that holds PretendThat's API keys, so anyone who clones and builds the app gets working AI without keys of their own, and no long-lived key ever ships inside the app.

**Status:** built and tested, not deployed yet. Deploying takes about 15 minutes (steps below).

## What it does

Every request must carry the header `X-PT-Token` matching the Worker's `APP_TOKEN` secret, or it gets a 401. Only these four routes exist; everything else (any other path, or any method but POST) gets a 404.

| Route | Forwards to | Checks |
|---|---|---|
| `POST /v1/messages` | Anthropic `api.anthropic.com/v1/messages` (adds the key, keeps the app's `anthropic-version` and `anthropic-beta`) | Model must be `claude-opus-5-5` or `claude-sonnet-5-5` (round 35 prep: guide + weave, app flag off by default); `max_tokens` capped at 16,000; no streaming |
| `POST /v1/images/generations` | OpenAI `api.openai.com/v1/images/generations` | Model must be one of the app's `gpt-image-2` family; `n` forced to 1; `moderation` forced to `auto` |
| `POST /v1/realtime/client_secrets` | OpenAI `api.openai.com/v1/realtime/client_secrets` | Mints a **120-second** ephemeral secret for `gpt-realtime-2.1` (or `gpt-realtime-2.1-mini` when the body asks for it: the scripted-lines session, round 35 prep, app flag off by default; anything else gets `gpt-realtime-2.1`) and returns only `{value, expires_at}`. The app then opens OpenAI's realtime WebSocket directly with it. The secret only has to *start* the session, and the app fetches a fresh one on every connect and reconnect. |
| `POST /v1/moderations` | OpenAI `api.openai.com/v1/moderations` | Kid-safety checks (round 19). Model forced to `omni-moderation-latest`; 1 to 32 text inputs of at most 4,000 characters, no images. Free on OpenAI. The app fails safe to its local filter if this errors. |

**Rate limits** (per client IP, via the [Workers Rate Limiting binding](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)): 10 Claude calls, 40 image calls, 6 realtime sessions and 60 moderation checks per minute. Over the limit you get a 429 with a friendly JSON error. Cloudflare only offers 10- or 60-second windows, and it counts per data center, so these are burst limits. **The spend caps in step 5 are the real ceiling.**

**Stateless, by design:** it never logs request or response bodies or headers, stores nothing, uses no database, and has Workers Logs turned off. The one exception is the optional **show counts** (round 38, below, off by default): one number per subscriber per month in Workers KV, under a one-way hash. Errors are generic, so nothing from a request is echoed back. This matches the project rule: never store anything about kids.

**About the app token:** `RELAY_TOKEN` in `Relay.xcconfig` is committed to the public repo and ships inside every build, so it is **not a secret**. Anyone can read it. It just stops random scanners. What actually protects the account is the per-IP rate limits, the model allow-lists and the spend caps.

## Show counts (round 38, optional, off until you turn it on)

The app's plans allow a number of **new** shows (Free Preview 2 in total, Show Pass 10 a month, Season Pass 30 a month; replays are always free). The app counts on the iPad; this lets the relay count too, so a modified app can't run up the AI bill.

**How it works**
- When a new show starts, the app calls `POST /v1/shows/start` with StoreKit's own signed proof: the plan's **signed transaction** (a JWS), or for the Free Preview the **AppTransaction** JWS. No account, no name, no device ID.
- The relay checks the JWS signature chain up to **Apple Root CA - G3** (pinned by its SHA-256 fingerprint in `src/shows.ts`; compare it once with [apple.com/certificateauthority](https://www.apple.com/certificateauthority/)), Apple's marker extensions on the intermediate and leaf, the bundle ID `co.crimsonfoundry.pretendthat` (the old `app.pretendthat.ios` is still accepted during the transition), the product, and that the plan isn't expired or refunded.
- It counts under `HMAC(SHOWS_SECRET, originalTransactionId)` (or the app transaction ID for the Free Preview), cut to 32 hex characters, per **month** anchored on the purchase date (a yearly plan still gets its shows per month). KV holds only `c:<hash>:<month start>` → a number, expiring after ~40 days (the Free Preview's after ~13 months).
- It answers `200 {ticket, remaining, allowance}`, or `402 limit_reached` when the month is used up. The **ticket** (HMAC-signed, 6 hours) rides on that show's Claude and image calls as `X-PT-Show`.
- `SHOW_LIMITS` in `wrangler.toml`: `off` (default: the endpoint 404s, everything works as before), `count` (counts, never blocks: usage numbers for pricing), `enforce` (blocks over the allowance **and** refuses Claude/image calls without a valid ticket, `402 show_ticket_required`). Realtime and moderation never need a ticket (replays use them).
- The app side is behind `RELAY_SHOW_LIMITS` in `Relay.xcconfig` (`NO` now). With `YES`, the app asks before each new show; a 404, an error or no network all mean "allow" (only `limit_reached` blocks), so turning the app flag on before the relay is ready is harmless.
- Workers KV is eventually consistent: two shows started at the same moment on two iPads might both count as the last one. It's a soft cap, which is fine here.

**Turn it on (about 5 minutes, after the App Store products exist)**
```sh
cd relay
npx wrangler kv namespace create SHOWS
```
It prints an `id`. In `wrangler.toml`, uncomment the `[[kv_namespaces]]` block and paste that id. Then:
```sh
openssl rand -hex 32          # copy the output
npx wrangler secret put SHOWS_SECRET   # paste it (keep it forever: changing it resets every count)
```
Set `SHOW_LIMITS = "count"` in `wrangler.toml` and `npx wrangler deploy`. Set `RELAY_SHOW_LIMITS = YES` in `Relay.xcconfig` for the next app build. Watch the numbers for a while (Cloudflare dashboard → Workers KV → SHOWS shows the key count; nothing in it identifies anyone). Switch to `"enforce"` only once **every build people use** sends tickets (older builds would get `402` on new shows).

Free tier note: Workers KV allows 1,000 writes a day on the free plan (one per new show), which is plenty to start; the $5/month Workers plan lifts it.

**Never set `TEST_ROOT_SHA256`** on the deployed Worker: it exists only so the tests can use their own certificate chain (`test/fixtures/make-test-chain.sh`; the private key there is a throwaway test key).

## Deploy (for Haylee, step by step)

You need [Node.js](https://nodejs.org) (already installed on your Mac) and a Terminal open in the repo folder.

### 1. Create a free Cloudflare account
Go to [dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) and sign up with your email. The free Workers plan is enough (100,000 requests a day). No credit card is needed.

### 2. Install and log in
```sh
cd relay
npm install
npx wrangler login
```
`wrangler login` opens your browser. Click **Allow** to let Wrangler (Cloudflare's command-line tool) use your account, then come back to Terminal.

### 3. Add the three secrets
Run each line. Each one asks you to paste a value, and nothing is shown while you paste. Press Return after each.
```sh
npx wrangler secret put OPENAI_API_KEY
npx wrangler secret put ANTHROPIC_API_KEY
npx wrangler secret put APP_TOKEN
```
- `OPENAI_API_KEY`: from [platform.openai.com/api-keys](https://platform.openai.com/api-keys). Creating a new key just for the relay is a good idea.
- `ANTHROPIC_API_KEY`: from [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys), again a new one just for the relay.
- `APP_TOKEN`: copy the `RELAY_TOKEN` value from `Relay.xcconfig` in the repo root (the 32-character string after `RELAY_TOKEN = `). It must match exactly.

The first `secret put` may ask to create the Worker. Say yes. Secrets live encrypted in Cloudflare and are never in the repo.

### 4. Deploy and point the app at it
```sh
npx wrangler deploy
```
At the end it prints a URL like `https://pretendthat-relay.your-name.workers.dev`. Open `Relay.xcconfig` and replace the placeholder, **without** the `https://` (xcconfig files treat `//` as a comment):
```
RELAY_HOST = pretendthat-relay.your-name.workers.dev
```
Quick check (should print a 401 JSON error, which means the relay is up and refusing requests that have no token):
```sh
curl -s -X POST https://pretendthat-relay.your-name.workers.dev/v1/messages
```
Then commit and push `Relay.xcconfig`. From now on, a fresh clone gets working AI.

> Your own `Secrets.xcconfig` still wins: with your personal keys in it, your builds keep calling OpenAI and Anthropic directly. To try the relay yourself, comment out the key lines **and** the blank `RELAY_HOST =` / `RELAY_TOKEN =` lines in `Secrets.xcconfig` (a blank line there overrides `Relay.xcconfig` and switches the relay off).

### 5. Set the spend caps ($20 a month in total)
Split it however you like. The default is $10 each.

- **OpenAI** (images and the voice): go to [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits) and set the monthly budget to **$10**, with an email alert at about 80%. OpenAI's budget may only *alert* rather than stop calls, so also check [platform.openai.com/settings/organization/billing](https://platform.openai.com/settings/organization/billing) and keep **auto-recharge off**. With prepaid credits and no auto-recharge, the credit balance is a hard stop. The voice is the priciest part, so this is the cap that matters most.
- **Anthropic** (Claude): go to [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits) and set the monthly **spend limit** to **$10**. Anthropic stops requests once it's reached. Keeping auto-reload off in [Billing](https://console.anthropic.com/settings/billing) adds a second stop.

When a cap is hit, the app degrades gracefully: no Claude means the bundled airplane adventure, and no images means the bundled art. Caps reset monthly.

### Later: updating or rotating
- Change the code: `npx wrangler deploy` again.
- Rotate a key: `npx wrangler secret put OPENAI_API_KEY` (or the others). It takes effect right away, with no app change.
- Rotate the app token: put a new value in both `Relay.xcconfig` and `npx wrangler secret put APP_TOKEN`. Note that older builds will stop working with the relay.
- Abuse? Lower the limits in `wrangler.toml` and redeploy, or rotate the app token.

## Develop

```sh
npm test            # vitest: auth, routing, allow-lists, 404s, 429s, no logging, show counts (JWS chain, KV counter, tickets)
npm run typecheck   # tsc
npx wrangler dev    # local server; put fake values in relay/.dev.vars (git-ignored)
```
