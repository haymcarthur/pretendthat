# Mascot name: Nutmeg

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** The stage-manager mouse is **Nutmeg**, a girl (she/her) with a headset and clipboard. "Nutmeg" replaces the placeholder "Pip" everywhere: docs, code types (`NutmegCharacter`, `NutmegVoice`, `NutmegCore`), and asset layer names (`nutmeg-*`).

**Why:** Haylee's pick. Warm, cozy and easy for a 4-year-old to say. The look and behavior from [Mascot: stage-manager mouse](mascot-mouse-stage-manager.md) are unchanged.

## Personality (Haylee, 2026-11-13)

Nutmeg is **bouncy and excitable**, eager to imagine and explore new worlds: a fellow kid running the show, not a calm adult stage manager. Her lines are short, enthusiastic and full of wonder ("Ooh! Pretend that we're flying over the ocean!").

**In code:** bouncier animation defaults (springy idle bob, a happy hop on "excited", ears that perk quickly); TTS pitch and rate a bit higher and livelier than the spec's 1.2 / 0.48; the system prompt steers her voice this way.

## Art contract: head on body poses (Haylee, 2026-11-13)

Replaces the single-pose layer list. One shared **head** sits on one of several headless **body poses** (`nutmeg-body-wave | point | celebrate | sit`), each with a neck anchor, head rotation and head scale stored in code (`NutmegPose`). `nutmeg-tail` is its own layer behind the body. Head canvas layers (full-frame, stack with no offsets): `nutmeg-ears-normal | perked | flop`, `nutmeg-head-base` (no eyes or mouth), faces `nutmeg-face-happy | talking | listening | thinking | ooh | yay | oops | nap` (eyes + brows), mouths `nutmeg-mouth-closed | small | open | wide | ooh`. An expression = face + ears + default mouth; while she speaks, the amplitude mouth overrides it.

State map: idle → wave/happy/normal; listening → point/listening/perked; thinking → wave/thinking/normal; talking → current pose/talking/normal + live mouth; excited → celebrate/yay/perked; error → wave/oops/flop; step-back → sit/nap/normal. Reference art in `design/nutmeg/`. Spec §7 updated.

## Update 2026-11-13 (Haylee): rest pose, brief gestures, pop swaps

- **Idle is the rest pose** (`nutmeg-body-idle`: arms relaxed at her sides, clipboard tucked under one arm; placeholder until Haylee's art). It is the default for resting, listening and talking.
- **Gestures are brief:** wave (hello/goodbye), point (presenting items), celebrate (kit ready, the end) each play once: pop in, hold about 1.2–2 s (`PoseRules.hold`), pop back to idle. Never a held state.
- **Sit** only for the step-back nap; **coloring** (`nutmeg-body-coloring`) only while generating.
- **Pop swap** (no joints): squash (scaleY 0.92, scaleX 1.05, ~90 ms) → small hop (−12 pt, scaleY 1.06) with a ~100 ms body crossfade at the peak → spring landing with overshoot. The head is one continuous view that springs to the new neck anchor and rotation. Swaps are throttled to one per 1.5 s (`PoseRules.minSwapInterval`). Tail and ears stay continuous. Reduce Motion: plain crossfade.
- Rules live in `NutmegCore/PoseRules.swift` (tested); drawing in `NutmegCharacter.swift`.

## Real art imported 2026-11-13

Haylee's Figma export (`design/export/`, imported by `tools/import_art.py` as vector imagesets). All Nutmeg layers share one 1178×1335 canvas, so bodies, `nutmeg-head-base`, faces and mouths stack full-frame; the head sits on every pose at offset (0,0) (verified for all 6 poses × 8 faces, `/tmp/pt-voice/art/`). Per-pose values in `NutmegPose`: neck anchor (600, 788) (sit 793.5), head offset (0,0) (sit +5 px), head tilt idle/wave/celebrate 0°, point 3°, sit −4°, coloring 5°. Each face SVG is split by fill color into the face (eyes/brows) and `nutmeg-face-<x>-mouth`, so the amplitude mouth replaces it while she talks. Ears and tail are drawn into head-base and the bodies, so ear perk/flop is not separate (`nutmeg-ears-flop` is imported but unused; it would draw over the normal ears). Stage props imported except `stage-beam` (a soft glow). The 30 `prop-<id>` vectors replace the cropped interim art.
