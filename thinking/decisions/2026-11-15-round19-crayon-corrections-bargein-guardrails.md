# Round 19: crayon motion back, corrections update everything + confirm step, barge-in on taps, kid-safety guardrails

**Date:** 2026-11-15 (after the competition). **Who decided:** Haylee asked for all four items. The implementation details are Claude's calls, noted below.

## 1. The writing hand moves as one unit (Haylee)
- **Cause (checked):** the fingers layer draws over the crayon's middle and stayed still. Round 10's rock moved only the crayon, so only its ends moved and the middle looked glued to the paw.
- **Fix:** the crayon AND the fingers layers get the same scribble, `2.4·sin(2πt/0.3) + 0.8·sin(2πt/1.3)` degrees (at most ±3.2°). It pivots at the wrist, art point (592, 640), the left edge of the fingers layer where the body's arm takes over. The body and clipboard stay still. Layer order is unchanged (body → crayon → clipboard → fingers). There are no art edits, Reduce Motion keeps it still, and it only runs while `writing`.
- **Checked:** offline renders of the real SVG layers at −3.2° and +3.2° (`/tmp/pt-round19/crayon-extreme±3.2.png`). There's no gap at the wrist, since the body art has the paw underneath. The tip (art ~750, 685) stays at the clipboard's edge as before.

