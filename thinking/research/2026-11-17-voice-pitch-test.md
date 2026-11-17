# Voice pitch test: raising the live voice to match the greeting clip (2026-11-17)

**By:** Claude (offline listening test only. No app code changed, no API calls, no simulator or iPad used.)
**Trigger:** [decisions/2026-11-17-nutmeg-higher-voice.md](../decisions/2026-11-17-nutmeg-higher-voice.md). Haylee
wants Nutmeg to sound like the bright greeting clip. The live voice gets a pitch raise, separate from speed.
**Listening page:** [design/voice-pitch-test/index.html](../../design/voice-pitch-test/index.html)

## Short answer (plain words)
- **The match is about +6 to +7 semitones** on top of today's Varispeed 1.20. The greeting clip's raw median is 389 Hz.
  The live full-model takes run 249–280 Hz raw, which is 5.7–7.8 semitones lower. The closest single step was +8, +6,
  +7 and +6 on the four test lines. The average gap over all six full-model A/B takes is about 6.6 semitones.
- **Artifacts start to show from +4 and get clear from +6.** Up to +3, the TimePitch output measures almost like
  natural speech at the same pitch. From +4 it gets "too clean": less breath noise between the harmonics than natural
  speech. That's the usual sign of a buzzy, metallic, slightly auto-tuned voice. This is a measurement. I can't
  listen, so Haylee's ear decides.
- **The bigger risk may be the chipmunk effect, not the artifacts.** TimePitch moves her vowel sounds (formants) up
  along with the pitch. At +6 on top of 1.20, her formants are at about 1.70× her natural voice. If +4 or +5 already
  sounds like the clip to her ear, that's the safer pick.
- **Timing and lip sync don't change.** Same length, no measurable delay (TimePitch reports 0 latency; a tone burst
  starts within ±4 ms).

## The page
- Top: "This is Nutmeg", the greeting clip 0adc8906 ("Welcome back! What should we play today?") rendered through
  Varispeed 1.20 as the app plays it (466 Hz heard). Below it, the softer greeting clip 2abd1df9 (406 Hz) for comparison.
- Four live lines, all **raw pre-Varispeed** full-model captures from the A/B v2 run (`NN-full.raw.caf`, 24 kHz float,
  `scratchpad/cap/`), so nothing is processed twice: 02 prop line, 06 Replay Pick question, 07 The End,
  08 nothing heard. (01 is 12 s long; 04 "Hi again!" is already at 386 Hz and needs no raise.)
- Each line: **Today** (1.20 only), **+2 … +8**, and **Per-line match** (each line nudged to the clip's 389 Hz raw
  median: +7.8, +5.7, +6.9, +6.3). The "closest step" tag marks the step whose heard median is nearest 466 Hz.
- Blind mode shuffles each line's 9 versions under letters A–I, with a Reveal button. It's level-matched to −20 dBFS
  speech RMS (measured −20.6 to −22.6 LUFS, within 0.8 dB per line). It's checked at 375 px in dark mode, and all
  38 files load (headless Chrome).

## How it was made (the app's own units)
`scratchpad/ptest/render.swift` (AVAudioEngine **offline manual rendering**, 48 kHz stereo out like the device):
player (24 kHz mono, fed in 100 ms chunks like `NutmegSpeaker.schedule`) → `AVAudioUnitVarispeed` rate 1.20 →
`AVAudioUnitTimePitch` (pitch = N×100 cents, rate 1, overlap 8 default) → main mixer → output. The pitch tracker is the
one from the voice-drift note (normalized autocorrelation, 40 ms / 10 ms, frames within 30 dB of peak), widened to
1000 Hz.

### Heard median F0 (Hz). Clip = 466.
| line | today | +2 | +3 | +4 | +5 | +6 | +7 | +8 | match |
|---|---|---|---|---|---|---|---|---|---|
| 02 prop line (raw 249) | 301 | 335 | 359 | 379 | 402 | 427 | 452 | **480** | 469 (+7.8) |
| 06 question (raw 280) | 338 | 372 | 400 | 432 | 450 | **482** | 510 | 539 | 473 (+5.7) |
| 07 The End (raw 262) | 316 | 354 | 375 | 400 | 421 | 448 | **472** | 500 | 469 (+6.9) |
| 08 nothing heard (raw 270) | 326 | 365 | 384 | 409 | 434 | **468** | 487 | 517 | 471 (+6.3) |

