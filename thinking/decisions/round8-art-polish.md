# Round 8: art polish (tie-backs, wave, clipboard layers, writing body, stars, toys, hand-off, checklist)

**Date:** 2026-11-13 (night) · **Decided by:** Haylee (items and rules, see queue-next-app-round.md); Claude's calls noted

1. **Tie-backs:** `tieback-left` replaces the code-drawn pill in `PTCurtain.half()`: width 1.1 x `m.visible`, height x 627/709,
   no rotation, knot (0.852, 0.270) on the tie point, same scale grow-in (anchored on the knot). The right half mirrors the
   left art. Same view on the start screen and the game stage.
2. **New wave:** body + `nutmeg-wave-arm` + `nutmeg-wave-clipboard`, one body transform for all three
   (`NutmegPose.bodyTransform`, matrix [0.876, 0, 0, 0.876, 104.2, 250]). Head bob in the wave only goes DOWN (breath
   follow and talking nod clamped), so no chin gap. Nothing clips the feet (no frame clip). Claude's call: import_art
   strips the wave's tail for the start screen at x < 200 (the new body's torso starts at x 291, so the old 300 cut
   removed everything).
3. **Clipboard-both:** re-imported the complete clipboard (no holes). The tiny orange slivers under the paws are faintly
   visible only when zoomed in; left as drawn (art rule).
4. **Clipboard in front of the head (idle, point, celebrate):** Claude's call on the method: `tools/split_clipboard.py`
   writes `nutmeg-<pose>-clipboard.svg` = the body's own paths, unchanged and in order, clipped to the clipboard
   silhouette (clipboard paths; celebrate also the gripping paw). Drawn above the head, it reproduces the body's pixels
   there, so the clipboard and the paw over it sit in front of the chin. The body SVGs are NOT modified (so no
   `.before-r8` backups were needed). The layer shares the body's breathing, never the head bob. Sit skipped: its
   clipboard lies on the floor, far from the head. The old standalone `nutmeg-clipboard-front/back.svg` (703x900 canvas)
   were not usable as layers. Celebrate: the raised clipboard now shows in front of the ear/headset (it was hidden).
   Before/after: /tmp/pt-round8/clipboard-front-before-after.png.
5. **Writing body + zoom out:** the writing moment now uses pose `.coloring` = `nutmeg-body-writing` (transform scale
   0.69 at (625, 436), +14, +330), crayon then fingers in front (the crayon wiggles ±4° around the grip, ~0.26 s),
   head at the idle values (rotation 0). `PoseRules.base(coloring:)` → `.coloring`; the kit hold stays clipboardBoth.
   Writing shot zoomed out: screen bottom at canvas y 1120 (`writeBottom`), a medium close-up with the head,
   clipboard and writing paw. Scribble sound, focus face and timing unchanged.
6. **Star sparkle:** `PTTwinkle` modifier: one star at a time (slot every 2.6 s on the stage, 2.0 s on the start
   screen), 0.6 s ease-in-out to 1.12x + 9° + a little brightness. Static with Reduce Motion. Verified by frame hashes
   (/tmp/pt-round8/stars*, only one star region changes at a time).
7. **Toys:** gap 0.3 → 0.1 s, each arc unchanged; every later beat (jump, card, logo, button, end) moves up 1.0 s
   (opening ~5.75 s instead of 6.75 s).
8. **Hand-off card:** "Pass the iPad to the Captain!" + a big role-colored "I'm the Captain! →" button with a 3D depth
   edge that presses down; "Tap your badge!" removed. Nutmeg's line: "Pass the iPad to the Captain! Then tap I'm the
   Captain!" (AdventureStore). **Skipped:** confirming by voice ("I'm the Captain"): it needs a change in the realtime
   transcript handling, which was off limits this round.
9. **Play checklist:** no ScrollView; the paper is sized to the step count (≤4 steps: 56 pt pictures, 22 pt text; 5:
   46/20; 6+: 40/18, tighter padding; never below 17 pt). "Done!" is a full-width 64 pt button. Chat open: the checklist
   is pinned at the top of the chat panel (like the prop/kit cards; compact 17 pt rows, full-width Done) and Nutmeg
   stands centered on the stage (Claude's call: biggest readable option; the stage card left of the chat would have
   been ~140 pt wide). Checked on the 11" simulator only (not 13").
