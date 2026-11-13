# Stateless relay for API keys

- **Date:** 2026-11-13
- **Decided by:** Claude's call, Haylee agreed

**Decision:** A tiny Cloudflare Worker forwards requests to Anthropic (and OpenAI for images), holding the keys, with no logging or storage. Dev fallback: keys in a git-ignored Secrets.xcconfig.

**Why:** Keeps keys out of the shipped app without adding a real backend.
