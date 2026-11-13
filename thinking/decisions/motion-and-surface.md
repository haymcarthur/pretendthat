# Motion and surface: crisp, calm, event-driven

- **Date:** 2026-11-13
- **Decided by:** Haylee (after looking at the app)

**Decision:**
1. **Backgrounds:** no colored per-phase backgrounds. One clean white base everywhere (`Theme.paper`, a very light warm off-white, is the alternate). Brand colors go only on accents. Crisp, not soft.
2. **No glows:** the soft spotlight glow and floor ellipse are gone. No blurry glows or soft gradients anywhere (the illustration loading tile is a flat tint).
3. **Motion:** much less continuous motion, Duolingo-style. Nutmeg mostly rests (subtle breathing, a slow small tail sway), with a blink or an ear twitch at pseudo-random moments several seconds apart, and lively motion only on events (talking, listening, presenting, celebrating, a pose change). Stage props are static: they pop in once when they appear and do a single bounce on a celebration (kit ready, the end) via `\.ptCelebrate`. Keep the springy pose-swap "pop" (see [mascot](mascot-nutmeg.md)).
4. **Components:** Haylee will redesign 6 key components in Figma (bottom control bar, item card, role badge, kit page thumbnail + print button, checklist row, hand-off card). Until then they stay simple and neutral (white, crisp light borders) so they're easy to restyle.
5. **Stage prop art** is coming as vectors (reference `design/nutmeg/stage-props-v1.webp`). Placeholders ship under: `stage-curtain-left`, `stage-curtain-right`, `stage-valance`, `stage-lamp`, `stage-star`, `stage-sparkle`, `stage-ticket`, `stage-bulbs`, `stage-sandbag`, `stage-crown`, `stage-scroll` (`tools/make_placeholder_art_v2.py`).

**Supersedes:** the colored backdrops in [brand visual style](brand-visual-style-and-layout.md) and the ambient sway/pulse in spec §7b.

**Why:** The soft, always-moving look read as busy; crisp and calm reads as designed and keeps attention on Nutmeg and the kids.
