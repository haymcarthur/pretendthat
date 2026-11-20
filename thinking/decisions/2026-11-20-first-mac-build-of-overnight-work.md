# First Mac build of the overnight rounds (MacBook Air, Xcode 26.6)

**Date:** 2026-11-20 · **Who decided:** Claude's calls (compiler fixes only, no behavior change); Haylee asked for the build and demo checks

## Compiler fixes
- `NutmegCore/KidSafety.swift`: `Kit.safetyTexts` built in steps (Xcode 26 type-check timeout).
- `App/RootView.swift`: `body` split into `stageLayers` + four parts of the modifier chain (`stageAnimated`, `stageObserved`, `stageObservedMore`, `stageKitObserved`, then `body`), same modifiers in the same order; the pre-connect task id is a named property (`preconnectKey`). Nothing else in the app needed a change.
- Debug and Release both build (iOS 26.5 simulator). NutmegCore: 823 tests pass (about 15 min on this Mac).

## Demo checks (no keys, throwaway simulators, $0)
Shots in design/sim-checks-2026-11-20/ (local, git-ignored).
- iPad area setup cards at 2, 3, 4, 6 kids: role small, area job big, picture chips, ▶ Let's play! green. **Bug: at 3 kids the centered bottom card is clipped** (its last row is cut and the card loses its bottom edge above ▶ Let's play!). 2, 4 and 6 fit.
- `oneIdea`: small translucent card low right with thumbnail, line and 🔊.
- `onePlaying -PTFastScene` (2 kids): event card with 🔊 → tense card (coral, alarmed face, "uh-oh" music pill) → calm-again (phew) → finale (celebrate, End scene hidden) → clean-up opens by itself.
- `oneCleanup`: "Tidy up the cockpit" cards, one put-away per prop, the paper-scraps row, ▶ The End.
- iPhone: 3-kid setup in the shelf, tense card.
- **Saved-offer screenshots retaken (the old next small task):** iPhone and iPad, chat closed and open: Moon Crumbs Bakery's real cover in the offer and in the chat. Note: `-PTDemo soundsLike` only seeds Moon Crumbs when the device has fewer than 3 saved games; on a simulator that already ran other demos it offers the airplane game instead (reinstall the app first).

## Not checked
Sound (music hand-overs, ducking, hear-again audio), pause/resume, relaunch resume, lock/unlock, and the one live game.
