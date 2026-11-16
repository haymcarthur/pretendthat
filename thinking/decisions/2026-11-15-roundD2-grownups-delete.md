# Round D2: the Grown-ups corner (parental gate + delete saved games)

**Date:** 2026-11-15 · **Decided by:** Haylee (delete lives in Grown-ups, not on the shelf; the gate style: hold 2 s,
then tap the spelled-out number). Details are Claude's calls, noted. Design: [saved games + replay design §D6, §10.3,
§11](../../docs/superpowers/specs/2026-11-15-saved-games-replay-design.md);
[delete in Grown-ups](2026-11-15-saved-games-delete-in-grownups.md).

## Haylee's decisions (built)
- **Entry:** a small, quiet **Grown-ups** pill (lock + label, translucent white, purple text) in the start screen's
  top-right corner, just inside the curtain and level with the title card (mockup states 1–2). Always on the start
  screen; never during a game.
- **`GrownUpGate`** (NutmegCore logic) + **`PTGrownUpGate`** (view): hold a button for **2 seconds**, then **tap the
  number that's spelled out** ("Tap the number fifty-eight") from a **grid of 6 numbers**. A wrong answer is a gentle
  reset: back to the hold ("Not quite. Let's try again."), and the number changes. **No voice**; Nutmeg stays quiet.
  Reusable for section E (purchases, outside links).
- **`GrownUpsView`** behind the gate (a sheet, native `NavigationStack` + `List`, the app's fonts and colors):
  **Saved games** (cover thumbnail or prop stickers, title, date saved, size; a trash button and swipe to delete;
  confirm "Delete Moon Crumbs Bakery? / This can't be undone." Delete / Cancel; the game's folder is removed from
  disk) and **About saved games** (plain privacy copy from §D7, for this iPad only). **Done** returns to the start
  screen. After the last game is deleted the start screen's **My games** button is gone.
- **No delete on the kid bookshelf** (D1's shelf is unchanged).

## Claude's calls
- **The numbers are 21–99** (two-word numbers like "fifty-eight" are harder for a 4–8 year old to sound out than
  "five"). Distractors: the swapped digits (85 for 58) and two same-tens numbers first, then random; all distinct,
  shuffled. The next question never repeats the last number. `NumberWords.spell` covers 1–99.
- **No "three wrong answers close the gate"** (the design's draft): Haylee's brief says a wrong answer just resets
  with a new number, which already stops guessing (each try costs another 2 s hold).
- **Hold timing:** `onLongPressGesture(minimumDuration: 2)`; the press start is recorded and `holdEnded(after:)`
  decides (a short hold stays on step 1). The ring fills over 2 s and empties on an early release.
- **Accessibility:** the hold button is one VoiceOver element ("Grown-ups: hold for 2 seconds", double-tap acts);
  the question reads "Tap the number fifty-eight"; number keys are 104 × 76 pt; the row is one element with the
  title, date and size and a "Delete" action; the trash button is 44 × 44 pt with "Delete <title>".
- **Section E slots:** `GrownUpsSection` lists Saved games, About saved games, Manage subscription, Restore
  purchases, Privacy policy, Help; the four E sections render a placeholder and are hidden while
  `GrownUpsFeatures.storeSections` is false (a test locks that only the two saved-games sections show).
- **Size** is the game folder's bytes (`ByteCountFormatter`), date medium style. Delete is permanent (no trash).
- **DEBUG hooks:** `-PTDemo seed2` (plays the bundled airplane game to The End offline and saves it twice as
  "Moon Crumbs Bakery" / "Pirate Ship on the Moon", no art) and `-PTGrownUps holding|grid|list|confirm|deleteAll`.

## Tests and checks
- NutmegCore **336 green** (`RoundD2GrownUpsTests`, 7: spelled numbers 1–99, the 2 s hold, 200 seeded questions
  (target once, distinct, in range), right answer passes / wrong resets with a new number, 50 wrong answers never
  repeat a number, visible sections + copy, store delete removes game.json/art/cover and My games follows the store).
- Simulator PT-R15-iPad (`/tmp/pt-roundD2/`): start screen with the pill, gate hold, number grid, Grown-ups with 2
  saved games, the delete confirm, the start screen after deleting both (no My games; the SavedGames folder empty).
  Live taps: a 1 s hold stayed on step 1, a 2.6 s hold showed the question, a wrong number reset with a new number,
  the right number opened Grown-ups, Done closed it.
- Not checked: VoiceOver on a device, swipe-to-delete by hand (the trash button and confirm were used), Dynamic Type
  at the largest sizes.
