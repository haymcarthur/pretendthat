# Round 26: the button audit, built (voice-first, icon-only, fewer buttons)

**Date:** 2026-11-16. **Who decided:** Haylee made the 11 calls in
[the button audit](2026-11-16-button-audit.md) (and changed decision 2 mid-round, below). The implementation details
are Claude's calls, noted here.

## Per decision
1. **Pick confirm, voice only.** The Yes / Change buttons, `confirmYes` / `confirmChange` and their tap notes are gone.
   The recap now ends with what to SAY: "So it's a magic bakery for two friends! **Say yes, or tell me what to
   change!**" (`ConfirmStep.question`). `confirm_plan` and the correction tools already handled the answers; the turn
   check accepts a turn that ends by saying what to say (`TurnCheck.saysWhatToSay`).
2. **Color: removed entirely (Haylee, changed mid-round from "voice only").** No color step, question, lines, buttons,
   `set_print_style` tool or `PlanningCall.setPrintStyle`; the confirm yes goes straight to the roles and the hunt.
   A new game makes **coloring pages by default** (`currentPrintStyle` = color-in; the kit pages and the save use it).
   The `PrintStyle` plumbing (store value, prompt builders, saved field) stays for the next round: both versions,
   the choice on the Print screen, and a bookshelf cover image. Round 20's color tests were deleted with it.
3. **Hunt card:** a big green ✓ and a white ✗ (`PTBigIconButton`, 76 pt on the stage card, 64 pt pinned in the chat
   panel), accessibility "We found it" / "We don't have it". Her first prop explains once: "say 'found it' or tap
   the green check when you have it, or tap the X if you don't".
4. **Print:** a black printer button + a green ▶ (80 pt), side by side above the fan; the same pair in the chat
   panel's pinned kit card. They're hidden while the page preview is open (the duplicate behind it is gone). Her
   line: "Your kit is ready! Tap the printer to print it, then tap the green play button when you're set!"
5. **Hand-off card:** "Pass the iPad to the Head Baker!" + one green ✓ (104 pt); no "I'm the …!" text, no Back to
   the checklist. Line: "Pass the iPad to the Head Baker! Tap the green check when you have the iPad!" Voice
   "I'm the Head Baker" (`confirm_handoff`) unchanged.
6. **Checklist, no Done.** Checking the last open step starts a **1.5 s grace** (`AdventureStore.autoAdvanceGrace`):
   the last check stays visible, an uncheck inside it cancels; then the congratulations leads the next line
   (hand-off / scene / The End). The last check says no step cheer (the congrats follows the advance). Voice "we're
   done" / "done" = a new **`finish_scene`** tool (play-step tool-first pass) that checks the rest and moves on.
   Claude's call: going back to the checklist from The End (rail Play ↺) opens it **unchecked** ("Here's your
   checklist again! Tap each step as you play it!"), since an all-checked list with no Done had no way forward
   except un- and re-checking; checking them all returns to The End. The hand-off "Back to the checklist" machinery
   (`doneSnapshot`, `canGoBackToChecklist`, `backToChecklist`) is gone.
7. **The End:** ⭐ (white disc, yellow star) = save, then home once her shelf line ends (≤ ~10 s; the round 19
   hang-up rules); 🏠 (purple house) = home without saving. A replay (or a game just saved) shows only 🏠. Lines:
   "Tap the star to save it, or the house to go home!" / replay "Tap the house to go home!". Claude's call: the
   round 25 "Tap Play at the top to see your checklist again" hint was dropped (too many instructions at once; the
   rail's Play ↺ still works). "Play it again" is gone (the shelf replays).
8. **Replay Pick, voice:** "Magic Bakery! How many friends are playing this time? Tell me!" `set_player_count` on a
   replay's Pick sets the count and goes straight on to Props (no Let's go). **Fallback:** with no voice session
   (offline, or Realtime can't connect: `AppModel.noVoiceSession`), the 1–6 tiles show, and a tile goes straight on.
9. **Replay Props = the first play's hunt:** the saved props one card at a time (the hunt card + ✓ / ✗; answered ones
   as small thumbnails above). ✗ uses the saved alternate once (the card changes: "A bowl works too! Do you have
   one?"), then pretends ("No problem, we'll pretend the mixing bowl! Next, do you still have a …?"), no AI. Voice
   `mark_found` / `skip_prop` / `swap_prop` drive the same state on a replay. The rail's Props restarts the hunt.
10. **Replay Print = the first play's Print** (`KitView`, printer + ▶, every page for the current count; voice
   `print_kit` / `start_play`). Removed: the replay props list and toggles, All set!, Print everything / Just the
   badges / Let's play!, `PaperChoice`, `ReplayProps.pages`.
