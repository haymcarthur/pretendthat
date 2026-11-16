# Round C1: generate for 6 (ranked roles, a step per playing role, rotating hand-offs, 6-up badge sheet)

**Date:** 2026-11-15 · **Decided by:** Haylee (the design, and answer 2: "every role gets called out"). Details are
Claude's calls, noted. Design: [saved games + replay design §C and §10](../../docs/superpowers/specs/2026-11-15-saved-games-replay-design.md).
This round built all of section C (the design's C1 and C2 rounds), changed by answer 2.

## Haylee's decisions
- Every game is written for 6: **6 ranked roles** (R1 the lead … R6), one kid each. The app shows, says and prints only
  the N playing roles (the first N).
- **Answer 2 (changed the design):** every playing role (1–6) gets its OWN checklist step, called out by its title, in
  EVERY scene. No optional extras. Hand-offs rotate through all the playing roles so each kid gets a turn.
- One **6-up badge sheet** image (3 × 2 portrait), sliced into role badges; N kids print N badges.
- Changing the count makes **no AI call** (roles, checklists, badges).

## Claude's calls
- **Scene shape:** Claude writes exactly 6 scenes, each with 8 steps: one per role R1–R6 (tagged `role`, text starts with
  the title) + 2 for everyone (`all`). Scenes have no owner any more (removed from the schema).
- **What N kids see** (`PlayCast`, pure): each playing role's step (a missing one is written from the role's job, after
  one Claude retry via `Validate.scenes`; a step that forgot its title gets "Navigator, …" in front), then as many group
  steps as fit, at most 6 rows (N=1 → 3 rows, N=4–6 → 6). The last group steps are kept (often the finale).
- **Hand-offs:** scene i belongs to playing role i mod N (R1, R2, …). With 6 scenes every kid holds the iPad at least once.
- **Names of roles that aren't playing:** step and title text → "a friend"; scene-intro sentences naming one are dropped
  (the "Pretend that" sentence stays). The prompt also asks that intros/group steps name only R1.
- **Ranking:** `RoleCast.rank` keeps the given order, drops repeats, caps at 6 and fills gaps with generic extras
  (Helper, Lookout, Cheerleader, …). `Role.count` stays in the type (always 1) so old data decodes.
- **The store** keeps `fullKit` (as written, for 6); `kit` is the N-player view, so all play code (checklist, cheers,
  Repeat, Done, hand-off lines) reads only playing roles. `playingRoles` is new.
- **Count change after the roles (voice):** during Pick/Props/Paper it is applied with no call, she says
  "Five friends! Our crew is a …!", the kit pages being written are NOT restarted (`KitInputs` no longer depends on the
  count), and Play starts over from scene 1 next time. During Play she says to tap Pick on the step rail (changing the
  rotation mid-scene would be confusing). Before the roles, the round 19 recap flow is unchanged.
- **Role colors R5/R6:** button coral (`coralStrong`) and Nutmeg brown (`nutmeg`); both ≥3:1 with white.
- **Badge sheet:** 1024×1536, prompt lists each role and job in order; sliced with the cut-out boundary search but
  `trimToSquare: false` (portrait cells). The app still prints "Name: ____" and the role title on each slice. If it
  fails or doesn't give 6 slices, the old shared badge image is used. Checklist `badge:Rk` pictures show slice k.
- **Draw it!:** badge/ticket counts come from the current count at display time (`DrawIt.line(…, players:)`).
- **Cost logging:** `ClaudeUsageMeter` records token counts per call (numbers only), logged in debug builds.

## Measured cost (Claude, `LiveCostTests`, LIVE_COST=1, same pirate game, 4 runs each)
- Before (HEAD, N roles, 4–6 scenes of 3–5 steps): pages 2.8¢ + play guide 4.5¢ = **7.2–7.6¢ a game**.
- After: pages 2.8¢ (unchanged) + play guide 7.7¢ (≈2,850 output tokens vs 1,350) = **10.5¢ a game, +3.1¢** (+43% of
  Claude; about +2% of the ~$1.60 game). A retry (an unusable first answer) adds ~3–8¢; it happened in 1 of 4 test runs
  and in the 2-player live run. Images unchanged (1 badge sheet replaces 1 badge image). Realtime: +a few dozen tokens.
- The play guide is longer to write: the live 2-player kit was final 30 s after Paper (it included one retry).

## Tests and live checks
- NutmegCore 310 green (`RoundC1Tests`: schema limits, per-role coverage at N=1–6, rotation, no-AI count change, badge
  slicing and fallback, Draw it! counts, colors). Relay unchanged (no redeploy).
- Live (typed, PT-R15-iPad): 2 players (pirates on the moon): hand-offs Captain → Navigator → Captain…, every scene
  "Captain, …" + "Navigator, …" + 2 group steps, 2 role badges from the sheet. 5 players (moon bakery, said 3 then
  "actually five" during the hunt: no Claude call, her line word for word): 5 rotating hand-offs, 6-row checklists fit,
  5 role badges. Screenshots in `/tmp/pt-roundC1/`.
- Not checked: a printed badge page (slices are ~120 dpi and look a little soft on screen), a 6-player checklist on
  screen, the tap fallback path live, spoken (mic) count changes.
