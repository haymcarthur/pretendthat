# Prop art library (household props from a vetted list)

- **Date:** 2026-11-13
- **Decided by:** Claude's call, pending Haylee's OK (built so it's easy to flip back)

**Decision:** Props come from a fixed library of household items that Haylee draws in Nutmeg's style, not from per-prop generated art. The Realtime `show_props` tool's `item_id` is an enum of these IDs (`PropLibrary`): stuffed-animal, chair, table, couch, pillow, blanket, rug, cardboard-box, plate, cup, bowl, tray, spoon, pot, towel, laundry-basket, books, hat, bag, backpack, toy-car, flashlight, broom (toy), teddy-bed (doll bed), lamp-off (unplugged lamp), cushion, stool, sheet (bedsheet), basket, bucket. Each suggestion also carries free-text `becomes` ("plate → steering wheel") and 1–2 `alternates` from the list.

- Art: assets `prop-<id>`. Interim art is cropped from Haylee's sheets (`design/nutmeg/household-props-sheet1.webp`, `-sheet2.webp`) by `tools/crop_prop_sheets.sh`; her final vectors replace them under the same names.
- Fallback: if the model insists on an item outside the list, it's logged (DEBUG) and gets a generated sticker; free text naming something unsafe is dropped. Game-idea and role cards keep generated stickers ([D5](generated-item-illustrations.md)).
- **Missing props (Haylee):** props are always optional and never block progress. `swap_prop(old_id, new_id, becomes)` flips the card to the new item; `skip_prop(id)` fades the card to a "We'll pretend!" state (it stays on stage, not removed like a failure). If kids are ready before finding everything, Nutmeg goes on cheerfully.

**Why:** Consistent hand-drawn art, instant (no image wait), cheaper, and safer: every prop comes from a vetted list.
