# Revert to the old animation (no coloring beats)

- **Date:** 2026-11-13 (night)
- **Decided by:** Haylee ("Let's revert back to the old animation. This is WAY too bad.")

1. Nutmeg's pose/expression behavior goes back to 3c4c140: idle by default, brief wave / point / celebrate pop-swap
   gestures, faces via set_expression, listening / thinking faces, lip sync, sticky close-up camera.
2. REMOVED: the start_planning coloring beats (tool, instructions, app beat). No coloring pose, crayon or focus face
   while she talks or plans roles/props; a brief thinking face (set_expression) is fine.
3. Kit generation: no coloring either. She waits in idle with the thinking face (happy while she speaks) in the close
   shot, no caption cards or loading dots; she looks up (excited) and the papers fly only after the whole kit is final.
4. The jointed-arm rig is cancelled (design/export/rig/ stays unused). The new coloring art (body / crayon / fingers)
   is not imported; tools/import_art.py skips it and the app never shows the coloring body.
5. Kept from fix round 2: the shared stage, prop-hunt layouts, pinned prop and papers cards, minimum size, head/neck
   fit, new eyes and head/ear/neck art, the prop lines.

Supersedes [planning beats](planning-beats.md) and the coloring parts of [no caption cards](no-text-overlays.md) and
D6 (loading = coloring).
