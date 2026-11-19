# Saved-game offer: only the picture (2026-11-18)

- **Date:** 2026-11-18
- **Who decided:** Haylee ("All I wanted is the picture. No buttons."). Claude's calls noted below.
- **Replaces:** item 2 of [device-testing fixes](2026-11-18-device-testing-fixes.md) (the white card with the green ▶, the title, the yellow sparkles and "New game").

## Decision
- When a kid asks for a game that matches a saved one, the screen shows **only the saved game's cover picture**, just above the control bar. It never covers the mic, Repeat or chat buttons.
- No white card, no ▶, no title, no "New game" button, no words.
- The picture looks like a picture: rounded corners and a soft shadow. It is 240 pt wide on the iPhone and 340 pt on the iPad (3:2). A game with no drawn cover shows its props on cream, the same as its spot on the bookshelf.
- Nutmeg still asks out loud: "We already have <title> saved! Do you want to play that one, or make a new game?" The kids answer by voice or typing. The answer is still read on the device (`SavedOrNew`, no AI call).
- The picture goes away once they answer.
- Unchanged: it is only offered with an active pass, and on the iPhone it hides while the chat shelf is open.

## Why
Haylee wanted the picture alone. The buttons and words made it look like a dialog, and the kids answer out loud anyway.

## Claude's calls
- **Tapping the picture still plays the saved game.** It is a quiet shortcut with nothing that looks like a button. VoiceOver still reads it as "Play <title>".
- **The unclear-answer line no longer mentions tapping or sparkles.** It is now "Do you want to play <title> again, or make a new game?" (`ShelfLines.soundsLikeAgain(title:)`). It names the saved game, so it is never kept with the new game.

## Verified
- `swift test`: 740 tests pass. One run had a single timing failure under load; the rerun passed.
- App builds. Demo-mode screenshots (no API keys, $0) on new throwaway simulators (iPhone 17e, iPhone 18 Pro, iPad Pro 11" M5), deleted afterwards: `/tmp/pt-soundslike-v2/`. There are two of each: `-props` is a saved game with no drawn cover, and `-cover` is a drawn cover (`PT_SEED_COVER`).
  - The iPad shots are landscape because the app is landscape-only on the iPad (Info.plist).
  - The shots use `-PTSkipAuth`, so the mic shows the gray "no permission" look. That is the screenshot setup, not this change.
  - On the iPad the picture sits over Nutmeg's chin, about where the old card sat.