### Artifact measurements
- **Breath noise vs natural:** spectral flatness (300–5000 Hz, speech frames) of the TimePitch version divided by a pure
  resample to the same pitch (Varispeed at 1.20×2^(N/12), so it's natural speech at that pitch, just faster). 1.0 means
  as breathy as natural, and lower means "too clean" or buzzy. Medians over the 4 lines: **+2 0.84, +3 0.90, +4 0.70,
  +5 0.72, +6 0.60, +7 0.57, +8 0.56.** Voicing clarity agrees: TimePitch is more periodic than the natural resample at
  +6/+8 (0.91–0.95 vs 0.86–0.94).
- **Not found:** no loss of voicing (tracked-voiced frames 72–89%, same as today), no pitch warble (frame-to-frame
  jitter goes *down*, 14–26 cents vs 22–30 today), no softened onsets, no cut ends (the speech ends at the same point;
  only a −46 dB breath tail is lost).
- **Overlap 32** (the TimePitch quality knob) costs 3× the CPU and measured the same as 8. It doesn't help.
- **My read:** +2/+3 are clean. +4/+5 may have a slight edge on breathy sounds ("h", "s", soft endings). +6 to +8 are
  the most likely to sound robotic or buzzy, and that's exactly where the clip match is. That's the trade-off Haylee is
  judging.

## How the app change would work (not built)
1. **Graph:** player → Varispeed 1.20 → **TimePitch (extra cents, rate 1)** → mixer, all at the 24 kHz play format.
   `VoiceConfig` gets an `extraCents` (default 0, so nothing changes until it's set). `SpeakerGraph.makePitchUnit` returns
   both units, and `SpeakerGraph.wire` chains them. `SpeakerGraphTests` gets a case: a 220 Hz tone at +N comes out at
   220×1.2×2^(N/12), same length. TimePitch at 0 cents measured identical to bypass, so default-off is safe.
   Varispeed stays first so the 1.20 is clean resampling and only the extra part goes through the phase vocoder.
2. **Clips must NOT get the same fixed raise.** Bundled and kept clips are stored before Varispeed and play through the
   same chain. A fixed +6 would push the greeting clip from 466 to ~660 Hz. Two options:
   - **(a) Per-source cents (recommended):** each clip carries its measured raw median F0 (measure once: bundled clips
     at build time into the CommonClips manifest, kept clips when they're recorded). Then `cents = 1200·log2(target /
     clipF0)`, clamped to about ±8 st. Set it on the TimePitch before scheduling the clip. Live lines get the fixed raise
     Haylee picks. That also covers the "pitch check on every clip" from the drift note.
   - (b) Re-record or re-pick clips near the live voice and raise everything by the same amount. It's simpler, but it
     needs new takes (API cost), and the clip she likes would no longer sound the same.
3. **Per-line normalization for live audio** (the "match" rows): the line's pitch is only known after ~0.5 s of
   streaming, and changing TimePitch mid-line makes an audible glide. The practical form is a **running median of the
   last few live lines' raw F0**, applied between lines only (never mid-line). It's medium effort. Only do it if a
   fixed raise sounds uneven line to line. Coral's takes vary 203–386 Hz raw, so a fixed raise keeps that spread.
4. **Lip sync / timing:** TimePitch rate is 1, so `SpeakerTimeline.playbackRate` (1.20) and `heardMs` truncation stay
   correct. The analyzer reads the pre-shift buffers, and the loudness envelope is unchanged, so the mouth is unaffected.
   Measured offset ≤ ±4 ms.
5. **Barge-in:** `cancel()` should also call `pitchUnit.reset()` (or `AUAudioUnit.reset`) so the phase vocoder's internal
   buffer doesn't leak tens of ms of the cut line into the next one. Check it on device.
6. **CPU / latency on iPad:** offline on this Mac, Varispeed alone renders ~1,900× real time, and Varispeed + TimePitch
   ~520×. That's about 0.2% of one core live. On an iPad expect a few times more, still well under 1%. No added output
   latency was measured. With streamed chunks the unit pulls input on demand, the same as Varispeed does today.

## Cost and risks
- **Cost:** no API spend (the test reused captures, and the change is on-device). The code is small to medium: about
  1 day with tests for the fixed raise plus per-source clip cents. Per-line running normalization adds about half a day.
- **Risks:**
  1. Buzzy/metallic tone at +6 and up (measured; needs her ear, ideally on the iPad speaker).
  2. Chipmunk formants: about ×1.70 total at +6. It might read as "cartoon" (good) or "squeaky toy" (bad) to kids.
  3. Clips double-raised if per-source cents are forgotten (the greeting would jump to ~660 Hz).
  4. Coral's take-to-take spread stays with a fixed raise. A low mini take (203 Hz raw) at +6 is still only ~350 Hz heard.
  5. Device-only behaviors not tested here: realtime TimePitch reset on cut, route-change relink with two units.

## What to do with her answer
- **She picks +6/+7 and it sounds fine:** build the fixed raise + per-source clip cents (target = 389 Hz raw).
- **She picks +4/+5:** same build with that value. The greeting clips then sit a little above the live voice, so set the
  clip target to the live voice's raised median instead (about 265 Hz × 2^(N/12)), so they meet in the middle.
- **She picks "match" over any fixed step:** add the running-median normalization (step 3).
- **She hears buzz at every step that matches:** the alternative is to bring the clip down (re-pick the greeting near
  ~330 Hz raw, like clip 2abd1df9) and raise the live voice only +3, the cleanest step.
