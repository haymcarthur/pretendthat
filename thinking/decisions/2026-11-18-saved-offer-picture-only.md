# Saved-game offer: only the picture (2026-11-18)

- **Date:** 2026-11-18
- **Who decided:** Haylee ("All I wanted is the picture. No buttons."; round 2: put it beside Nutmeg on the iPad, and show the whole cover). Claude's calls noted below.
- **Replaces:** item 2 of [device-testing fixes](2026-11-18-device-testing-fixes.md) (the white card with the green ▶, the title, the yellow sparkles and "New game").

## Decision
- When a kid asks for a game that matches a saved one, the screen shows **only the saved game's cover picture**.
- No white card, no ▶, no title, no "New game" button, no words.
- **The whole cover shows, never cropped** (round 2). The picture uses the cover's own shape (aspect-fit). A game with no drawn cover shows its props on cream (3:2), also uncropped. Rounded corners and a soft shadow.
- **Where it sits:**
  - **iPhone:** just above the control bar, never over the mic, Repeat or chat buttons. It fits in 240 × 240 pt. It hides while the chat shelf is open.
  - **iPad (round 2):** beside Nutmeg, in the empty stage to her right: below her right ear, around her face height, left of the curtain. Never over her face or the control bar. It fits in that space (about 210 × 300 pt on an 11" iPad). While the iPad's chat panel is open, the stage has no room beside her, so the picture goes back above the control bar (220 × 200 pt).
- Nutmeg still asks out loud: "We already have <title> saved! Do you want to play that one, or make a new game?" The kids answer by voice or typing. The answer is still read on the device (`SavedOrNew`, no AI call).
- The picture goes away once they answer.
- Unchanged: it is only offered with an active pass.

## Why
Haylee wanted the picture alone. The buttons and words made it look like a dialog, and the kids answer out loud anyway. On the iPad the first version sat over Nutmeg's chin, and the 3:2 crop cut off the top and bottom of the sign covers (they are tall).

## Claude's calls
- **Tapping the picture still plays the saved game.** It is a quiet shortcut with nothing that looks like a button. VoiceOver still reads it as "Play <title>".
- **The unclear-answer line no longer mentions tapping or sparkles.** It is now "Do you want to play <title> again, or make a new game?" (`ShelfLines.soundsLikeAgain(title:)`). It names the saved game, so it is never kept with the new game.
- **iPad with the chat panel open:** the picture goes back above the control bar, because the narrowed stage has no free space beside her.

## Verified (round 2)
- `swift test`: all 740 tests pass. App builds (main merged in first).
- Demo-mode screenshots (no API keys, $0) on new throwaway simulators (iPhone 17e, iPhone 18 Pro, iPad Pro 11" M5), deleted afterwards: `/tmp/pt-soundslike-v3/`.
  - There are two of each: `-cover` is a drawn cover (a tall sign, `PT_SEED_COVER`), and `-props` is a game with no drawn cover.
  - The iPad shots are landscape because the app is landscape-only on the iPad. The simulator saved them sideways, so they were turned upright afterwards.
  - The shots use `-PTSkipAuth`, so the mic shows the gray "no permission" look. That is the screenshot setup, not this change.
- Round 1 shots (3:2 crop, iPad over her chin): `/tmp/pt-soundslike-v2/`.
