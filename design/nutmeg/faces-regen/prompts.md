# New Nutmeg faces for the one-scene play (2026-11-21, v2)

**How the face art works:** each face in the app is only the EYES (with lashes/brows) plus a MOUTH, layered on the shared head (`nutmeg-head-base` + headset) on a 1178 × 1335 canvas. `tools/import_art.py` splits a `nutmeg-face-<name>.svg` into eyes and mouth by fill color.

**Workflow:** attach `reference-ooh.png` (her current head with the "ooh" face, rendered from the app's own SVGs) and ask ChatGPT to change ONLY the eyes, brows and mouth. In Figma, vectorize it, place it over the 1178 × 1335 face frame (line it up with `reference-blank-head.png`), keep only the eyes/brows and mouth layers, and export as `nutmeg-face-alarmed.svg` / `nutmeg-face-phew.svg`. The app uses them as soon as the assets exist.

(v1 attached the old face sheet and asked for "her face", which is why ChatGPT drew a whole new head in a different style.)

## 1. Alarmed ("uh-oh!"): for tense events (attach reference-ooh.png)
Redraw this exact image, keeping EVERYTHING identical (same head shape, ears, hair curl, headset, fur colors, muzzle, nose, whiskers, flat vector style with no outlines, same size and position on the same white canvas) and change ONLY her eyes, eyebrows and mouth to an alarmed-but-playful "uh-oh!" expression: eyes wide open with smaller pupils (keep the same eye style and lashes, no sparkles), small eyebrows raised and tilted up in the middle (worried), mouth a small open "oh no" oval with a slightly wavy top lip. Kid-friendly, not scary. Nothing else changes.

## 2. Phew (relieved): for the calm-again lines (attach reference-ooh.png)
Redraw this exact image, keeping EVERYTHING identical (same head, ears, hair curl, headset, colors, muzzle, nose, whiskers, flat vector style with no outlines, same size and position on the same white canvas) and change ONLY her eyes, eyebrows and mouth to a relieved "phew, that was close" expression: eyes gently closed as soft happy curves with her lashes, eyebrows relaxed, a soft relieved smile with slightly puffed cheeks, as if letting out a breath. Optional: one tiny light-blue sweat drop near the top of her head. Nothing else changes.
