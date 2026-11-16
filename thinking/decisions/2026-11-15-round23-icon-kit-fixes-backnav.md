# Round 23: Haylee's Repeat icon, kit fixes (6 players, exact badges, $1 money), back-navigation, step renames, point fix

**Date:** 2026-11-15 · **Decided by:** Haylee (every item, plus the mid-round changes below); the details are
Claude's calls, noted.

## 0. The Repeat icon is Haylee's own (Haylee: "Replace this")
- Her ChatGPT icon, vectorized in Figma (node 75:148). Cleanup only, no redraw: the green background deleted; the green
  shape inside the speaker was a hole, so it was **subtracted** from the speaker body (deleting it would have filled the
  speaker in solid). Then everything was flattened into one vector, filled with the app ink **#2A1846** (the brief said
  #2A1A4A; `BrandPalette.ink` is 2A1846, so Claude used the app's value), and the frame was made square (1046) with even
  padding and no fill.
- Figma: renamed "UI icon / Hear it again (Repeat)" in a new **"UI icons"** section under "App icon & branding"; the
  hidden source raster moved to the raw-references section.
- Export: `design/export/ui/icon-hear-again.svg`, added as `icon-hear-again` (template rendering, preserves vector data).
  `PTIconButton` gained `asset:` (round 22's composed `ring:` is gone). *Claude's call:* 0.56 × the button (0.5 looked
  lighter than the chat icon), same ink, same 0.4 dim. Label "Hear it again" unchanged. `/tmp/pt-round23/pill-zoom.png`.

## A. Kit and player fixes (Haylee)
1. **Players 1 to 6.** `Players.max` 8 → 6; the tap picker's "6+" is now "6". The Realtime step 3 and the
   `set_player_count` description say 1 to 6 (max 6). *Claude's call:* the schema has `minimum: 1` but no `maximum`, and
   the model is told to call it with the number the kid said: the app answers anything over 6 itself
   (`Players.overCapOutput`: "Wow, what a big crew! Up to six friends can play. Should we make it six?") and changes
   nothing, so the cap line is deterministic. A schema maximum would let the model silently clamp to 6. A yes → 6;
   another number → that. After the kit is made the old "the kit is made for N" answer still applies.
   Live: "Eight friends are playing" → the cap line word for word; "Okay, two friends" → the recap for two.
2. **Badges = exactly the player count.** The bug was `KitLayout` padding the 3 × 2 badge page with spare badges. Badges
   now print one per kid (2 kids → 2 badges; the rest of the page is blank). Tickets still fill their page. The badge art
   is still one shared image the app prints role titles onto, so section C's 6-up sliced sheet isn't blocked.
   Live (2 players): `/tmp/pt-round23/badges-page-2-players.png` (Moon Baker, Starlight Assistant).
3. **Money = one $1 bill page.** The Claude recipe guide says every bill is $1; the sanitizer forces `bigNumber` to "$1"
   and rewrites any other amount on a bill; the image prompt says "a ONE-dollar bill". Menu prices: the guide asks for
   whole dollars $1–$5, and the sanitizer rounds cents and caps at $5 (`Money.smallPrices`). The airplane fallback's bill
   was "5", now "$1". Live: `/tmp/pt-round23/money-page.png` (8 Moon Dollars, all $1), `menu-page.png` ($1, $2, $3, $5, $1).
   - **"More money" button: built, then removed (Haylee, after seeing it).** No extra print button; the money page
     prints with the kit (and Print again).

## B. Clearer navigation back (Haylee)
1. **Step rail:** every step shows a picture (masks, box, paper + crayon, play) instead of a number or check. Finished
   steps are lime with a small ↺ badge; a later step already reached (after going back) gets a ↻ badge; both shrink and
   dim a little when pressed (`PTRailButtonStyle`). The current step stays yellow with the ring; steps not reached are
   faded and disabled. Targets 72 × 64 pt. Same rail with the chat open or closed.
2. **One navigation path.** Rail taps and voice both go through `AdventureStore.goTo` (unchanged behavior; now
   returns whether it moved, with `canGoTo`). On a tap Nutmeg says one arrival line (`BackNav.arrivalLine`, e.g.
   "Back to Paper! Tap Print to print it again.") and the conversation gets a silent note of where the kids are.
3. **Print again buttons: built, then removed (Haylee: the rail's ↺ marks are enough).** They sat beside Done! on the
   checklist, under Done! in the chat panel's Checklist tab, and on The End, and printed the cached kit directly. Those
   screens are back to their pre-round layout (PlayScreens.swift is unchanged from before the round).
4. **Voice:** new `go_to_step` tool (pick / props / paper / play; "game" and "print" are accepted too). Its result is
   "Say exactly: <arrival line>", so it's one spoken reply in the chat. `print_kit` during play also goes back to Paper.
   *Found live (run 1):* round 22's play-step coaching said "No tools", so "Can we print it again?" got a chat answer
   and no move. *Run 2:* with the tool offered it moved, but the model talked first ("Sure, let's jump back… let me
   switch things") instead of the arrival line. *Fix (Claude's call):* after the hunt a kid turn is tool-first like
   planning (`Realtime.afterHuntTools`: Paper = start_play / print_kit / go_to_step / just_talk; hand-off adds
   confirm_handoff; play and The End = go_to_step / just_talk), and `just_talk`'s result is phase-aware (help the
   scene; at Paper no "go play"). Costs one silent text pass (~0.5 s) on post-hunt turns. Barge-in rules unchanged (a
   rail tap is `UserAction.stepRail` and stops her speech first).

## Mid-round changes (Haylee, after seeing the simulator screens)
- **Step names: Pick · Props · Paper · Play** (were Game · Get Ready · Print · Play): rail labels, accessibility,
  arrival lines, the tool's step names, README, pitch script, design spec. The buttons that really print still say
  **Print** and **Print again**. Paper's icon is a sheet with a crayon (`doc` with a `pencil` overlay, both iPadOS 13+),
  not a printer, since round 24's no-printer path draws instead.
- **No "Skip" on the props grid.** It ran the same `confirmProps()` as All set! (no voice mapping for skipping the whole
  hunt; per-prop `skip_prop` / "Don't have it" stay). The grid (`PropsView`) is only the tap fallback (no Realtime) and
  the `-PTDemo props` screen; the live hunt uses the one-at-a-time card and presented cards, also when going back to
  Props.
- **No arrows on prop cards:** the item name big, the pretend use as a smaller line under it ("Chair" / "Airplane
  seats"). Only the grid card (`PTPropCard`) had the arrow; the live cards already used a plain second line.
- Screenshots: `/tmp/pt-round23/props-before.png` → `props-after.png`; `print-before-with-more-money.png` →
  `print-after.png`. The grid shot is the `-PTDemo props` screen.

## Pointing at nothing (Haylee, seen on the simulator)
- After a prop was found the card moved to the done stack but she kept the 60 s point aimed at the empty card zone.
- `PoseRules.holdsPoint(huntActive:cardShown:cardDone:)`: the point holds only while the current card is on stage and
  still open. `AppModel.releasePointIfNoCard()` runs right after every hunt change (the Found it / Don't have it taps
  and every tool call: mark_found, skip_prop, finish_planning) and drops the point in the same tick as the card
  leaving; the next card's reveal points again (unchanged). A swap keeps the point (the card stays). The pose swap is
  still throttled by `minSwapInterval` (1.5 s since her last swap), so a very quick answer can lag by that much.

## Tests and checks
- NutmegCore: 276 tests green (was 266). New `Round23Tests` (cap line + nothing changes, exact badges 1–6 and a 2-player
  kit, $1 bills, menu prices, rail pictures/marks/labels, voice navigation through `goTo`, tool-first after the hunt,
  `canGoTo`) and `Round23PointTests` (no visible card → no point). Updated: the
  smallItemsFill test (badges excluded), set_player_count decode, the 6-kid role test, the session tool list.
- Live (typed, PT-R15-iPad, personal keys): `/tmp/pt-round23/live1/` (cap line, 2 players → 2 badges, $1 money,
  rail tap back to Print), `live2/` (voice moved but paraphrased), `live3/` (final build: "Can we print it again?" →
  go_to_step → "Back to Paper! Tap Print to print it again."; rail tap → "Back to Play!…"; "Go back to the props" →
  "Back to Props! Here's everything for our game.", each one reply in the chat).
- Screenshots: `rail-closed-checklist.png`, `rail-open-checklist.png`, `the-end.png`, `print-after.png`,
  `paper-step-chat-open.png`, `props-after.png`, `live-paper-after-voice.png`, `live-back-to-props.png`,
  `badges-page-2-players.png`, `money-page.png`, `menu-page.png`, `pill-zoom.png`.
- Odd, not explained: in live3 a page preview was open at the Paper step (paging 1 → 3). Nothing in the code opens it
  without a tap (or the DEBUG `-PTPreview` flag, not passed); runs 1–2 didn't show it, so it was most likely a manual tap
  on the shared simulator.
- Not checked: the AirPrint sheet itself (simulator), spoken (mic) back-navigation, the point release caught on camera
  in the instant between a found card and the next card (unit rule + code path only), a real iPad.
