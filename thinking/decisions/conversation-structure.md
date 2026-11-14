# Conversation structure (refines conversation-voice.md)

- **Date:** 2026-11-13
- **Decided by:** Haylee (rules); enforcement design Claude's call

1. Fixed steps, varied wording: GAME (question + 2–3 example games) → THEME (question + 2–3 themes that fit) → PLAYERS
   (how many, with an example) → ROLES (announced, "Sound good?") → PROPS (what to find, tell me when found / missing)
   → FINISH (making the kit). New tool `set_theme`; `AdventureStore.planningStep` follows the calls.
2. Every turn ends with ONE question plus 2–3 suggestions, or a clear instruction. Reactions are one short sentence.
   Off-topic: one kind line, then re-ask with suggestions. The instructions carry good/bad examples, and say to call
   a step's tool as soon as the kid answers instead of filler ("let me set that up").
3. App-side enforcement (`TurnCheck`): after a turn completes (no follow-up pending), the app checks how it ended for
   the current step; if it broke the rule, one silent system note ("If they already answered, call <tool> and ask the
   next step's question; otherwise …") and one short follow-up response. Never more than one nudge per kid turn.
   After ~8 s of silence she gently re-asks the step's question (at most twice per turn).
4. Every question is in her spoken line, so it streams into the chat panel.
