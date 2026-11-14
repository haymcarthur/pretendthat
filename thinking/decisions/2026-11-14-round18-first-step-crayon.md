# Round 18: checklist names the first step; crayon stops rocking

**Date:** 2026-11-14 (code-freeze morning). **Who decided:** Haylee reported both bugs; the fixes are Claude's call within her brief.

## 1. The checklist intro names step 1
- **Bug:** when a scene's checklist appeared, Nutmeg said the scene line + "Tap each step when you do it, then tap Done!" but never said what step 1 was (ChecklistCheers only names step 2 onward).
- **Decision:** `HandOffLines.checklist(sceneLine:firstScene:firstStep:)` puts "First, <step 1>!" between the scene line and the how-to, e.g. "… First, hang up the theater sign! Tap each step when you do it, then tap Done!". Skipped if the scene line already names the step (letters-only match), still one spoken reply through `sayInPlay`, so it shows in the chat as well. Tests: `Round18FirstStepTests` (202 tests pass).

## 2. "A piece of the crayon stays stuck to her hand"
- **What we found:** no stray red crayon in `nutmeg-body-writing.svg` or `nutmeg-writing-fingers.svg` (the body's only red path is a tiny shoulder sliver, not near the paw). The crayon layer is already the only crayon. The round 10 rock (~2.5° around the tip) swung the top end while the short visible middle near the tip (between paw and board) barely moved, so with the paw still it read as a stuck piece.
- **Decision:** the safe fallback in Haylee's brief. The crayon no longer rocks relative to the paw. It moves with the body (breathing, transform) only. No art files changed, so there's no `.before-r18` backup.
- **Later (idea):** a real scribble would need the fingers and crayon to move together as one unit.

## Doubled valance (Haylee, 07:33)
Round 15 added a curtain copy above the floor, and that copy also redrew the valance slightly out of line, so the top looked doubled. The copy now skips the valance (`PTCurtain(showsValance: false)`). Commit after e294f29/dab790e, pushed at 07:34.
