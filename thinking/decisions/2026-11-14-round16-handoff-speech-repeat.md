# Round 16: Nutmeg says the next step at every hand-off, and the checklist's "Hear it again"

**Date:** 2026-11-14 (before the 7:59 AM code freeze) · **Decided by:** Haylee asked for both items after her daughter
tested the app (at print-ready Nutmeg said nothing, so the child didn't know whether to tap Let's play). Implementation
details are Claude's calls, noted.

## 1. Never hand off without saying the next step out loud (Haylee asked)
Rule: whenever the app hands control to the kid (a button appears or the screen waits on them), Nutmeg says what to do
next, naming the real button labels. One line per moment, through the existing app-line path (`sayExactly` with the
shared voice style), so it shows in the chat. All lines come from `HandOffLines` (NutmegCore, unit-tested).

| Moment | Line |
|---|---|
| Print ready (whole kit landed) | "Your kit is ready! Tap Print to print it, then tap Let's play when you're set!" |
| Hand-off card | "Pass the iPad to the Captain, then tap I'm the Captain!" (matches the card's button) |
| Checklist appears | the scene line + "Tap each step when you do it, then tap Done!" (first scene) or "Tap the steps as you go, then tap Done!" (later scenes); nothing added if the scene line already says to tap |
| The End | "The end! What a show! Take a bow! Tap Play again to do it again, or New game for a new adventure!" + "Tap Back to the checklist to see it again." when that button shows |
| Back to the checklist (audit find) | "Here's your checklist again! Tap Done when you're finished." (it used to come back in silence) |

- **Print-ready silence (Claude's call on the fix):** the ready line was sent the moment the papers flew out, even when
  a kit progress line or reply was still playing, and its wording didn't name the Let's play button. It now waits for
  quiet (`voiceBusy`, at most 6 s), then says the new line once (still deferred across a lock/background as in round 9).
  Not proven to be the only cause of her test's silence; the live run below heard it.
- A pending early-Done congratulations still starts the next line (round 15), so a Done! tap is still one reply.
- "Let's play" is a button name here, not a "go play" line: the print-ready test strips the button name before the
  go-play check.
- **Audit, not changed (Claude's call):** planning steps always end with her question; prop cards are explained by her
  prop line; the kit-making wait isn't on the kid. The step rail's jumps back to Print or Play stay silent (the kid chose
  that screen themselves); the start screen's Let's play! has no voice yet (the session isn't open).

## 2. Checklist "Hear it again" (Haylee asked)
- A secondary pill with a speaker icon and the label "Hear it again" (64 pt tall, accessibility label + hint), in the
  checklist's bottom row on the stage card (beside Done!, same 64 pt row, so round 14's fit and long checklists are
  unchanged) and in the chat panel's Checklist tab (stacked under Done!, since side by side squeezed Done! to "D" in
  the narrow panel; that tab scrolls).
- **Claude's call: there was no Back button on the checklist card to move.** The checklist card only had Done! (the
  "Back to the checklist" button is on the hand-off card and The End, and goes back TO the checklist). So nothing was
  moved to the top-left corner; Repeat went in the bottom row next to Done!. If Haylee meant a different control, it's
  a quick follow-up.
- Tapping it (`AppModel.repeatChecklist`): Nutmeg reads the scene title, then the unchecked steps in order ("First, ...
  Then, ... Last, ..."; "Last step: ..." for one); all steps if every one is checked (`HandOffLines.repeatText`). A
  pending cheer is cancelled (never said late), the line waits for anything she's saying to finish (≤ 8 s), and taps
  are ignored while one is queued or within 2.5 s of the last: one reply per tap, in the chat.

## Tests
- NutmegCore: 196 green (was 189): + Round16HandOffTests (print-ready names both buttons and no go-play, hand-off line
  matches the card, checklist how-to added once and not duplicated, The End names the buttons, play flow uses the
  builders incl. back to the checklist, repeat reads title + only the steps left in order, all steps when all checked).
  Two old tests updated for the new hand-off and ready wording.
- Built for the second simulator (PT-R15-iPad); screenshots in /tmp/pt-round16/ (checklist-scene-closed.png,
  checklist-scene-open.png, print-ready-closed.png).

## Live run
Typed harness on PT-R15-iPad (/tmp/pt-round16/live1/console.log): airplane, moon, just me, 3x found, kit, Let's play,
check step 0, Hear it again twice, early Done!. In the chat, in order, no overlap:
- "Your kit is ready! Tap Print to print it, then tap Let's play when you're set!" (after the two kit lines finished)
- "Pretend that today is your very first flight to the moon! Pilot, get your plane all ready. Tap each step when you do
  it, then tap Done!"
- cheer: "Wonderful! Next, put on the captain's hat!"
- repeat: "Get Ready to Fly. First, put on the captain's hat. Then, hang up the gate sign. Last, set up the box control panel."
- The second tap's repeat was read again after the first finished (the harness's taps aren't instant), so Claude added a
  guard afterwards: a tap while the read-aloud is still playing doesn't queue another. Built, not re-run live.
- Early Done!: "Woohoo, the whole checklist is done! Pretend that sleepy teddy passengers... Tap the steps as you go,
  then tap Done!" (one line). Hand-off card and The End lines are covered by unit tests only (single-player run).
