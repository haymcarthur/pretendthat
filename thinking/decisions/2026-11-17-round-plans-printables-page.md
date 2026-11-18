# Round: printables draw once + color in, plans 5/20, saved game page, no control bar in Play

- **Date:** 2026-11-17 (built overnight into 11-18)
- **Spec:** decisions/2026-11-17-printables-draw-once-color-in.md, 2026-11-17-plans-5-and-20.md,
  2026-11-17-saved-game-page-and-play-bar.md (+ Haylee's two follow-ups during the build: a big "Play with Nutmeg" with
  ▶ and her face, Nutmeg says a line when the page opens; and the 2 Free Preview games get NO replay exception).
- **Who decided:** Haylee (all of the above). Claude's calls are marked **(Claude)**.
- **Tests:** `swift test` 702 passing (was 681). Relay `vitest` 69 passing, `tsc` clean. No API keys, no live game.

## 1. Printables: draw once, color in
- Each AI page is DRAWN once, as the coloring (outline) page (`/v1/images/generations`). The color page is made from
  that exact PNG with `/v1/images/edits` (`ImageClient.edit`, multipart; never sends `input_fidelity`). The color set
  waits for the outline set's KEPT page on a shared `OutlineBoard` (app, `KitArtService`).
- Per-player sheets (badges, tickets): still drawn for all 6 and cut apart; the color sheet is the same layout, so
  `SheetCutter` cuts both.
