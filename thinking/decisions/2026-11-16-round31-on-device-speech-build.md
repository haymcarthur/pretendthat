# Round 31 build: kids' voices stay on the iPad + an instant mic press

**Date:** 2026-11-16. **Who decided:** Haylee (the design: decisions/2026-11-16-on-device-speech.md, and the mic-press item in queue-next-app-round.md; she pre-approved this round while away). The details below are Claude's calls.

## 1. On-device speech, text-only turns
- **Pipeline:** hold the mic → the shared engine's input (already running for the whole game: pre-warmed) feeds `KidSpeechCapture` → Apple Speech, `requiresOnDeviceRecognition = true`, en-US, dictation hint, punctuation → release (80 ms tail) → final words (≤1.5 s wait) → the request and every audio buffer are dropped → `SpokenTurn.decide` (too short / kit being made / nothing heard / send) → `NameScrubber` → the SAME gate as a typed turn (`AppModel.typed(kind: .spoken)`: local filter first and blocking, moderation in parallel with her reply, round 21) → ONE `conversation.item.create` with `input_text` (`Realtime.kidSpokenTurn`) → the usual `response.create` (tool-first rules unchanged).
- **Removed:** `input_audio_buffer.append / commit / clear`, `MicPump`, and the session's `gpt-4o-mini-transcribe` + `noise_reduction` (session.update keeps the PCM output format, `turn_detection: null`, the same instructions and tools, so the cached prefix is unchanged). A NutmegCore test scans `PretendThat/` and fails if `input_audio_buffer`, `appendAudio`, or a non-on-device recognition request ever comes back.
- **Also removed:** the old DEBUG-simulator fallback to Apple's SERVER recognizer (Listener). There is no audio fallback of any kind now.
- **Nutmeg's voice:** unchanged (Realtime audio, coral, Varispeed 1.20 through NutmegSpeaker).
- **Chat:** shows the scrubbed words exactly as sent ("My name is [name] and I want a pet shop").
- **Safety got stricter for speech:** before, audio went out first and only self-harm / grown-up topics steered afterwards; now the local filter blocks spoken words before anything is sent (live: "I want to hurt my sister with a real knife" → blocked, she steers, nothing sent).
- **Nothing heard** after a real hold (≥0.8 s): her one fixed line "Hmm, I didn't catch that. Hold the red button and tell me again!" (Claude's call; shorter holds stay silent).
- **Barge-in:** pressing still stops her at once (live: line cut at 1.19 s, response cancelled). A press while the last turn's words are still being finished is ignored (logged).

**Name scrubbing (Claude's call, simple rules):** a capitalized word or two right after "my name is / my name's / I'm / I am / call me / this is / it's / his|her|their name is / my brother|sister|friend|mom|dad|cousin|best friend (is)" becomes "[name]". Lowercase words, roles ("I'm the doctor"), stop words and pretend names elsewhere ("a dragon named Sparkle") are kept. Known gap: "I'm Elsa" (a pretend role said as a name) is scrubbed too; fine for privacy. 19-row test table.

**Fallback (no audio, ever):** `SpeechReadiness` (NutmegCore) decides ready / not asked / speech denied / mic denied / restricted / on-device unavailable. Not ready → the mic shows a slashed gray mic that still takes a press → a grown-up alert ("Grown-ups: Nutmeg's ears need a download …" / permission wording) with **Type instead** (opens the chat's text field) or OK. A recognition error that says the model can't load (kLSRErrorDomain 300, kAFAssistantErrorDomain 1700/1101/1107, "on-device"/"asset" errors) flips the state at runtime. Verified live in the simulator (its speech model is broken, see 3).

**Permission strings (Info.plist):**
- Microphone: "Nutmeg listens only while you hold the microphone button. Your child's voice is turned into words right on this iPad and is never sent anywhere."
- Speech recognition: "Speech is turned into words right on this iPad, so Nutmeg can understand your child. Voices are never sent anywhere or saved."
- **Heads-up for Haylee:** iOS puts its OWN fixed sentence above our speech text: "Speech data from this app will be sent to Apple to process your requests…" (screenshot /tmp/pt-round31). Apple shows it for every speech app; we can't change it. Onboarding (round 33) should say plainly that PretendThat forces on-device recognition.

## 2. Instant mic press
- **Root cause found by measuring:** the old `DragGesture(minimumDistance: 0)` fired **750–850 ms after the touch** (on a short press, at about the release; holds under ~0.8 s were even dropped as "too short"). Not the screen-edge gesture gate (deferring system gestures changed nothing).
- **Fix:** `PTPressSurface`, a UIKit touch view on the mic circle: `touchesBegan` sets the listening look at once (local state), fires a pre-warmed light haptic, and passes the touch's own timestamp; the model's work (stop her, start the turn, ~8–60 ms on the main thread) waits for the next display refresh so it can't delay that frame. The recognition task starts off the main thread.
- **Buffer from touch-down:** the input stays running all game; the last ~4 tap chunks (≈200 ms, memory only, overwritten) are kept so the chunk the touch lands in goes into the request. Audio is captured from 40–145 ms BEFORE the touch.

| measure (simulator, iPad Pro 13" M5) | before | after |
|---|---|---|
| touch → gesture callback | 755–847 ms | 9–25 ms |
| touch → listening look inserted | 766–857 ms | 12–15 ms (one cold first press: 400 ms) |
| touch → next frame on screen | 790–1206 ms | 29–46 ms (headless simulator: an upper bound) |
| touch → first captured audio (delivered) | 832–893 ms | 36–105 ms; its first sample −42 to −145 ms (pre-roll) |

The first press after launch once took 400 ms to insert the view (cold); repeat presses were 12–15 ms. Worth a check on the iPad.

## 3. Turn latency (release → first Nutmeg audio)
| path | before | after |
|---|---|---|
| typed turn (round 21) | 1.2–1.5 s | 1.14–1.45 s (this run) |
| voice turn (round 13, audio commit) | ~1.1 s | **1.30–1.53 s, plus the on-device recognizer's finishing time** (not measurable here) |

The "after" voice numbers use stand-in words (`#heard`): a real press, hold and release on the live session, with the recognizer's OUTPUT supplied (everything after the words is real: scrub, gate, text item, tool-first pass, reply). Release → words was 0.08–0.10 s (the 80 ms tail). On an iPad, Apple's on-device finish after `endAudio` usually adds a few hundred ms; measure it there (the `LAT voice: words +x s` mark).

**Accuracy: NOT verified.** 12 synthesized kid-like phrases (macOS `say`, Junior / Flo / Shelley, /tmp/pt-round31/phrases) run through the app's own capture (`#bench`): the simulator reports `supportsOnDeviceRecognition == true` but its on-device model fails to load (`kLSRErrorDomain 300`, mini.json missing). A macOS host bench needs a speech-permission prompt (TCC) and was not run while Haylee is away. **Run `#bench` (or just talk) on the iPad.**

## Verified on the simulator vs needs a real iPad
- Verified: no audio upload code or session transcription (tests + source guard); spoken turns as text items end to end with names scrubbed in the model's input and the chat; typed turns unchanged; local filter blocks spoken text before sending; nothing-heard line; barge-in; the fallback note + Type instead (real recognition error in the simulator); mic press timings; permission strings.
- Needs the iPad: real on-device recognition accuracy with kids' voices, the recognizer's finishing time, the first-press cold time, haptic feel, and the alert wording on a device without the English model.

## Suggested privacy page wording (pretendthat.app/privacy; for Haylee to approve, the site was not edited)
> **Your child's voice stays on the iPad.** Nutmeg only listens while the microphone button is held down. What your child says is turned into words right on the iPad by Apple's on-device speech recognition, and the recording is thrown away the moment the button is let go. The sound of your child's voice is never sent to us or to anyone else, and it is never saved.
>
> **Only the words go to our AI partner.** To answer, Nutmeg sends those words (with names like "my name is …" replaced by "[name]") to OpenAI, which creates her reply and her voice. The words are checked for kid safety first. PretendThat doesn't keep a transcript; the chat on screen disappears when the game ends.
>
> **Microphone and speech permissions.** iOS asks for both. Its standard speech message mentions Apple processing; PretendThat requires on-device recognition, so if the iPad can't do it on the device, the microphone stays off and you can type instead.

Also update: the App Privacy label (audio data: not collected) and the compliance list item on voice/COPPA. Text sent to OpenAI still needs data terms (see the design decision).

## Files
NutmegCore: `OnDeviceSpeech.swift` (NameScrubber, SpeechReadiness, SpokenTurn), `RealtimeProtocol.swift` (no transcription, `kidSpokenTurn`, audio-upload events removed), tests `Round31OnDeviceSpeechTests.swift` (+ RealtimeTests updated). App: `Voice/KidSpeechCapture.swift` (new), `Voice/Listener.swift` (readiness, no server fallback), `Voice/RealtimeSession.swift` (capture on the shared input, text turns), `Voice/MicTiming.swift` (DEBUG timing + next-frame helper), `DesignSystem/PTComponents.swift` (PTMicButton + PTPressSurface, `.unavailable` mode), `App/AppModel.swift`, `App/RootView.swift` (SpeechHelpAlert), `App/DemoDriver.swift` (`#heard`, `#speak`, `#bench`, `-PTStandInWords`), `Resources/Info.plist`.

## Follow-ups (not done)
- The silence reminder still says "Hold the red button…" when the mic is unavailable (should say "type").
- iOS 26's SpeechAnalyzer / AssetInventory could download the English model in-app instead of the Settings hint.
- Scrubbing is rules-only; a small on-device names list could catch "Mia wants…" without a lead-in.
