# Round 21: the lag (measured and fixed), choice buttons on top, keyboard fixes

**Date:** 2026-11-15. **Who decided:** Haylee reported all three items after testing round 20 (and said the lag "may
have been my computer battery", so code changes only for a real measured regression). The implementation details
are Claude's calls, noted below.

## 1. "It seems a little laggy": measured first
Typed live runs (`tools/live-voice.sh`, same bakery script, PT-R15-iPad, personal keys, so direct to OpenAI). The trace
now starts at the send or tap itself (round 13's started after the safety check, so it hid this cost):

| step | round 13 baseline | round 20 build (before) | round 21 (after) |
|---|---|---|---|
| game ("Let's do a bakery!") | 1.2–1.6 s | 2.61 s | 1.44 s |
| theme | 1.2–1.6 s | 2.14 s | 1.46 s |
| count | 1.2–1.6 s | 2.23 s | 1.32 s |
| confirm ("Yes!" typed) | (new) | 1.39 s | 1.24 s |
| color ("Full color please" typed) | (new) | 2.67 s | 1.20 s |
| hunt tap, Found it | 1.50–1.62 s | 1.85, 1.93 s | 1.68, 1.59 s |
| hunt tap, Don't have it (swap) | 0.84–0.91 s | 0.72 s | 0.64 s |

- **It was a real regression, and the cause was (a) moderation.** Round 19 awaited OpenAI moderation BEFORE each
  typed turn was sent (measured 0.15–1.16 s) and again before each text tool's output (set_game, set_theme,
  show_next_prop: 0.2–0.86 s). Haylee's low battery may have added to it, but these were ~0.6–1.5 s per typed turn on
  their own. Voice turns paid the tool part.
- **Not the cause:** (b) the kit's background work (tap times only moved by the tool moderation); (c) off-step refusals
  (none in the runs); (d) the stable prefix (the round 20 runs show the same created → first-audio times as round 13).
  So the e294f29 (round 18) worktree build wasn't needed: the moderation marks show the added time directly, and
  round 18's one logged turn (1.55 s) matches round 13.
- **Fix (`SafetyGate`, NutmegCore):** the local filter stays instant and blocks first. Remote moderation runs IN
  PARALLEL with her reply. A late flag cancels the reply (the round 19 stop path), puts the planning state back to the
  last all-clear snapshot (`AdventureStore.safeSnapshot/restore`), takes the typed line out of the chat and deletes it
  from the conversation (client item id), tells the model it was undone, and steers with fresh ideas, as before.
  Live: "I want to make the baby cry and smack it" passed the local filter, moderation flagged it 0.35 s later, her
  reply was cancelled, the line left the chat, and the steer line played at 0.99 s.
- **Unsafe text never goes out:** only state-only calls run ahead (set_game / set_theme at the first steps,
  show_next_prop, and the no-text calls). Roles, finish, a late correction and idea lists wait for every check, then
  check their own text in full. Claude's kit pages and play guide (`store.outboundGate`) and sticker images wait for
  `gate.cleared()`; a flag drops them.
- **Main thread (cheap and safe, done anyway):** kit art decode, paper-white tone curve and cut-out sheet slicing ran
  on the main actor during the hunt; now they run in a detached task, with a full decode before display. The print
  PDF stays on the main actor (SwiftUI `ImageRenderer` needs it, and it only runs at the Print tap).
- *Claude's call:* a flagged prop card can show for a moment (about 0.3–1 s) before it's put back. The local filter
  catches the obvious words first.

## 2. Choice buttons "show up on top" (Haylee)
- The confirm (Yes, let's go! / Change something) and color (Full color / I'll color them) rows hang at the TOP of
  the stage, just under the valance (the same line as the corner X), centered over the stage between the X and the
  right curtain or the chat panel. They keep their size.
- *Claude's call:* her talking close-up keeps her ears clear of the row (`topReserve`, which the close-up now honors),
  so she zooms out a little while the row shows, with the chat open or closed. "On top" read as the top of the stage,
  not the cards' right-side zone.
- Screenshots: `/tmp/pt-round21/confirm-top-chat-closed.png`, `confirm-top-chat-open.png`, `color-top-chat-closed.png`,
  `color-top-chat-open.png`.

## 3. Keyboard (Haylee)
- **(b) Nutmeg shrank (cause found):** this simulator runs the app as an iPadOS window, and there the keyboard RESIZES
  the window (782 → 814 → 406 pt tall), before the keyboard notification arrives. The root's "keyboard-free" size
  (the camera's `referenceSize`) followed it to 406, so she rezoomed tiny. Not caused by the choice rows or the round
  17 X. **Fix:** the stage is its own keyboard-ignoring layer (the chat panel is a separate layer that still rises),
  never lays out shorter than the reference (`PTStageGeometry.keyboardProofSize`), and both the reference and the
  stage's own size, insets and top are only updated after holding 0.4 s with the keyboard down. The round 14 rule
  holds: the keyboard just covers her lower half. Tests: `Round21KeyboardGeometryTests`.
- **(a)** The chat jumps to the bottom when the keyboard opens and on every new line while the field has focus.
- **(c)** After send (button or return key), focus is cleared once and nothing asks for it again (round 11 set it back
  to true "to keep typing", which reopened the keyboard). Tapping the field opens it again. Live: typed, pressed
  return, the keyboard stayed down while she answered.
- *Note:* the window chrome (X, rail, choice row) still moves up a little with the keyboard in windowed mode (iPadOS
  drops the window's top inset); Nutmeg and the floor stay put.
- Screenshots: `/tmp/pt-round21/keyboard-open-chat.png`, `keyboard-open-close-up.png`, `live-typing-keyboard-up.png`,
  `after-send-keyboard-closed.png`.

## Tests and checks
- NutmegCore: 266 tests green (was 255). New: Round21SafetyGateTests (instant local block, screen returns at once,
  late flag fires once and `cleared()` is false, which tools run ahead, snapshot restore, the kit pages wait for the
  gate, the flagged line leaves the chat), Round21KeyboardGeometryTests (no shorter stage, identical framing with the
  keyboard, close-up clears a top row).
- Relay unchanged (no redeploy needed).
- Not checked: a real iPad in full-screen mode (keyboard as a safe-area inset rather than a window resize), the
  relay path's moderation timing, spoken (mic) turns' timings.
