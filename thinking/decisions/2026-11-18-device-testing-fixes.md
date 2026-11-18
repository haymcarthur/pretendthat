# Fixes from Haylee's device testing (2026-11-18)

- **Date:** 2026-11-18
- **Who decided:** Haylee (the four items); Claude's calls noted below.
- **Verified:** `swift test` 740 tests pass (was 728), app builds. Demo-mode screenshots on new throwaway simulators (iPhone 18 Pro, iPhone 17e, iPad Pro 11" M5), deleted afterwards: `/tmp/pt-round-device/`. No API keys, no live game, no live voice check ($0).

## 1. Peek hands (pick one)
- The paws layer carries the whole arms (shoulder to paw), so the 2026-11-18 lift slid the arms up off her shoulders. The lift is now one constant, `PeekHands.chosen` in `NutmegCharacter.swift` (`-PTPeekHands hang|half|onEdge` overrides it in DEBUG). Offsets only, no shape edits.
  - `hang`: the original. Arms on the shoulders, paws over the card's top edge (the rows start below them).
  - `half`: lifted half the overhang. Paws grip the edge, arms stay closer to the shoulders. **Set as the default for now (Claude's call).**
  - `onEdge`: the lift from earlier today. Paws rest on the edge, a gap shows between the arms and the shoulders.
- Screenshots: `/tmp/pt-round-device/hands/` (`zoom-*-4.png` for a close look; 4 and 6 rows on iPhone 18 Pro, 6 rows on iPhone 17e). All fit with no scrolling.
- If none of the three looks right, the art needs a Figma re-export: one whole arm + paw layer per side.

## 2. "Sounds like a game you have": no more dialog
- The saved game's cover sits just above the control bar (it never covers the mic, Repeat or chat buttons). It has a green ▶ (play the saved game), the yellow sparkles (make a new game), and a short word under each (the short title, "New game").
- Nutmeg asks: "We already have <title> saved! Do you want to play that one, or make a new game?"
- The kids answer with a tap, or out loud or typed. The spoken answer is read on the device (`SavedOrNew`, no AI call): "that one / yes / play it / the airplane one" plays the saved game. "New / no / something else / a different one" makes a new game. If the answer is unclear, she says once more: "Tap the picture to play that one, or tap the sparkles to make a new game!"
- It is still only offered with an active pass. On the iPhone it hides while the chat shelf is open (closing the chat brings it back).
- The model's tool output is now "the app handles their answer, say nothing". It no longer says "Tap the one you want!"

## 3. Gaze in Play
- In the peek (scene cards, and the saved game page), while Nutmeg speaks she looks UP at the kids: the talking eyes, her head tipped up about 4° and 8 art px. When the line ends she looks back DOWN at the rows (the focus eyes). That covers a role's job, the setup line and any other line.
- `PeekGaze` (NutmegCore) adds a 0.5 s hold after her voice stops, so the pauses between sentences don't make her eyes flicker. The head tips over 0.18 s; with Reduce Motion it switches at once. `-PTPeekLookUp 0|1` holds either look for screenshots.
- On the iPad she stands beside the card and already looks forward, so nothing changed there.

## 4. BUG: taps and the mic dead after idle / lock — root cause and fix
**Root cause:** when the voice session was lost while the phone was away, nothing brought it back. Three ways this happened:
1. **One failed reconnect ended the voice for the rest of the game.** On unlock, the app pings the socket. If the socket is gone, the app reconnects once. Right after an unlock the network or the audio session is often not ready, so that one try can fail. The session then sat in `.failed` with no retry. Every option tap (`huntReply`) and the live mic (`beginTalk`) is guarded by `realtime.isLive`, so they silently did nothing. The mic still looked normal and went down a non-voice path. A session that failed while in the background was never retried on return either (only `suspended` was checked).
2. **An idle socket could die without anyone noticing.** A Wi-Fi or NAT drop while the phone sat idle is not reported by `URLSessionWebSocketTask`. The status stayed `.live`, so taps and mic turns went into a dead socket and she never answered.
3. **On a replay, the speaker engine was never restarted properly after a lock or an audio interruption.** The session was never reactivated and the player node was not played again. There was also no interruption or media-reset handling, so after a call, Siri or an alarm her voice (and the mic tap) stayed dead.

**Fix:**
- `ForegroundRecovery` (NutmegCore, tested) decides what happens on `.active`: resume a suspended session, or reconnect one that failed or dropped while away.
- `ReconnectBackoff`: a failed silent reconnect tries again after 0, 1.5, 4 and 8 s. If all four fail, the next tap, mic press or foreground tries again (`bringVoiceBackIfNeeded`).
- Keepalive: a ping every 20 s while in the foreground. Two missed pongs in a row close the socket (`SocketHealth`), and the normal drop path reconnects silently.
- While the voice is coming back (the ping, or a reconnect) the mic shows gray "connecting" instead of taking a dead press. The conversation stage stays up (no flip to the tap screens).
- When the app comes back, `clearAwayState()` clears anything left over from before the lock: a half-finished hold or release, the thinking dots, a reminder that never played.
- `NutmegSpeaker`: handles interruptions (stops at began; at ended, reactivates the session, restarts the engine and plays the player) and rebuilds the engine after a media services reset. `recover("foreground")` runs on return. A held engine is now properly restarted. `player.play()` is never called on a stopped engine (that would crash).
- **Simulator check (demo mode, no voice):** background → foreground → tap "Next scene" works (`/tmp/pt-round-device/lock/`). The simulator can't fake a network drop or an audio interruption, so the voice paths were checked by reading the code and by the state-machine tests. They are not proven live (no live check was run, $0). Worth one check on Haylee's phone: lock it for a few minutes mid-game, unlock, then press the mic.

## Claude's calls
- The `half` hands are the default until Haylee picks.
- The short words under the two choices ("<short title>", "New game") stay small, but the pictures lead.
- An unclear spoken answer gets one fixed app line instead of going to the model (cheaper, and it can't wander off).
