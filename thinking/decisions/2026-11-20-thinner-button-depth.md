# Thinner 3D edge on buttons (2026-11-20)

**Decision (Haylee):** the chunky bottom edge (the "shadow") on our icon buttons makes them look tall, bulky and oval. Make it much thinner, like her reference: a slim darker lip of the same color under a round face.

**Claude's calls:**
- Today every button uses a fixed edge (`Theme.depth` = 6 pt on buttons, `Theme.cardDepth` = 5 pt on cards and rows, PretendThat/Theme/Theme.swift:112). That's fixed whatever the size, so it's thick on small buttons (6 pt on a 44 pt 🔊 = 14%).
- New rule: the edge scales with the button, about 4% of its height, between 2 and 4 pt (88 pt → 3.5 pt, 44 pt → 2 pt). Presses push the face down by the same amount. Applies to PTBigIconButton, PTNextSceneButton (and the new Previous scene), PTIconButton, the start / My games buttons, the 🔊 row buttons and the round checks. Cards keep a small edge (3 pt) or none (decide from screenshots).
- Goes in the scene build round with before/after screenshots for Haylee.
- **Update (Haylee):** do the same for the pill/labeled buttons too (Next/Previous scene, start, My games, every button with a depth edge), not just the round icon buttons.
