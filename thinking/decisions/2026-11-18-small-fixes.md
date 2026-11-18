# Small fixes: no pale-letter re-color, the Claude meter prices each model, "game" not "show"

- **Date:** 2026-11-18
- **Decided by:** Haylee (the three items, from morning-2026-11-18.md and research/2026-11-18-cost-per-game.md). How each
  was built is Claude's call, noted below.

## 1. No automatic pale-letter re-color on color pages
- **Why:** it cost about 10¢ a game and fixed nothing. In the pet hotel game 3 pages were re-colored, all 3 were still
  flagged, and the letters were readable anyway.
- **Removed:** the redraw for pale letters (`ColorInFlow`) and the "darker letters" note in the re-edit prompt.
- **Kept:** the no-pale-letters rule in the color prompt (`ColorInPrompt.letters`), and the word check on the color page
  with its ONE re-edit (an edit once turned "002" into "202").
- **Contrast check (Claude's call):** it stays as a log line only. It runs on the device with no AI call, inside the
  Vision read the word check already does, so it costs nothing. The log reads "N pale letter box(es)" and
  "(pale letters: logged only)". A pale page never causes a redraw.
- **Cost:** about 10¢ less per game (3–4 re-edits at 3.4¢ each). Measured $1.01 becomes about $0.91 (estimate; not
  re-measured live).

## 2. The Claude cost meter prices each model
- **Why:** `[CLAUDE] usage` cents, `#cost`, and `LIVEKIT COST` priced every call at Opus rates. The guide and the
  weaves run on Sonnet, so the meter read about 10¢ a game too high (logging only; no plan math used it).
- **Now:** `ClaudePrices` (NutmegCore/ClaudeClient.swift): Opus 5.5 $4 / $20, Sonnet 5.5 $2 / $10 per 1M tokens, from
  research/2026-11-18-cost-per-game.md (the claude-api skill's 2026-11-03 table). Each metered call stores the model
  that answered (the response's `model`, or the model the app asked for if the response has none) and is priced at
  that model's rate. `#cost` now also prints the Claude cents.
- **Not in the repo:** Haiku's price (and any other model's). Those use `ClaudePrices.unknownModelFallback` = Opus
  rates, so the meter can read high but never low.

## 3. "Game", never "show"
- **The End:** "The end! What a game! Take a bow! This game is saved, so you can play it again later. Tap the arrow to
  play it again, or the house to go home!" (`HandOffLines.endLine`).
- **Re-recorded clip:** one live `-PTRecordCommon` run on a throwaway simulator (deleted afterwards), through the relay
  with no personal keys. ONE take: 292 Hz raw (in the 230–307 Hz band), 12.1 s (10.1 s heard at ×1.20), words exact.
  New file `common-0ef40155….aac`; the old `common-6d87e6be….aac` was removed. The band test passes on all 14 clips.
  The line went through the scripted-lines session (gpt-realtime-2.1-mini, on by default since round 44). That is the
  same session that says The End in a live game, and it uses the same voice settings as every clip (coral, varispeed
  1.2, +2 st). **Cost ≈ 1¢** (7,291 text in, 136 text out, 246 audio out on mini).
- **Other lines that called the game a show (Claude's call, all changed to "game"):** the scene opener "Pretend that the
  game is starting!", the setup and clean-up lines used when a game has no title ("Pretend that the game starts in just
  a minute…" / "…is over for the night…"), the fallback story "Welcome to our game!", the clean-up filler "…a big high
  five for a great game", the bundled airplane game's "Ooh! Let's play a game! Which one?", and two model instructions
  ("running the game", "keep the game moving").
- **Left as "show":** Show Pass (the plan); shows that ARE the game (puppet show, talent show, cooking show, show
  program); code and log names (`ShowTicket`, "SHOWS relay…").
- **Tests:** `GameNotShowTests`: the End line; no "show" in her fixed lines, bundled lines, or the fallback game; every
  bundled line has its own clip file (catches a stale clip). `ClaudePricesTests`. Updated: `ColorInFlowTests` (pale
  letters are logged and never re-colored; the word re-edit is unchanged) and the round 26/42 End-line tests.
  709 tests pass.
