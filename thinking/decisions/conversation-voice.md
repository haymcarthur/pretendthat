# Conversation voice: Nutmeg is a friend, not a script

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** Nutmeg must not sound canned. The Realtime session instructions (`Realtime.instructions`) make her a warm, curious friend who reacts to what the kids actually say: she comments on their ideas, gets excited about specific details, riffs ("Ooh, a pancake restaurant on the moon?! Do the pancakes float?"), asks one natural follow-up, and varies her wording every time. She still steers through game → who's playing → roles → props → finish via function calls, in her own words, never a fixed script and never reading lists out. Turns are 1–3 short sentences, one question at a time.

- No hard-coded spoken lines in planning: the kickoff is an unspoken stage direction, and function outputs are short notes to the model ("React to it, then find out who is playing"), not lines to read. App-written lines remain only after planning (kit ready, scenes) and in emergency fallbacks.
- Temperature: the GA Realtime session no longer exposes a `temperature` field (checked against OpenAI's session reference, 2026-11-13), so variety comes from the instructions.

**Why:** Kids light up when they're heard; a form-like script loses them in seconds.