- The character sheet (in-app pictures) is still drawn by the color set with generations (it has no outline twin).
- Prompt: the tuned v2 prompt from design/printables-match-test/notes.md + a letters rule (`ColorInPrompt`): dark ink or a
  strong saturated letter fill with a dark outline; never white / cream / pale yellow / pastel fills; never yellow on
  white; paper stays white (v2's "white or a pale cream" paper is now white only) **(Claude: wording)**.
- On-device checks on every color page (`ColorInFlow`, `PageOCR.inspect`): the round 46 word check (it caught
  "002"→"202" in the test) + a contrast check per Vision text box (`LetterContrast`: the letter fill's median color vs the
  median of a margin around the box; mostly-ink letters pass; WCAG ratio < 1.7 = too light; tiny print under 1.2% of the
  page height isn't judged) **(Claude: method and thresholds)**. A miss or pale letters → ONE re-edit of the SAME outline
  (naming the missed words and / or "fill every letter with dark purple or navy"); the strictly better one is kept (words
  first, then pale boxes); still pale → kept and logged.
- The outline page keeps the round 46 rule: it is read and redrawn once on a real miss. Round 47's option b ("read the
  outline only when the color page missed") is retired: the color page doesn't exist yet when the outline is checked
  (`PageCheckRule`). **(Claude: this means more outline reads; bubble letters read poorly, so watch the redraw count in
  the live check.)**
- If an outline page fails twice, its color page is drawn on its own the round 46 way (generations + word check), so the
  kit never loses a color page **(Claude)**.
- Cost: an edit ≈ 3.3¢ vs ≈ 2.2¢ drawn (1,536 image input tokens at $8/M). `ImageUsageLog` now counts image input
  tokens and prices them. A 6-page kit ≈ +6–7¢; each contrast/word re-edit is +3.3¢.
- Timing: color pages now start only after their outline lands (serial per page). The papers come out when the first
  set is final (usually the outline set now); the Print screen shows the color set's progress.
- Relay: `POST /v1/images/edits` added (multipart, one PNG/JPEG/WebP image ≤ 8 MB, prompt ≤ 32k chars, the image model
  list, IMAGE_LIMIT, show ticket when enforcing, n=1 and moderation=auto forced, only size/quality/output_format/background
  forwarded, masks refused). README updated. **Not deployed.**

## 2. Plans 5/20, no intro offers
- PlanCatalog: Show Pass 5 a month $9.99 / $99.99, Season Pass 20 a month $24.99 / $249.99. Intro fields, intro text and
  `isEligibleForIntroOffer` removed (PlanOffer, PriceText, PTStore/PlanPrice, onboarding row, plans cards).
- StoreKit/PretendThat.storekit: new prices, no `introductoryOffer`, new descriptions.
- relay/src/shows.ts: 10/30 → 5/20 (tests updated). Relay error texts no longer say "Replays are always free".
- Free Preview copy reads as once: "2 free games to try" (onboarding title), "Try 2 free games" (button), "2 free games
  to try. No card…" (plans body), "1 of 2 free games to try left" (allowance) **(Claude: exact wording)**. A test scans
  every free-games string for "month".

## 3. Saved game page (everyone)
- A bookshelf card opens the page (`SavedGamePageView`, `AppModel+SavedPage`): Nutmeg peeks over a white sheet
  (`NutmegPeek`), the cover + title, a big yellow "Play with Nutmeg" with ▶ and her live head on it, Printables (Color /
  Black & white toggle, the kit page thumbnails, page count), black Print. No player picker: always the full 6-role
  sheets (`SavedGamePage.printPlayers`). The page's art is restored into its own two `KitArtService`s (no image client:
  never draws).
- On open, Nutmeg says "Want to play <title> again? Tap play!" through her usual line path (a clip if the game has one,
  else her live pre-connected voice once, never kept; silent in demo/offline). No bundled clip fits (it names the game)
  **(Claude)**.
- Play with Nutmeg: active pass → today's replay (asks how many). No pass (the Free Preview games included, Haylee's
  follow-up) → Nutmeg's card "Ooh, <title>! Let's ask a grown-up to help us play this one again." (OK / Grown-ups, a 🔊
  to hear it again, her point pose) → the existing `PTGrownUpGate` → the grown-up card ("Your saved games are still
  yours." / body / See passes → `PlansContent` / Not now). NO footnote (Haylee). Kids never see prices. Pass + no AI
  consent → the existing consent card.
- Print stays one tap (the iOS print sheet is the second). Kids CAN print again and again from this page (each tap opens
  the print sheet; no AI cost, only paper/ink); not limited **(Claude: flagged, not changed)**.
- "Sounds like a game you have" (Pick confirm) is only offered with an active pass now; it starts the replay directly
  **(Claude)**. Replays still never count; a new game still counts when its kit is made (unchanged code; tests).
- Copy changed from "saved games are free to play again" to: printables always yours; playing with Nutmeg is included
  with a pass (onboarding lead, plans bodies, out-of-games body, purchase message, App Store descriptions, Grown-ups →
  About, kid card "You can still look at and print your saved games!").
- NOT changed: The End's bundled clip says "This game is saved, so you can play it again later." Re-recording is a live
  voice job; suggested new words: "This game is saved, so you can print it again later." **(open)**

## 4. No control bar in Play / The End
- The mic / repeat / chat bar slides away when Play starts (setup, story, scenes, clean-up) and stays off at The End; the
  chat closes and a held mic is released. Each row keeps its 🔊; a small 🔊 on the scene title says her setup line again
  (`repeatScene`) **(Claude: purple, right of the centered title)**. Saying "next scene" no longer works (no mic).
- The End: the arrow and the house sit where the bar was, bigger (124 pt iPad / 104 pt phone); the stage keeps room for
  them. The title stays under Nutmeg.
- iPhone peek: the freed bottom gives the scene card the room; on iPhone 18 Pro 6 rows fit with the peek at 66% of the
  card width. On the smallest iPhone (SE) 6 rows still scroll with a smaller peek (as before).
- Voice session in Play (report only, not changed): with no mic in Play the main conversation session gets no kid input;
  every Play line is a fixed app line (scene openers, row tasks, The End), which goes to the mini lines session (on by
  default since round 44) or a clip on replays. So the main session could be closed at Play start (saves its idle
  context on any line that lands there and any stray response); the step rail's Back to Pick/Props would then need a
  reconnect (~1–2 s, the round 9 silent reconnect path). Realtime bills by tokens, not connected time, so the saving is
  small unless lines fall back to the main session (mini off or down).

## Screens (demo mode, no keys): /tmp/pt-round-plans/
iPhone 18 Pro, iPhone SE (3rd gen), iPad Pro 13": saved page no pass / pass / ask card / gate / grown-up card, replay
Pick from a pass, play scenes with 4/5/6 rows, clean-up, The End, onboarding plans page, Grown-ups → Plans.
New demo targets: `-PTDemo savedPage | savedPageAsk | savedPageCard` (env PT_PAGE_TITLE), `-PTFakePass`, `-PTGateOpen`.
