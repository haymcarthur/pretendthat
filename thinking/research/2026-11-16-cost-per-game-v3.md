# Cost per game v3: current build, cheaper Claude, mini voice for scripted lines (2026-11-16)

Haylee asked: "can we test the cheaper claude model and the nutmeg scripted lines on cheaper voice model?", plus a re-measured
cost per game on the current build (rounds 29 to 31: ensemble scenes with no hand-offs or cheers, 4 or 5 props, on-device
speech with text-only turns). Measured by a background agent (Claude) in its own worktree, clean build
(`build/DD-cost3`, the experiment flags and round 29/31 strings confirmed in `PretendThat.debug.dylib`), simulator
iPad Pro 13-inch (M5), personal keys, typed live games. Same count-only logging as v2 (commit fcb26b5); nothing logged
content about kids. Raw logs: `/tmp/pt-cost3/<run>/console.log`; Claude outputs side by side: `/tmp/pt-cost3/claude/`.

**Bottom line**

- **A new game now costs about $1.03** (measured $0.97 for 3 players, $1.09 for 5 players with a skip). Down from $1.20,
  mostly because the play phase has no hand-off lines or cheers any more: only 6 app lines a game (3 scene openings,
  print-ready or save, The End).
- **Cheaper Claude:** move the **play guide** and the **per-prop weave** to **Sonnet 5.5**; keep **Opus** for the kit
  pages (and the tap-path plan). Saves about **$0.09 a game** with no quality loss found. Haiku 5.5 is nearly free, but
  its weaves broke the task format and its kit pages printed instructions on the badges, so not for these calls.
