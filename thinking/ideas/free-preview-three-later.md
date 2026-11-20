# Later: Free Preview of 3 free games (instead of 2)

- **2026-11-20:** Haylee chose 3 (Claude: 3, or 2 + free replays of the preview games; 5 turned down: ~$4.50 of AI per family that never pays and equal to a month of Show Pass). Built, then rolled back the same day: the App Store side was more than she wanted to do right now.
- **Why it's worth it:** replaying a saved game needs a pass now, so 2 free plays is little time to fall for the app. ~$0.90 a game → 3 free ≈ $2.70 per family that never pays.
- **To do it:** revert commit a30b25e in the app repo (it puts back `PlanCatalog.freePreviewShows = 3`, the two hard-coded lines, the relay's `FREE_PREVIEW_SHOWS = 3` and tests, docs/app-store-listing.md) and e70987e in pretendthat-site (home, pricing, terms). Then: redeploy the relay, push the site, change the App Store Connect listing + review notes, and retake any App Store screenshot that says "2 free games".
