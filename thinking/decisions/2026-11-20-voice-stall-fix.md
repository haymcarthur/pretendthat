# Voice stall on the Play scenes: fix (2026-11-20)

- **Date:** 2026-11-20
- **Who decided:** Haylee asked for the fix (a real family game on build 4). How it's done, the numbers (3 s, 4 s, reopen waits, memory budget) and the code shape are Claude's calls.

## The bug
On the Play scenes the kids tapped each role row's 🔊 and the scene speaker a couple of times each. Everything played at first, then **all** speech stopped. Tapping any row (even rows heard several times) did nothing, and ▶ Next scene changed the card but Nutmeg stayed silent. The iPad was in use the whole time (no lock, no app switch). Leaving the game and reopening it fixed it.

## Why it happened (checked against the code)
- **A. The fixed-lines session had no health check.** Row lines go to the separate scripted-lines session. Its errors after ready were ignored, the keepalive only pinged the main session, and nothing ever reconnected it. Once it failed, every live line went into a dead socket until the game was left.
- **B. Repeat taps still went live.** A spoken line was only reused in the same game if it passed the save checks (finished, transcript match, and a pitch band measured on the main voice). Takes from the lines session likely failed that band, so every tap went to the voice, and A silenced it.
- **C. The cancel bookkeeping could drift for good.** A stop cancelled "creates sent so far" by counting response.created events. One create that never got response.created left the counts one behind, so from then on each tap's own new line was cancelled the moment it arrived (with `cancelAll`, also anything else running). Lines-session responses also drove the main ResponseGate.
- **D. (Not this bug, but real.)** `suspended` could stay on in the foreground after a lock/unlock during a resume (`ForegroundRecovery` returned `.none` while busy, and `resumeSession` had `guard !resuming`). That blocks clips and live lines.
- **E. (Minor.)** A failed speaker rebuild left the engine nil, and live audio was then dropped (only clips restarted the engine).

## The fix
1. **Same-game takes** (`GameTakes`, `ClipRecorder.finish`, `ClipStore.keepForGame`): every finished take of an app line (completed, has sound) stays in memory for the rest of this game, whatever its pitch or transcript. Repeat taps play it with no socket. What gets **saved** for replays still goes through the transcript gate and the live pitch band. Memory only, about 8 minutes max (oldest out), cleared on a new game, replay or leave.
2. **Lines-session health** (`LineSocketHealth`): an error after ready (except a benign "nothing to cancel"), a response.done with status failed, no response.created within 3 s of a line, the receive loop ending, or two missed pongs all count as failure. Then lines go to the main session, the pending line is resent there once (not if a tap already moved past it, or if it's older than 8 s), and the lines session is reopened in the background after 2, 10 and 30 s. The lines session is in the keepalive now, and `lineSocket` is cleared when its receive loop ends. Cancels go only to the socket that owns the response (a cancel for an unknown id is an error event there).
3. **Per-request tags** (`CreateLedger`): `RealtimeSocket.send` stamps every response.create with `metadata.pt_req` (next to the recorder's `pt_line`). A stop marks the requests sent so far; a response that arrives later with one of those tags is cancelled on arrival (only that one, `SpeechStop.cancel`). Requests sent after the stop are never cancelled. One ledger per socket. Lines-session responses no longer touch the main ResponseGate (`lineLifecycle`); the silence reminder takes the gate only when it goes to the main session.
4. **Suspended can't stick** (`ForegroundRecovery`, `ResumeLoop`): a suspended session resumes even while busy; the resume runs once at a time and goes again when it ends suspended with the app active (max 4 rounds). `resumeIfAlive` re-checks `suspended` after its ping, and `connect` stops the audio if the app went away meanwhile. `speak()` with the session suspended while the app is active resumes first, then says the line.
5. **Live route starts the engine** if it is nil (instead of dropping her audio).
6. **Watchdog** (`LineWatchdog`): an app line with no audio within 4 s is logged, marks the voice unhealthy and triggers a silent reconnect (both sessions); the line is said again once the voice is back. At most one watchdog reconnect per 20 s.
- **Release diagnostics:** `voiceLog` (os.Logger, subsystem "PretendThat", category "voice") shows in Release: clip kept / not kept and why (kind, length, which session; never the words), take kept for this game, lines-session failure and fallback, reopen, watchdog, resume rounds, engine starts. Nothing a kid said, no transcripts.

## Files
- NutmegCore: `VoiceStall.swift` (new: `GameTakes`, `CreateLedger`, `LineSocketHealth`, `LineWatchdog`, `ResumeLoop`), `VoiceClips.swift` (`ClipRecorder.finish`), `SpeechStop.swift` (`cancel(_:)`), `DeviceTesting.swift` (`ForegroundRecovery.decide`).
- Tests: `VoiceStallTests.swift` (new, 14 tests, including create ×3 / one errors / stop / create → the new one is not cancelled, and every lock/unlock/ping order up to 6 steps); `DeviceTestingTests.swift` (the busy case now resumes a suspended session).
- App: `RealtimeSession.swift` (socket tags, lines health + fallback + reopen + keepalive, line lifecycle, watchdog, engine start, suspended re-checks, `voiceLog`), `ClipStore.swift` (in-memory takes), `AppModel.swift` (wiring, `ResumeLoop`, suspended speak), `NutmegSpeaker.swift` (rebuild failure logged in Release).

## What was and wasn't compiled or tested here
- This Linux container has no Xcode. Swift 6.0.3 for Linux was installed (from the official Docker image layers; swift.org downloads are blocked here). NutmegCore was built in a throwaway SwiftPM package in the scratchpad with everything except the Apple-only parts (the Signalsmith/Accelerate pitch shifter, `SpeakerGraph` (AVFAudio), the CloudKit mapper; CryptoKit swapped for a small SHA-256 shim). Two Linux-only compiler quirks were worked around in the copy only.
- **Result:** 707 tests ran (693 before + 14 new). All new tests pass, and DeviceTesting, D3b clips and SpeechStop suites pass. The same 10 failures as before the change. They are environment-only: tests that read the app's source and project files from paths outside the copied package.
- **Not compiled:** the app files (`RealtimeSession.swift`, `AppModel.swift`, `ClipStore.swift`, `NutmegSpeaker.swift`). They need the iOS SDK. They were written to match the surrounding Swift 6 style and read over twice, but Haylee's Mac build is the first real compile.
- **Not tested live:** no API keys, no live game, no voice ($0). The real proof is a device game on the Play scenes.

## Checks on Haylee's Mac
1. Build the app (Release config).
2. `swift test` in NutmegCore (expect about 765 tests: 751 + 14).
3. One quick demo-mode device or simulator run: on a Play scene, tap the role rows' 🔊 and the scene speaker rapidly, several times each, then ▶ Next scene. Nothing should crash or get stuck. (Demo mode has no voice, so this checks the taps and the UI only.)
4. When there's a live game anyway: repeat taps of a row should play instantly (Console.app, "voice" category: "take kept for this game", then no new live line for that row).