11. **Start screen:** yellow "▶ New game" and white "⭐ Saved games" (same widths; the bookshelf icon is gone).

## Fallback (no voice session)
A first play with no Realtime still uses the existing tap screens (players / props grid / All set). The confirm step
only ever showed in a live conversation, so removing its buttons can't dead-end tap mode; the chat panel's text field
is the backup when a live session has no mic. A replay without voice gets the Pick tiles; its hunt card's ✓ / ✗ and
Print's buttons are taps anyway.

## Also (Claude's calls)
- The bundled common clips were re-recorded from her real voice for the changed lines (7/7 kept; obsolete ones removed).
- Grown-ups empty text: "Tap the star at the end of a game to keep it here." `ReplayLines.savedGame`: "This is a saved
  game! Start a new game from home for a new adventure."
- DemoDriver: `#ifhunt TEXT` (a voice turn only while a card is up), `#checkall`, `#print`; `#playthrough` taps every
  step (exercises the auto-advance); removed `#yes`, `#fullcolor`, `#colorin`, `#change`, `#back`, `#letsgo`,
  `#nothave`, `#alt`, `#allset`, `#paper`, `#again`.
- Tests: `Round26Tests`, new auto-advance / grace / cancel-on-leave tests in `AdventureStoreTests`, the replay test
  rewritten for voice count + one-card hunt + first-play Print; 371 core tests green.

## Live checks (typed turns as voice, PT-R15-iPad, old test saves deleted first)
- **New "Magic Bakery" game, 2 players, all by voice:** "We want to play bakery" → "A magic bakery" → "Two of us" →
  the recap → "Yes" → `confirm_plan` → straight to `start_planning` / `set_roles` / the first card (no color
  question). Hunt by voice (`mark_found`, two `swap_prop`s). Print → "Let's play" (`start_play`) → hand-off → "I'm the
  Head Baker" (`confirm_handoff`) → one step tapped → "We're done" (`finish_scene`: "You finished it all! What a team!
  Pass the iPad to the Spell Mixer! Tap the green check when you have the iPad!") → every other scene finished by
  tapping all its steps (auto-advance each time, hand-offs R2, R1, R2…) → The End → rail Play ↺ → the checklist,
  unchecked → all checked → The End again → ⭐: saved (16 clips, 16 art files), her shelf line, then home.
- **Found live and fixed:** on the replay, her app lines aren't in the conversation, so after three "found it"s the
  session answered the last card with `just_talk` and the hunt stuck on it. Every replay move now adds a silent
  note naming the card on screen (`ReplayLines.stepNote`); and items read right ("some books", "Some books work too!").
- **Replay by voice (after the fix), 3 players:** "Three of us" (`set_player_count`) → Props card 1 → "We don't have
  that one" (`skip_prop`) → the saved alternate (pot) → "No, we don't have one either" → pretend + the next card →
  "Found it" ×2 (`mark_found`) → Print → "Print it" (`print_kit`, the print sheet, every page for 3) → "Let's play"
  (`start_play`) → "I've got the iPad" → play through (hand-offs R1, R2, R3 rotating) → The End with only 🏠 → rail
  Play ↺ → 🏠 home (session idle, silent). **0 content AI calls**; clips 18/25 (72%), $0.11 Realtime.
- **No voice session (offline replay):** the Pick tiles show and a tile goes straight on to Props.
- **After-audit:** `/tmp/pt-buttons-after/` (30 screens, `NN-name.png`) and `/tmp/pt-buttons-after/sheet.png` (each
  screen captioned with the buttons left).

## Not verified
- By ear and on a real iPad; spoken (mic) turns (all live checks were typed turns). The 1.5 s grace's feel with real
  kids. VoiceOver reading the new icon buttons' labels. The chat-open pinned cards (hunt, kit, checklist) weren't
  re-shot.
