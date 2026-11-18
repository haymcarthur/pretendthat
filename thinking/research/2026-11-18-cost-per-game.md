# Cost per game, 2026-11-18: the first live game with "draw once + color in" printables

One live game (Haylee approved exactly one) on main `4535754`, through the shared relay (version b93de830, with
`/v1/images/edits`), no personal keys (the worktree has no Secrets.xcconfig, so the Debug build uses Relay.xcconfig).
Throwaway iPad Pro 13" simulator (deleted after), typed turns via `-PTLive -PTSay`. Measured by a background agent (Claude).

- **Game:** "A pet hotel!", 4 players (Hotel Manager, Guest, Pet Caretaker, Room Decorator), 5 props all found
  (stuffed animal = pet guest, table = check-in desk, towel = drying towel, bag = pet carrier, hat = pet bed),
  Pick → Props → Print → Play (story, setup, 3 play scenes, clean-up) → The End. Saved: `BF742EA9-7C67-4476-9832-BDEE541D6C8B`.
- **Kit:** Pet Hotel Team (badges), Pet Hotel (sign), Room Key (tickets), Pet Stay List (menu), Paw Bucks (money),
  Room Tags (labels). 7.5 minutes from launch to The End.
- **Files:** console log `design/appstore-screens/saved-games/live-game-2-pet-hotel-console.log`, game folder
  `design/appstore-screens/saved-games/BF742EA9-…/`, the 6 black-and-white pages in `design/site-print-stack/`.

## Bottom line

- **A new game now costs about $1.01** (measured, real prices). The same method on the 11-17 moon bakery game gives
  **$0.73**. The difference (+$0.28) is almost all printables: drawing once + coloring in costs **$0.58** of images
  vs $0.31 before.
- **The "$0.83" from 11-17 was overstated by ~10¢:** the app's Claude meter prices every call at Opus rates
  ($4/$20), but the guide and the 5 weaves run on Sonnet 5.5 ($2/$10). Real Claude cost is ~13¢, not ~23¢. So the
  $0.83 was really $0.73, and the plan math's "$0.92 with color-in" was a +9¢ guess; the real color-in step added +27¢.
- **Biggest new cost: 4 re-edits** (3 for "pale letters", 1 for words) at 3.4¢ each = 13.5¢, and **3 outline
  redraws** (bubble letters read poorly) = 6.7¢. None of the 4 re-edits was kept as better on pale letters except one
  (labels), and all 3 pale pages were still flagged pale afterwards. Looking at the pages, the "pale" letters are
  readable (see printables check), so the contrast check looks too strict.
- **Plans still profit at full use on monthly plans, but the margin is thinner:** Show Pass monthly +$3.44 (plan math
  said +$3.89), Season monthly **+$1.04** (said +$2.84). Season yearly at full use **−$2.49/month** (said −$0.69).

## Cost table (this game)

Prices: OpenAI gpt-realtime-2.1 $4 text in / $0.40 cached / $24 text out / $64 audio out per 1M; gpt-realtime-2.1-mini
$0.60 / $0.06 / $2.40 / $20; gpt-image-2.6-flare $5 text in / $8 image in / $30 image out (from
research/2026-11-16-cost-per-game-v3.md). Anthropic (claude-api skill, 2026-11-03 table): Opus 5.5 $4/$20, Sonnet 5.5
$2/$10. Moderation is free.

| Service | Calls | Tokens | Cost |
|---|---|---|---|
| Realtime main, gpt-realtime-2.1 (Pick + Props conversation; idle in Play) | 20 responses | in 170,609 (88% cached), out 2,194 (audio 750) | $0.227 |
| Realtime lines, gpt-realtime-2.1-mini (kit lines, story, 5 scene openers, The End) | 16 responses | in 116,455 (93% cached), out 4,234 (audio 2,512) | $0.066 |
| Claude Opus 5.5, kit pages (medium) | 1 | 5,219 in / 740 out | $0.036 |
| Claude Sonnet 5.5, play guide (low) | 1 | 8,118 / 2,519 | $0.041 |
| Claude Sonnet 5.5, prop weaves (low) | 5 | 21,868 / 1,267 | $0.056 |
| Images drawn (`/v1/images/generations`): 6 outline pages + 3 outline redraws + cover + character sheet | 11 | text in 5,203, out 7,304 | $0.245 |
| Images color-in (`/v1/images/edits`, the kept outline PNG as input, 1,536 image tokens each): 6 pages + 4 re-edits | 10 | text in 3,193, image in 15,360, out 6,640 | $0.338 |
| Moderation (omni-moderation) | 23 | | $0 |
| **Total** | | | **$1.01** |

