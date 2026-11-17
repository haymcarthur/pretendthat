# Round 36 build: story opener, setup scene (every prop and page used on purpose), clean-up scene

**Date:** 2026-11-17 · **Decided by:** Haylee (the design: [story-setup-cleanup-scenes](2026-11-16-story-setup-cleanup-scenes.md),
queue "Round 36"). How it was built is Claude's call, noted below.

Arc: Print → **story** → **setup scene** → 3 play scenes (unchanged) → **clean-up scene** → The End.

## How it works
- **Kit pages have a purpose.** `KitItem.purpose` (required in the pages schema): one sentence, what the kids do with the
  page while they play ("Customers pay with them"). The guide prompt receives it with each page.
- **One guide call writes the arc** (`KitScenesSix`): `story` (3–4 sentences, ~15 s), `setupScene` / `cleanupScene`
  (title + one "Pretend that" line) and `pageJobs`: per page a setup job and a clean-up job (imperative phrase that names
  the page, short row text, the role it suits). Schema uses `$defs` so the 6 jobs share one definition.
- **Props get their jobs with their weave** (Claude's call: the guide is written during the hunt, before any prop is
  known). `PropWeave.jobs`: setup job (named by what it becomes) + clean-up job (the household item goes back).
- **Validation + repair** (`Bookends`, NutmegCore): a job is valid when it's 2–22 words, no quotes, and names its item.
  Missing/invalid jobs are **re-asked once** during the hunt (`PhaseService.itemJobs`, small call, kid-safety checked);
  anything still missing is written by the app (`Bookends.repair`, deterministic, idempotent). Story/titles/lines too.
