# Round 10: Haylee's review fixes (clipboard layer, Go play removed, Done/Back, pinned cards, framing, one animation)

**Date:** 2026-11-14 (~00:20–01:00) · **Decided by:** Haylee (the 11 items in queue-next-app-round.md "Round 10", plus
"remove the twinkle"); implementation details are Claude's calls, noted.

1. **Clipboard front layer = board + clip only (idle, point; start screen + stage).** `tools/split_clipboard.py` now
   cuts the arm path (idle and point: path 11, which includes the paw on the board) OUT of the front layer with a second,
   nested clipPath (canvas rect + arm, even-odd), so the arm is drawn only by the body, behind the head. The paw/fingers
   on the board are far below the chin, so the body draws them unchanged. Celebrate kept as is (board + gripping paw,
   away from the head). No art redrawn; body SVGs untouched. CoreSVG renders the nested even-odd clip correctly
   (checked on the simulator: /tmp/pt-round10/start-chest-idle-zoom.png, stage-idle.png).
2. **Tie-backs inward:** the curtain's open tie point moved from 0.2 to 0.34 of the swag width (`PTCurtainShape`), so
   the knot and the WHOLE tassel show on both sides (start screen + stage). The swag waist moves in with it (Claude's
   call: moving only the art would float the knot off the fabric).
3. **Star twinkle: REMOVED (Haylee, mid-round).** A random-clock twinkle with a glint was built first, then Haylee asked
   for static stars. `PTTwinkle` is deleted; stars and sparkles are static on the stage and the start screen (they keep
   the pop-in and the celebrate bounce).
4. **Writing shot:** bottom edge at canvas y 1015 (round 8: 1120, round 7: 790); head, top ~2/3 of the clipboard and the
   writing paw with the crayon. **Notch:** the crayon now rocks around its TIP (art ~760, 778) at ±2.5° with no drift
   (was ±4° around the grip + drift), so the tip stays inside the cut in the clipboard edge and only the top end
   scribbles. A 1–2 px purple sliver (part of the crayon layer) can still flicker at the tip edge when zoomed in.
5. **Roles → prop pause:** 1 s → 0.4 s (`RealtimeSession.startPropLine`, the only change there).
6. **One shared animation:** `Theme.stageMove` (spring 0.8 / 0.84) for the camera (frame), Nutmeg, floor, hunt cards,
   presented cards (no more 0.12 s stagger), phase content, the pinned card, and the chat panel / rail slide (they
   cause the camera move). The hunt's zoom-out now waits for the card it makes room for (`desiredShot` needs a visible
   prop), so zoom + card are one move instead of zoom-during-roles then card. Kit papers start with the zoom (60 ms,
   was 650 ms after it); the checklist paper too (60 ms, was 350). Verified: /tmp/pt-round10/zoom-transition-sheet.png
   (scene → hand-off at 10 fps: camera, Nutmeg and card move together).
7. **Checklist, chat closed:** `PTStageDirector.huntFrame` exactly (same camera, Nutmeg, floor as the prop-card step);
   the checklist sits in the hunt card's zone (`huntContent`), paper width 380 (was 440, Claude's call so it scales
   less in that zone). Compare checklist-chat-closed.png with prop-card-step.png.
8. **Checklist, chat open:** compact pinned card (28 pt pictures, 17 pt text, 6 pt padding, title on one line). If its
   estimated height is over 50% of the chat panel, it collapses to a summary row ("Get the plane ready · 1 of 3 ✓",
   tap to expand, chevron to collapse) with Done! still visible. Claude's call: a height estimate (rows by text length)
   instead of ViewThatFits, which stretched the card to the cap.
9. **"Go play!" screen removed:** the `.stepBack` phase is gone (and the napping/Help/Next scene screen). "Done!" is
   always enabled; an early tap checks the remaining steps one by one (140 ms each, + 350 ms hold), then goes straight
   to the next "Pass the iPad to the …" card (or the next scene if the same role continues, or the finale). Taps on rows
   are ignored during the auto-check. `helpRequested` now works in a scene (unused by the UI; the mic covers help).
10. **Undo:** `AdventureStore.doneSnapshot` keeps the checkmarks from before Done. "← Back to the checklist" on the
    hand-off card (and, Claude's call, on the finale right after the last scene) restores them exactly, until the next
    role taps "I'm the …!" or confirms by voice (`confirm_handoff` unchanged; Back then Done then voice confirm is
    unit-tested). Tapping a checked step unchecks it (was already so; now tested).
11. **Hand-off card, chat open:** pinned at the top of the chat panel at full readable size (big "I'm the Captain! →"
    button full width + Back), Nutmeg centered on the stage. Rule: the pinned cards share one chat-open treatment
    (`.ptPinnedCard()` for checklist + hand-off; the prop and kit pinned cards already used the same white rounded
    look and were left as they are).
- **Extra (prompt only):** the first-prop rule now says to think about what this game's main action needs (examples:
  bakery bowl, space box, doctor towel, pirate sheet), that a plate is never the first prop unless the game is about
  plates/food and never becomes a wheel first; `show_next_prop` says the list order means nothing; the "PRETEND THAT"
  example says "towel" instead of "plate". Not live-tested (no voice tests this round).

## Tests
- 164 tests (5 new: early Done → auto-check → hand-off, Back restores exactly, uncheck, Back + voice confirm, finale +
  Back). `walk()` and the hand-off voice test updated for async `sceneDone()`.

## Screenshots (/tmp/pt-round10/)
start-chest-idle.png (+ -zoom), stage-idle.png, writing-shot.png, crayon/tip*.png, prop-card-step.png,
checklist-chat-closed.png, checklist-chat-open.png, done-early-autochecked.png, done-handoff-with-back.png,
back-restored-checklist.png, doneflow/ (0.5–1 s frames), handoff-chat-open.png, handoff-chat-closed.png,
zoom-transition-sheet.png + zoomseq/.

## Not verified
- 13" iPad; the collapsed summary row on a real long scene (bundled scenes fit); Reduce Motion paths; the first-prop
  prompt live; the hunt zoom waiting for the card in a live session (logic only, demo shots have no live session).

## Round 10b (2026-11-14, ~01:00, Claude's call on the method; Haylee: "the arm still isn't fixed")
- The head always wins over the arm/paw; only the clipboard board/clip may draw over the head. The round-10 cut used an
  even-odd clip, which Apple's SVG renderer ignores, so the arm's top still drew over her chin on device. Option (a):
  tools/split_clipboard.py now splits the idle/point front layer by the head zone (head-base bottom as placed +12, plus
  a 12 px bob margin widening for the state tilts): the arm and paw are only in front below it, and only the clip pieces
  painted after the arm are in front inside it. Simple nonzero polygons, 3 px overlaps so no anti-aliased hairline.
  Celebrate, wave, writing checked, not affected. Crops: /tmp/pt-round10b/crop-*.png.
