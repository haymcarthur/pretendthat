# Voice drift: "the first bit sounds right, then it slowly gets lower" (2026-11-17)

**By:** Claude (investigation only; no app code, flags or simulators changed; Haylee's sim AF512F6A only had its log
and app container read). **Trigger:** Haylee's screen recording `~/Downloads/Screen Recording 2026-11-17 at 9.35.17 AM.mov`
(66 s, ReplayKit, 48 kHz AAC). **Chart + audio:** [design/voice-drift/index.html](../../design/voice-drift/index.html)
(`greeting-clip-then-live.m4a` is the 5 s where it happens).

## Short answer (plain words)
- **It's (c): a bright recorded clip followed by a lower live voice.** It isn't the playback rate (a) or the model
  sliding lower over the session (b).
- Every New game opens with a **bundled greeting clip**. Both greeting clips are among the brightest takes ever recorded
  of her: 384 Hz and 334 Hz raw (the 13 bundled clips run 224–396, median 294). Today's opening, "Welcome back! What
  should we play today?", was heard at **~447 Hz**. Then, 2.2 s in, **the live model finishes the greeting at ~258 Hz**,
  which is **9.5 semitones lower**, in the same breath. After that the live lines sit at **294–344 Hz**, 4.5–7.3
  semitones under the clip. Her ear calibrates to the clip ("sounds right") and everything after is a step down.
- **Within this conversation there is no gradual fall.** The live line medians go 258 → 294 → 324 → 338 → 304 → 299 →
  344 Hz (flat to slightly up). Speaking rate also holds (4.3–6.1 syllable peaks per second). The "slowly" is probably
  the live greeting tail plus individual sentences that end low (two lines fall to ~250 Hz in their last third).
- **The rate is 1.20 the whole time.** Every line logged `VOICEFMT … 48000 … heard ×1.200`. Measured raw-to-heard
  ratios: greeting 6.1 → 5.1 s (×1.196), prop line clip 12.4 → 10.4 s (×1.19), game 1's 10.7 → 8.9 s (×1.20).

## What was recorded (aligned to the app log; recording t=0 ≈ 09:35:17.9)
This is **game 2** of the run. Game 1 (09:32–09:34) ended with Home at 09:34:40. A **fresh** Realtime socket was
pre-connected at 09:34:40 (`SESSION ready`, USAGE #14 `cached 0`), so this conversation was about 1 minute old, not a
long session. Model `gpt-realtime-2.1` (full, no `-PTMiniLines`), voice coral, server speed 1, Varispeed 1.2.

| rec time | line (log) | source | heard F0 median (p10–p90) | vs clip | syllable peaks/s |
|---|---|---|---|---|---|
| 1.4–3.9 s | "Welcome back! What should we play today?" (GREETING short, clip 0adc8906) | **bundled clip** (raw 384 Hz) | **447** (228–615) | 0 | 4.3 |
| 3.9–6.2 s | greeting, live tail (2.8 s) | live | **258** (208–398) | −9.5 st | 3.1 |
| 13.9–25.6 s | set_game reply (cut by her next typed turn, "line cut") | live | 294 (229–442) | −7.3 | 4.3 |
| 26.3–34.4 s | set_theme reply | live | 324 (225–494) | −5.6 | 4.3 |
| 35.3–41.5 s | player count reply (cut) | live | 338 (232–450) | −4.8 | 4.6 |
| 44.3–47.5 s | confirm_plan reply | live | 304 (220–434) | −6.7 | 5.1 |
| 55.8–60.0 s | roles line | live | 299 (234–361) | −7.0 | 4.5 |
| 61.8–66.3 s | PROPLINE app line "First, can you find a cardboard box?…" (cut by the recording end) | live take of an app line | 344 (226–442) | −4.5 | 6.1 |

(Pitch: normalized autocorrelation, 40 ms frames / 10 ms hop, frames within 30 dB of each line's peak. Syllable
peaks: energy peaks ≥3 dB over the preceding dip, voiced, ≥80 ms apart: a relative measure, not true syllables.)
The bundled clip check: raw 384 Hz × 1.2 = 461, measured 447 in the recording (inside tracker noise).

## Log for the run (09:32–09:38, her sim)
- `AUDIOFMT` at both game starts: PlayAndRecord/Default 48 kHz, output hw 48 k, mixer 48 k, input on.
- `VOICEFMT … → heard ×1.200` on **every** line (17 lines over both games). No re-link, route change, sample-rate
  change, Varispeed change or interruption logged. The only session change was the planned new socket after Home.
- Bundled clips: `CLIP play 2abd1df9` (game 1: "Yay, you're back! What should we play?") and `CLIP play 0adc8906`
  (game 2). Everything else was live: the replies, roles and the app's prop lines (`realtime.say`, then kept as a
  game clip). No saved-game clip was replayed.
