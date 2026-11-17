# Voice pitch test 2: +2 semitones without the "tunnel" (2026-11-17)

**By:** Claude. This was an offline listening test only. No app code changed, no API calls, no simulator, nothing committed.
**Trigger:** Haylee likes the pitch at +2 in [voice-pitch-test](2026-11-17-voice-pitch-test.md), but TimePitch makes Nutmeg
sound "like she is talking inside a tunnel". She wants that pitch without the tunnel.
**Listening page:** [design/voice-pitch-test-2/index.html](../../design/voice-pitch-test-2/index.html)

## Short answer (plain words)
- **The tunnel is phase smearing, and Signalsmith doesn't fix it.** In real speech, each vocal-cord pulse lines up all the
  harmonics at once. Phase-vocoder shifters rebuild each harmonic on its own and blur those pulses. I measured that as
  "pulse sharpness" against natural speech at the same pitch. TimePitch and Signalsmith Stretch (every setting, +1, +2
  or +3, vowels kept or not) all land at **73–76%**. They are both phase-vocoder style, so I don't expect Signalsmith to
  sound much less tunnel-like. Its "vowels kept" (formant) mode does avoid the extra chipmunk shift.
- **Ranking, least tunnel at about +2:**
  1. **Speed 1.35** (100%, no processing). The only cost: she talks 12% faster than today.
  2. **Split: speed 1.27 + PSOLA +1** (91%). She's 6% faster, and only a small shift is processed.
  3. **PSOLA +2** (90%). Same speed as today. It may have a slight rough or hoarse edge: more noise between harmonics
     than natural (+36%) and the harmonics a little less clean (−0.6 dB).
  4. Signalsmith +2, vowels kept (74%).
  5. Signalsmith +2 (75%).
  6. Old TimePitch +2 (74%, the tunnel anchor).
  - Signalsmith +3 and +3 vowels kept measure like +2, just higher. Speed 1.27 alone is clean, but it's only +1.
- **What I expect sounds cleanest:** Speed 1.35, if the extra speed is OK. If she must keep today's speed, the **split**
  (or PSOLA +2) is the only option that measurably keeps the voice pulses. Her ear decides; I can't listen.
- **Split only helps with PSOLA.** A phase vocoder blurs the pulses the same at +1 as at +2. Split with TimePitch +1 = 75%,
  and split with Signalsmith +1 = 76%.

## The page
- **Reference:** greeting clip 0adc8906 through Varispeed 1.20 (467 Hz heard).
- **Four live lines:** the same raw pre-Varispeed full-model captures as test 1 (02, 06, 07, 08,
  `scratchpad/cap/NN-full.raw.caf`).
- **Ten versions per line:** Today, Old TimePitch +2, Speed 1.35, Speed 1.27, Split (1.27 + PSOLA +1), PSOLA +2,
  Signalsmith +2, +2 vowels kept, +3, +3 vowels kept.
- **Blind mode:** shuffles each line under A–J, with Reveal.
- **Level match:** −20 dBFS speech RMS, measured −20.8 to −22.6 LUFS, within 0.6 dB per line.
- **Checks:** headless Chrome at 375 px in dark mode (no horizontal scroll) and at desktop width in light mode. All 41 files
  load, and blind mode hides labels until Reveal.

## How it was made
Scripts are in `scratchpad/ptest2/` (outside the repo). `make2.sh` builds everything, `summ.py` summarizes and `page.py`
writes the page.
- **Speed and TimePitch:** `render2.swift` is test 1's AVAudioEngine offline renderer with the Varispeed rate as an
  argument (100 ms chunks, 48 kHz out).
- **Signalsmith Stretch 1.3.2:** this needs its dependency, Signalsmith Linear 0.6.6 (same author, also MIT). Both were
  cloned into their own scratchpad folders, `ext-ss/` and `ext-linear/`, and were not added to the app. `ss.cpp` runs it
  on the 1.20 output in 100 ms chunks, using seek/flush so the output lines up with the input.
  - On the page: a **60 ms block / 15 ms interval** config.
  - `presetDefault` (120 ms / 30 ms) measured the same pulse sharpness. But with vowels kept it added 2–4 dB of echo
    before word onsets and a tail after offsets, and it has twice the latency.
  - Formant preservation is `setFormantFactor(1, compensatePitch: true)` with automatic formant base.
