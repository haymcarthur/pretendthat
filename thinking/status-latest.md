> New session (after the repo transfer)? Read [session-handoff-2026-11-21.md](session-handoff-2026-11-21.md) first.

# MORNING SUMMARY (for Haylee, 2026-11-21 morning)

Everything below was built overnight on the branch `claude/optimistic-allen-mifsgp` (pushed). Nothing was compiled as an app here (no Xcode): NutmegCore compiles and its tests pass on Linux; the app files were read line by line against NutmegCore and pass `swiftc -parse`. No API keys, no live calls, $0.

## Built overnight
- **Scenarios + ownership round** ([build](decisions/2026-11-21-round-scenarios-ownership-build.md)): events are real scenarios (a gesture-only line becomes an app scenario); the opener sets the scene; event and calm-again cards stay up with a 🔊 hear-again (no automatic repeat); every page and prop has ONE owner (2–3 rows a card, badges said once); prop stand-ins (10–15 believable uses per prop, approved); End scene; ▶ buttons never grey; music on/off pill; the face no longer drifts on zoom.
- **Safety rule:** everything in play is pretend; a line that points kids at a real hazard (stove, oven, sink, outlet, stairs, climbing, outside) is rewritten in the stored guide and again on load.
- **Music code:** four more families (snowy north, robot lab, circus & carnival, race day; 14 in all) and calm → calm2 → calm loops on the audio clock (`CalmLoop`), with pause, mute, duck and the tense crossfade still working.
- **One game plan** ([build](decisions/2026-11-21-round-game-plan-build.md), your design: [one-game-plan](decisions/2026-11-21-one-game-plan.md)): one plan call writes the areas, every page's life cycle (area, owner, setup, a use in play, put-away) and events that use them; ONE props call at the end of the hunt places the found props (the per-prop weave calls are gone); setup cards by AREA (role small, "Build the cockpit" big, picture chips, 3 kids = 2 + 1); clean-up by the same owners; calm-stretch idea cards (low right, 🔊, no chime, no duck); a traceability check in code; saved games schema 8 (2–7 still replay).
- **Final review pass** (this morning's notes in the round file's "Review pass"): the app files needed no edits. Three fixes in NutmegCore: Play can no longer wait forever for the plan or props call (60 s / 60 s / 25 s, then the app composes the game); on a replay, a prop skipped this time is "the pretend …" in event lines; a swapped prop's put-away names the new household item.

## Needs your ear / eye
- **5 music clips:** magical calm A→B→A (`design/music-test/magical/processed/loop-test-calm-aba.m4a`; calm2 is in another key, delete it if it jars), the new magical win, the new superhero win, the race-day win, the circus tense. The stand-ins file (design/prop-stand-ins.md) is approved.

## Your Mac checklist
1. `git pull` on `claude/optimistic-allen-mifsgp`, then `xcodegen` (new: NutmegCore PlayPlan.swift, PlayPlanCompose.swift, PrintPlayJobs.swift, Resources/airplane-gameplan.json; the Music folder reference picks up the new families).
2. Build (Release). Most likely spots if the compiler complains: ChecklistSceneView `PTChecklistCard.titles/progressMark`, RootView `beatChrome`'s idea card, KitPrefetch `Deadline`. Optional: `swift test` in NutmegCore.
3. Demo mode, no keys (`-PTNoAI -PTAnalyticsOff -PTSkipAuth`), iPad and iPhone:
   - `-PTDemo oneSetup` with `-PTPlayers 2`, `3`, `4`: area cards (role small, the area job big, picture chips, max 3 items); 3 kids = two on top, one centered below; ▶ Let's play! always works.
   - `-PTDemo oneIdea`: the small idea card low right, no chime, the music does NOT duck, Nutmeg keeps grooving; 🔊 says the same line.
   - `-PTDemo onePlaying -PTFastScene`: a whole scene in about a minute (ideas between events, never during a tense event); End scene (asks first → finale → clean-up); the music pill off/on.
   - `-PTDemo onePlaying` without the fast clock for ~2 minutes in a couple of families: calm hands over to calm2 and back with no gap or click.
   - `-PTDemo oneCleanup`: "Tidy up the cockpit" cards, each prop put away once.
