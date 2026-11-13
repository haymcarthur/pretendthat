# Checklist and scene pictures (no emoji)

- **Date:** 2026-11-13
- **Decided by:** Haylee
- **Supersedes:** emoji on steps, scenes, props, ideas, roles and choices (and the EmojiMatch fixer); extends [generated item illustrations (D5)](generated-item-illustrations.md) and [prop art library](prop-art-library.md).

## Decision
- **No emoji.** Each checklist step gets exactly ONE picture reference of one of three kinds:
  1. `prop:<library id>`: the household-prop art ("Put the plate on the tray" → `prop-plate`).
  2. `action:<id>`: Haylee's ACTION art set: wave, clap, point, listen, look, count, give, knock, write, stir, brush, wash, ring-bell, stamp, measure, cheer (`action-<id>`; placeholders until the vectors arrive).
  3. `kit:<item>[:<variant>]`: art from THIS game's generated kit: `kit:ticket` (one ticket tile), `kit:money` (one bill), `kit:badge:<role>`, `kit:menu`, `kit:sign`, `kit:cutout:<n>` (one specific cut-out, e.g. a pancake for "Hand out the pancakes").
- The **cut-outs page is generated as individual images** (one per cut-out, 6–8, in parallel); the app tiles them onto the printed page like tickets, so each item is available on its own. Tickets, money and badges are already single-tile images and are reused.
- Claude's scene schema: each step and each scene title has `picture: {kind: prop|action|kit, id}`, both enums (library IDs, action IDs, this kit's item kinds and cut-out indices). Prefer kit pictures when a step hands out or uses a printed item, prop pictures for household props, actions otherwise. **Fallback when unresolvable: action-point.**
- **Other emoji/icon stand-ins removed:** confetti uses the stage-star / stage-sparkle art; the hand-off card shows Nutmeg (point pose) plus the role title in the role color (no role emoji or symbol); prop cards never fall back to emoji (props must come from the library; off-list suggestions are dropped); the backup tap screens drop emoji (text, plus library/action art where it fits). Standard UI control icons stay (mic, chat, close, checkmark, arrows).

## Implementation notes (Claude)
- `Picture`, `ActionArt`, `PictureResolver` (NutmegCore/Picture.swift). Badges resolve by role id (`badge:R1`) or role title; a badge for a role not in this game, a cut-out index past the list, an unknown prop/action, or no kit yet → `action-point`. Steps without a picture decode as `action-point`.
- `PTPictureTile` (DesignSystem) draws the art, the badge's role title in the role color, or a placeholder word while art is missing (action vectors pending, kit art still drawing).
- `KitArtService` generates cut-outs as `<item>#<n>` jobs at 1024×1024; `KitPageView` tiles them 2 columns under the title with dashed cut lines.
- Claude's props schema: `id` is a PropLibrary enum; the Sanitizer drops anything off-list. Ideas, roles and choices no longer ask for emoji (old JSON still decodes).
