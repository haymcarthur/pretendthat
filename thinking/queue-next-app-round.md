# Queue: next app round (held until the current build round reports)

Art ready in design/export/ to import:
- nutmeg/nutmeg-head-base.svg: left-ear shadow fixed (thin crescent inside ear; old band removed). Backup: nutmeg-head-base.before-ear.svg
- nutmeg/nutmeg-face-yay.svg, nutmeg-face-nap.svg: closed eyes aligned to open-eye positions (blinks)
- (pending) all 9 faces with new straight-looking eyes + focus face (Figma agent in progress)
- (pending) crayon + gripping paw pieces for the coloring pose (waiting on Haylee's ChatGPT art)
- startscreen/chest-body.svg: new box art (sent to the build already)

## Round 3 (after round 2 reports)
- Crayon v3: nutmeg-body-coloring.svg (v3), nutmeg-coloring-crayon.svg, NEW nutmeg-coloring-fingers.svg. Stack: body → crayon → fingers → head → face.
- JOINTED-ARM RIG (Haylee approved 2026-11-13): parts in design/export/rig/ + rig.json (body bases stand/jump/sit, tail, upper/forearms L/R with joint caps, hands open/grip/point/fingers-front, clipboard, crayon). Build a NutmegRig view behind a Grown-ups toggle ("Jointed Nutmeg", default OFF until verified); keep whole-pose Nutmeg as the fallback. Poses become joint-angle presets (idle, wave, point, celebrate w/ clipboard, coloring, both-hands clipboard in-between) with spring interpolation between them; props attach to hands.

## Updated after revert (2026-11-13 evening)
- Rig and coloring beats CANCELLED (see decisions/revert-animation.md). Whole poses only.
- NEW whole pose: nutmeg-body-clipboard-both.svg (clipboard held in front with both hands). Use as the in-between when she brings out the clipboard (e.g., before the kit reveal / while making the kit) — pop-swap like other gestures.
- Pending art from Haylee (ChatGPT regen, not Figma patches): a clean head (smooth chin rim, subtle ear shadows, brown neck).

## Round 3 done (2026-11-13 night)
- Imported head-base (new), nutmeg-headset (own top layer), idle (new), clipboard-both; clipboardBoth pose during kit making.
- Art issues for Haylee (not patched): head-base silhouette includes the idle body's hanging right arm (app masks it); thin light sliver along the idle body's right vest edge; clipboard-both fur AD5E36 / clipboard FEC726 more than ±12 from the palette (left as drawn).

## Round 5 (after round 4)
- New headless WAVE + POINT bodies (Haylee regenerating) → cleanup/import.
- WRITING animation, new approach: close shot framing head + top of clipboard (hands out of frame), clipboardBoth pose, crayon-v3 layer wiggling with only its top visible, scribble sound, focus face; then look up → normal view. (When: kit-making; planning moments TBD by Haylee.)
- Fresh screenshot pass of the CURRENT app for the deck: conversation, prop hunt, kit reveal (papers), play step (checklist/hand-off), start screen with tiny gear. Then update slides 3 (all four step cards) and 5 (waving Nutmeg with new art).
- WRITING moment runs EVERY time she is planning (roles, each prop, kit), even if quick — short beat so it flows (Haylee 2026-11-13).
- clipboardBoth pose fixes: head too big/low/offset on this pose → per-pose head scale + offset (torso is ~55px taller; neck top 734 vs 789). LAYERING: split the clipboard-both art into body / clipboard / hands layers (layer split only, no reshaping), stack body → head → face → headset → CLIPBOARD → HANDS, so the clipboard sits in front of her chin/face and her paws grip in front of it.
