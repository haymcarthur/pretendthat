# Stateless relay for API keys

- **Date:** 2026-11-13 (updated 2026-11-13 PM)
- **Decided by:** Claude's call, Haylee agreed; update by Haylee

**Decision:** A tiny Cloudflare Worker forwards requests to Anthropic (and OpenAI for images), holding the keys, with no logging or storage. Dev fallback: keys in a git-ignored Secrets.xcconfig.

**Update (Haylee, 2026-11-13 PM):** Haylee has no Cloudflare account, so **the demo uses direct keys on the iPad** (Secrets.xcconfig). The relay is the **post-hackathon path**: `relay/README.md` holds the plan and stub code; it is not deployed, and there is no Settings switch for it. The app still reads `RELAY_HOST`/`RELAY_TOKEN` if they are ever set. The demo script must not claim a relay is live.

**Why:** Keeps keys out of the shipped app without adding a real backend. Deferred because no account and limited time before code freeze.

**Update (2026-11-15):** Haylee chose to deploy the relay with a $20/month cap. Built in `relay/`; see [2026-11-15-relay-for-shared-builds.md](2026-11-15-relay-for-shared-builds.md).