## 2. A correction updates everything, plus a confirm step (Haylee)
- **Root causes (Claude's trace):** (a) on the player-count step, the voice model's tool-first pass could only call `set_player_count`/`just_talk`, so a theme fix said in that turn could never reach `set_theme`. Roles and props only used the fix in words. (b) The kit art title came from `plan.gameTitle`, a snapshot taken when the roles were set.
- **One source of truth:** `AdventureStore.context` (every Claude request) and `currentTitle` (kit art prompts, print job, recap) are read at call time. The plan's title is kept in step with the current one.
- **Corrections at any step:** the tool descriptions and instructions say to call set_game/set_theme/set_player_count again with the fix. Those tools are offered on every planning step's tool-first pass, including the hunt.
  - A fix before the count is known stays on the count question.
  - With a count, a fix goes to the confirm step.
  - After roles or props exist, they're cleared, the count is kept, and she says she'll redo them, then recaps.
  - At the print step (kit being made or ready), the kit is remade for the new title. She says "Ooh, a candy shop! Let me fix your kit to match." The old page art is dropped, using a generation counter in KitArtService and in the store's kit request.
  - Once play has started, the adventure stays as printed. She says "tap New game".
- **Confirm step (`PlanningStep.confirm`, `ConfirmStep`):** after set_player_count she says the recap word for word: "So it's a bug movie theater for three friends! Ready, or want to change something?" Two big buttons appear above the pill, "Yes, let's go!" and "Change something". Voice works too: yes → `confirm_plan`, a change → the set_* tools, then a fresh recap.
  - After a tool-first pass on this step, the app adds the newest recap as a note. That way set_theme and set_player_count in the same pass recap the final state, still one reply.
  - Yes (tap) confirms at once and she goes straight into the planning line. set_roles is refused before the yes.
  - The turn check accepts the recap question on this step. Everywhere else it still blocks "Ready?".
- **Claude's calls:** recap phrasing ("just for you" for 1; no article for plural names; lowercase words except acronyms). A player-count change after the kit is made isn't remade (the roles would change); she points to New game.

## 3. Taps that move on stop her speech (Haylee)
- `UserAction` (NutmegCore) lists the actions. Everything stops her except chat tab switches and opening/closing the chat: check/uncheck, Done, Back, hand-off, Found/Don't have, Print, Let's play, Repeat, Play again, New game, close/leave, step rail, confirm buttons.
- **How it stops:** every response is tracked by its id (`SpeechStop`). That covers her replies AND out-of-band app lines (cheers, scene lines, the ready line). A stop sends `response.cancel` with each id. Responses asked for just before the tap are cancelled the moment they're created. The local player is cleared, and late audio or words from a cancelled response are dropped. Pending cheer, repeat and deferred lines are cancelled. Then the newest line plays. (The WebSocket API has no server output buffer to clear, so clearing the local player is that step.)
- **Chat:** a line cut mid-way is marked with "…". Cancelled lines that never played never reach the chat.
- **Home is silent:** New game now goes all the way home (`leave()`: it hangs up). It used to set the start screen with the session still live, which is how she kept talking there. Phase `.hello` always disconnects.
- The kit-ready line is never said late after the kid already tapped Let's play.

## 4. Kid-safety guardrails (a judge asked; Haylee)
- **Realtime:** a `KID SAFETY` block sits at the top of the session instructions. Never violence or weapons, self-harm, sexual content, drugs or alcohol, scary or gory content, hate, or strangers. Never suggest going outside alone, the stove, knives, fire or medicine. Steer without repeating the unsafe words, never ask for or repeat personal info, and "Please go get a grown-up right now" if a kid seems hurt. The Claude system prompt got the same rules.
- **Local filter (`Sanitizer.kidSafety`):**
  - Normalization: case, accents, look-alike digits/symbols ("k1ll", "$ex"), stretched letters, spaced-out letters.
  - Matching is whole-word, with an allow list ("shooting star", "fire station" is fine). It also catches phone/email/address patterns.
  - Categories map to steer lines. Self-harm and hurt/danger get the grown-up line.
- **Moderation:** `ModerationClient` (`omni-moderation-latest`, POST /v1/moderations). Personal key: direct. Otherwise the relay's new `/v1/moderations` route (token, its own `MODERATION_LIMIT` 60/min, model forced, 1–32 text inputs ≤ 4,000 chars, no images). It fails safe to the local filter (4 s timeout).
- **Where it runs:**
  - Typed kid text is checked before it's sent or shown.
  - Tool-call text (game/theme titles, roles, what a prop becomes, idea lists) is checked before the app uses it. If flagged, the tool output tells her not to use it and to steer.
  - The tap-fallback free speech is checked before it reaches Claude.
  - Spoken turns go straight to the voice model (its instructions handle them). The app adds a backstop: a transcript that sounds like danger or self-harm gets the grown-up line at once.
  - Claude's JSON (ideas, plan, props, kit, turns) is checked. If flagged, it's regenerated once with a "kid-safe only" note, then falls back to the bundled game.
  - Image prompts come only from checked text, end with a safety suffix, and send `moderation: "auto"`. The relay forces auto too.
- **Fresh ideas every redirect (Haylee, added mid-round):** every steer-away offers 3 NEW game ideas from the Suggestions pool (`SteerIdeas`). It never repeats one already offered or mentioned this session: today's game ideas, the theme ideas, the chosen game, earlier redirects. When the voice model writes the redirect (a blocked tool call), its note carries that fresh set and says not to repeat earlier ideas. Memory only, reset each game. Live: three redirects in a row gave 9 different ideas, none from the greeting.
- **Privacy:** nothing is stored. Logs show the category only, never kid text. The prop rules (soft household items) are unchanged.
- **Claude's calls:** swords and knives are blocked as weapons, even for knights and pirates (moderation would allow them; Haylee can relax this). Fire is only blocked as an action ("start a fire"), so firefighters and fire stations still work. Slurs aren't spelled out in code; moderation covers hate.

## Tests and checks
- NutmegCore: 231 tests green (was 202). New: Round19ConfirmTests, Round19SpeechStopTests, Round19SafetyTests + Round19SteerIdeasTests (three redirects never repeat an idea; an unsafe/safe input table, normalization, every bundled suggestion/prop/kit line passes, steer lines, moderation decode and fail-safe, regenerate-then-fallback, image suffix + moderation). Relay: 41 tests (moderation route, forced model, limits, token, no logging, images forced to auto).
- Live typed runs on PT-R15-iPad (/tmp/pt-round19/live1–3):
  - The kid fixed "bus" → "bug" while answering the count. set_theme + set_player_count ran in one pass, and she recapped "So it's a bug movie theater for three friends!…". After Yes, the roles and props fit, and the kit was "Bug Movie Theater" with bug scenes.
  - Fast checklist taps cancelled the queued cheers and scene lines (the chat kept only what was spoken). New game → home: silent, session idle, for 3 s.
  - Typed "guns and kill people" and "hit and punch the baby" were blocked (moderation flagged the second). She steered "Ooh, let's pick a different adventure! How about…" and a bakery went on normally.
- Not live-checked: the confirm buttons by voice "change" path, the print-step remake, and the spoken grown-up backstop (unit tests only).
- **The relay needs a redeploy** (new route + `MODERATION_LIMIT` binding) once it's deployed at all.
