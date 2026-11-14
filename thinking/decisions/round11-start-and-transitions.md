# Round 11: start-screen choreography, one-move transitions, stage audit

**Date:** 2026-11-14 (~01:00–02:30) · **Decided by:** Haylee (the items in queue-next-app-round.md "Round 11");
implementation details are Claude's calls, noted.

## 1. Start screen choreography (Haylee)
- **Chest wiggle during the curtains:** wiggle 1.0–1.6 s (curtains 0.15–1.95; they're ~60% open at 1.0). Lid pop
  1.6–1.95 as the curtains finish, toys from 1.9 (round 8's 0.1 s gap kept), Nutmeg's crouch as the last toy lands.
- **Logo card + "Let's play!" pop WITH Nutmeg:** one shared curve `PTStartTimeline.pop(t, peak:)` (her rise, ease-out
  cubic to the peak, then the drop back) drives her height, the card's scale and the button's scale; same start
  (3.2 s), same length (0.42 s). Card/button overshoot 1.15 (hers ~1.2; Claude's call so the UI reads as a pop, not a
  jump). The logo is WHOLE as the card arrives: the 40 ms letter-by-letter build was removed from the start screen
  (PTLogo still supports it; the gallery uses nil). The button is tappable once the pop ends.
- Opening: ~3.8 s (was 5.75 s). Proof: /tmp/pt-round11/start-to-game/sheet-intro.png.

## 2. Transitions as ONE move (Haylee)
Every phase change now starts all its moving parts in the same frame on `Theme.stageMove` (spring 0.8 / 0.84).
Staggers / delays removed:
- **Start → game:** the exit (`PTStartExit`, now ~1.05 s) starts everything on the tap: card + button pop away,
  Nutmeg crouches and hops, the toys scoot off together (was 0.6 s later, 50 ms apart), and the CAMERA pushes in to
  the game's first framing during the hop (new `ExitCamera`: Nutmeg and the floor share one transform from the arrival
  framing to the talking close-up). The game's stage stars grow in on the same camera move (the stage's own 80 ms
  staggered pop-in is gone). The step rail and control pill slide in from the tap (`onExitBegan` → RootView
  `startExiting`), not after the swap. RootView sets the camera to the close-up at the tap (no animation; the stage
  isn't on screen yet), so the old 0.9 s "let her landing settle" wait + second zoom is gone: the game takes over at
  rest. Without voice (no key) the exit lands on the arrival framing as before (tap screens). The ONLY thing that
  waits is the chest's drop (0.32 s, once her feet clear the rim; otherwise she'd stand on air inside it).
- **Kit papers (props → kit → print):** `PTPaperReveal` stagger 150 ms → 0 and its own spring → `Theme.stageMove`;
  `KitView` no longer waits 60 ms after the zoom-out (`cameraSettled` removed); the Print / Let's play! buttons come
  in WITH the papers (were after the papers landed, on `Theme.bouncy`); the chat-open fold uses stageMove (was 0.5 s
  spring).
- **Play checklist:** `SceneView` reveals its paper in the same frame (was a 60 ms `Task.sleep`).
- **Stage stars:** no 80 ms index stagger (`PTStageStar`, `PTStageAccents`); stars show/hide with the camera.
- **Role badges (tap fallback):** `ptPopIn` index stagger removed (all together on stageMove).
- **RootView:** the pill and hunt cards hide/show with the writing shot on stageMove (were 0.25 s ease); the
  `inConversation` switch (conversation ↔ classic) uses stageMove (was 0.4 s ease); arrival wait removed.
- Kept on purpose (Claude's call): audio-timed beats (roles line + 0.4 s → prop card; kit "making" line → writing),
  the 2 s anti-ping-pong gap between camera shot changes (zoom-outs for cards were already immediate), the round-10
  Done auto-check (140 ms per step, it's a feature, then the hand-off is one move), Nutmeg's pose-swap timing
  (`PoseRules`, character animation: on scene → hand-off her point lands ~0.5 s into the move), the confetti, button
  press springs and the chat scroll.

### Frame strips (10 fps, /tmp/pt-round11/)
- start-to-game/ (f*.png, sheet-intro.png, sheet-exit.png): pop = card + button + Nutmeg on one curve; exit = card,
  toys, floor, camera, stars, rail and pill all move from the tap frame; no zoom after the landing.
- print-to-play/ (sheet-papers.png, sheet-play.png, overview.png): papers + buttons fly with the zoom-out; Let's play!
  → kit out, camera, Nutmeg, floor, hand-off card and rail highlight in the same frames.
- scene-to-handoff/ (sheet.png): auto-check, then checklist out, camera, card in together.
- Debug args added: `-PTAutoStart` (start screen taps Let's play! itself, conversation stage without a voice session)
  and `-PTAutoPlay <s>` (with `-PTDemo kitReady`).
