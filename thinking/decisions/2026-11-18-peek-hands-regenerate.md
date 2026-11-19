# Peek hands: regenerate as separate body and paws (2026-11-18)

**Decision:** None of the three paw-lift variants (hang / half / onEdge) work. Regenerate the peek art in ChatGPT as two pieces: (1) Nutmeg's body with no hands, arms reaching down and cut off at the bottom, which sits BEHIND the scene card; (2) two paws only, gripping an edge, which sit IN FRONT of the card. The card hides the wrists, so nothing has to line up exactly. Haylee vectorizes in Figma; Claude cleans up/exports and wires it in.

**Why:** the current paws layer carries the whole arms, so any lift slides the arms off the shoulders. Patching shapes is off-limits (regenerate, don't patch).

**Who decided:** Haylee (the split); Claude's call: the prompt wording, green #00C853 background for the paws, keep the rig head on top.

Prompts: design/nutmeg/peek/regen/prompts.md. Reference: design/nutmeg/peek/regen/reference-current-peek.png.

Build 4 waits on this art.

## Follow-up (2026-11-18): the new art is in the app
- **Art:** `design/nutmeg/peek/regen/peek-body-v2.svg` (headless body, forearms cut flat at y 762, tail) and `peek-paws-v2.svg` (two paws), exported by Haylee on one 1774×887 canvas. Neither has a background shape (no green left). `tools/peek_v2_imagesets.py` copies them VERBATIM into `nutmeg-peek-back` / `nutmeg-peek-paws` and refuses an export that still has a `<rect>` or #00C853. `tools/split_peek_parts.py` (v1) is marked superseded. No shape edits.
- **Layers (unchanged order):** body + tail BEHIND the card; paws IN FRONT of its top edge; the rig head (head-base, focus/talking eyes, mouth, headset, blink, look-up) on the neck, drawn last.
- **PeekHands removed** (hang / half / onEdge and `-PTPeekHands`): no lift, one placement. The rows clear the paws' whole overhang.
- **Fitted to the v1 peek by measured landmarks (Haylee, after three rounds of by-eye sizes missed).** The layout space is the v1 peek art (1536×1024), whose proportions Haylee approved. The rig-head fit (0.6, −5°, nose at (795, 314)), the card edge (y 514) and the figure box (x 433…995 from y 24) are all the v1 ones. Named constants in `NutmegPeek`:
  - **`bodyScale` = 381 / 1061 = 0.359.** v1's shoulder width (outer edges of the upper arms, x 576…957) over v2's (x 448…1509), both measured from rendered SVGs.
  - **`bodyOffset` = (419.3, 269.1).** v2's V-neck tip (978, 632) lands on v1's (770.5, 496). The forearm and tail cuts (v2 y 762) land at v1 y 543, under the card edge.
  - **`pawScaleDefault` = 95 / 495 = 0.192.** A v1 paw is ~95 px wide (left 615…709, right 858…951) and a v2 paw is 495. Each paw is drawn on its own: the paws export is clipped to its half (the paws don't touch: gap x 777…996), scaled, and its y 460 point (where it bends over the edge) placed at the centre of its forearm on the card edge. That's v2 x 603 / 1358, which is v1 (635.8, 514) / (907.0, 514). Transform and clip only. DEBUG `-PTPeekPawScale <n>` overrides it.
- **Mismatches reported, not fudged:**
  - **Tail:** with the shoulders and neck matched, v2's tail curls up BEHIND the left ear and headset. v1's curls out to the left below the ear. The tail is part of the body export, so it can't move on its own without splitting it into its own layer.
  - **Paws vs forearms:** v2's forearms are ~106–110 v1 px wide where they meet the card edge (v2 296–306 px at y 682). A v1-width paw (95) is ~12–16% narrower, so the forearm's edges show beside each paw. A paw ~10% wider than the forearm would be scale 0.24 (close-up provided).
- **Check images:** `/tmp/pt-peek-v2/onion-v2-over-v1.png` (v2 at 50% over v1), `v1-composite.png`, `v2-composite-v1-space.png`, `v2-composite-v1-space-paws-forearm-plus10.png`.
- **Fit in the app:** iPhone 18 Pro and iPhone 17e, 4 and 6 rows, all fit with no scrolling. The overhang is 42 v1 px (v1: 32).
- **For Haylee to look at:**
  - The vest's V-neck is WHITE in the new art (the old one was cream). The rig chin covers most of it, but a small white triangle shows under her chin. Not recoloured (regenerate, don't patch).
  - The new body/paws fur (#B55E31) is a hair redder than the rig head's fur. You can only see it up close.
- **Screenshots:** `/tmp/pt-peek-v2/` (`iphone18pro-*`, `iphone17e-*`, `zoom-*` close-ups of the paws). Demo mode, no keys, $0.

## Follow-up 2 (2026-11-18): Haylee's body v3 replaces v2
- **Art:** `design/nutmeg/peek/regen/peek-body-v3.svg` (514×173, 15 flat paths), Haylee's own composition. The tail curls out to the left, the V-neck is cream, and it includes both paws. **v2 is dropped** (body and paws). `tools/peek_v2_imagesets.py` is removed.
- **What I found about the paws:** they are their OWN paths, not fused with the forearms. Each paw is one shape (#AF6131), plus its dark top arc and two finger lines (#843912). Under the left paw, the vest path traces the paw's bottom (a purple blob); it is hidden behind the paw. Behind the right paw there is no forearm fill, but the paw covers that spot.
- **Split:** `tools/peek_v3_imagesets.py` is a path split only. Every path is copied verbatim, in its original order.
  - `nutmeg-peek-paws` (IN FRONT of the card): paths 5–8 and 10–13 (each paw, its arc, its fingers).
  - `nutmeg-peek-back` (BEHIND the card): the other 7 (vest, neck shading, cream V, both shoulders, star, tail).
  - The script checks every path's fill, so a re-export in a different order fails instead of splitting wrong. The paws touch nothing they used to sit under (the star and tail come after them in the file, but don't overlap them), so the look is unchanged.
- **Fit by landmarks (same method):** v3 is drawn at v1's scale.
  - Shoulders and paws, outer edges: v3 x 129…512 = 383, v1 x 574…957 = 383. So **`bodyScale` = 1.0**.
  - V-neck tip: v3 (327.1, 125.05) → v1 (771.9, 498.4). So **`bodyOffset` = (444.8, 373.35)**. The tail then starts at v1's tail corner (444, 373).
  - Both layers use the same transform, so the paws keep her proportions. There's no separate paw scale any more (`pawScale` and `-PTPeekPawScale` are gone).
  - The v1 head fit, card edge (y 514) and figure box (x 433…995, y 24…546) are unchanged. The paws overhang the card by 32 v1 px, the same as v1.
- **Onion skin:** v3 at 50% over v1 is a near-exact overlap (`/tmp/pt-peek-v3/onion-v3-over-v1.png`).
- **Screenshots:** `/tmp/pt-peek-v3/` (iPhone 18 Pro and 17e, 4 and 6 rows, looking down and up, `zoom-*` close-ups of the paws). Demo mode, no keys, $0.
- The Follow-up above (v2: landmarks, tail behind the ear, paws narrower than the forearms) is history now.

## Follow-up 3 (2026-11-18): body v4 (better hands)
- **Art:** `design/nutmeg/peek/regen/peek-body-v4.svg` (514×173, 15 paths; Haylee: v3's paws had "a little blurb"). Compared with v3, only the two paw shapes were redrawn. The other 13 paths (vest, neck shading, cream V, shoulders, arcs, finger lines, star, tail) are byte-identical, just in a new order. The right paw now ends at x 504 (v3: 512), so the little nub on its right is gone.
- **Split script:** `tools/peek_v3_imagesets.py` now finds the paws by GEOMETRY, not position.
  - Paw shape: a #AF6131 path reaching the canvas bottom that isn't the tail.
  - Paw marks: the #843912 paths centred over a paw (its arc and two finger lines).
  - It checks for 2 paws with 3 marks each, and refuses a split that would change what's on top of what.
  - v4: paws = paths 5, 7, 10–15; back = 1–4, 6, 8, 9. Stacking order is verbatim.
  - Run on v3, it rebuilds byte-identical image sets to the v3 commit.
- **Fit unchanged:** the shoulders (x 129…469), vest and V-neck tip are the same paths. So `bodyScale` stays 1.0 and `bodyOffset` stays (444.8, 373.35). The onion skin over v1 still overlaps (`/tmp/pt-peek-v4/onion-v4-over-v1.png`).
- **In the art, for Haylee (reported, not fixed):**
  1. **The right paw has no dark top rim.** Its arc (path 5) is unchanged, but the redrawn right paw is taller and covers it completely. The left paw's arc still shows, so the paws don't match. See `/tmp/pt-peek-v4/zoom-iphone18pro-paws-3x.png` and `art-crop-right-paw-8x.png`.
  2. **Finger-line ends poke out of the bottom outline** between the knuckle bumps: tiny dark nicks on both paws. Visible at 8× (`art-crop-*-paw-8x.png`), not at phone size.
  3. **The left paw's outer side** is a short straight edge that makes a tiny step where it meets the card (3× crop). Very small.
  4. **Purple vest slivers** under the bottom-left of each paw are below the card edge, so they're hidden in the app.
- **Screenshots:** `/tmp/pt-peek-v4/` (iPhone 18 Pro and 17e, 4 and 6 rows, looking down and up, all fit with no scrolling, plus `zoom-*`). Demo mode, no keys, $0. 740 tests pass.
