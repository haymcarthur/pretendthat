# Round 13: one voice for every line, faster replies, a thinking state, "Pretend that…"

**Date:** 2026-11-14 (~01:30–02:45) · **Decided by:** Haylee (the four asks, after playing the round 12 build; tap
latency added mid-round); implementation details are Claude's calls (marked).

## 1. Voice changed again: root cause and fix
- **Settings were fine.** The voice is still Haylee's latest pick: **coral, Varispeed 1.20** (conversation-voice.md
  update, `Realtime.defaultVoice` / `defaultVarispeedRate`). The simulator has no stored `nutmeg.v4.*` values, and every
  connect in her 01:17 game logged `coral, varispeed, rate 1.2, api speed 1.0`. No reconnect happened in that game,
  and no device-voice (AVSpeech) line played.
- **Root cause:** every app-written line (kit progress, kit ready, the silence reminder, scene lines, hand-off lines)
  goes through `Realtime.sayExactly`, an out-of-band response with `conversation: none`, `input: []` and its OWN
  `instructions`. In the Realtime API, a response's instructions **replace** the session's. So those lines lost
  the whole Nutmeg voice description ("a cheerful kid around 8–9 … bouncy … quick pace") and only got "an excited,
  bubbly young girl cartoon character". Same voice (coral) and same Varispeed, but a different character and delivery.
  The play step is ALL app lines, so that's where she sounded like someone else.