4. **ONE live game**, watching: does the plan flow (areas, pages named in events, ideas that make sense)? Are the printouts actually used? Console token lines for the plan call and the ONE props call (cost; no "weave" calls), `[PLAN]` lines (expect none), and the hunt's "PROP stand-in" lines.

# Where things stand (handoff, 2026-11-21)

Start here in a new session, after CLAUDE.md. The 2026-11-18 handoff is below (still true unless this section says otherwise). The 2026-11-20 round (voice-stall fix, checklist scenes) is in [round-checklist-scenes-build](decisions/2026-11-20-round-checklist-scenes-build.md) and [voice-stall-fix](decisions/2026-11-20-voice-stall-fix.md); its checklist scenes are replaced for new games by the one scene below (their saved games still replay).

## 2026-11-21: shipped to the branch (claude/optimistic-allen-mifsgp), not in a build yet
- **One scene with music** ([round-one-scene-build](decisions/2026-11-21-round-one-scene-build.md), design: [one-scene-music-beats](decisions/2026-11-21-one-scene-music-beats.md), layout: design/mockups/one-scene/):
  - The guide writes a setup checklist (2–3 items per role), a "Pretend that…" opener, a pool of 8–12 calm/tense events (each names its roles and one thing to do; tense ones have a calm-again line that never credits the kids), a finale and a music family. Estimated ≈ 4.3–4.6¢, about today's ~4.5¢.
  - The app picks 3 / 4 / 5 events for 1–2 / 3–4 / 5–6 kids, calm → tense → calm…, with **fair calls counted in code** (max difference 1, everyone at least once; app-written events repair a pool that can't be fair).
  - Flow: setup cards → ▶ Let's play! (grey until every card is done) → 10-minute scene (only ✕ and ⏸ Pause; music pill; scene bar with dots + finale star; event cards, calm-again cards, the finale's confetti) → the clean-up opens by itself → ▶ The End lights up when everything is checked. Pause stops music, clock and speech; background pauses; a relaunch resumes the scene paused at its time.
  - Music: calm/tense loops + win ending per family + one chime, ducked −12 dB under her voice, on the app's current audio session (never touches her speaker engine or the mic). Resources/Music/ now holds the real ElevenLabs music for all 14 families (calm, calm2, tense, win + the shared chime). Missing files = silence.
  - Clean-up: one item per prop the kids got out + one print-mess item, spread fairly.
  - Nutmeg grooves to the music, alarmed at tense events, phew at calm-again (both faces are in the catalog), yay + celebrate at the finale.
  - The mic stays off for all of Play (`PlayMic`, tested). Saved games are schema 7; 2–6 still replay.
- **Scenarios + ownership round + live-test fixes** ([round-scenarios-ownership-build](decisions/2026-11-21-round-scenarios-ownership-build.md)):
  - Events are scenarios (prompt with good/bad examples; a gesture-only line becomes an app scenario event); the opener always sets the scene ("Pretend that we're at…").
  - No automatic repeat: the event card stays up until the next cue, with a 🔊 hear-again (also on the calm-again card).
  - One owner per object: every page and prop in exactly one setup card (2–3 rows; a solo kid may get more), the badges said once in the setup cue; clean-up by the same owners + one print-mess item.
  - Prop stand-ins: 10–15 believable uses per prop, for review in **design/prop-stand-ins.md**; the hunt and the weave only allow listed uses (no AI call).
  - Items use the pretend name ("Hold up the planet"); 3 new music families (superhero city, pirate adventure, rescue team).
  - Live-test fixes: End scene (asks first → finale → clean-up); ▶ Let's play! / ▶ The End never grey (they check what's left); every card line is speakable (the print-mess item no longer says scissors); the music pill toggles music off/on (remembered on the device); ⏸ Pause verified (it does stop the music, nothing changed); the face drifting off her head during zooms (root cause + fix in the decision file).
