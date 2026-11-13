# D2: OpenAI Realtime API (speech-to-speech) for the conversation

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** The planning conversation uses OpenAI's Realtime API (speech-to-speech). Haylee accepts that kids' audio goes to OpenAI, as long as **we store nothing**. This **supersedes** [On-device speech-to-text](on-device-stt.md) and [Kids' names tokenized](names-tokenized.md) **for the planning phase**. Claude still writes the kit and scenes, and names stay tokenized in those Claude calls.

**Privacy wording for the demo (must be accurate):** "PretendThat stores nothing: no accounts, no recordings, no transcripts. Audio is processed live by OpenAI under its API terms." Do not claim OpenAI keeps nothing.

**Why:** Hands-free turn-taking (server VAD), natural voice and live function calling make the conversation feel alive; on-device STT plus TTS could not do that in the time left.
