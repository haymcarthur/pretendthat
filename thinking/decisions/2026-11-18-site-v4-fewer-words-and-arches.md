# Site v4: hero art on the left, no hero logo, fewer arches, half the words

**Date:** 2026-11-18 · **Who decided:** Haylee (what); Claude's call (exact copy cuts and spacing).

- **Hero:** PretendThat logo removed from the hero (the header keeps it). Art on the left, text on the right on desktop;
  on phones the copy comes first, then the art. The mirrored image 49 was not found: the newest
  `~/Downloads/image 49 [Vectorized].svg` (Nov 18 11:03) is byte-identical to the art already in use, so nothing was swapped.
  When Haylee exports the mirrored version, copy it over `assets/art/hero-nutmeg-wave.svg` (site, then `scripts/version_assets.py`)
  and `slides-v3/src/img/hero-nutmeg-wave.svg` (then `build.sh`); slide 1's position may need a nudge.
- **Arches:** site: no arch on the white Props and Play sections or the "Ready to play" card (cream sections and the hero keep it).
  Slides v3: arch only on slides 1 and 2; 3 to 6 sit on plain cream (`ARCH_ON` in gen.mjs).
- **Words:** home page main text 1152 → 540 words: one short sentence + 2–3 short bullets per section, "Why parents love it"
  down to 2 cards, 3 safety bullets, FAQ answers 1–2 sentences, plan cards trimmed, home plans note dropped.
  Pricing and support trimmed the same way; privacy and terms policy text unchanged (privacy intro tightened by one phrase).
- **Why:** Haylee: the logo cramped the hero, arches were overused, and the site was too word-heavy to scan.
- Site commit 9c86f7e (not pushed). Previews: design/site-restyle-preview/v4/.
