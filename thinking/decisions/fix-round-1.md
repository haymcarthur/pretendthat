# Fix round 1 (Haylee's demo feedback)

- **Date:** 2026-11-13
- **Decided by:** Haylee (feedback); placement details Claude's call

1. **Nutmeg size and centering:** default conversation shot shows her whole body at ~70% of the screen height. Her
   visual center (mass center of head + body, canvas x 578; the tail skews the bounding box) sits at the center of the
   area left of the chat panel, which is also the control pill's axis. The rail floats over the left; cards keep clear
   of it. Claude's call: "stage area" = the screen (minus an open chat panel), so she lines up with the pill.
2. **Camera:** close-up (talking/listening) frames her head (canvas center 566, 410) at ~80% of the screen height,
   centered both ways; wide (presenting) zooms out so two card columns fit beside her. Nutmeg is re-laid out at each
   size (not scaleEffect) so the vector art stays crisp. `PTStageCamera` in PTConversation.swift.
3. **Stage props:** ticket stub removed. Three static stars (stage-star, 2 × stage-sparkle) placed in art-canvas
   coordinates clear of her head; a star hides when it would touch a card, the rail or the pill.
4. **Kit thumbnails:** `PTPageGrid`, a 1–3-row grid of whole pages, sized to fit beside Nutmeg (no fan, no overlap).
5. **Page preview:** `PTPagePreview` via fullScreenCover (clear background): whole page at letter aspect on a dim
   backdrop; close with the round X, a backdrop tap or a swipe down; swipe or chevrons to page.
6. **Page fill:** small items tile their whole page; per-player items cycle the players as spares (8 tickets,
   6 badges, 8 bills). Badges are 3×2 portrait cells. AI art is aspect-fitted, never cropped.
7. **Also:** play money has no name field (app and image prompt); item cards wrap/shrink titles instead of
   truncating and sit in non-overlapping columns; a sticker that fails or takes longer than 30 s settles on a bundled
   stage illustration (no endless placeholder); the oops face uses `nutmeg-ears-flop`.
