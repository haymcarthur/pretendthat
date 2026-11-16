# Round D3a: the speaker refactor (NutmegSpeaker), no behavior change

**Date:** 2026-11-15 · **Decided by:** Haylee (D3a = a refactor-only round before any clip work, design §D4.4 / §8 /
build plan). The structure and names are Claude's calls, noted. Design:
[saved games + replay design §D4.4](../../docs/superpowers/specs/2026-11-15-saved-games-replay-design.md).

## What changed (structure only)
- **`NutmegSpeaker`** (new, `PretendThat/Voice/NutmegSpeaker.swift`, `@Observable @MainActor`, **owned by `AppModel`**
  so D3b's clips can play without a live session). It owns playing her voice:
  - the AVAudioEngine and output chain: player → Varispeed 1.20 (or TimePitch / none) → mixer at 24 kHz mono; the
    configuration-change rewire; the mic shares the engine, so `start(echoCancel:installInput:)` lets the session
    install its tap;
  - one playback path, `schedule(_ buffer)` (live deltas today via `play(_ pcm16:)`; D3b clips go through it too);
  - lip sync (`LipSyncAnalyzer` → stamped windows → 60 Hz clock → `MouthShaper`), publishing `level` and `mouth`;
  - speaking state (`isSpeaking`, the clock + 0.45 s end check) with callbacks `onStartedSpeaking`,
    `onFinishedSpeaking` (the session's silence timer, reminder clock for Doze, face reset) and `onScheduled` (the
    latency trace's "heard" mark);
  - barge-in: `cancel()` (player cleared, mouth closed, clock reset), `heardMs(itemStart:)` for the truncate point,
    `itemStart()`, `hasAudioQueued` (round 20's kid-turn stop check);
  - app lines: `say(_:thinking:echo:)` forwards to the live voice (`NutmegLiveVoice`, which `RealtimeSession` adopts:
    its `sayExactly`), and the Repeat memory (`remember` / `lastAppLine`, round 17's fallback).
- **`RealtimeSession`** keeps the socket, the protocol, `ResponseGate`, `SpeechStop`, tools, the silent pass, the
  cached prefix (session.update and response.create payloads are byte-for-byte unchanged), chat, expressions and the
  mic. It hands audio deltas to the speaker. `level`, `mouth`, `isSpeaking` are now read-through properties, so
  every existing reader (poses, Doze, DemoDriver, cheers' waits) is unchanged.
- **`AppModel`**: `let speaker`, `RealtimeSession(speaker:)`; its app lines (`speak`, safety steer, rail arrival,
  Repeat, "Almost ready!") call `speaker.say`; `lastAppLine` reads the speaker's memory; the mouth reads the speaker.
- **NutmegCore `SpeakerTimeline`** (Claude's call): the speaker's pure bookkeeping moved unchanged (speaking clock with
  Varispeed divided out, end-check tail, buffer placement / heard time, truncate ms, clear). Plus `LastLineMemory` and
  the D3b seam `SpeechSource` (live / clip). 9 new tests (`RoundD3aSpeakerTests`), incl. a lock on coral + Varispeed
  1.20 (D4.5).
- **D3b seam, declared only:** `NutmegClip` (float PCM before Varispeed), `NutmegClipSource.clip(for:)`,
  `NutmegClipPlayback.playClip(_:echo:)`, and `speaker.clips` (nil). Nothing calls them yet.

## Proof of no behavior change
- `swift test` (NutmegCore): 345 tests green.
- Live typed runs on PT-R15-iPad (personal keys), the SAME scripts on a baseline build of HEAD 339551b and on the
  refactor. Logs: `/tmp/pt-roundD3a/{baseA,newA,baseB,newB}/console.log`.

| moment | baseline (today) | refactor | round 21 |
|---|---|---|---|
| typed turns (game, theme, count), send → heard | 1.26, 1.53, 1.01 s | 1.66, 1.52, 1.65 s | 1.20–1.46 s |
| Found taps | 1.37, 1.37 s | 1.62, 1.78 s (2nd = mid-speech re-tap) | 1.59–1.68 s |
| confirm / printer / color taps | 0.52, 0.47, 0.64 s | 0.77, 0.70, 0.67 s | 1.24 (typed) |
| Don't have it | 0.65 s | 0.93 s | 0.64 s |
| replay app lines (Pick → checklist) | 0.79–1.24 s | 0.62–0.99 s | (D1) |
| **first delta → heard (the speaker's own part)** | **0.02–0.04 s** | **0.02–0.04 s** | |

  The spread is all server time (response.created → first audio delta: 0.34–0.42 s baseline vs 0.51–0.78 s in the
  refactor's planning run, and the other way round in the replay runs). The local part the refactor touches is the
  same, and the replay runs (refactor faster) show it's network noise.
- Behavior checks (refactor run): greeting cut by a typed turn 35 ms after the send ("1 response cancelled, line
  cut"), no greeting audio after; a Found tap mid-reply cancels it ("line cut"); Repeat in the hunt says her last line
  word for word (no second bubble); Repeat on the checklist reads the checklist; the kit-ready line ("tap Let's
  play"); checklist cheers; going home mid-cheer: "line cut", speaking=false at +0.5 s, no audio after; a replay from
  the bookshelf speaks every line live. Lip sync: peak mouth level 0.80–1.00 per line, mouth open in the mid-speech
  screenshots.
- Noticed, not caused here: once the model sent two audio items in one response at the color step (model variance;
  the speaker plays what it's given, as before).

## Not verified
- Mic push-to-talk on a real device (the simulator runs are typed); the engine-configuration-change path (route
  changes); background/foreground resume. All are moved code with the same calls in the same order.
