# Round 20: color choice, kit made during the hunt, no settings, hunt wording, cheaper Realtime and images

**Date:** 2026-11-15. **Who decided:** Haylee asked for all six items (queue, round 20) plus two mid-round additions
(pretend swords; the typed-turn barge-in bug). The implementation details are Claude's calls, noted below.

## 4. Roles → hunt wording (Haylee)
- After the roles she says **"Now it's time to hunt for props!"** (`AdventureStore.huntTransition`), never "Pick
  who's who!". Then the first card appears, she points, and she says the first prop line. Updated: the Realtime
  instructions, the first-prop tool output, the roles step goal, the confirm output and the turn-check coaching.
- Live: "Our crew is a Head Baker and an Assistant Baker! Now it's time to hunt for props!" → card + point →
  "First, can you find a bowl? It'll be our mixing bowl…".

## 3. Settings removed (Haylee)
- The start-screen gear, the 2-second press on the logo card, `ParentSettingsView`, `VoiceSettings` (UserDefaults
  `nutmeg.v4.*`), the voice audition and the live pitch shaping are gone. The voice is `VoiceConfig.nutmeg` (coral,
  Varispeed 1.20, speed 1.0, echo cancellation off), the old defaults.
- **Claude's calls:** old `nutmeg.v4.*` keys are removed at launch (nothing stored). `SuggestionMemory` (last
  session's suggestion IDs) stays: it's not a setting. The DEBUG component gallery stays reachable from Xcode previews.

## 1. Color choice (Haylee)
- New step **3c** (`PlanningStep.color`) right after the confirm step's yes, before the roles: "Do you want your
  printables in full color, or do you want to color them yourself?" Two big buttons (**Full color** / **I'll color
  them**) or voice (`set_print_style`: `full_color` / `color_myself`). One spoken reply per turn: the yes reply is the
  question; the answer's reply is the planning line + roles.
- `AdventureStore.printStyle` is the one source of truth. Full color: every kit image prompt asks for a full-color,
  kid-friendly cartoon illustration (the line-art / coloring-page wording is dropped; the safety suffix and
  `moderation: auto` stay). "I'll color them": the coloring-page prompt, word for word as before. All pages (badges,
  sign, money, tickets, menu, cut-outs) follow it.
- **Claude's calls:** a color said early ("yes, in full color!") is kept and the question is skipped; a round 19
  correction keeps the color (after the new yes, straight to roles); a change mid-hunt redraws the art (the page text
  stays); a change at Print redraws the pages ("Ooh, full color! Let me paint your pages to match."); once play has
  started it stays as printed. The tap-fallback path (no Realtime) has no color screen and uses coloring pages.
  Full-color art gets a gentler paper-white curve (only above ~94%), so light colors keep their tint.

## 2. The kit is made during the prop hunt (Claude's proposal, Haylee confirmed)
- As soon as the color and the roles are set, Claude writes the **kit pages** (`Prompts.kitPages`, `KitPages`: the 6
  recipe items, 6 themed cut-outs) and their art starts in the background (`KitArtService.prepare`). When the hunt
  ends, only the **play guide** (`Prompts.kitScenes`, with the found and skipped props) and the **skipped props'
  cut-outs** are left. The page ids don't change, so the art carries over.
- Skipped props get a printed cut-out of what they would have been ("the big oven" → "big oven"), appended after the
  themed ones (at most 2, at most 8 cut-outs in all).
- Image calls run in parallel, **at most 3 at once** (`AsyncLimiter`; the relay allows 40 images a minute).
- A correction (game/theme/count, new roles) cancels and restarts the pages (a generation counter drops late results);
  a color change only redraws the art. Retry once (`RetryOnce`), then the old fallbacks: the one-call kit for the
  pages, an app-drawn page for an image (a network failure while away still gets one more try when the app is back).
- Nothing talks over the hunt: kit commentary only starts at Print and only names pages still in progress
  (`KitProgress.inProgress(pagesWritten:scenesWritten:pendingPages:)`: the checklists while the guide is written,
  then pages whose art is still drawing).
- **Claude's calls:** two Claude calls instead of one (pages at the roles, guide at the end), because the scenes
  need the real props; about +$0.01 a game. The play guide runs at **low effort** (live: 9.8 s vs 19.1 s at medium,
  same shape, 5 vs 6 scenes); `PhaseService.scenesEffort` flips it. "Show what's ready" at Print: the papers still fly
  out together once the whole kit is final (the no-text-overlays rule), but now that's usually seconds, not ~40 s.

