# Guide prefetch: the play guide is written during the hunt (Paper never waits for it)

**Date:** 2026-11-15 · **Decided by:** Haylee ("fix it first": no new wait at Paper; prefer option (a)). The approach
and details are Claude's calls, below.

## Problem
Round C1 made the play guide ~2,800 output tokens (6 scenes × a step for each of 6 roles + 2 for everyone). It still
waited for the hunt's end (it needed the found/skipped props), so Paper waited for it: 20–30 s live.

## What changed (Claude's calls)
- **Option (a), adapted.** There are no "planned props": the voice model picks props one at a time during the hunt.
  So the guide is written **as soon as the kit pages land** (~8 s after the roles) with NO props
  (`PhaseService.earlyGuide`), and each prop is **woven in** as its card comes up: one small low-effort call
  (`weaveProps`, ~2–4 s) rewrites 1–2 existing steps of a playing role (or an everyone step) to use it by what it
  becomes, keeping the step's role. Steps keep their roles, so every playing role still has its own step in every
  scene and the hand-off rotation is unchanged.
- **Skips and swaps at the hunt's end: no call** (`GuideWeave.finalize`). A skipped prop's steps say "the pretend
  <what it becomes>" and show its printed cut-out (`cutout:N`); a swapped prop's steps show the new item.
- **Restart only on a structural change:** a game/theme/roles correction already restarts the pages (round 19/20); the
  guide is tied to the same generation, so it restarts with them. A count change still makes no call (C1).
- **Paper never waits for the guide.** If the hunt ends before it's final, the pages go out (`guidePending`); Let's
  play! (tap, voice or step rail) is queued, she says one "checklists" line from the existing pool, the kit commentary
  keeps going, and Play starts by itself when the guide lands. If the early guide failed, the old after-hunt call runs
  then (with the props).
- **Fixed answer shape for the early guide** (`KitScenesSix`): scene1…scene6, each with R1…R6 + all1/all2 as required
  fields. At low effort the array form came back cut short about 1 call in 3 (ONE scene, or scenes with ONE step;
  the baseline 2-player live run kept a 1-scene guide). 4 of 4 fixed-shape calls were complete. 6 inline copies were
  refused by the API ("grammar too large"), so `$defs`/`$ref` plus a short picture enum (actions + kit items only:
  no prop pictures before the props exist).
- **Filters on the final text:** the weave answer goes through the kid-safety check (`safe`, regenerated once, then
  dropped); the final guide (after skips/swaps) runs the safety check again (`guideIsSafe`), falling back to the guide
  as written; prop pairings were already PropFit-checked at the card, and finalize resets a prop picture that no
  longer fits.
- **Cost:** ~+1–2¢ a game (one weave call per prop, ~2–3k input tokens each); the guide itself is unchanged in size.

## Measured (typed live runs, PT-R15-iPad, `/tmp/pt-guidefix/`)
| run | hunt start → guide ready | wait at Paper (Print → kit final) | wait at Play |
|---|---|---|---|
| before, 2 players, 1 skip | 64.7 s (after the hunt; kept a 1-scene guide after a retry) | **20.0 s** | 0 (Paper waited) |
| before, 5 players | 73.8 s | **23.5 s** | 0 (Paper waited) |
| after, 2 players, 1 skip | 29.7 s written, 42.5 s final (0.5 s after Print) | **1.5 s** (art) | 0 (not queued) |
| after, 5 players | 31.1 s written, 46.1 s final (0.6 s after Print) | **0.8 s** | 0 (not queued) |

The early guide call is ~23 s; each weave ~2–4 s (`LIVE_GUIDE`). After-run 2p skip: the star map was skipped and the
step reads "Navigator, follow the clues on the pretend star map!" (cut-out picture). Every scene kept a named step per
playing role (2p: Captain + Navigator; 5p: R1–R5) and hand-offs rotated R1, R2, … as before. Logs: `after2b/`, `after5/`.

## Tests
NutmegCore 318 green. New `GuidePrefetchTests`: deterministic substitution (skip → "pretend …" + cut-out, swap,
gone prop), weave answers checked, fixed shape decodes with roles, guide written during the hunt and a skip makes no
call, a correction restarts the guide, Paper goes ahead and Play waits then starts by itself, safety on the final text.
Live harness: `LIVE_GUIDE=1` (`LiveGuidePrefetchTests`).

## Not changed / not verified
- No-printer (Draw it!) path unchanged: its guide is still written at the hunt's end.
- Not live-checked: spoken (mic) runs; a theme correction mid-hunt restarting the guide (unit test only); the
  queued-Play path ("Let's play!" before the guide is final: unit test only, since live the guide was always final
  ~0.5 s after Print); a swapped prop's wording.