- **Review pass + music code (2026-11-20 night, Claude):**
  - Review of the scenarios/ownership code (compiler-style read, notes in the round decision's "Review pass"): fixed ▶ Let's play! / ▶ The End going dead after leaving the game mid check-off, and End scene cutting off the finale line (it now does nothing at the finale and the pill hides).
  - Four more music families: snowy north, robot lab, circus & carnival, race day (labels, fits, keywords; "robot" moved from Space to Robot lab, a "magic show" is the circus, "ice cream" stays a shop). The guide's list and schema come from the enum (14 families).
  - **calm → calm2 → calm…**: when calm2.m4a is bundled (all 14 families), `MusicPlayer` plays each calm loop once through and schedules the other on the audio device clock for the exact moment it ends (`play(atTime:)`, `CalmLoop` in NutmegCore). Pause, mute, duck, the tense crossfade and the restart after an interruption keep working; a scene always starts on calm.
  - Resources/Music is a folder reference, so the new folders are picked up: just **run xcodegen**.
- **Scenarios round, tested here:** NutmegCore (Linux): 749 tests, all pass except the same 10 environment-only failures (run in two parts after container restarts). App files pass `swiftc -parse` only (not compiled). No live calls, $0. Safety rule added late in the round (everything in play is pretend; hazards rewritten in the stored guide and on load).
- **Compiled/tested here (one-scene round):** NutmegCore only (Linux): 737 tests, all pass except the 10 known environment-only failures. **The app files were not compiled** (no Xcode here) and nothing ran on a simulator. No live calls, no music generation, $0.

- **One game plan round (2026-11-20 night, Claude; [round-game-plan-build](decisions/2026-11-21-round-game-plan-build.md))**:
  - The guide call is now the GAME PLAN call (same spot, during the hunt): story, 2–4 areas with owners and jobs, every page's life cycle (area, owner, setup placement, a use in play, put-away), events that name the pages and areas, finale, music. The kit pages prompt carries each type's play job (`PrintPlayJobs`), so pages are picked for a use; a page the plan leaves unused is repaired by the app, never shipped unused.
  - The per-prop weave calls are gone: ONE props call when the hunt ends places every found prop into the plan (and may rewrite one event per prop to use it). No answer = the app places them. Cost ≈ the same per game (fewer input tokens, a bit more output).
  - Setup cards by AREA (role small + "Build the cockpit" big, a picture chip per item, 3 kids = 2 + 1); clean-up by the same owners ("Tidy up the cockpit"). Calm-stretch idea cards (small, low right, 🔊, no chime, no duck) fill the calm gaps for every object no picked event uses.
  - Traceability check (`PlayPlans.trace`) tested at 1–6 kids with all props, a skipped prop, an extra prop and none. Saved games are schema 8; schema 7 one-scene games keep their path. The bundled/demo game is a plan (the cockpit, the passenger cabin, the snack galley, the gate).

## Haylee's Mac checklist
1. `xcodegen` (picks up the four new music folders; new files: App/AppModel+OneScene.swift, Screens/BeatSceneView.swift, Voice/MusicPlayer.swift; Resources/Music is now a folder reference), then build **Release**. Expect a few type-check fixes in the uncompiled app files (riskiest spots listed in the decision file).
2. `swift test` in NutmegCore (about 798 tests: the earlier ~781 + 14 + 3 new music tests). Here (Linux): the music, one-scene and scenarios suites pass (29 tests); the full suite was not re-run this pass (only the music keyword lists and `CalmLoop` changed in NutmegCore).
3. Demo mode (no keys), iPad and iPhone simulators (`-PTNoAI -PTAnalyticsOff -PTSkipAuth`, `-PTPlayers 2` and `-PTPlayers 6`):
   - `-PTDemo oneSetup`: setup cards, titled "Get the Plane Ready", ▶ Let's play! grey; `oneSetupDone`: green with a halo.
   - `-PTDemo onePlaying`: no step rail, only ✕ + ⏸ Pause, the music pill on top, the scene bar at the bottom, Nutmeg centered and gently bobbing.
   - `oneEvent` (calm card), `oneTense` with `-PTPlayers 4` (two pictures "Co-Pilot + Flight Attendant", coral style, pulsing halo, alarmed face), `oneCalmAgain` (soft card, phew face), `oneFinale` (celebrate + confetti), `oneCleanup` (clean-up cards; ▶ The End lights up once all checked → The End), `onePaused` (dimmed stage, Paused card, ▶ Resume).
   - **Fast clock, a whole scene:** `-PTDemo onePlaying -PTFastScene` (or tap through from `oneSetupDone` with `-PTFastScene`): about a minute: chime + cards at each event, calm-again cards, the finale, then the clean-up opens by itself.
   - **Pause/resume:** ⏸ mid-scene: the music and the bar stop; ▶ Resume continues from the same spot. Lock the device mid-scene: it comes back Paused.
   - **Relaunch resume:** kill the app mid-scene, relaunch: the start screen's picture with ▶ opens the scene paused at its time (no event said again); the same from the setup and the clean-up keeps the checks.
   - **Music missing = silent:** delete Resources/Music (or rename the family folder) and run `onePlaying -PTFastScene`: no music, everything else runs.
4. **Scenarios + ownership round (demo mode, no keys):**
   - `-PTDemo oneSetup` with `-PTPlayers 1`, `2`, `4` and `6`: no job or page in two cards; 2–3 rows per card (one kid: more rows, pairs); the cue says "Everyone, put on your badge."; no "pretend" or household names in the rows. ▶ Let's play! is green even with rows unchecked: press it and watch the rows tick off, then the scene starts. `oneSetupDone`: green with the halo.
   - `oneEvent` / `oneTense`: the card has a 🔊 (tap it: the same line again, no new call in Console); the card stays up until the next event (calm) or its calm-again (tense), check with `-PTFastScene`. `oneCalmAgain`: the soft card has a 🔊 too.
   - `onePlaying`: tap the music pill: "Music off" (crossed speaker), events still chime and she still talks; relaunch: still off. ⏸ Pause: music stops; Resume: it continues.
   - "End scene" under ⏸ Pause (iPad) / under the top bar (iPhone): asks first; End scene → the finale, then the clean-up 20 s later. Kill + relaunch right after: it resumes at the finale.
   - `oneCleanup`: the print-mess row reads "Pick up the paper scraps and crayons"; ▶ The End works with rows unchecked.
   - **Face drift:** watch Nutmeg's face through setup → ▶ Let's play! (zoom in), each event card (she moves aside), calm-again, finale, clean-up: the face, eyes and mouth stay on her head.
   - Read **design/prop-stand-ins.md** and mark anything that isn't believable.
5. **Music (demo mode, no keys):** `-PTDemo onePlaying` (no `-PTFastScene`, the music follows the real clock) for about two minutes in a few families (Console "music: <family> (3 of 3 segments + calm2)"): calm hands over to calm2 and back on a bar line with no gap, no overlap and no click (compare with `design/music-test/<family>/processed/loop-test-calm-aba.m4a`); tap the music pill off/on across a hand-over; ⏸ Pause just before a hand-over, then ▶ Resume; an event (tense crossfade) and back to calm; lock/unlock mid-scene (it comes back). Check the new families' routing by eye in a live game only if one comes up (snow, robots, circus, races). Magic kingdom's calm2 is in another key: listen and delete it if it jars.
6. **One live game** (the round's one live game; also check: scenario events, not gestures; the hunt's Console "PROP stand-in" lines; no repeated jobs; 🔊 on every card says exactly the card's words): check the AI's setup items, the event pool (short lines, roles named, tense ones resolved without "you fixed it", fair at your count), the music family, the opener/finale, and that 🔊 hear-again replays the same take (Console "voice": take kept, no new live line).

7. **One game plan round (demo mode, no keys)** — `xcodegen` first (new NutmegCore files: PlayPlan.swift, PlayPlanCompose.swift, PrintPlayJobs.swift, Resources/airplane-gameplan.json), then build:
   - `-PTDemo oneSetup` with `-PTPlayers 2`, `3`, `4` (and `6`): AREA cards: role name small, the area job big ("Build the cockpit"; 2 kids: "Set up the cockpit and the snack galley"; 6 kids: "Help set up …"), a picture chip on each item (prop art or the page's thumbnail once the art is in; in demo the page chips show the page title placeholder), check left, 🔊 right, max 3 items. 3 kids: two cards on top, one centered below. iPhone: the same cards in the shelf. ▶ Let's play! always works.
   - `-PTDemo oneIdea` (any count): the small translucent idea card low right above the scene bar, thumbnail + line + 🔊; no chime; the music does NOT duck while she says it; Nutmeg stays centered and grooving. Tap 🔊: the same line again.
   - `-PTDemo onePlaying -PTFastScene` (2 and 5 kids): a whole scene in about a minute: ideas between events (never during a tense event or its calm-again card), each up ~2 s at 10× (20 s real) or until the next event; a calm event's card goes down when its gap's idea comes.
   - `-PTDemo oneCleanup`: "Tidy up the cockpit" style cards, each prop's put-away once, one print-mess row.
   - An older one-scene save (schema 7) from the shelf: still the old setup cards (no area words), no ideas.
   - **The one live game:** watch Console for the plan call and ONE props call (no "weave" calls), the `[PLAN]` lines (DEBUG: any traceability issue; expect none), the area cards' wording, whether events use the pages by name, the idea lines, and the token lines for the cost comparison.

# Earlier handoff (end of 2026-11-18 session)

The decision files have the details; this is the map of what's done, what's live, and what's next.

## First: set up the MacBook Air (2026-11-20)
The repos moved to mcartha ([repos-moved-to-mcartha](decisions/2026-11-20-repos-moved-to-mcartha.md)) and this Mac has no copies yet.
1. Clone if missing: `git clone https://github.com/mcartha/pretendthat ~/PretendThat` and `git clone https://github.com/mcartha/pretendthat-site ~/pretendthat-site` (same paths the notes and scripts use).
2. Not in git: `Secrets.xcconfig` (ask Haylee to copy it from the old Mac, or fill in from Secrets.example.xcconfig), design/appstore-screens/ (only needed for App Store screenshot work).
3. Tools: `brew install xcodegen`, then `xcodegen` in ~/PretendThat; `npm install` in ~/pretendthat-site. Check Xcode 16+ is installed and signed in.
4. Check `swift test` in NutmegCore (751 tests passed last time) and a simulator build in demo mode, then do the next small task below.
5. Pages for pretendthat-site was checked 2026-11-20: main / root, pretendthat.app, HTTPS enforced (DNS check was still running).

## Shipped
- **TestFlight build 1.0 (4)** uploaded 2026-11-18 (commit 933c6c6, pushed to origin/main). Internal testers get it without beta review. Contents: [decisions/2026-11-18-build-4.md](decisions/2026-11-18-build-4.md).
  - Peek v4: Haylee's redrawn body + paws; the body sits behind the scene card, the paws in front ([peek-hands-regenerate](decisions/2026-11-18-peek-hands-regenerate.md)).
  - Saved-game offer is just the picture. On iPad it sits beside Nutmeg, on iPhone above the bar, and in the chat (both devices) when the chat is open. Tapping the picture plays the game. ([saved-offer-picture-only](decisions/2026-11-18-saved-offer-picture-only.md)).
  - Nutmeg looks up at the kids while she talks during Play. The idle/lock fix: the voice reconnects with retries, a keepalive ping, and the speaker restarts. ([device-testing-fixes](decisions/2026-11-18-device-testing-fixes.md)).
  - Printables after a lock: art requests cut off by the lock are retried on return, and the color and coloring pages always come from the same AI picture. Live games show **no fallback art** (Haylee): a page that still fails shows a "Try again" tile and won't print until it loads. ([printables-after-lock](decisions/2026-11-18-printables-after-lock.md)).
- **Repos moved (2026-11-20):** now github.com/mcartha/pretendthat and github.com/mcartha/pretendthat-site ([repos-moved-to-mcartha](decisions/2026-11-20-repos-moved-to-mcartha.md)). Update the Mac remotes and check Pages.
- Build 3 was submitted for beta review earlier (may be moot now that internal testers have 4).
- NutmegCore: 751 tests pass.

## Waiting on Haylee (device checks of build 4)
- **Idle/lock:** lock the phone mid-game for a few minutes, unlock, then press the mic and tap a prop card. Both should work.
- **Printables after lock:** lock the phone during the prop hunt (ideally switch Wi-Fi → cellular), come back, and check that the color and coloring pages match and none show built-in art.
- **Try again tile:** never seen on screen yet. Demo mode can't show it because it has no AI images.

## Next small task
- **Retake the saved-offer screenshots from current main.** Demo games now seed "Moon Crumbs Bakery" with its real cover, so the offer shows the same picture as its bookshelf book ([demo-seed-real-cover](decisions/2026-11-18-demo-seed-real-cover.md), merged). The agent's shots in /tmp/pt-saved-offer-v2/ were built from an old base and show the OLD card with buttons. Ignore them. Retake 4 shots (iPhone/iPad, chat closed/open: `-PTDemo soundsLike`, `-PTChat`, plus `-PTNoAI -PTAnalyticsOff -PTSkipAuth`) and show Haylee. **Real-game behavior was never wrong:** the offer and the shelf both use `AppModel.cover(for:)`.

## Open / later
- **Peek right paw rim:** the right paw's dark top rim (path 5) is hidden under the taller redrawn right paw, so the two paws don't quite match. This is Haylee's call: either fix the art in Figma (move the arc above the paw, re-export) and rerun `tools/peek_v3_imagesets.py`, or leave it. Tiny finger-line nicks only show at 8×.
- **Not-ready page voice line:** Nutmeg says nothing when a printable isn't ready (a clip would cost money). Maybe add one later.
- Carried over: the iCloud schema deploy to production (needs Haylee's iPad signed into iCloud), the D&B name change, and the rest of [business-setup-todo.md](business-setup-todo.md). The App Store listing draft is in docs/app-store-listing.md. Plus the other items in [open-questions.md](open-questions.md).

## How we work (standing rules from this stretch)
- Art: regenerate Nutmeg art in ChatGPT and vectorize it in Figma (Haylee), never patch shapes in code or Figma. She exports SVGs to ~/Downloads, and they're copied into design/nutmeg/peek/regen/. Prompts are in design/nutmeg/peek/regen/prompts.md.
- Queue app changes into rounds of 3–5 items, with one build agent at a time on the same files.
- No API keys in agent tests by default (demo mode), and at most one live game per round.
- No new TestFlight build until Haylee says. Builds use team 66898X3HH3, Release config, and the key check must pass. Upload with `xcodebuild -exportArchive` (method app-store-connect, destination upload) through her signed-in Xcode account.
- Don't touch simulators AF512F6A / 1820E3FA or her devices; agents make throwaway simulators.
- Local only (not in git, too big): design/appstore-screens/ (298 MB of App Store screenshot work).
