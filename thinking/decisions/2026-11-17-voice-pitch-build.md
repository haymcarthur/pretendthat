# Voice pitch build: Signalsmith +2 on the live voice, clips moved to meet it

- **Date:** 2026-11-17
- **Decision (Haylee):** Nutmeg's live voice is OpenAI Realtime coral → Varispeed 1.20 (unchanged) → Signalsmith Stretch
  +2 semitones, formant preservation OFF (the "plain +2" in design/voice-pitch-test-2/). She approved Signalsmith Stretch
  and Signalsmith Linear (both MIT). See decisions/2026-11-17-signalsmith-pitch.md.
- **Built by:** Claude, on branch `worktree-agent-a392bcdc3a1dce04f`. **Listen:** [design/voice-pitch-build/index.html](../../design/voice-pitch-build/index.html).
- **Still to do:** Haylee listens on the iPad before it's final.
- **Superseded for clips** by [voice clips match](2026-11-17-voice-clips-match.md): clips now get exactly the live +2
  (the per-clip shift and formant matching below are gone) and the bundled clips were re-recorded.

## Libraries (for the Code Camp team profile)
| Library | Version | License | Where |
|---|---|---|---|
| Signalsmith Stretch | 1.4.0 (tag 1.4.0; files from main @ 88061fd4, which only adds a Linear bump in CMakeLists) | MIT, © 2022 Geraint Luff / Signalsmith Audio Ltd. | NutmegCore/Sources/SignalsmithShift/vendor/signalsmith-stretch |
| Signalsmith Linear | 0.6.6 (tag 0.6.6 @ 7bb1c8f3) | MIT, © 2025 Signalsmith Audio | NutmegCore/Sources/SignalsmithShift/vendor/signalsmith-linear |

- **How they're added:** vendored, unmodified, with their LICENSE.txt files (`vendor/PINNED.txt` records the pins).
  Upstream has no Package.swift, so a SwiftPM dependency by tag isn't possible. They sit in a new C++ target,
  `SignalsmithShift`, inside the NutmegCore package. A ~50-line C wrapper (`SignalsmithShift.cpp`, C API in
  `include/SignalsmithShift.h`) exposes create, set, latency, seek, process, flush and reset.
- **Build settings:** Accelerate FFTs (`SIGNALSMITH_USE_ACCELERATE`). Always `-O3`, even in Debug, through a local
  package `unsafeFlags`, which Xcode accepts for a path package. No `-ffast-math` (the Stretch README warns about Apple
  Clang 16.0.0). One upstream warning: a `-Wshorten-64-to-32` in signalsmith-stretch.h:439.
- **Credits:** Grown-ups → About what we save gets a new "Credits" section at the end. It lists each library with its
  version, license, copyright line and URL, plus the MIT license text in a disclosure. There were no earlier credits
  in the app.