- **PSOLA:** `psola.cpp` is my own minimal TD-PSOLA. Its parts:
  - Autocorrelation pitch, 5 ms hop.
  - Analysis marks on low-passed glottal peaks.
  - Asymmetric Hann grains between neighbouring marks, so 0 st is exact identity.
  - Synthesis spacing of period / 2^(st/12), keeping duration.
  - It's about 120 lines, and no third-party code was used.
- **Metrics:** `measure.cpp` and `smear.cpp`. The pulse, clarity and breath metrics are compared with natural speech at the
  same pitch (Varispeed alone at 1.20 × 2^(st/12)). The echo and tail metrics compare each version with its own unshifted
  input (same timing).

### Results (averages over the 4 lines)
| version | st | speed | pulse sharpness | kurtosis | HNR diff dB | breath | echo before dB | tail dB |
|---|---|---|---|---|---|---|---|---|
| Today | 0 | 1.20 | 100% | 100% | 0 | 100% | 0 | 0 |
| Speed 1.27 | +1.0 | 1.27 | 100% | 100% | 0 | 100% | – | – |
| Speed 1.35 | +2.0 | 1.35 | 100% | 100% | 0 | 100% | – | – |
| TimePitch +2 | +1.9 | 1.20 | 74% | 62% | +1.1 | 100% | +0.8 | −0.1 |
| Signalsmith +2 | +2.0 | 1.20 | 75% | 63% | +0.6 | 110% | −0.3 | +0.1 |
| Signalsmith +2 vowels kept | +2.0 | 1.20 | 74% | 62% | +0.8 | 110% | +0.8 | +1.2 |
| Signalsmith +3 | +3.0 | 1.20 | 74% | 62% | +0.8 | 111% | −0.2 | −0.2 |
| Signalsmith +3 vowels kept | +2.9 | 1.20 | 74% | 62% | +0.8 | 111% | +1.1 | +1.2 |
| Signalsmith +2 default block, vowels kept | +1.9 | 1.20 | 74% | 62% | +0.6 | 127% | +2.8 | +1.9 |
| PSOLA +2 | +2.0 | 1.20 | 90% | 81% | −0.6 | 136% | +0.9 | +0.7 |
| PSOLA +3 | +3.0 | 1.20 | 89% | 79% | −0.9 | 161% | +1.3 | +1.4 |
| Split 1.27 + PSOLA +1 | +2.0 | 1.27 | 91% | 82% | −0.2 | 117% | +0.4 | +0.3 |
| Split 1.27 + TimePitch +1 | +2.1 | 1.27 | 75% | 62% | +0.4 | 98% | +0.6 | −0.8 |
| Split 1.27 + Signalsmith +1 | +2.0 | 1.27 | 76% | 64% | +0.3 | 104% | −0.5 | +0.2 |

**What the columns mean:**
- **Pulse sharpness:** the median crest factor of the LPC residual (order 48, 40 ms frames) in voiced frames.
- **Kurtosis:** the same residual's kurtosis. Both are measures of phase coherence, and they agree.
- **HNR diff:** the autocorrelation harmonics-to-noise ratio, minus natural speech at the same pitch.
- **Breath:** spectral flatness, 300–5000 Hz.
- **Echo before and tail:** extra energy 10–40 ms before sharp onsets and 10–50 ms after sharp offsets (32 onsets and
  23 offsets in all). Time smearing is small for every option. **The tunnel shows up in pulse sharpness, not in time
  smearing.**
- Test 1's flatness measure couldn't see the tunnel: TimePitch +2 reads 100% on it.

## If the winner is Speed 1.35 (the simplest)
- **App change:** set `Realtime.defaultVarispeedRate` (VoiceShape rate) to 1.3469. The graph and the TimePitch path don't
  change. CPU and latency are the same as today.
