# Relay for shared builds

**Date:** 2026-11-15 (after the competition). **Who decided:** Haylee chose "Deploy the relay" with a **$20/month** total spend cap; the details below are Claude's calls.

**Decision:** Build the stateless relay (`relay/`, a Cloudflare Worker) so anyone who clones the public repo and builds gets working AI without their own keys. Haylee does the account steps (Cloudflare sign-up, `wrangler login`, secrets, deploy, spend caps) from `relay/README.md`. Supersedes the "post-hackathon, not deployed" part of [stateless-relay.md](stateless-relay.md).

**Why:** A public repo whose AI only works with your own keys is a weak demo. The relay keeps the long-lived keys off every device, stores nothing, and gives a clear privacy story.

## Claude's calls
- **Three routes only:** `/v1/messages`, `/v1/images/generations`, `/v1/realtime/client_secrets`. Everything else returns 404. Header `X-PT-Token` (was `x-nutmeg-token` in the stub).
- **Allow-lists:** Claude `claude-opus-5-5` only, `max_tokens` capped at 16,000 (the app's value), no streaming. Images: the app's three `gpt-image-2` family IDs, `n` forced to 1. Refused image models answer `400 model_not_found`, so the app's model fall-through still works. Bodies over 256 KB are refused.
- **Realtime:** the relay mints an ephemeral client secret (OpenAI GA `POST /v1/realtime/client_secrets`, `session: {type: realtime, model: gpt-realtime-2.1}`) that lasts **120 s**. That's only long enough to start a session, since a started session outlives the secret. The model is fixed by the relay, and the app's body is ignored. The app fetches a **fresh secret on every connect** (pre-connect, first connect, silent reconnect, voice audition), so Resume's reconnects never reuse an expired one.
- **Rate limits:** the Workers Rate Limiting binding only allows 10 s or 60 s windows (not 10 minutes), so the limits are per minute per IP: 10 Claude, 40 image (a kit plus stickers can be about 20–30 images in a burst), 6 realtime. They are counted per Cloudflare location, so the **spend caps are the real ceiling**.
- **Stateless:** no logging anywhere (a test checks this), Workers observability off, no KV or Durable Objects, and generic error messages.
- **Config:** a committed `Relay.xcconfig` (placeholder host + a random 32-character app token) is the base config in `project.yml`. It ends with `#include? "Secrets.xcconfig"`, so the git-ignored file is optional and overrides it. **Personal keys now win over the relay** (they used to lose), which is dev mode. The placeholder host (`<subdomain>`) counts as unset, so an undeployed relay is never called and the app runs the bundled fallback.
- **The app token is public** (it's in the repo and in every build). It's documented as such: it only stops scanners.
- **Spend caps:** $10 OpenAI + $10 Anthropic by default. OpenAI's monthly budget may only alert, so the README also says to keep auto-recharge off (prepaid credits are the hard stop).

## Not verified
The real ephemeral-secret call and connecting OpenAI's WebSocket with an `ek_` secret can't be tested until the relay is deployed. The request and response shape follows OpenAI's API reference (checked 2026-11-15).