## What was built
- **Config:** `VoiceConfig.pitchShift: PitchShift(semitones: 2, preserveFormants: false)`, set in
  `Realtime.defaultPitchShiftSemitones`. `PitchShift.off` (0 semitones) means no processing at all, for live lines
  and clips. The voice ID, and so the clip keys, doesn't include the shift, so the bundled clips keep their keys. The
  DEBUG flag `-PTPitchShift N` overrides it for one run (0 = today's voice). That flag made the before captures.
- **Where the shift runs [Claude's call]:** live lines are shifted in `NutmegSpeaker` on the 24 kHz audio, before
  `player.scheduleBuffer`, not as a unit in the graph. That keeps lip sync right: `queueMouth` analyzes exactly what is
  heard, and `SpeakerTimeline` counts exactly what is scheduled. Varispeed stays the graph's one unit.
- **Matching the reference's block size:** the STFT block is 60 ms / 15 ms as *heard*, which is 72 ms / 18 ms of
  24 kHz source at 1.20 (1728 / 432 samples). That matches the 48 kHz "speech" config in the reference you picked.
- **Streaming shifter (`VoicePitchShifter`, NutmegCore):**
  - The first input-latency samples prime the shifter (`seek`), and the first output-latency samples are dropped.
    Output is sample-aligned with the input and the same length, so `heardMs` and the truncate point stay right.
  - **Line end:** the session's `response.output_audio.done` calls `speaker.endOfLine()`, which plays the held-back
    tail.
  - **Missed audio-done:** an idle check flushes the line if no audio arrives before the queue is about to run dry.
  - **Barge-in:** `cancel()` and `silence()` reset the shifter and stop any clip still being fed, so a cut line never
    leaks into the next one.
- **Clips (bundled and recorded, both stored before Varispeed and before the shift):**
  - Each clip gets its own `ClipPitch.plan`: semitones = 12·log2(target / clip pitch), clamped to ±6 st.
  - The target is the live voice after the raise: 266 Hz raw × 2^(2/12) = 298.6 Hz raw (358 Hz heard). 266 Hz is the
    `PitchTracker` median of the eight A/B v2 full-model captures.
  - **Where the pitch comes from:**
    - Bundled clips are measured once when they're decoded.
    - Recorded clips are measured off the main actor while they're encoded.
    - Saved clips on a replay are measured on decode and cached. `SavedClip` didn't change, so no schema or privacy
      key change.
  - **Feeding:** a clip is shifted in 100 ms chunks, the first three now and the rest one per main-actor turn, so a
    60 s scene line never blocks the UI.
- **Clip formants [Claude's call]:** a clip moved by a different amount than the live +2 gets its formants placed
  where the live voice's are (Signalsmith's formant shift +2 with pitch compensation). The bright greeting is moved
  down about 4 st, and a plain shift would also pull its vowels about 6 st below the live voice's. On a cepstral timbre
  distance to the four new live lines, the greeting measures:

  | Greeting version | Distance |
  |---|---|
  | formant-matched | 16.6 |
  | plain | 21.9 |
  | today | 22.2 |

  The spectral centroid points the other way: matched 973 Hz, plain 721, live lines about 700. The page has both
  versions. `matchLiveFormants: false` switches to plain.
- **Pitch check (`ClipPitch.check`, sane range = ±5.5 st around the target, about 217–410 Hz raw):**
  - `VoicePitchTests.everyBundledClipIsInTheSanePitchRange` fails for any future bundled clip outside the range.
  - The app logs `CLIP pitch OUT OF RANGE` for a recorded clip outside it.
  - The 13 bundled clips measure 224–395 Hz raw. The lowest, 4b20d018 at 224 Hz, is the closest to the edge.

## Measurements (no API spend, no live game)
- **App output on the PT-R15 simulator:** captured with `-PTTapOut`, using the new DEBUG driver
  `-PTVoiceRender <raw .caf>`. It plays the greeting clip through the real speaker, then feeds a saved raw capture as
  live PCM16 deltas (50 ms each, faster than real time) plus the audio-done.

  | | Greeting pitch heard | Live line 07 pitch heard | Pulse sharpness (line 07) |
  |---|---|---|---|
  | Today (`-PTPitchShift 0`) | 465 Hz | 316 Hz | 4.95 |
  | New | 368 Hz | 353 Hz | 3.64 |
  | Your pick (test 2, 07-ss2) | – | 355 Hz | 3.64 |

  - The gap between the greeting and the live line goes from 6.7 st (today) to 0.7 st.
  - The live line starts 40 ms later than today, at the simulator measurement's 20 ms resolution. The budget is
    about 60 ms.
- **Offline, through the same chain** (`renderForListening`: shifter → player → `SpeakerGraph` Varispeed → 48 kHz),
  pitch and pulse sharpness:

  | Line | New | Your pick |
  |---|---|---|
  | 02 | 338.5 Hz / 3.68 | 338.4 Hz / 3.71 |
  | 06 | 382.3 Hz / 3.59 | 379.8 Hz / 3.61 |
  | 07 | 353.4 Hz / 3.63 | 354.5 Hz / 3.64 |
  | 08 | 365.8 Hz / 3.64 | 365.1 Hz / 3.63 |

- **The one measured difference from your pick is breathiness.** Spectral flatness, which measures noise between the
  harmonics, comes out lower:

  | | Flatness vs natural speech at +2 |
  |---|---|
  | New | about 84% |
  | Your pick | about 120% |

  - Your pick ran Signalsmith at 48 kHz, after Varispeed. The app runs it at 24 kHz, before the player.
  - My wrapper gives the same output as the test agent's own code when both run at 24 kHz (flatness 0.0529 vs 0.0524).
    So the difference comes from where in the chain the shift runs, not from a bug.
  - Pulse sharpness and pitch are identical. If New sounds "cleaner" or buzzier than the pick, the fallback is to
    shift after Varispeed instead. That needs a 48 kHz unit in the graph, the bigger change the research note
    described.
- **CPU:** 154× real time in `swift test` (Debug, under parallel test load). The test agent measured about 535×
  standalone. On the iPad, expect well under 1% of a core.

## Tests and builds
- `swift test` in NutmegCore: 526 tests pass. `VoicePitchTests` adds 16:
  - the config, and 0 = off
  - the block size and latency budget
  - the clip plan math (target, greeting down, clamp, unmeasured, formants)
  - the sane range
  - the pitch tracker
  - length and alignment at four chunkings
  - no leak after a reset, a line shorter than the priming
  - +2 on pulses, and the graph render at 1.20 and +2
  - every bundled clip in range, and the greeting landing within 0.75 st of the live target
  - speed, and the credits matching the LICENSE files
- `xcodegen generate`, then Debug and Release builds for iPad (PT-R15) and iPhone (PTi-iPhone18Pro): all four succeed.
  The Release key check is clean ("no personal keys in the Info.plist").

## Notes
- `-PTTapOut`'s voice-in.caf and the A/B capture's `.raw.caf` tap the player, so they now hold the shifted audio, not
  the raw voice.
- If the iPad listen goes badly, set `Realtime.defaultPitchShiftSemitones = 0`. That restores today's voice exactly:
  nothing is processed, and clips aren't shifted.
- No live keys were used. Secrets.xcconfig was never copied. Haylee's simulator AF512F6A and her iPad weren't touched.
