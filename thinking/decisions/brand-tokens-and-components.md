# Brand tokens and component look

- **Date:** 2026-11-13
- **Decided by:** Claude's call, implementing [Brand: visual style, palette and layout](brand-visual-style-and-layout.md) (Haylee)

**Decision:**
- **Palette** (hex in `NutmegCore/BrandPalette.swift`, Colors in `Theme`): coral FF6B5B (curtains, decoration), deep purple 5B2A86 (backstage / play mode), sunny yellow FFC93C (spotlight, kit ready), lime 8BD346 (success), nutmeg brown A0623A, cream FFE9CF, ink 2A1846 (dark purple-navy). Each has a darker "shade" for the 3D edge.
- **Contrast:** every text pairing is unit-tested against WCAG (`BrandPaletteTests`). White on the brand coral is only 2.8:1, so the primary button face is a slightly deeper coral EE5242 (white label 3.55:1, passing AA large text; button labels are 22 to 28 pt black). Ink passes AA on white, cream, yellow, lime and coral; white and cream pass on purple.
- **Type:** SF Rounded: black for display, heavy for headlines, bold for body.
- **Components:** Duolingo / "Как белка" look: solid faces on a solid bottom edge (6 pt on buttons, 5 pt on cards); a press pushes the face down onto the edge. Soft light borders, no dark outlines, no blur shadows. One solid backdrop per phase (`PTBackdrop`): purple for Hello and play (scene, step back), yellow for kit ready and the end, cream for hand-off, white for setup.
- **Stage accents:** `PTStageAccents` (spotlight glow pulse, floor ellipse, ticket stub, star, sparkle) sits behind Nutmeg; `PTCurtainCorner` sways in the top-left corner. Nutmeg's column grows (30% to 40%) when the screen is sparse. All ambient motion stops with Reduce Motion.
- **Motion:** springy phase transitions, a squash bounce on picks, a burst on check-off, confetti when the kit is ready, a tilted slide-in hand-off card, and soft haptics (no-ops on iPads without a haptic engine).

**Why:** Matches Haylee's references while keeping text readable for kids and grown-ups.
