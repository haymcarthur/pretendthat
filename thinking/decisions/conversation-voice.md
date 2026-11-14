# Conversation voice: Nutmeg is a friend, not a script

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** Nutmeg must not sound canned. The Realtime session instructions (`Realtime.instructions`) make her a warm, curious friend who reacts to what the kids actually say: she comments on their ideas, gets excited about specific details, riffs ("Ooh, a pancake restaurant on the moon?! Do the pancakes float?"), asks one natural follow-up, and varies her wording every time. She still steers through game → who's playing → roles → props → finish via function calls, in her own words, never a fixed script and never reading lists out. Turns are 1–3 short sentences, one question at a time.

- No hard-coded spoken lines in planning: the kickoff is an unspoken stage direction, and function outputs are short notes to the model ("React to it, then find out who is playing"), not lines to read. App-written lines remain only after planning (kit ready, scenes) and in emergency fallbacks.
- Temperature: the GA Realtime session no longer exposes a `temperature` field (checked against OpenAI's session reference, 2026-11-13), so variety comes from the instructions.

**Why:** Kids light up when they're heard; a form-like script loses them in seconds.

## Voice choice and pitch processing (Haylee, 2026-11-13 evening)
- **Problem:** Nutmeg sounded robotic. Cause: the +350-cent `AVAudioUnitTimePitch` (time-stretching pitch shift adds a phasey, robotic artifact).
- **Voice:** default **`marin`** (OpenAI's Realtime docs list alloy, ash, ballad, coral, echo, sage, shimmer, verse, marin, cedar and recommend marin or cedar for best quality). Marin is the natural, expressive female voice; shimmer and coral stay one tap away in the audition. The squeak comes from the voice and delivery, not heavy processing.
- **Delivery instructions:** "Speak like an excited, bubbly young girl cartoon character: bright and high, lively intonation, playful giggles, natural pauses; never flat or monotone."
- **Pitch method:** default **Varispeed** (resampling, pitch and speed together, artifact-free) at **1.06×**, server speed 1.0. Grown-ups can switch Off / Varispeed / TimePitch (TimePitch default +100 cents) to compare.
- **Voice audition (Grown-ups):** pick a voice, play a fixed sample line in a short Realtime session through the same audio path and pitch settings. The voice applies to the next conversation (Realtime can't change voice mid-session).
- **Pipeline check (Claude):** Realtime output is 24 kHz PCM16 and the player/pitch nodes run at 24 kHz float, so the only resample is the mixer's single conversion to the hardware rate; no 8/16 kHz anywhere; PCM16→float stays within ±1 at unity mixer gain (no clipping). Voice-processing IO (echo cancellation) also processes the output on iOS, so it is now **off by default** (a Grown-ups toggle); the mic is gated while Nutmeg talks, so she still never hears herself.

### Younger (Haylee, same evening)
- Marin was realistic but sounded like an adult woman. Default voice now **shimmer** (brightest/youngest candidate; Haylee confirms by ear), Varispeed rate **1.12** (≈ +2 semitones, slightly quicker), still no TimePitch.
- Instructions add: "You sound like a cheerful kid around 8–9 years old: young, bright, bouncy, playful. Short, simple words, a quick pace, giggles."
- Grown-ups: rate slider 1.00–1.25 with live preview (applies to a live voice at once; letting go plays the sample), and an audition list of every Realtime voice, each playable at the current rate.
- The Realtime API `speed` is forced to 1.0 while Varispeed is on, so the two never stack.