By the app's own Claude meter (Opus prices on every call) the same game reads $1.11.

### Printable redraws and re-edits

| Page | Outline word check | Color-in |
|---|---|---|
| Sign "Pet Hotel" | 2/2 | 1 edit, 2/2 words, 0 pale |
| Badges (6 roles) | 7/7 | 1 edit, 7/7, 0 pale |
| Room Key tickets | 8/8 | 2 edits: re-edited for 2 pale boxes, kept the first (still pale) |
| Paw Bucks money | 1/2 → **redraw** 1/2 (kept the redraw) | 2 edits: re-edited for 3 pale boxes, kept the first (still pale) |
| Pet Stay List menu | 7/9 → **redraw** 7/9 (kept the first) | 2 edits: re-edited for words (8/9), kept the first |
| Room Tags labels | 5/6 → **redraw** 6/6 (kept the redraw) | 2 edits: re-edited for 4 pale boxes, kept the re-edit (still pale) |

Totals: **3 outline redraws** (6.7¢), **4 color re-edits** (3 contrast, 1 word; 13.5¢). The menu "misses" are OCR
misses on bubble letters ("Fluffy Pillow", "$3" are printed correctly on both pages).

## Compared with earlier measurements

| | 11-16 v3 (Opus guide, full voice) | 11-17 moon bakery (live, relay) | **11-18 pet hotel (this)** |
|---|---|---|---|
| Realtime main | $0.31–0.32 + app lines | $0.230 | $0.227 |
| Realtime lines (mini) | (on main: $0.18–0.25) | $0.055 (12) | $0.066 (16) |
| Claude (real prices) | $0.19–0.20 | $0.132 | $0.134 |
| Images | $0.28–0.33 (13–15 drawn) | $0.312 (14 drawn) | **$0.583** (11 drawn + 10 edits) |
| **Total** | $0.97–1.09 | **$0.73** (was reported as $0.83 with the meter's Claude) | **$1.01** |

Moon bakery was also 4 players, 5 props, typed. Voice and Claude are flat; images nearly doubled.

## Plans (decisions/2026-11-17-plans-5-and-20.md) at the measured $1.01

After Apple's 15% (Small Business Program): Show $9.99 → $8.49; Season $24.99 → $21.24; Show yearly $99.99 → $7.08/mo;
Season yearly $249.99 → $17.71/mo.

| Plan, all games used | Plan math ($0.92) | Measured ($1.01) |
|---|---|---|
| Show monthly, 5 games | +$3.89 | **+$3.44** |
| Season monthly, 20 games | +$2.84 | **+$1.04** |
| Show yearly, 5 a month | +$2.48 | **+$2.03** |
| Season yearly, 20 a month | −$0.69 | **−$2.49** |

Break-even cost per game at full use: Season monthly $1.06, Season yearly $0.89. A game with a skipped prop, 6 players
or a theme change costs more, so heavy Season monthly families are close to break-even.

## Levers (for Haylee, not changed)

- **Loosen or drop the contrast re-edit** (`LetterContrast`, ratio < 1.7): 3 of 3 contrast re-edits did not cure the
  flag and 2 of 3 kept the first page anyway. Saves ~10¢ a game. The flagged letters (light cyan with a dark outline,
  dark purple on a mid-purple tag) are readable on the page.
- **Skip the outline word re-read for bubble letters** or accept 1 miss: the menu redraw was thrown away (same 7/9).
  Saves ~2–7¢.
- **Fix the app's Claude meter** to price Sonnet calls at Sonnet rates (it overstates ~10¢ a game in logs and
  `#cost`; the `[CLAUDE] usage` cents line uses Opus prices for `model=claude-sonnet-5-5`).
- With both levers a game is about $0.85–0.90.
