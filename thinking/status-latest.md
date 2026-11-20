# Where things stand (handoff, 2026-11-21)

Start here in a new session, after CLAUDE.md. The 2026-11-18 handoff is below (still true unless this section says otherwise). The 2026-11-20 round (voice-stall fix, checklist scenes) is in [round-checklist-scenes-build](decisions/2026-11-20-round-checklist-scenes-build.md) and [voice-stall-fix](decisions/2026-11-20-voice-stall-fix.md); its checklist scenes are replaced for new games by the one scene below (their saved games still replay).

## 2026-11-21: shipped to the branch (claude/optimistic-allen-mifsgp), not in a build yet
- **One scene with music** ([round-one-scene-build](decisions/2026-11-21-round-one-scene-build.md), design: [one-scene-music-beats](decisions/2026-11-21-one-scene-music-beats.md), layout: design/mockups/one-scene/):
  - The guide writes a setup checklist (2–3 items per role), a "Pretend that…" opener, a pool of 8–12 calm/tense events (each names its roles and one thing to do; tense ones have a calm-again line that never credits the kids), a finale and a music family. Estimated ≈ 4.3–4.6¢, about today's ~4.5¢.
  - The app picks 3 / 4 / 5 events for 1–2 / 3–4 / 5–6 kids, calm → tense → calm…, with **fair calls counted in code** (max difference 1, everyone at least once; app-written events repair a pool that can't be fair).
  - Flow: setup cards → ▶ Let's play! (grey until every card is done) → 10-minute scene (only ✕ and ⏸ Pause; music pill; scene bar with dots + finale star; event cards, calm-again cards, the finale's confetti) → the clean-up opens by itself → ▶ The End lights up when everything is checked. Pause stops music, clock and speech; background pauses; a relaunch resumes the scene paused at its time.
  - Music: calm/tense loops + win ending per family + one chime, ducked −12 dB under her voice, on the app's current audio session (never touches her speaker engine or the mic). Resources/Music/ holds PLACEHOLDER tones (a parallel session was processing a real space-adventure take into it: check before shipping). Missing files = silence.
  - Clean-up: one item per prop the kids got out + one print-mess item, spread fairly.
  - Nutmeg grooves to the music, alarmed at tense events, phew at calm-again (both faces are in the catalog), yay + celebrate at the finale.
  - The mic stays off for all of Play (`PlayMic`, tested). Saved games are schema 7; 2–6 still replay.
- **Compiled/tested here:** NutmegCore only (Linux): 737 tests, all pass except the 10 known environment-only failures. **The app files were not compiled** (no Xcode here) and nothing ran on a simulator. No live calls, no music generation, $0.

## Haylee's Mac checklist
1. `xcodegen` (new files: App/AppModel+OneScene.swift, Screens/BeatSceneView.swift, Voice/MusicPlayer.swift; Resources/Music is now a folder reference), then build **Release**. Expect a few type-check fixes in the uncompiled app files (riskiest spots listed in the decision file).
2. `swift test` in NutmegCore (about 795 tests: the earlier ~781 + 14 new).
3. Demo mode (no keys), iPad and iPhone simulators (`-PTNoAI -PTAnalyticsOff -PTSkipAuth`, `-PTPlayers 2` and `-PTPlayers 6`):
   - `-PTDemo oneSetup`: setup cards, titled "Get the Plane Ready", ▶ Let's play! grey; `oneSetupDone`: green with a halo.
   - `-PTDemo onePlaying`: no step rail, only ✕ + ⏸ Pause, the music pill on top, the scene bar at the bottom, Nutmeg centered and gently bobbing.
   - `oneEvent` (calm card), `oneTense` with `-PTPlayers 4` (two pictures "Co-Pilot + Flight Attendant", coral style, pulsing halo, alarmed face), `oneCalmAgain` (soft card, phew face), `oneFinale` (celebrate + confetti), `oneCleanup` (clean-up cards; ▶ The End lights up once all checked → The End), `onePaused` (dimmed stage, Paused card, ▶ Resume).
   - **Fast clock, a whole scene:** `-PTDemo onePlaying -PTFastScene` (or tap through from `oneSetupDone` with `-PTFastScene`): about a minute: chime + cards at each event, calm-again cards, the finale, then the clean-up opens by itself.
   - **Pause/resume:** ⏸ mid-scene: the music and the bar stop; ▶ Resume continues from the same spot. Lock the device mid-scene: it comes back Paused.
   - **Relaunch resume:** kill the app mid-scene, relaunch: the start screen's picture with ▶ opens the scene paused at its time (no event said again); the same from the setup and the clean-up keeps the checks.
   - **Music missing = silent:** delete Resources/Music (or rename the family folder) and run `onePlaying -PTFastScene`: no music, everything else runs.
4. **One live game** (the round's one live game): check the AI's setup items, the event pool (short lines, roles named, tense ones resolved without "you fixed it", fair at your count), the music family, the opener/finale, and that the repeats replay the same take (Console "voice": take kept, no new live line).

# Earlier handoff (end of 2026-11-18 session)

The decision files have the details; this is the map of what's done, what's live, and what's next.

## Shipped
- **TestFlight build 1.0 (4)** uploaded 2026-11-18 (commit 933c6c6, pushed to origin/main). Internal testers get it without beta review. Contents: [decisions/2026-11-18-build-4.md](decisions/2026-11-18-build-4.md).
  - Peek v4: Haylee's redrawn body + paws; the body sits behind the scene card, the paws in front ([peek-hands-regenerate](decisions/2026-11-18-peek-hands-regenerate.md)).
  - Saved-game offer is just the picture. On iPad it sits beside Nutmeg, on iPhone above the bar, and in the chat (both devices) when the chat is open. Tapping the picture plays the game. ([saved-offer-picture-only](decisions/2026-11-18-saved-offer-picture-only.md)).
  - Nutmeg looks up at the kids while she talks during Play. The idle/lock fix: the voice reconnects with retries, a keepalive ping, and the speaker restarts. ([device-testing-fixes](decisions/2026-11-18-device-testing-fixes.md)).
  - Printables after a lock: art requests cut off by the lock are retried on return, and the color and coloring pages always come from the same AI picture. Live games show **no fallback art** (Haylee): a page that still fails shows a "Try again" tile and won't print until it loads. ([printables-after-lock](decisions/2026-11-18-printables-after-lock.md)).
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
