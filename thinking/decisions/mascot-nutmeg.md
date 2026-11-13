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
