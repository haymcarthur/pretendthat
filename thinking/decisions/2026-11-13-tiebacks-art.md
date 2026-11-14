# Curtain tie-back art (rope + tassel)

**Date:** 2026-11-13
**Who decided:** Haylee (made the art; read-only export rule). Export, split, crop and suggested placement: Claude's call.

## Decision
Replace the code-drawn yellow capsule tie-back in `PTCurtain` (PTStartScreen.swift) with Haylee's ChatGPT-generated, Figma-vectorized rope-and-tassel art.

- Source: Figma file 8e4btNgdUzrGeaA6TYH8Zq, Page 1, frame **34:57 "image 38 [Vectorized]"** (1920x819, left and right tie-backs side by side). Exported as SVG, read only, nothing edited in Figma.
- Files: `design/export/stage/tieback-left.svg` and `tieback-right.svg`, each **709 x 627** (viewBox `0 0 709 627`), cropped to the art's render bounds.
- Cleanup: the vectorizer's full-frame background path (already white, not green) and the frame clip were removed. No green anywhere. No recolor, no reshape; left = the image's left group (16 paths), right = its right group (14 paths). They are near mirrors, both drawn by Haylee, so no transform mirror was needed.

## Colors
Rope/tassel fill `#FEC325`, outline/shadow `#DF9002`. Close to the brand gold used by the curtain/valance SVGs and the old pill (`yellow #FFC93C`, `yellowShade #E0A100`): the fill is a hair more orange, the outline noticeably deeper/more orange than `#E0A100`. Neither hex appears in any other exported stage or start-screen SVG. Reads as the same gold next to the coral `#FF6B5B` / fold `#DC4D42` curtain; left as-is (no recolor).

## Suggested placement (for the build agent)
Replaces the Capsule at `.position(x: geo.tieX, y: geo.tieY)` (currently `visible*0.5` x `height*0.045`, rotated -12°).
- Size: width ≈ **1.1 x `m.visible`** (166pt on a 1194x834 iPad; height = width x 627/709). 0.9x to 1.2x all look fine.
- Anchor: the knot center sits at art point **(604, 169)** on the left art (≈ unit point x 0.852, y 0.270), and **(105, 169)** on the right art (x 0.148, y 0.270). Put that point on (tieX, tieY). No rotation needed.
- Effect: the rope runs off the screen edge behind/over the curtain, so you see the knot pinching the drape and the tassel hanging. Keep the scale grow-in.
- Since the right half is drawn as a mirrored copy of the left half, either use `tieback-left` inside the mirrored half (it flips to match) or draw `tieback-right` outside the mirror.

## Check
Render: /private/tmp/claude-502/-Users-haymcarthur-Library-Application-Support-Claude-scratch-workspaces-7428a2c3-dbb9-49cc-9b4e-27f9b9d74bf7-9954e1dd-ee6f-4356-a9e5-e3c06f788ee0-scratch-2026-11-13-da39be/7c409d49-b5ad-41d9-b89a-dd106d2c1a7b/scratchpad/tieback-check.png (full stage + 2x insets comparing the old pill, 0.9x and 1.2x). Clean edges, no green, no white box.

## Notes
- The left art has two small extra knot pieces the right one doesn't (16 vs 14 paths); not visible at app size.
- Most of the rope is off-screen at the current open geometry (tie point is 30pt from the edge). If Haylee wants more rope visible, the swag would need to be wider; not an art problem.
