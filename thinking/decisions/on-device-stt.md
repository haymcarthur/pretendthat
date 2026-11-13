# On-device speech-to-text

> **Superseded for the planning phase** by [D2: OpenAI Realtime API](realtime-api.md) (Haylee, 2026-11-13). Hold-to-talk on-device STT remains only on the fallback tap screens (used when the Realtime connection fails).

- **Date:** 2026-11-13
- **Decided by:** Claude's call, Haylee agreed

**Decision:** SFSpeechRecognizer with on-device recognition only, using a press-and-hold mic. Always paired with big tap choices.

**Why:** Kids' audio never leaves the iPad. Hold-to-talk stops Nutmeg from hearing herself.
