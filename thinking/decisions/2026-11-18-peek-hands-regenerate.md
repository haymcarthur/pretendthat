# Peek hands: regenerate as separate body and paws (2026-11-18)

**Decision:** None of the three paw-lift variants (hang / half / onEdge) work. Regenerate the peek art in ChatGPT as two pieces: (1) Nutmeg's body with no hands, arms reaching down and cut off at the bottom, which sits BEHIND the scene card; (2) two paws only, gripping an edge, which sit IN FRONT of the card. The card hides the wrists, so nothing has to line up exactly. Haylee vectorizes in Figma; Claude cleans up/exports and wires it in.

**Why:** the current paws layer carries the whole arms, so any lift slides the arms off the shoulders. Patching shapes is off-limits (regenerate, don't patch).

**Who decided:** Haylee (the split); Claude's call: the prompt wording, green #00C853 background for the paws, keep the rig head on top.

Prompts: design/nutmeg/peek/regen/prompts.md. Reference: design/nutmeg/peek/regen/reference-current-peek.png.

Build 4 waits on this art.
