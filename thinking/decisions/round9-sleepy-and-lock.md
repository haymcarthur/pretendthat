# Round 9: game survives lock/background, sleepy Nutmeg, hand-off voice confirm

**Date:** 2026-11-14 (after midnight) · **Decided by:** Haylee (the features, see queue-next-app-round.md and
2026-11-13-stage-polish-ideas-approved.md); implementation details are Claude's calls.

## 1. Game survives lock / background (Haylee)
- Nothing in the game reacts to `scenePhase` except the audio: step, game, theme, roles, props found, kit pages and
  images, and the chat transcript all stay in memory (AdventureStore, KitArtService, RealtimeSession.chat). Only
  fully closing the app (or Leave) ends the game. Nothing is written to disk (save-to-disk stays an idea).
- **Background** (`AppModel.scenePhaseChanged(.background)` → `RealtimeSession.suspend()`): a held push-to-talk is
  ended with `input_audio_buffer.clear` (nothing sent), her line in progress is interrupted and truncated at what was
  heard, the silence timer stops, the audio engine and mic tap stop, the audio session deactivates. The socket is
  kept. A socket that drops while suspended is only noted (no `.failed` status), so the UI never flips to the tap
  screens. Audio deltas and app lines are dropped while suspended. The scribble loop and TTS stop too.
- **Foreground** (`resumeSession`): `resumeIfAlive()` pings the socket (pong within 3 s). Alive → the audio restarts,
  nothing is said. Gone → `reconnectSilently()`: a new session with `Realtime.resumeInstructions` = the usual
  instructions (with this session's game ideas) + `ResumeContext.summary` (NutmegCore/Resume.swift): "do NOT greet …
  do NOT repeat your last question … do NOT give new suggestions … say NOTHING until a kid talks", where we are
  (step and what she's waiting for), choices so far (game/theme, kid count, roles), every prop with id + status
  (found / we'll pretend / CURRENT card / not asked), kit status (not started / being made / ready / playing scene k of
  n), and the latest 6 chat lines (clipped at 220 chars). No kick-off, so no greeting. The chat is kept
  (`connect(keepChat: true)`).
  Session-side turn state starts fresh; the app re-applies hunt mode / quick-reply mode, marks the props as already
  planned (no second writing beat), shows a prop card that was held for the roles line, and restarts the normal
  silence timer (the one reminder is not repeated if it was already used for this question).
- *Claude's call:* a drop in the FOREGROUND (Realtime session time limit, network blip) also reconnects silently the
  same way (`onDropped`), at most one attempt per 5 s, instead of failing over to the tap screens.
- **Kit generation in flight:** a `UIApplication` background task starts on background during kit making (or before
  the kit is final) so in-flight requests can finish; it ends when the kit is final or on return. Page-art requests
  that failed for a network reason (`URLError` / transport) are retried by `KitArtService` once the app is active
  again (up to 2 retries; only missing pages). The kit stays not-final meanwhile, so the papers and the ready line
  wait. A failed kit JSON request is retried via `store.retry()` on return.
- **Kit-ready line plays once:** `kitReadySaid` guards it; if the session is away (background / reconnecting) it is
  deferred and spoken once the session is back.
- **Idle timer:** `isIdleTimerDisabled = true` during the conversation (pickGame/players/props) and kit making (until
  the papers are out); auto-lock allowed in the Print step (papers out) and Play.
- DEBUG: `-PTDropOnBackground` closes the socket on background to force the reconnect path in the simulator.

## 2. Sleepy Nutmeg (Haylee)
- `DozeClock` (NutmegCore/Doze.swift, unit-tested): starts when the ONE silence reminder has finished playing; after
  30 s more quiet → **sitting** (sit pose, happy eyes) for 3 s → **drowsy** (heavy slow blinks to the nap eyes, head
  nods down 2°) for 4.5 s → **asleep** (nap face, head down 3°, slow deep breathing: 5.5 s period, 2x depth). No text,
  no "z"s (the step-back nap keeps its old z's).
- Only in the conversation steps (game, theme, how many, prop hunt), never during the writing moment (roles), kit
  making, Print or Play, and never while she or the kid is talking or a response/beat is pending.
- Waking: pressing the mic or typing → a 1.2 s happy pop (yay face; the sit → idle swap does the squash-and-hop, or a
  crossfade with Reduce Motion). From drowsy/asleep a silent note goes with the kid's turn: she may start with a tiny
  "Oh! I'm awake!", then carries on (no greeting, no repeated question). Seen live: "Oh! I'm awake! A pirate ship
  sounds daring and fun. What kind of twist should it have? …"
- DEBUG: `-PTDozeFast` (reminder after 4 s, the 30 s wait scaled to 4.5 s).

## 3. Hand-off voice confirm (left from round 8)
- New Realtime tool `confirm_handoff` (play-step hand-off only): same as tapping "I'm the Captain!"
  (`store.badgeTapped`). During a hand-off the post-planning note names the role and asks for the tool when the kid
  says they're that role or have the iPad. It ends her turn (the app speaks the scene line). Refused outside a
  hand-off. Unit-tested on the bundled game.

## Tests
- 159 tests (11 new): DozeTests (6), ResumeTests (4), HandoffVoiceTests (1); RealtimeTests tool list updated.

## Live verification (simulator, typed turns, `-PTDropOnBackground` so every return took the reconnect path)
- (a) Prop hunt: background 15 s → return: "reconnect: silent … 6 recent lines, no kick-off", no line from her, card +
  chat + step intact (/tmp/pt-round9/lifecycle/a1, a3). The next "we found it!" → mark_found → next prop, as normal.
- (b) Kit generation: background 25 s during kit making; the background task let the kit + art finish while away
  (progress lines while away were dropped, not queued). Return → reconnect → one progress line, then the kit-ready line
  exactly once (b1, b2).
- (c) Play (hand-off card): background 3 min → return → reconnect, nothing said; "I've got the iPad!" →
  confirm_handoff → scene 1 line (c1, c2, d-final).
- Sleepy: /tmp/pt-round9/sleepy/1–6 (reminder done → sit → drowsy → asleep → woken pop → "Oh! I'm awake!" + answer).
- Event log: /tmp/pt-round9/silent-reconnect-event-log.txt.
- Not verified: the "socket still alive" path (ping OK, audio restart only), since the debug flag always drops it; a
  real device lock; a page-art network failure + retry; Reduce Motion on the sleepy transition (code path is the
  existing crossfade swap); push-to-talk held at the moment of backgrounding.