## 5. Stable Realtime prefix (Haylee, cost lever 1)
- Every session sends the same `instructions` and the ONE tools array (`set_expression` removed: it was never
  offered after round 13), serialized with sorted keys. Responses never carry their own `tools` or `instructions`.
- Per-step guidance moved after the cached prefix: a silent tool-first pass gets its step tools as a system note
  (`allowedToolsNote`) and the app refuses any other tool it calls (`offStepOutput`, not run); today's game ideas and a
  reconnect's state are system items; app lines (`sayExactly`) keep the session prefix and send the line as their
  only input item (out of band, no conversation, `tool_choice: none`). Step rules still live in `apply()` as before.
- DEBUG logs `response.done` usage counts only (`RealtimeUsage`), never content.
- **Measured (typed live runs, same bakery script, 22–28 responses):** before (liveA): 156,092 input tokens, 69,312
  cached (**44%**); app lines 0% cached. After (liveB): 140,991 input, 118,208 cached (**84%**); after warm-up most
  responses are 93–99% cached, app lines included. Uncached input fell from about 86.8k to 22.8k tokens a game (text
  only: typed runs have no kid audio, so audio caching is unverified).

## 6. Cheaper images (Haylee, cost lever 3)
- Samples of one kit (Bakery on the Moon) at medium and low, both styles: `/tmp/pt-round20/quality/compare.png`
  (+ `slices.png`, and every page as its own PNG). **Claude's judgment: low keeps the lines crisp and colorable**
  (slight softness on edges at 100%, no broken or gray lines); full color at low is also clean. So
  `ImageQuality.kit = "low"` (one constant; Haylee reviews and can flip it to "medium").
- The themed cut-outs are **one grid image** (`CutoutSheet`, 3×2 on 1536×1024), sliced back into one picture per
  cut-out at the emptiest lines near the grid and trimmed to squares, so the printed page and the `cutout:N` checklist
  pictures work as before. Live samples: all 6 came out in the asked order and sliced cleanly in both styles. A failed
  sheet falls back to one image per cut-out; `CutoutSheet.enabled` turns the sheet off. A typical kit is now 6
  images + skipped props (was 11–13).

## Mid-round additions (Haylee)
- **Pretend swords are allowed:** "sword"/"swords" (toy, foam, cardboard) no longer trigger the filter or a redirect;
  the Realtime, Claude and image rules allow pretend swords for pirates, knights and dragons; a sword prop is always a
  soft stand-in (rolled towel, paper towel tube, pool noodle, rolled newspaper) or a cut-out. Knives, guns, real or
  sharp swords, hurting and gore stay blocked. (Round 19 had blocked swords as Claude's call.)
- **The kid's own turn stops her speech:** typing or pressing the mic now runs the round 19 stop path first (every
  response cancelled by id, player cleared, "…" on the cut line, pending cheers/repeats/deferred lines dropped). Live:
  a typed answer 1.8 s into the greeting cut it in the same tick (before the safety check), then one new reply.
- **Pretend ovens (found live, Claude's call):** a bakery's "the oven" prop card was blocked mid-hunt (round 19's
  "oven" rule) and she steered to new games. Tool fields and generated kit text now allow pretend oven/stove/glass;
  kid-typed text stays strict.

## Live checks (typed, PT-R15-iPad; `/tmp/pt-round20/`)
- liveB (final build, full color): hunt start → Print **45.1 s**; all 11 hunt images had landed by Print; the wait at
  Print (Print reached → kit final) **15.2 s** (the play guide ~8 s, then the one skipped-prop cut-out). Before: round
  19 measured ~37 s from finish_planning to the ready line; liveA (prefetch, medium, before the oven fix) 45.2 s.
- Screenshot of the full-color kit at Print: `/tmp/pt-round20/fullcolor-kit-at-print.png`.
- Not live-checked: voice (spoken) answers to the color question, a color change at Print, the cut-out sheet's
  fallback, a mid-hunt correction restarting the pages (unit tests only), audio-token caching.

## Tests
- NutmegCore: 255 tests (was 231). New: Round20ColorTests (+ swords, pretend ovens), Round20PrefetchTests (+ sheet,
  stable prefix, usage counts, kid turn stops speech). Live harnesses: `LIVE_SPLIT=1`, `LIVE_IMAGES=1`.
