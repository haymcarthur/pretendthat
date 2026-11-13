# D6: Loading = Nutmeg coloring; reveal = clipboard flip

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** While the kit (and later a checklist) is generated, Nutmeg is shown coloring on her clipboard. When it's ready, the clipboard flips around to reveal the result. For checklists: just the clipboard, with Nutmeg's head peeking from the side. Haylee supplies the art; the build uses placeholders under these names: `nutmeg-body-coloring` (pose), `nutmeg-clipboard-back`, `nutmeg-clipboard-front`, `nutmeg-peek` (head peeking from the side).

**Why:** A wait becomes part of the story, in character with a stage manager.

## Revised 2026-11-13 (Haylee): papers fly off the clipboard

The clipboard-flip reveal is **replaced**. Nutmeg keeps her clipboard (coloring pose while generating). When it's ready, white sheets of paper fly off her clipboard: each lifts from the clipboard, arcs out with a slight spin and settles next to her, facing the user (crisp white, rounded corners, the panel shadow). `PTPaperReveal`.
- **Checklist:** one paper becomes the checklist panel beside her.
- **Kit:** one paper per page, launched ~150 ms apart, settling in a neat fanned row; the black Print pill appears once all have landed; tapping a paper enlarges it for a preview.
- After the papers land, Nutmeg does a brief celebrate gesture, then back to idle.
- `nutmeg-clipboard-front/-back` are kept but unused; `nutmeg-peek` is gone. Reduce Motion: fade in place.
