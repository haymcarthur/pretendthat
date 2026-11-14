# Round 6: push-to-talk, control pill, exit warning, single-tap print, prop text, confetti

**Date:** 2026-11-13 · **Decided by:** Haylee (the features, the pill layout and shape, one reply per turn, one reminder at most). The implementation details below are Claude's calls.

## Push-to-talk (Haylee: [push-to-talk](2026-11-13-push-to-talk.md))
- Session: `turn_detection: null`. No server VAD and no `create_response` toggling. The old addressee gate (`HuntGate`) and hunt-mode `autoRespond` are gone.
- Hold the mic: `input_audio_buffer.append`, only while held. Release: a 120 ms tail (the mic tap sends about 50 ms chunks, so this keeps the last word), then `input_audio_buffer.commit` + `response.create`. A hold under 0.3 s (`Realtime.minHoldSeconds`) sends `input_audio_buffer.clear` and nothing else. *(Claude's call: the 120 ms tail.)*
- Pressing while she talks: `response.cancel` (only if a response is active), the player stops, and her item gets `conversation.item.truncate` at the sample actually played. Late audio from the cancelled response is dropped. *(Claude's call: the item id comes from `response.output_item.added`.)*
- The mic is enabled only during planning in a live session. It's disabled while connecting and after planning (D3: kids tap from there on). Without a live session, the same hold gesture drives the on-device `Listener` fallback.
- Hiding the pill during the writing moment releases a held mic. `@GestureState` resets on cancel, so a lost touch always releases.

## Exactly one spoken reply per kid turn (Haylee, after the first build repeated questions 2–3 times)
- Root causes: the turn-ending nudge asked for a second response, and the expression-only follow-up spoke again. `TurnCheck.lastSentence` also picked the wrong sentence when a turn had 3 or more sentences, so a "Hold the red button and tell me!" ending looked like a broken turn.
- Fix: new NutmegCore `ResponseGate`. It never overlaps responses. After `response.done` it sends ONE follow-up only if this kid turn hasn't spoken yet (she called tools or set her face silently). `set_expression` never asks for a response by itself. The writing beat's announcement is the one deliberate second part. This is unit-tested in `oneSpokenReplyPerKidTurn`.
- Turn-ending nudges are now silent notes that steer her next turn. *Claude's call:* the one exception is a turn with no question and no instruction at all (seen live: "Ooh, a pet rescue, so sweet!"). That turn gets one short continuation, and the note forbids repeating anything. Without it, the kid has nothing to answer.
- The transcript starts a new bubble for a silence reminder instead of gluing it onto her last reply.

## Silence (Haylee)
- At most ONE reminder per question, after 20 s of quiet (45 s during the prop hunt). It is short and never repeats the question ("Hold the red button whenever you're ready!"). After that she stays quiet until the kid talks. Checked live: 70 s idle, one reminder.

## Instructions
- She says "Hold the red button and tell me!" only in her very first question. She never says "just talk" or that she's always listening. The hunt explanation no longer mentions the button.
- `show_next_prop.becomes`: 6 words or fewer, kid-friendly (in the tool description and the parameter description).

## Control pill (Haylee)
- Close LEFT · big red mic CENTER (92 pt, `Theme.micRed` #D93025, white glyph) · chat RIGHT. The gap is 20 pt, about 10 pt from a side button to the mic's backing.
- The backing is `PTMicPillShape`: a capsule that swells into a circle around the mic, with concave fillets (radius 14). It has the same white fill and shadow as before. The circle reaches about 24 pt above the old pill top. *Claude's call:* the stage camera presets were left untouched as instructed, so the bump overlaps the stage a little.
- Mic states: idle, listening (scales to 0.92, pulsing red rings, waveform glyph), disabled (gray). Medium haptic on press, light on release. VoiceOver: tap to start and tap to send.

## Exit warning
- `PTLeaveDialog`: a white PT panel on a scrim, with "Leave the game?" and "If you leave now, you'll start a new game next time." "Keep playing" is the black primary pill and "Leave" is secondary. Tapping the scrim keeps playing. *(Claude's call: a PT panel instead of a system alert.)*

## Print
- Hold-to-print is gone from the kit screen and the chat panel's pinned kit card. A single tap on "Print" (a printer icon plus the word) opens `UIPrintInteractionController`. `PTParentGate` stays only for the Grown-ups gear.

## Prop card text
- No `lineLimit` on the "becomes" line in `PTPropActiveCard`, `PTPropPinnedCard`, `PTItemCard`, `PTStageItemCard` or `PTPropCard`. The card grows instead.

## Confetti
- Moved out of KitView into RootView as the topmost layer (above the chat panel, rail, pill and leave dialog), with `allowsHitTesting(false)`. It runs once per landing and is removed after 3 s.