- **Fix:** one `Realtime.voiceStyle` string used by the session instructions AND `sayExactlyInstructions` ("You are
  Nutmeg … Your voice: <voiceStyle> Say exactly this line, word for word …").
- **Same connect config everywhere:** new NutmegCore `VoiceConfig` (voice, method, rate, cents, speed → api speed).
  Every connect (pre-connect, first connect, silent reconnect, audition) takes only a `VoiceConfig`. A silent reconnect
  uses the game's first-connect config (`gameVoice`), never a changed setting or a default; DEBUG logs
  "reconnect: voice identical to first connect" and asserts it. Unit test `firstConnectAndReconnectSendTheSameVoice`
  checks the session.update audio output, tools and modalities match on first connect and reconnect.
- **No device voice by accident:** `AppModel.speak` used AVSpeech whenever the session wasn't live. Now, once a game
  has a voice session, a line that arrives while it's down is deferred and a silent reconnect starts; AVSpeech is used
  only when there is no Realtime at all, and that is logged ("AVSpeech fallback (no Realtime session)").

## 2. Lag: measured, then cut
DEBUG `LatencyTrace` logs one line per turn: `LAT <kind>: commit, silent.create, silent.created, tool …,
spoken.create, created, first delta, heard` (seconds after the release / send / tap; "heard" = when the first sample
leaves the speaker, from the player clock + output latency).

**Before** (Haylee's real game, round 12 build, simulator log 01:17–01:27):
| path | tap/release → speaking |
|---|---|
| Let's play! → greeting | 3.2 s (connect 1.1 s + a face-only `set_expression` response 1.4 s + reply) |
| voice turn, tool came fast | 1.1 s |
| voice turn, silent pass generated narration audio first | 3.4–3.9 s |
| tap Found it / Don't have it (sent as text → silent pass with audio) | 3.3–4.1 s |
| hand-off / scene line (sayExactly) | ~1.0 s |

**After** (typed live runs, /tmp/pt-round13/run1–3-event-log.txt, to first sample heard):
| path | after |
|---|---|
| Let's play! → greeting | 0.92, 1.31 s |
| typed turns (game, theme, count, hunt) | 1.21–1.56 s (one outlier 3.85 s: the model took 3 s to emit mark_found + show_next_prop) |
| tap Found it (check-off instant, next prop is her pick) | 1.50–1.62 s |
| tap Don't have it with an alternate (swap instant, one response) | 0.84, 0.91 s |
| tap Let's play! (print step) → scene 1 line | 1.08, 1.19 s |
| tap I'm the ___! → scene line | 0.90, 0.91 s |
| app lines (kit progress, ready, hand-off) | 0.89–1.13 s |

What changed:
- **Pre-connect** (`RealtimeSession.preconnect`): the socket opens and session.update (voice + instructions with
  today's game ideas) is sent while the start screen shows; no audio or mic permission yet. "Let's play!" reuses it
  when the config and instructions match (≤ 15 min old, no error), so only the audio start and greeting remain. Grown-ups
  closing re-runs it (a changed voice gets a new socket).
- **Greeting speaks at once:** the kick-off response has `tool_choice: none` (it used to call `set_expression` first,
  which ended the response and needed a second one).
- **Silent tool-first pass is text-only** (`output_modalities: ["text"]`, `tool_choice: required`): it used to
  generate 2–3 s of unheard narration AUDIO before the tool. Its text items are deleted from the conversation afterwards
  (was: audio truncated to 0 ms). Measured tool arrival: 0.5–0.9 s after the send.
- **No face-only round trips:** every app-requested spoken response offers all tools except `set_expression`
  (`Realtime.responseCreateSpoken`), and the instructions no longer ask her to call it. Faces now come from her words
  (blips: "Ooh!", "Yay!"), the thinking face and the app. *Claude's call* (it cost 0.4–1.4 s each time).
- **Follow-up on function_call_arguments.done: not done.** With the text-only pass, response.done arrives 2–30 ms after
  the last call, and the hunt pass can carry two calls (mark_found + show_next_prop), so waiting for response.done is
  kept: it's safe and costs nothing measurable.
- **Taps (Haylee, mid-round):** Found it / Don't have it change the card AT ONCE (local `store.apply` first), then:
  a swap to the prop's alternate → ONE spoken response, no tools (she just says it); a check-off or a skip → the next
  prop is still her pick, so a text-only `show_next_prop` (or finish) pass, then her line. The hand-off and Let's play!
  taps were already local; their lines now show the thinking state until they play.
- *Claude's call:* if the hunt pass moves to `show_next_prop` without `mark_found` (seen once live with the text-only
  pass), the open card is checked off first.
- Fixed delays: the thinking face's 250 ms wait is gone. Kept: the 120 ms release tail (catches the last mic chunk;
  not a speaking delay), the writing moment, and the 0.4 s roles → prop pause.

## 3. Thinking state (Haylee)
- From the moment the kid lets go of the mic, sends text or taps (and for tap-triggered scene/hand-off lines) until her
  first audio arrives: Nutmeg shows her existing thinking face (with its −4° head tilt), and a typing-dots bubble sits on
  her side of the chat, replaced by her line. `RealtimeSession.thinkingGap` (now immediate); it also clears when a
  turn ends with nothing to say (finish_planning, start_play).
- New `PTTypingBubble` (DesignSystem/PTComponents.swift): three dots in her gray bubble style, pulsing in turn, still
  under Reduce Motion. PTChatPanel gets `typing:` and inserts it after the last line. Screenshot:
  /tmp/pt-round13/loading-state.png.

## 4. "Pretend that" (Haylee)
- Every scene intro (`Scene.nutmegSays`) starts with "Pretend that…": the kit prompt and system prompt require it
  (vary the rest), and `Sanitizer` adds a varied "Pretend that…" opener to any scene line still missing it
  (`PretendLine`). The bundled airplane game's scenes were rewritten to start with it.
- Prop hunt: the app now asks for "pretend that" on props 3 and 6 (about 1 in 3) and tells her not to on the others.
- Live run 3: all 5 scene lines started with "Pretend that…", and prop 3 was "Let's pretend that it's the station
  scanner!" (run 1 and 2: prop 3 also used it).

## Tests
- 174 NutmegCore tests green. New: VoiceConfigTests (defaults, first connect = reconnect, app lines carry the voice
  description, text-only silent pass + no face tool on spoken replies), PretendLineTests (2), prop 1-in-3 rule.

## Not verified
- Real push-to-talk timings (all runs were typed or driver taps; Haylee shares the simulator, no `say` tests). The
  voice path differs only by the 120 ms tail + commit, so expect ~0.1–0.2 s more than the typed numbers.
- Whether the shared voice description makes the play-step lines sound like the conversation to Haylee's ear (logic
  verified; not listened to).
- A failed pre-connect / stale pre-connected socket path (falls back to a normal connect), the reconnect-on-speak path
  in the play step, and Grown-ups voice change after a pre-connect.
- The 3 s outlier on one hunt pass is model time; not reproducible on demand.
