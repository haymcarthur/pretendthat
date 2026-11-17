# Onboarding voice "sounded different" on the iPad: investigation

**Date:** 2026-11-16 · **By:** Claude (read-only investigation, no app source changed) · **Trigger:** Haylee walked the
round 33 parent onboarding on her physical iPad and Nutmeg's voice "sounded different".

## Short answer
- **The clips are fine.** The onboarding clips are the same coral voice, the same model, the same 24 kHz mono AAC-LC
  format as every other bundled and D3b clip, stored before Varispeed (no speed baked in).
- **The rate is 1.20 in code.** The onboarding builds its own player → Varispeed 1.20 → mixer → output chain with
  `SpeakerGraph.wire`, so the clips are sped up once, not twice and not zero times.
- **What is different is the playback path, and only a real device hears it.** The onboarding is the ONLY place
  Nutmeg plays through a **separate engine on a `.playback` / `.spokenAudio` audio session**. Everywhere else (live
  game, New game greetings, replay clips) she plays through `NutmegSpeaker` on **`.playAndRecord` / `.default` /
  `[.defaultToSpeaker, .allowBluetoothA2DP]` with a 48 kHz preference**. On an iPad the two categories go through
  different output processing for the built-in speakers (media vs play-and-record tuning: loudness, EQ, and
  stereo vs mono-ish output). The simulator plays both through the Mac's output and ignores the category, so it can't
  show the difference. This is the most likely root cause (high confidence that it's the only path difference; medium
  confidence on exactly how iOS tunes it, since that can't be measured from here).
- The onboarding engine also lacks the round 25/33 guards (no 48 kHz preference, no configuration-change or
  route-change re-link). They don't change the rate in the normal case, but they are the remaining way it could play
  at the wrong rate on a device.

## 1. What onboarding plays
- `OnboardingVoice.play(_:)` in `PretendThat/App/AppModel+Onboarding.swift` (about line 183) plays two lines:
  - `OnboardingCopy.getAGrownUp` on screen 1 and from "Hear Nutmeg again" (`OnboardingView.swift` lines 39 and 117)
  - `OnboardingCopy.greetKid` at the hand-off, 700 ms after `finishOnboarding`
- Files: `PretendThat/Resources/CommonClips/common-<key>.aac`, key = `ClipKey.make(line, "coral@gpt-realtime-2.1")`.
  getAGrownUp = `common-2a6c3f89…aac`, greetKid = `common-a03de5c7…aac`.
- **How they were recorded:** `AppModel.debugRecordCommonLines()` (AppModel.swift about line 1591, launch flag
  `-PTRecordCommon`). It connects the normal Realtime session (`voiceConfig` = `VoiceConfig.nutmeg`: coral, server
  speed 1.0 because Varispeed is on, `Realtime.instructions`, model `gpt-realtime-2.1`). Then it calls
  `realtime.say(line, record: true)`, the same tagged `sayExactly` + recorder + transcript gate as D3b game clips, and
  encodes with `ClipStore.encodeAAC` (AAC-LC 24 kHz mono 32 kbps ADTS). Not the `-PTMiniLines` mini model, never TTS.
  Seven clips were added in commit 5126e1e (the 2 onboarding lines, the first-game intro and the 4 short greetings).

### Measured (ffprobe + ffmpeg decode; F0 by autocorrelation at 8 kHz)
| clip | added | format | decoded s | median F0 | RMS |
|---|---|---|---|---|---|
| getAGrownUp 2a6c3f89 | r33 | AAC-LC 24000 Hz mono | 5.67 | 267 Hz | 1925 |
| greetKid a03de5c7 | r33 | same | 7.04 | 286 Hz | 2260 |
| firstIntro 7666e583 | r33 | same | 4.35 | 308 Hz | 2045 |
| short greetings (4) | r33 | same | 1.49–2.30 | 286–381 Hz | 2385–3197 |
| Wi-Fi note f0f099fc | D3b | same | 5.50 | 296 Hz | 1945 |
| saved game 4b20d018 | r26 | same | 4.14 | 242 Hz | 1772 |
| print line 7951fcdc | r27 | same | 9.98 | 296 Hz | 2120 |
| how many e51ce7ec | r26 | same | 3.50 | 320 Hz | 1788 |

- Same format, sample rate and loudness range across all 13 bundled clips. The pitch (F0 roughly 240–380 Hz, raw
  coral) is the same range as the older clips. If speed had been baked in, F0 would sit near 1.2× (about 350 Hz or
  more) and durations would be about 17% short. They aren't, so the clips are pre-Varispeed like the rest.
- Delivery: getAGrownUp is a little slower and has more pauses (15 words, 47% voiced, about 2.6 words/s raw) than the
  older informational lines (3.3–3.6 words/s). That's normal model prosody for "Hi! I'm Nutmeg. …" with its
  exclamations. It's minor, and it would sound the same on the simulator, so it doesn't explain a device-only
  difference.
- Same recordings, different paths: the r33 greeting clips play through `NutmegSpeaker` on New game, while the r33
  onboarding clips play through `OnboardingVoice`. If Haylee hears the New game greeting as "normal" and the onboarding
  as "different", that confirms it's the path.

## 2. Playback path
`OnboardingVoice.play`:
```swift
if session.category != .playAndRecord { try session.setCategory(.playback, mode: .spokenAudio) }
try session.setActive(true)
let engine = AVAudioEngine()            // a second engine, not NutmegSpeaker's
… SpeakerGraph.makePitchUnit(.nutmeg)   // Varispeed 1.20
SpeakerGraph.wire(engine, player: player, pitchUnit: pitch)   // mixer → output at hw format
```
- Rate: Varispeed 1.20 once, with the mixer → output link at the hardware format. Same graph as `NutmegSpeaker`. No
  AVAudioPlayer, no rate of 1.0, no double speed-up.
- Differences from `NutmegSpeaker.start` (NutmegSpeaker.swift about lines 117–175):
  | | NutmegSpeaker (game, greetings, replays) | OnboardingVoice |
  |---|---|---|
  | category / mode | `.playAndRecord` / `.default` | `.playback` / `.spokenAudio` (unless the session is already playAndRecord) |
  | options | `.defaultToSpeaker, .allowBluetoothA2DP` | none |
  | preferred rate | `setPreferredSampleRate(48_000)` before activating | none |
  | engine | the one shared engine (input tapped for the mic) | its own new engine per line, output only |
  | config change observer | re-wire + restart | none (engine would just stop) |
  | route change re-link | yes (round 33 guard) | none |
  | VOICEFMT / AUDIOFMT log | yes | only "clip play (x s heard)", computed, not measured |
  | output volume | mixer `outputVolume = 1` | default (1) |

## 3. Audio session differences on a real iPad
- `.playback` vs `.playAndRecord` on the built-in speakers: iOS routes playAndRecord audio through its
  play-and-record output path, which applies different speaker processing than media playback. Developers commonly
  report it as quieter and thinner, and it may not use the full stereo or 4-speaker media tuning. `.playback` gets the
  full media tuning: louder, more bass, wider. Both run at the hardware rate (usually 48 kHz on current iPads), so
  pitch and pace should match, but the **timbre and loudness differ**. That sounds like "her voice sounds different"
  even at the same rate. Haylee has only ever heard Nutmeg in playAndRecord until now.
- Voice processing is off in both (`AppModel.echoCancel = false`), so there's no AGC or echo-cancellation difference.
- iPads have no receiver/earpiece, so receiver vs speaker isn't a factor (`.defaultToSpeaker` only matters on iPhone).
- `.spokenAudio` mainly changes interruption and ducking behavior, not the sound itself.
- Sample rate: without the 48 kHz preference, the `.playback` session on some iPads can come up at 44.1 kHz. The
  graph is wired at whatever the hardware reports, so that is fine *unless the hardware rate moves after wiring*. If it
  moves (a route change, or the other engine switching the session to playAndRecord at 48 kHz), this engine has no
  re-link. It would then play at 1.20 × link / hardware (for example 1.20 × 44.1/48 = 1.10, the round 25 symptom) or
  stop.

## 4. Other device-only factors checked
- **Hand-off clip and the pre-connect:** `preconnect()` runs right after `finishOnboarding`, but
  `RealtimeSession.preconnect` only opens the socket (no engine, no session change). The greetKid clip isn't disturbed.
- **Replay the intro (Grown-ups):** if `NutmegSpeaker`'s engine is up, the session is already playAndRecord, so
  `OnboardingVoice` keeps that category and runs a second engine beside it. On that path it sounds like the game.
  Only the first launch (and any time the session isn't playAndRecord yet) gets `.playback`. That fits Haylee hearing
  it on the first run.
- **Lip sync:** the envelope is paced at step/1.20. It's cosmetic and doesn't touch the audio.
- **Not onboarding, but against the "never TTS" rule:** an AVSpeechSynthesizer path still exists. `NutmegVoice`
  (`PretendThat/Voice/NutmegVoice.swift`) is called from `AppModel.speak` (about line 1193, "AVSpeech fallback (no
  Realtime session)") and from `repeatTapped` (about line 722) when `realtimeAuth == nil`. If a device build has no
  relay or keys, that path speaks in a system voice. Worth removing or guarding (stay quiet plus the Wi-Fi/grown-up
  note instead).

## Fix proposal (for a build agent)
Goal: Nutmeg sounds byte-for-byte the same everywhere, so the onboarding must use the game's session and graph.

1. **`OnboardingVoice.play` (AppModel+Onboarding.swift): use the game's session configuration.** Use
   `.playAndRecord`, mode `.default`, options `[.defaultToSpeaker, .allowBluetoothA2DP]`, then
   `setPreferredSampleRate(48_000)` before `setActive(true)`. Keep the engine output-only (never touch
   `engine.inputNode`). Best: factor one helper, e.g. `NutmegSpeaker.configureSession()` (static) or `SpeakerGraph`
   in the app target, that both `NutmegSpeaker.start` and `OnboardingVoice.play` call, so they can't drift again.
   - **Verify (must):** on a fresh install (simulator *and* the iPad), screen 1 must not show the microphone prompt
     before screen 4 (round 33 rule). Activating a playAndRecord session without starting input shouldn't prompt,
     but confirm it. If it does prompt, fall back to option 2 and keep `.playback` there (tell Haylee it will sound
     slightly different from the game on purpose).
2. **Better long-term: play onboarding clips through `NutmegSpeaker` itself.** Add an output-only start, e.g.
   `NutmegSpeaker.startForClips(installInput: false)` that skips `installInput` and never reads `inputNode` (today
   `startForClips` calls `start(echoCancel:installInput:)`, and `start` reads `engine.inputNode`, which would set up
   input). Then give `ClipStore`/`NutmegSpeaker` a `playBundled(line)` that uses the existing `playClip` path: the
   same engine, session, relink guard, VOICEFMT log and lip sync, and when the voice connects after consent the mic
   tap is added to the same engine (the existing "engine already running" branch in `start`). Then delete the
   separate `AVAudioEngine` in `OnboardingVoice`, or make `OnboardingVoice` a thin wrapper that forwards
   `speaking`/`level` from the speaker.
3. **If any separate engine stays,** give it the same guards: an `AVAudioEngineConfigurationChange` observer
   (re-wire with `SpeakerGraph.wire`, restart), `SpeakerGraph.relinkIfNeeded` before scheduling, and a route-change
   re-link.
4. **Log for the iPad check (DEBUG and release-safe):** in the onboarding play, log the same `VOICEFMT` line as
   `NutmegSpeaker.logFormats`: session category, mode, sampleRate, output hw rate and channels, mixer→output link,
   current route port type, and the computed heard rate. Then one run on Haylee's iPad settles it.
5. **Test:** extend `Round33OnboardingTests`/`SpeakerGraphTests` with a check that the onboarding path uses the shared
   session configuration (same category, mode, options and preferred rate as the game).
6. **Separate item (TTS rule):** remove the `NutmegVoice` AVSpeech fallback in `AppModel.speak` and
   `AppModel.repeatTapped`, or make it unreachable in release builds.

## How to confirm on the iPad (2 minutes)
Install with `-PTResetOnboarding` and listen to screen 1. Finish the onboarding, then tap New game and listen to the
greeting (same recording session, NutmegSpeaker path). Then Grown-ups → Replay the intro → "Hear Nutmeg again" while
the voice session is up (playAndRecord path). If screen 1 on the first launch sounds louder or fuller than the other
two, the session category is the cause, and fix 1 or 2 makes it match.
