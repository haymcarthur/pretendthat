# Site v5 + slides: roomier hero, Play bar on the real button, 3rd Why card, 6 safety points, arch on slide 1 only

**Date:** 2026-11-18 · **Who decided:** Haylee (what); Claude's call (exact sizes, which card, bullet wording).

- **Slides v3:** the stage arch is now only on slide 1 (built into its hero); slide 2 joins 3-6 on plain cream (`ARCH_ON` empty in gen.mjs). All sets rebuilt.
- **Hero:** top padding about +60% (desktop 64 → 102px at 1280; phones 36 → 56px) plus new bottom padding (64px desktop, 35px phones).
- **Saved games:** the floating "Play with Nutmeg" bar now sits centered on the real button of the screen: on desktop it is a new
  crop-only iPad piece (`assets/pieces/play-bar-ipad-*`, raw-v3 ipad 07, same crop as slide 6), about 1.4x the real button; on phones
  the iPhone piece, about 1.4x, overhanging both device edges like slide 6. It no longer sits off to the right or covers the cover.
  On the iPad the bar can't reach the device edges without covering the Pet Hotel cover, so it floats inside the screen there.
- **Why parents love it:** back to 3 cards: added "Every game is new / A fresh story and kit each time." Claude's call: the removed
  card "Uses what you have" is already said in the Props section ("No toys to buy"), and "no reading" is in the Pick section.
- **Safety card:** 3 → 6 bullets: No accounts or sign-in · No names, just roles · Voices stay on the device · No ads or ad tracking ·
  Safety checks on words and pictures · Grown-ups OK the AI and purchases (all from the privacy page and the grown-up gate decision).
  Card columns centered on desktop.
- Site commit d313f8c (not pushed). Previews: design/site-restyle-preview/v5/.

- **Published (Haylee, 2026-11-18):** site restyle commits 85829fe..d313f8c pushed; live site.css?v=7f51f052. Pending: mirrored hero art, mic retakes for slides.