- **Lip sync and timing:** `SpeakerTimeline.playbackRate` and `heardMs` already use the rate, so they follow.
- **Clips:** they get the same raise, so the greeting goes from 467 Hz to about 524 Hz. Check this against the live voice.
  The per-source-cents idea from test 1 still applies if the gap matters.
- **Risk:** lines are 12% shorter. Kids aged 4–8 may find it fast, so check it with the scene openings (01 is 12 s at 1.20).
- No library is involved, so nothing new goes on the Code Camp profile.

## If the winner is the split or PSOLA +2 (own code)
- **Where it goes:** process speech before the player, in `NutmegSpeaker.schedule`, not as an AVAudioUnit in the graph.
  - Each 24 kHz chunk goes through a per-line PSOLA state object (Swift + vDSP, or a small C file) before
    `player.scheduleBuffer`. Varispeed stays in the graph (1.27 for the split, 1.20 for PSOLA +2).
  - `queueMouth` then analyzes the shifted buffer, so lip sync stays right automatically.
- **Latency:** PSOLA needs about one analysis frame plus one period of lookahead, roughly 30–40 ms per line. The lookahead
  has to be flushed at the end of a line, which needs an end-of-line hook: the session knows when `response.audio.done`
  arrives.
- **Barge-in:** `cancel()` resets the state.
- **Clips:** they go through the same path, so the per-source-cents note from test 1 applies.
- **CPU:**
  - My unoptimized test code runs at 140× real time at 24 kHz on one M3 Pro core, about 0.7% of a core. On iPad,
    expect 1–2% before optimizing.
  - Most of the cost is the naive autocorrelation. FFT-based autocorrelation via vDSP would make it negligible.
- **License:** our own code, so nothing to list. TD-PSOLA is an old, public technique.
- **Risks:** pitch-mark errors on creaky or very breathy takes can cause roughness or a "double voice". The tracker needs
  tests: a sine and a pulse train in, an exact pitch out, and 0 st = identity. The measured breath noise +36% at +2 needs
  her ear.
- **Effort:** about 1 day with tests (state object, end-of-line flush, cancel reset, tests).

## If she still prefers Signalsmith after listening
- **License:** MIT (Signalsmith Stretch, and its required dependency Signalsmith Linear, also MIT). The MIT notice must
  ship in the app's acknowledgements.
- **Code Camp:** both must be **listed on the Code Camp team profile** ("all libraries and services must be listed").
- **App change:**
  - It's header-only C++. Add it through SPM or vendor the two folders, behind a tiny Objective-C++ (`.mm`) wrapper with
    a C API: `create(sampleRate, semitones, keepFormants)`, `process(in, out, n)`, `flush`, `reset`.
  - Use it the same way as PSOLA above: in `schedule`, before the player, on 24 kHz mono. Varispeed 1.20 stays in the
    graph. Wrapping it as an AUAudioUnit for the graph is possible but much more work.
  - Build it with optimization even in Debug, because Debug is up to 10× slower. The README warns that Apple Clang
    16.0.0 with `-ffast-math` miscompiles, so don't use fast-math.
- **Latency:**
  - The 60 ms / 15 ms config has 30 ms input + 30 ms output latency: **60 ms** more before her first sound, plus a flush
    at the end of each line.
  - `presetDefault` is 120 ms.
- **CPU:**
  - At 24 kHz mono on one M3 Pro core (100 ms chunks): **≈ 535× real time (0.19% of a core)**, and ≈ 380× (0.26%) with
    vowels kept.
  - On iPad, expect well under 1%.
  - It computes in bursts (one spectral block every 15 ms). `splitComputation` evens that out for +15 ms of latency.
- **Effort:** about 1 day with tests.

## Notes
- **Rubber Band and SoundTouch** are GPL / LGPL (Rubber Band has a paid commercial license). I didn't use them and they
  aren't suggested for the App Store build. Rubber Band's R3 engine is a phase vocoder too.
- **Apple's built-in options:** the only units are `AVAudioUnitTimePitch` (a phase vocoder) and Varispeed (resampling).
  There's no built-in PSOLA.
- **Not tested here:** the iPad speaker, real-time streaming (offline render only), and kids' reactions to 1.35.