- Two of her typed turns cut Nutmeg mid-line (`speaker cleared, line cut` at 09:35:43 and 09:35:59).

## Is (b), model drift over a long session, real for us?
- Not in this recording: the session was one minute old and the live pitch doesn't fall.
- The A/B v2 captures (one session, 8 lines in a row, raw pre-Varispeed): **full** 263, 250, 275, 386, 263, 281, 262,
  271 Hz, no trend. **Mini** 277, 198, 289, 273, 258, 199, 209, 202 Hz: 4 of the last 5 are low, but the line texts
  differ, so it's not proof of drift. Worth watching if mini goes on.
- Not tested: a full 10–15 minute game (planning → hunt → scenes). Long Realtime sessions drifting in voice is an
  anecdotal report, not something we've measured. A cheap test is in fix 5.

## Fixes, ranked (none implemented)
1. **Make the greeting all one voice: drop the bundled clip at the start of the greeting, or re-record both greeting
   clips at the live voice's typical pitch.** This removes the step she's hearing. Cost: tiny (two lines in
   `openGreeting`, or two re-recorded clips). Risk: dropping the clip gives up the instant start (+~1.4 s to first
   sound, from the round-13 latency work). Re-recording keeps the instant start: pick takes near **290–300 Hz raw** (the
   bundled median) instead of 334/384. Low risk.
2. **A pitch check on every recorded clip (bundled and kept):** reject or re-ask a take whose raw median F0 is outside
   about 260–330 Hz. That keeps clips and live in one band. Cost: small (the tracker exists in tools/voice_measure.swift;
   the app needs a cheap on-device version, about 1 ms per line with vDSP). Risk: low. A re-asked take costs one more
   mini/full response.
3. **Stronger, steadier voice instructions:** add "keep the same high pitch on every line, including the ends of
   sentences; don't drop low at the end" to `Realtime.voiceStyle`. Cost: a one-line change plus a listen. Risk: low,
   though prompt effects on the voice are weak and uneven. Doesn't fix the clip mismatch alone.
4. **Per-line pitch normalization:** measure each live line's median F0 and nudge the Varispeed/TimePitch rate (for
   example ±1–2 semitones) toward a target. Cost: medium (streaming audio means you only know the pitch after the
   first ~0.5 s; it changes speed too with Varispeed, so it needs a separate pitch unit). Risk: medium (artifacts,
   audible pitch jumps mid-line). Only if 1–3 aren't enough.
5. **Session refresh per scene (in case (b) shows up in long games):** re-open the Realtime socket at scene boundaries
   with a state summary (the round-9 silent reconnect already does this after a lock). Cost: medium. Risk: medium
   (latency at the switch, lost context). **Do the measuring first:** one 15-minute game on PT-R15 with `-PTTapOut`,
   then plot raw F0 by turn. Only build this if the raw pitch falls over turns.

**Recommendation:** do 1 (re-record the two greeting clips near 295 Hz raw, or drop the clip) plus 3. Add 2 when
clips are next touched. Run the fix-5 measurement once before deciding on the mini flag.
