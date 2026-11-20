# Prop art: openings show through (no filled-in gaps)

**Date:** 2026-11-20 · **Who decided:** Haylee (fixed the art in Figma); the check was Claude's

- **The flaw:** the vectorizer painted some openings (the bag's handles) in the background color instead of leaving them empty. A check of every prop and stage/action image on a blue background (see-through areas show blue) found: action-stir (pot handles, white), stage-lamp (bracket, white), and maybes: prop-cup (solid handle), prop-chair (slat gaps), prop-tray, prop-toy-keys.
- **Imported 2026-11-20** (Haylee's Figma fixes from ~/Downloads, checked before/after on blue, nothing else changed): prop-tray, stage-lamp, action-stir, prop-jump-rope, prop-hula-hoop, prop-wagon, prop-toy-keys.
- **Not imported:** prop-bag. Haylee's fixed file lost the front straps and the bottom band (only the dark purple back-strap paths are left). Repair it or regenerate it (prompt 3).
- **Next:** the cup and the chair are regenerated in ChatGPT with a transparent background: prompts and reference images in design/props-regen/ (a green-background fallback if transparency doesn't come through).