- **Rows are composed per player count, not by the AI** (Claude's call), so a count change still needs no AI call and
  the rule holds at every count 1–6: `Bookends.setupAssignment`: items no visible play task names are **always** set up
  (a role may take a 2nd/3rd); every role gets ≥1 item; then roles fill up to 2 items (solo: 3); anything left over is
  already used in a play task the same kids see. Badges: the setup's opening adds "Everyone, put on your badge first!".
  Clean-up: every real prop goes back (the role it suits first, spread evenly); a role with no prop tidies a page.
  Rows read "Head Baker, hang the sign by the door, then set the mixing bowl on the counter!"; more than 3 items
  (solo) continue "After that, …". Swaps rename the item in the job; a skipped prop is a printed cut-out (covered by
  the cut-outs page) and has nothing to put away.
- **`SetupCoverage`** (tested at every count): every found/swapped prop and every page is named by a setup task (or the
  opening, badges) or a visible play task; `notInSetup` / `log` give the item → task map (DemoDriver `#arc`).
- **Story on stage:** a scene of kind `.story` (no rows, no card, no step tab), camera preset `.talk` (Nutmeg alone,
  close-up). When her line ends the setup opens by itself (`AppModel.watchStory`); ▶ / "next scene" skip it; Repeat
  tells it again. No voice at all → moves on after a short pause (never a stuck stage). The ▶ how-to moves to the
  setup scene (first scene with rows).
- **Tabs, tools, nav:** chat panel step tab says **Setup** (hammer) / **Scene** / **Clean-up** (basket); story = Chat
  only. `next_scene`, `read_job` (setup and clean-up rows too), `go_to_step play` and Resume work on the 6 composed
  scenes; The End's Play ↺ reopens the clean-up scene.
- **Saves:** schema 3 (kit carries `story`, `setup`, `cleanup`). **Schema 2 games still open** and replay exactly
  their 3 play scenes (no arc, nothing invented: replay parity). Unknown schemas are refused.
- **Replays:** story, setup opening, every scene opening and row reads are app lines → recorded on the first play
  (D3b) and replayed from clips (same words when the count and answers match).

## Measured
**Guide cost (live `liveGuidePrefetchTimings`, same pirate game, Opus 5.5 $4/$20 per M):**

| Call | Before (2 runs) | After (final schema) |
|---|---|---|
| Pages | 3,160 in / 789–823 out = 2.84–2.91¢ | 3,324 in / 985 out = 3.30¢ (+purpose) |
| Early guide | 5,708–5,740 in / 1,615–1,671 out = 5.51–5.64¢ | 7,464 in / 2,430 out = **7.85¢** (first schema without `$defs`: 9,834 in = 8.90¢) |
| Weave, per prop | 3,596–3,681 in / 241–590 out = 1.9–2.6¢ | 4,361–4,395 in / 281–357 out = 2.3–2.5¢ |

≈ **+3.5¢ per new game** of Claude (guide +2.3¢, pages +0.4¢, weaves +~0.3¢ × 4–5 props); a re-ask (seen once
per game for one prop, ~2¢) only when a job is missing. The early guide takes longer (15 s → 23–44 s in the app), but
it is written during the hunt: Print was reached before it mattered in both games (guide final 0.4 s / 1.1 s after Print).

**Realtime (gpt-realtime-2.1, game 1, 3 kids, audio-out tokens per line):** story 302–318 (12.9 s heard), setup
opening 302 (12.3 s; includes the badge line + ▶ how-to the first scene used to carry), play openings 135–171, clean-up
opening 180 (7.2 s), a setup/clean-up row read 113–242. Net extra per game ≈ story ~310 + clean-up opening ~180 +
setup vs old first opening ~+80 ≈ **+570 audio-out tokens ≈ +4¢** (each line ~0.3¢ cached input + ~0.25¢ text), plus
~1–1.5¢ per setup/clean-up row a kid taps. Replays: ~0 (clips).

## Live runs (iPad Pro 13" M5 sim, typed `-PTLive`, personal keys) → /tmp/pt-round36/
- **Game 1, "bakery with cupcakes", 3 kids** (plate skipped): story → setup opened by itself → 3 scenes → clean-up → The End.
  Item → task: badges → setup opening · Sprinkle Cupcake Bakery sign → setup Head Baker · Cupcake Cash → setup Customer
  (+ scene 1) · Order Tickets → setup Cupcake Decorator (+ scenes 1–3) · Cupcake Menu → setup Customer · cut-outs → setup
  Cupcake Decorator · mixing bowl → setup Head Baker · big stirrer → scenes 1, 3 · baker hat → scene 3 · delivery box →
  scenes 2, 3. Clean-up: bowl + hat (Head Baker), box (Customer), stirrer (Decorator). One prop's jobs were re-asked.
- **Game 2, "space station with friendly robots", solo** (one swap): badges → opening · sign, Star Bucks, Price List,
  greeter hat → setup · Space Tour Passes, control console → scene 1 · repair mat → scene 2 · supply sorter → scene 3 ·
  cut-outs → scenes 1–3. Nothing unused. Solo rows run long (4 items + "After that, …", ~45 words) because items no
  solo play task named must be set up.
- **Replay of game 1 at 3:** story, setup opening, every scene opening and the setup row read played from the first
  play's clips (screenshots match the first play pixel for pixel on Setup); 0 Claude/image calls; clips 11/17 (the
  misses: lines that differ because the replay found the skipped plate, The End's replay wording, the count/prop lines).
- Screenshots: g1-bakery3/ (pick, print, story, setup, play1, cleanup, end), g1-replay/ (r1-*), g2-space1/ (g2-*),
  demo/ (no-voice story + setup).

## Not done / follow-ups
- Two-item row shorts fall back to "<first> and more" when both don't fit in 8 words (readable, not specific).
- A swap that renames the household item can produce "the treat plastic plate" (same replace rule as the play guide).
- The solo setup row can be long; option: let the solo play tasks name more pages so fewer are forced into setup.
- PT-R15 could not be used: its microphone permission is off and `simctl privacy grant` was refused here; Haylee may
  want to re-allow the mic on that sim.
- **Needs the real iPad:** hearing the story and the setup/clean-up lines in her voice; the timing of the auto-advance
  after the story; kids actually setting up with real props.
