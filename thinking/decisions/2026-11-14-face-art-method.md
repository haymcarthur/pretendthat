# Face art method: eyes (and mouths) only, on green

**Date:** 2026-11-14 (method set on 2026-11-13, written down now)
**Who decided:** Haylee (method); Claude's call on the wording of each prompt

## Decision
New facial expressions for Nutmeg are never generated on her head or body. In ChatGPT we generate **only the eyes and eyebrows** (and a mouth, when one is needed) floating by themselves on a solid bright green background (#00C853), at a large size and in flat vector style.
- Attach the **current green eye sheet** so the style, lashes, iris size and gaze match the other 8 faces.
- Use these flat colors: white, iris #6B3A1E, lashes #2B140B, brows #8A4A28. There should be no skin, fur, nose or face.
- Haylee vectorizes it in Figma. Cleanup is then allowed: an agent removes the green and swaps the new eyes into the face frame **one eye at a time at the current eye positions**, keeping the existing mouth unless a new one was made, and keeping backups. Claude checks the close-up render before the art goes into the app.

## Why
- The white of the eye sits against the cream face patch, and Figma's Vectorize merges two light colors that are that close. On green, every shape comes out as its own clean piece.
- If the face is drawn on a head, it lands on a slightly different head than our master, so the features don't line up.
- Patching the vectors in Figma kept looking off (see memory: regenerate, don't patch).

## Open item
- **Focus (coloring) face redo, 2026-11-14.** Haylee doesn't like the current focus eyes, which are the brown lid caps from the 02:33 prompt. Regenerate the focus set using this method, with no separate brown lids. The swap waits until round 15's build agent is finished.
