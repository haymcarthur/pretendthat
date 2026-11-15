# PretendThat relay

A tiny, stateless [Cloudflare Worker](https://developers.cloudflare.com/workers/) that holds PretendThat's API keys, so anyone who clones and builds the app gets working AI without keys of their own, and no long-lived key ever ships inside the app.

**Status:** built and tested, not deployed yet. Deploying takes about 15 minutes (steps below).

## What it does

Every request must carry the header `X-PT-Token` matching the Worker's `APP_TOKEN` secret, or it gets a 401. Only these three routes exist; everything else (any other path, or any method but POST) gets a 404.

| Route | Forwards to | Checks |
|---|---|---|
| `POST /v1/messages` | Anthropic `api.anthropic.com/v1/messages` (adds the key, keeps the app's `anthropic-version` and `anthropic-beta`) | Model must be `claude-opus-5-5`; `max_tokens` capped at 16,000; no streaming |
| `POST /v1/images/generations` | OpenAI `api.openai.com/v1/images/generations` | Model must be one of the app's `gpt-image-2` family; `n` forced to 1 |
| `POST /v1/realtime/client_secrets` | OpenAI `api.openai.com/v1/realtime/client_secrets` | Mints a **120-second** ephemeral secret for `gpt-realtime-2.1` and returns only `{value, expires_at}`. The app then opens OpenAI's realtime WebSocket directly with it. The secret only has to *start* the session, and the app fetches a fresh one on every connect and reconnect. |

**Rate limits** (per client IP, via the [Workers Rate Limiting binding](https://developers.cloudflare.com/workers/runtime-apis/bindings/rate-limit/)): 10 Claude calls, 40 image calls and 6 realtime sessions per minute. Over the limit you get a 429 with a friendly JSON error. Cloudflare only offers 10- or 60-second windows, and it counts per data center, so these are burst limits. **The spend caps in step 5 are the real ceiling.**

**Stateless, by design:** it never logs request or response bodies or headers, stores nothing, uses no KV or database, and has Workers Logs turned off. Errors are generic, so nothing from a request is echoed back. This matches the project rule: never store anything about kids.

**About the app token:** `RELAY_TOKEN` in `Relay.xcconfig` is committed to the public repo and ships inside every build, so it is **not a secret**. Anyone can read it. It just stops random scanners. What actually protects the account is the per-IP rate limits, the model allow-lists and the spend caps.

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
npm test            # vitest: auth, routing, allow-lists, 404s, 429s, no logging (fetch mocked, no real keys)
npm run typecheck   # tsc
npx wrangler dev    # local server; put fake values in relay/.dev.vars (git-ignored)
```
