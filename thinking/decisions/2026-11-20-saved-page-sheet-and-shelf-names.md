# Saved game page: only the sheet slides up, ✕ on the sheet; shelf names don't overlap

**Date:** 2026-11-20 · **Who decided:** Haylee; how: Claude's calls

- **Saved game page:** the white sheet (with Nutmeg peeking over it) slides up from the bottom on its own; the stage behind it fades in instead of the whole screen sliding up (`SavedGamePageView.sheetIn`; RootView's transition is now `.opacity`). Closing slides the sheet back down, then the page fades out.
- **Close button:** an ✕ in the sheet's top-right corner (the chat panel's `PTIconButton` xmark), replacing the ← arrow in the screen corner.
- **Bookshelf names:** a name label was wider than its card plus the gap between cards on iPhone (w + 1.5 gaps), so neighbours overlapped; now w + 0.6 gaps (iPhone) and w + 0.3 gaps (iPad), with a clear space between names.
- **Checked:** iPhone and iPad simulators (demo): the shelf, the saved page, and closing (burst shots: the sheet slides down, the stage stays, then the shelf).
