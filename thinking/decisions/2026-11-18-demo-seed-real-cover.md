# Demo seeds a real cover (saved-game offer shows the same art as the shelf)

**Date:** 2026-11-18
**Who decided:** Haylee asked (the offer looked like it used the wrong art); how: Claude's call.

**Decision:** In DEBUG demo mode, seeded saved games (`DemoDriver.seedGames`) give "Moon Crumbs Bakery" its real
generated cover (design/demo/cover-moon-crumbs-bakery.jpg, 600 x 400, the same kind `CoverArtService` saves) when env
`PT_SEED_COVER` is not set. `-PTDemo soundsLike` offers that game, so the offer card shows the same picture as its
book on the shelf (`-PTDemo shelf`). `PT_SEED_COVER` still overrides (that JPEG on every other game).

**Why:** without a cover.jpg the picture fell back to the sign page, so the demo offer didn't look like a real game's.
The cover is read from the repo by path (simulator only), never bundled, so no test art ships in release.
