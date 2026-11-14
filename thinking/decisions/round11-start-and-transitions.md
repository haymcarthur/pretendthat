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

## 3. Experience-wide stage audit (Haylee, added mid-round)
**One camera, one set of framings.** `PTStageDirector.Preset` (NutmegCore/StageCamera.swift) is the ONLY way a phase
gets a framing; `PTStageDirector.preset(...)` maps phase × chat → preset and `frame(preset)` gives the camera frame.
RootView's per-screen special cases are gone (the round-8/10 "chat open in a scene/hand-off → centered wide" and
"scene chat closed → huntFrame" overrides), as are `side(g)` / `sideContent` / `sideLane` and the wide shot's
ears-below-the-top nudge (the non-landing wide frame no longer exists).

| Phase | Chat closed | Chat open (keyboard up = same) |
|---|---|---|
| Start → game hop (landing) | hop | hop |
| Game / count / theme conversation (talking) | talk | talk (centered between rail and panel) |
| Writing moment (planning or kit) | writing | writing |
| Prop hunt (prop card step) | propCard | propCardChat (card pinned in the panel) |
| All props at once (legacy `show_props`) | presentedCards | presentedCards |
| Kit being made (coloring) | talk | talk |
| Print (kit pages) | propCard (fan in the card zone) | propCardChat (pages pinned) |
| Play checklist | propCard | propCardChat (checklist pinned) |
| Hand-off | propCard (card in the card zone; was a whole-body left lane) | propCardChat (pinned) |
| Finale | propCard (card zone) | propCardChat (pinned, new: `EndView` in `.ptPinnedCard()`) |
| Tap screens (no voice) | propCard | propCardChat |

- **Keyboard:** the stage group, the step rail and the control pill `.ignoresSafeArea(.keyboard)`: the keyboard
  covers the stage's bottom and nothing re-frames; only the chat panel (and its field) rises.
- **Floor scales with Nutmeg:** the camera's reference (arrival framing on the start screen's floor) is now computed
  for the full chat-closed, keyboard-free stage (`PTStageGeometry.referenceSize`, from RootView's root size measured
  with the keyboard ignored). Before, the narrower chat-open stage shrank the reference, so the floor grew relative to
  her. Floor width ÷ Nutmeg scale is now constant in every preset (unit test). Her contact shadow is part of her view.
- **Stage stars = stage props:** exactly the camera transform (no 70% parallax, no point cap), so they keep their size
  relative to her; shown only where they fit (unchanged rule).
- Content: every phase's content sits in the prop-card zone (`huntContent`). The content scale-to-fit (content wider
  than the zone scales down) is unchanged: it's the content fitting its zone, not the camera (Claude's call).
- Hand-off/print→play now share the propCard framing, so print → play moves only the content (kit out, card in), in
  one move. Checked: /tmp/pt-round11/print-to-play/sheet-play.png.

### Tests
- 167 (3 new, `StagePresetTests`): every phase/shot/beat/writing combo yields only preset frames; the phase table
  above; floor : Nutmeg constant across presets and chat states. StageCameraTests green.

### Screenshots
- /tmp/pt-round11/audit/grid.png (rows: checklist, coloring, finale, handoff, kitpages, propcard, talk, tapscreen,
  writing; columns: chat closed, chat open, chat open + keyboard) + the single PNGs. Debug arg `-PTKeyboard` (with
  `-PTChat`) focuses the chat field.

## Not verified
- 13" iPad; Reduce Motion; a live voice session (the start → game close-up push assumes the voice key is set; the
  frame strip uses `-PTAutoStart`, which forces the conversation stage without audio); the legacy presented-cards path
  and the tap screens with real content beyond pickGame; the step rail's current-step highlight still lands at the
  end of the start exit (the phase changes then).
