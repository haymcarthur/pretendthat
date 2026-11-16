# Round 24: props that make sense, "Do you have a printer?", and the no-printer "Draw it!" path

**Date:** 2026-11-15. **Who decided:** Haylee asked for both items (queue, round 24) and for this record. The
implementation details are Claude's calls, noted below.

## 1. Props must make sense (Haylee: a bowl was suggested "as a pirate map")
- **Tags per item:** `PropLibrary.tags` gives each of the 30 library items shape/function tags (round, flat, long,
  soft, container, wearable, sheet, sittable, big, boxy, creature, light, paper, surface, vehicle), and
  `PropLibrary.uses` gives each one 1 to 3 curated pretend uses, each with a kid-friendly reason ("A bowl is round
  like a captain's hat!").
- **Uses need tags:** `PropFit.needs` maps the use's words to the tags it needs (map/flag/menu → sheet, paper or flat; hat/helmet/crown
  → wearable or round; cape → sheet; seats → sittable; boat/rocket → vehicle, sittable or boxy; chest/bowl/pot →
  container; wand/telescope/sword → long; …). The head noun picks the rule (the last word it knows before
  "for/of/…": "pirate map" → map, "treasure chest" → chest, "airplane seats" → seats).
  **Claude's call:** a use the rules don't recognize is allowed, so a pairing is never rejected by mistake.
- **Where it's checked:** `show_next_prop` and `swap_prop` (voice) and Claude's prop list (tap path). On a misfit
  the card isn't shown, and the model gets one retry: the tool result names items that fit. A second misfit gets a
  curated sensible pair: an item that fits the same use (the model's alternates first, items already used skipped),
  or a curated pair from the library if nothing fits. Alternates that don't fit the use are dropped. On the tap path,
  `Validate.props` asks Claude once more, then `PropFit.repair` fixes whatever is still wrong.
- **The reason:** `show_next_prop` has a required `reason` field (and Claude's props schema has a `reason` too). The model's reason is kept
  when it's 3 to 14 words and passes the kid-safety filter. Otherwise the app writes one (curated, or from the shared
  tag: "A towel is big and floppy like a cape!"). The reason is checked like any other tool text (round 21
  gate). She says it briefly inside her prop line ("Next, can you find a cardboard box? It'll be the treasure chest,
  and a box can hold pretend treasure!"). The first prop's line gets it too.
- **Claude's calls:** "pillowcase", "paper", "newspaper", "paper towel tube" and "pool noodle" have alias tags for
  the check, but they aren't new cards (no hand-drawn art for them). The pillow is also "sittable" (pillow → train
  seat is fine).
- **Tests:** the pair table (bowl → pirate map rejected; bowl → captain hat, towel → cape, pillowcase → treasure
  map, chair → airplane seats OK, plus 12 more), every curated use passes its own check, retry then fallback in the store, a swap
  that has to fit, Claude's list repaired after one retry, and the reason decoded and required.

## 2. Printer question and the no-printer "Draw it!" path (Haylee)
- **Step 3c `printer`** (between the confirm yes and the color question): "Do you have a printer?" Two buttons sit at the top of the stage,
  in the same row as round 21's choices (**Yes, I have one** / **No printer**), plus voice (`set_printer`). One spoken reply per
  turn: the yes tap's reply is the printer question; the answer's reply is the color question (yes) or the
  planning line + roles (no).
- **Yes:** the round 20 flow, unchanged (color question, kit pages and art during the hunt).
- **No:** no kit pages and no image calls at all. During the hunt Claude writes a draw-your-own guide
  (`DrawIt.prompt`, low effort). When the hunt ends, it writes the play guide for the drawn pieces. **Limits, enforced by `DrawIt.clean`
  and tested:** at most 5 pieces, instructions at most 2 sentences and 14 words, titles at most 3 words, SF Symbols
  only from the print allowlist, each kind once (except "thing"), badges first. **The app owns every count:** badges = players
  (capped at 6), tickets = players, money = 5 bills that always say $1 (any other amount is replaced with "Draw a
  long rectangle. Write $1 in the middle."). Without Claude there's a bundled guide (badges, money, tickets).
- **The Paper step becomes "Draw it!"** (`PTDrawItCard`): one piece at a time with a big SF Symbol of the shape, the
  title, the instruction + count, progress dots, **Next** (**Let's play!** on the last piece) and the pill's Repeat
  (it reads the current piece). Voice uses `draw_step` with next or again (tool-first, like round 23's back-nav). She reads each
  piece. The first line says what to grab and to tap Next; the last says to tap Let's play. After the last piece,
  play starts as usual. Going back to Paper on the rail starts again at piece 1. The rail icon stays paper + crayon.
- **Save printables for later** (on the Draw it! card): Claude writes the normal kit pages and the art is drawn. The
  PDF goes to the iOS share sheet (Save to Files, AirDrop, send to a grown-up). **Claude's call:** always coloring pages,
  with no extra question (they're printed somewhere else later, and kids can color them). The PDF is a temporary file, deleted at
  New game/Leave. Nothing about kids is in it.
- **Claude's calls:** a printer answer changed during the hunt switches which kit is written (yes → coloring pages
  unless a color was said). After the hunt it doesn't change: she points to Save printables instead. The kit
  commentary while the kit is made only talks about the play guide in draw mode. `print_kit` by voice in draw mode
  doesn't print.
- **Relay:** unchanged (it doesn't know tool names or schemas), so no redeploy.

## Live checks (typed, simulator PT-R15-iPad)
See the round report. Screenshots are in `/tmp/pt-round24/`.
- **A (pirates on the moon, printer yes):** the printer question came right after the yes, then the color question. Props:
  sheet → pirate ship sail, cardboard box → treasure chest ("a box can hold pretend treasure!"), bowl → captain's
  helmet ("a bowl is round like a helmet"). That run didn't speak the first prop's reason; fixed (the first prop line now
  gets it too). Screenshot: `A-hunt-bowl-captains-helmet.png`.
- **B (pirate island with parrots, 3 kids, no printer):** no color question. Sheet → sail ("A big sheet can billow like a
  sail"), box → chest, hat → captain's hat. The draw guide had 4 pieces (badges "Make three", $1 gold coins "Make five",
  treasure map, parrot friend). Next by tap, then "next" and "again" by voice, each read once. The last Next went to the
  hand-off ("Pass the iPad to the Captain"). **No image calls** until Save printables (log: no "kit art" line before it).
  Save printables: 6 coloring pages in 24 s, then the share sheet (Save to Files, Print, …). Screenshots:
  `B-printer-question.png`, `B-draw-it-piece2.png`, `B-draw-it-piece3.png`, `B-save-printables-share-sheet.png`.
- Unrelated, seen in A: the kit-ready app line was spoken as "tap Start" instead of "tap Let's play" (the voice model
  paraphrasing a sayExactly line). It was already happening before this round and isn't fixed here.

**Name the button "Let's play!", never "Start" (Haylee reported; fix was Claude's call).** At the Paper step Nutmeg sometimes said "tap Start". The cause: the realtime instructions banned saying "let's play" before the play step, and `TurnCheck.mentionsGoPlay()` flagged any "let's play", so the model dodged the button's real name and made one up. Now the instructions say to call the button exactly "Let's play!" when telling kids what to tap (never Start, Go, Begin or Play), and only ban "let's play" as an invitation to go play. `mentionsGoPlay()` strips button references ("tap/press/hit/push/click/touch Let's play") before matching, so "Tap Print, then tap Let's play when you're set!" passes while "Let's play pirates now!" is still flagged. The print-step chat reply prompt also names the button exactly. Tests in `Round16HandOffTests`.
