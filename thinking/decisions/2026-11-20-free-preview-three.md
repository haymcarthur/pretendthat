# Free Preview: 3 free games to try (was 2)

**Date:** 2026-11-20 · **Who decided:** Haylee (3; Claude suggested 3 or "2 + free replays of them" instead of 5)

- **Decision:** the Free Preview is **3 new games to try, once** (never per month, no card). Still "N free games to try" wording everywhere, never "a month". Show Pass 5 / Season Pass 20 and the prices are unchanged.
- **Why:** replaying a saved game now needs a pass (2026-11-17), so 2 free plays was too little for a family to fall for it. 5 was considered and turned down: ~$4.50 of AI per family that never pays (a game is ~$0.90) vs ~$2.70 at 3, and 5 free would equal a month of Show Pass.
- **Changed:** `PlanCatalog.freePreviewShows = 3` (the app's copy reads it: "3 free games to try", "Try 3 free games", "2 of 3 free games to try left"); the two hard-coded lines (`plansBody`, `outOfShowsBody`); the relay's `FREE_PREVIEW_SHOWS = 3` (+ its test); docs/app-store-listing.md; the site's home, pricing and terms pages (pretendthat-site).
- **Not done yet:** the relay redeploy (`cd relay && npx wrangler deploy`; until then the relay still stops the Free Preview at 2 when limits are enforced); pushing the site; the App Store Connect listing and review notes text; any App Store screenshot that shows "2 free games".
- **Supersedes:** the "Free Preview: 2" line of 2026-11-17-plans-5-and-20.md.