- **Mini voice for the scripted lines:** works. 32 of 32 test lines were said word for word, first audio comes sooner
  (about 0.55 s vs 0.83 s), and it saves about **$0.16 a game** ($0.14 to $0.19). **Haylee needs to listen** to the A/B
  files in `design/voice-ab/` before this ships (her rule: Nutmeg's voice never changes).
- **Both together: about $0.78 a game** (measured $0.72 on a 3-player game with both flags on).
- **Limits (monthly plans):** at today's $1.03, Show Pass **8** and Season Pass **12**. With both changes ($0.78), Show
  Pass **10** and Season Pass **15**. 20 or 30 a month still loses money in every scenario; yearly at 33% off is only
  safe at Show 6 / Season 10.

## 1. Prices used (checked 2026-11-16)

**Anthropic** (the `claude-api` skill, model table cached 2026-11-03), per 1M tokens: `claude-opus-5-5` $4 in / $20
out; `claude-sonnet-5-5` $2 / $10 (cache read $0.10); `claude-haiku-5-5` $0.10 / $0.50 (prompts up to 100K tokens).
No Claude call hit the cache (every prompt is different), so cache prices don't matter here. The skill also says Haiku
5.5 has **no server-side refusal fallback**, so the experiment leaves `fallbacks` off for Haiku.

**OpenAI** ([pricing page](https://developers.openai.com/api/docs/pricing), fetched 2026-11-16), per 1M tokens:

| Model | Text in | Text cached | Text out | Audio in | Audio cached | Audio out |
|---|---|---|---|---|---|---|
| gpt-realtime-2.1 | $4.00 | $0.40 | $24.00 | $32.00 | $0.40 | $64.00 |
| gpt-realtime-2.1-mini | $0.60 | $0.06 | $2.40 | $10.00 | $0.30 | $20.00 |

- gpt-image-2.6-flare (same as 2.5-flare and gpt-image-2): text in $5, image in $8, image out $30.
- omni-moderation-latest: free.
- Note: v2's app-side estimate (`RealtimeUsageTotals.dollars`) uses $16 for text out; the page says **$24** for
  gpt-realtime-2.1. This doc uses $24 (it adds about a cent a game).

## 2. Baseline: the current build

| Run | Script | AI calls |
|---|---|---|
| Game A | 3 players, "pizza restaurant in the jungle", all 5 props found, played to The End, saved | 34 Realtime responses, 8 Claude, 13 images, 26 moderation |
| Game B | 5 players, "pet shop for dragons", 5 props with 1 skipped, played to The End, saved | 34 responses, 7 Claude, 15 images, 27 moderation |
| Replay of B | Shelf → B → "Five of us" → found it × 5 → play to The End | 18 responses, 0 Claude, 0 images, 1 moderation |

| Service | Game A (3 players) | Game B (5, 1 skip) |
|---|---|---|
| Realtime, conversation (28 responses; 95% of input cached) | $0.313 | $0.319 |
| Realtime, app lines (6 `sayExactly`: 3 scene openings, The End, save, a short line) | $0.181 | $0.250 |
| **Realtime total** (audio out 4,273 / 4,980 tokens ≈ 3.6 / 4.2 min) | **$0.494** | **$0.569** |
| Claude Opus 5.5: pages (medium) + early guide (low) + a weave per prop (low) | $0.201 (8 calls) | $0.194 (7 calls) |
| Images (2.6-flare, both print styles + cover; the skip adds 2) | $0.275 (13) | $0.326 (15) |
| Moderation / transcription | $0 (free) / $0 (none: round 31 sends no audio) | $0 / $0 |
| **Total** | **$0.97** | **$1.09** |

What changed since v2 ($1.02 / $1.25): the play phase used to be 23 to 37 responses (hand-offs, checklist intros, cheers);
now it's 6 app lines. But each scene opening is long (25 to 41 s of her voice, 560 to 800 audio tokens), so app lines
are still **37 to 44% of the voice bill**. Claude went up a little ($0.15 → $0.20) because there's a weave call per prop
and 5 props now, and the weave thinks more on later props.

Typical / low / high for a new game: **about $1.03 typical**, about $0.90 low (2 players, 4 props, no chatter), about
$1.70 high (6 players, 2 skips, lots of chatter, a theme change that remakes the kit). Real spoken turns now cost the
same as typed ones (on-device speech sends text), so v2's +$0.02 kid-audio line is gone.

**First replay: $0.30** (v2: $0.14). This replay's answers differed from the first play (the skipped flashlight was found),
so 2 of 3 scene openings had different text and were said live (the clips didn't match), plus 6 replay hunt lines.
A replay with the same answers would be close to v2's $0.14; later replays about $0.03. With mini app lines (section 4)
the first replay would drop to about $0.12.

## 3. Cheaper Claude for the small calls

### The calls

| Call | When | Effort | Path | Opus cost |
|---|---|---|---|---|
| `kitPages` (the 6 printed pages' text) | during the hunt | medium | voice | ~3.2k in / 0.8k out = $0.029 |
| `earlyGuide` (3 scenes × a task per role + solo) | as the pages land | low | voice | ~4.0k / 1.0k = $0.036 (+ a retry sometimes) |
| `weaveProps` (each prop into 1 to 3 tasks) | per prop card | low | voice | ~3.4k / 0.2–0.9k = $0.018–0.031 each, 4–6 a game |
| `kitScenes` (guide fallback if the early guide failed) | hunt end | low | voice (rare) | as the guide |
| `plan` (roles), `props`, `ideas`, `kit` | tap / no-voice path only (in a voice game, roles come from the Realtime `set_roles` tool) | medium | tap | plan $0.021 |
| `help`, `turn` | tap path | low | tap | $0.013 |

New DEBUG flag: **`-PTClaudeModels "guide=claude-sonnet-5-5,weave=claude-haiku-5-5"`** (launch argument) or the
`PT_CLAUDE_MODELS` environment variable (live tests); keys are `ideas, plan, props, kit, pages, guide, weave, turn, help`
or `all`. `PhaseService` tags each call (`ClaudeRouting.call`, a task-local), `ClaudeClient` picks the model and logs
`call=` in the usage line. Release builds always use `claude-opus-5-5`.

### Same 3 setups, all three models

`LiveModelCompareTests` (NutmegCore, `LIVE_COMPARE=1`): fixed roles (R2 is always the customer counterpart) and fixed props,
then pages → early guide → one weave per prop → the final guide (skips applied, `GuideRepair`, safety check), plus the
tap-path plan and a help call. Setups: A pizza restaurant in the jungle (3 players, 5 props), B pet shop for dragons
(5 players, 5 props, flashlight skipped), C space station with robots (2 players, 4 props). Outputs:
`/tmp/pt-cost3/claude/{opus,sonnet,haiku}/` (raw JSON per call, a readable `*-guide.md` per game, `summary.txt`).

| Check (3 games each) | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 |
|---|---|---|---|
| Schema valid, every call | yes | yes | yes |
| Validation retries | 1 (guide C) | 0 | 0 |
| 3 scenes, a task for every role + solo | 3/3 | 3/3 | 3/3 |
| "Pretend that" setups | 9/9 | 9/9 | 9/9 |
| Real-props rule (objects the kids don't have, before repair) | 2 ("shell", "radio") | 0 | 1 ("wheel") |
| Scripted lines (quotes) | 0 | 0 | 0 |
| Tasks with 3+ parts (rough count, of 21) | 3–6 | 3–4 | 2–3 |
| Final guide passes the safety check | 3/3 | 3/3 | 3/3 |
| Customer roles in the plan (tap path) | Monkey Guest, Dragon Buyer, Space Visitor | Jungle Customer, "VIP Owner" (pet shop), Space Visitor | Hungry Customer, Dragon Customer, Alien Visitor |
| Guide time | 11 s (20 s with the retry) | 9 s | 13–16 s |
| Weave time, whole hunt | 21–34 s | 12–18 s | 26–35 s |

**Quality by eye** (the `*-guide.md` files):
- **Sonnet** reads as well as Opus. Tasks are interactive and connect across roles ("Server, write down the order on a
  Pizza Order Ticket and carry it to the Pizza Chef on the pizza tray!"), customers are real customers, props land in
  sensible places. Kit pages are a bit plainer ("Role Badges", "Pet Shop for Dragons" vs Opus's "Sparkle Scale Dragon
  Shop" with "Gentle Hands Please").
- **Haiku** writes a decent guide, but its **weaves broke the format**: some solo rewrites dropped the role title
  ("Pretend to be the Shopkeeper alone: …", "Pretend the shop is packed: welcome visitors…"), and it gave the vet's light
  to the Shopkeeper. Its **kit pages printed instructions** on the badges ("Wear your badge all game", "Write your name on
  the line") and the menu had 5 items, not 6. It also thinks a lot (2–4k output tokens per guide), so it's slower than
  Sonnet. Its help lines were fine.

### Recommendation per call

| Call | Recommendation | Opus → new, per game | Why |
|---|---|---|---|
| Kit pages | **Keep Opus** | $0.029 | It's the printed product kids hold; Opus's pages are the most inventive. Sonnet would save only $0.015 |
| Play guide (early guide + fallback) | **Sonnet 5.5** | $0.048 → $0.020 | Same quality, fewer retries, 2 s faster at Print |
| Per-prop weave | **Sonnet 5.5** | $0.111 → $0.046 (5 props) | Same quality, about twice as fast |
| Plan (tap path) | Keep Opus | $0.021 | Sonnet's pet-shop plan had an odd "VIP Owner" customer; the tap path is rare anyway |
| Help / turn (tap path) | Haiku 5.5 is fine; Sonnet to be safe | $0.013 → $0.0004 / $0.006 | Short, one line |

**Savings: about $0.09 a game** (measured: game A's Claude bill $0.201 → $0.105 in the both-flags game, which even wrote
the guide twice). **To ship it, the relay needs the new models:** `relay/src/index.ts` has
`CLAUDE_MODELS = ["claude-opus-5-5"]`; add `claude-sonnet-5-5` (and `claude-haiku-5-5` only if help moves to Haiku), and
move the per-call model choice from the DEBUG flag into `ClaudeConfig` (a small map). Sonnet keeps `fallbacks: "default"`.

## 4. Scripted lines on the mini voice model

**Prototype (DEBUG, `-PTMiniLines [model]`, personal keys only):** when the live session connects, the app also opens a
second Realtime socket on `gpt-realtime-2.1-mini` with `VoiceConfig.lineSessionUpdate()`: the same voice (coral), the
same server speed (1.0) and output format, short instructions that carry the same `Realtime.voiceStyle`, no tools. Every
`sayExactly` (scene openings, task read-outs, Repeat, print/kit lines, the End, save, replay Pick/hunt lines, the
silence reminder) goes to that socket; the conversation stays on the full model. Its events feed the same handler, so
Varispeed 1.20, lip sync, barge-in (tap or mic cancels on both sockets), clip recording and the chat all work as before.
Its counts are kept apart (`USAGE-LINES`, `#cost` prints a "lines session" line).

### Voice match: A/B files for Haylee

**`/Users/haymcarthur/PretendThat/design/voice-ab/`**: `01-full.m4a` … `08-mini.m4a` and `index.txt` (each line's
text). Full = the app's own session (full instructions + tools), exactly how app lines are said today; mini = the
prototype's separate session. Both coral, server speed 1.0, the same voice style, then Varispeed 1.20 applied the way the
app's pitch unit does (24 kHz played as 28.8 kHz: pitch and speed together). Lines: a scene opening, a task read-out, the
print line, a kit progress line, a replay hunt line, the replay Pick question, The End, the nothing-heard line.
Made by `LiveVoiceABTests` (2 takes per model; the files are take 1). **Not checked by ear by the agent; this is
Haylee's call.**

| | Full (gpt-realtime-2.1) | Mini (separate session) |
|---|---|---|
| Said the exact text (transcript) | 16/16 | 16/16 |
| First audio after the request (test, 8 lines × 2) | median 0.83 s (0.66–1.12) | median 0.56 s (0.34–0.93) |
| First audio in the app (game A vs game D) | 0.76–1.63 s | 0.62–1.27 s (median 0.7) |
| Scene opening length (raw, before 1.20) | 22.1 / 26.7 s | 21.2 / 21.4 s (a bit quicker, steadier) |
| Audio tokens per second | ~20 | ~20 (same) |
| Input per line | ~6,800 tokens (the whole session prefix, mostly cached) | ~250–330 tokens |

**Wording drift: none seen.** All 32 test takes and all 6 in-game mini lines matched the text (the clip recorder only
stores a line whose transcript matches, and all 6 were stored). The test lines include the long scene opening, which is
where drift would show first.

### Savings

| | Game A | Game B | Game D (mini, measured) |
|---|---|---|---|
| App lines on the full model | $0.181 | $0.250 | |
| Same lines on mini (separate session) | ~$0.043 | ~$0.059 | **$0.042** (6 lines) |
| **Saved** | **$0.14** | **$0.19** | |

About **$0.16 a game** (more with more players, since scene openings get longer). It also cuts replays: a first replay's
live lines would cost about a third.

**To ship it:** the relay pins `REALTIME_MODEL = "gpt-realtime-2.1"` and mints client secrets for that model only; it would
need to mint a second secret for the mini model. `SavedGame.voiceID` includes the model ("coral@gpt-realtime-2.1"), so
mini clips would get a new voice ID (old clips would stop matching unless the ID ignores the model). A second socket also
means a second connection to keep alive and reconnect (round 9's lock/background path only handles the main one in the
prototype). Watch out for hidden cost: the prototype opens the second socket at connect even if no line is said; that's
free (billing is per response) but counts toward connection limits.

## 5. Combined projection

| Scenario | Per new game | Notes |
|---|---|---|
| (a) Current build | **$1.03** | measured $0.97 / $1.09 |
| (b) + Sonnet for guide and weave | **$0.94** | −$0.09 |
| (c) + mini voice for scripted lines | **$0.87** | −$0.16 |
| (d) both | **$0.78** | measured $0.72 (3 players, game D) |

Remaining big items in (d): the conversation itself (about $0.31: planning talk and the hunt, 95% cached), images
($0.28 to $0.33; drawing only the chosen print style would save about $0.13, v2's lever 2), and Opus pages ($0.03).

## 6. Margin table

Apple keeps 15% (Small Business Program). Yearly prices shown per month. "Every game" = the family uses its whole monthly
limit (worst case; replays not counted). Values are what's left per month after Apple and AI costs.

**You keep:** Show monthly $8.49 · Show yearly $5.67/mo · Season monthly $12.74 · Season yearly $8.50/mo.

| Plan | Scenario ($/game) | 6 games | 10 | 15 | 20 | 30 | Break-even |
|---|---|---|---|---|---|---|---|
| Show Pass monthly $9.99 | (a) $1.03 | +$2.31 | −$1.81 | −$6.96 | −$12.11 | −$22.41 | 8.2 |
| | (b) $0.94 | +$2.85 | −$0.91 | −$5.61 | −$10.31 | −$19.71 | 9.0 |
| | (c) $0.87 | +$3.27 | −$0.21 | −$4.56 | −$8.91 | −$17.61 | 9.8 |
| | (d) $0.78 | +$3.81 | +$0.69 | −$3.21 | −$7.11 | −$14.91 | 10.9 |
| Show Pass yearly $79.99 | (a) | −$0.51 | −$4.63 | −$9.78 | −$14.93 | −$25.23 | 5.5 |
| | (b) | +$0.03 | −$3.73 | −$8.43 | −$13.13 | −$22.53 | 6.0 |
| | (c) | +$0.45 | −$3.03 | −$7.38 | −$11.73 | −$20.43 | 6.5 |
| | (d) | +$0.99 | −$2.13 | −$6.03 | −$9.93 | −$17.73 | 7.3 |
| Season Pass monthly $14.99 | (a) | +$6.56 | +$2.44 | −$2.71 | −$7.86 | −$18.16 | 12.4 |
| | (b) | +$7.10 | +$3.34 | −$1.36 | −$6.06 | −$15.46 | 13.6 |
| | (c) | +$7.52 | +$4.04 | −$0.31 | −$4.66 | −$13.36 | 14.6 |
| | (d) | +$8.06 | +$4.94 | +$1.04 | −$2.86 | −$10.66 | 16.3 |
| Season Pass yearly $119.99 | (a) | +$2.32 | −$1.80 | −$6.95 | −$12.10 | −$22.40 | 8.3 |
| | (b) | +$2.86 | −$0.90 | −$5.60 | −$10.30 | −$19.70 | 9.0 |
| | (c) | +$3.28 | −$0.20 | −$4.55 | −$8.90 | −$17.60 | 9.8 |
| | (d) | +$3.82 | +$0.70 | −$3.20 | −$7.10 | −$14.90 | 10.9 |

### Recommended monthly game limits

| Scenario | Show Pass (monthly) | Season Pass (monthly) | Yearly at 33% off (Show / Season) |
|---|---|---|---|
| (a) $1.03 | **8** | **12** | 5 / 8 (or yearly at ~17% off) |
| (b) $0.94 | 8 | 12 | 6 / 9 |
| (c) $0.87 | 9 | 14 | 6 / 9 |
| (d) $0.78 | **10** | **15** | 7 / 10 |

These keep a family that uses every game at or above break-even on monthly billing. Most families won't use every
game, so these are the safe floor, not a forecast. **Don't promise 20 or 30** in any scenario (30 needs about $0.42 a
game on Season monthly). Monthly stays the better default: it keeps 1.5x more per month than yearly at 33% off. If yearly
must carry the same limits as monthly, price it at about 17% off ("2 months free": $99.99 / $149.99), as v2 said.

## 7. What's committed (DEBUG only) and how to run it

- `ClaudeRouting` + `ClaudeCall` (`ClaudeClient.swift`): per-call model override (`-PTClaudeModels` / `PT_CLAUDE_MODELS`),
  `call=` in the usage log, no `fallbacks` for Haiku. `PhaseService` tags every call.
- `-PTMiniLines [model]`: the fixed-lines session (`RealtimeSession` line socket, `VoiceConfig.lineSessionUpdate`,
  `Realtime.lineSessionInstructions` / `lineModel`); `#cost` prints its counts.
- Tests: `LiveModelCompareTests` (`LIVE_COMPARE=1`, `PT_CLAUDE_MODELS`, `PT_COMPARE_LABEL`, `PT_COMPARE_OUT`),
  `LiveVoiceABTests` (`LIVE_VOICE_AB=1`, `PT_AB_OUT`, `PT_AB_ROUNDS`), `CostV3RoutingTests` (unit).
- Pricing script used for this doc: not committed (it lived in the worktree's `build/`); the per-run numbers are above.

Example: `EXTRA_ARGS="-PTMiniLines -PTClaudeModels guide=claude-sonnet-5-5,weave=claude-sonnet-5-5" tools/live-voice.sh …`

## 8. Open for Haylee

1. Listen to `design/voice-ab/` (8 pairs). Is mini the same Nutmeg? If yes, the mini-lines change can be built for real
   (relay second secret, voice ID, reconnect).
2. OK to move the play guide and the weave to Sonnet 5.5 (relay allow-list change)?
3. Which limits: today's (8 / 12) or after both changes (10 / 15)?
