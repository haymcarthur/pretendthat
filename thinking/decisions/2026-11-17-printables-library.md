# Printables overhaul: picture-only art, a library of 17 types, kits chosen per game

- **Date:** 2026-11-17
- **Decision (Haylee approved all five recommendations):**
  - **Art is a picture only:** no words, frames, banners or blank boxes in any AI image. The app draws the card, border, Name line and all text in its own space beside the picture, never on top. This fixes the double frames on badges and tickets and the baked-in text ("Mission Pass", "Agent Level: Super").
  - **Library of 17 printable types** (research/2026-11-17-printables-library.md):
    - Today's six, reworked: badges, sign, money, tickets (each copy numbered), menu/price list, cut-outs.
    - The new ones: order slips, map, clue cards, mission cards, log/chart, medals, stickers, passport, labels, code decoder, control panel.
    - Common types get 2–3 app-drawn layout variants (e.g. badge: lanyard / pin / ID card). The app picks the variant from the game family and avoids the last 2–3 games' variants.
  - **The five answers:**
    1. No sign when the game has no "place" (treasure hunt, spy, ...).
    2. One picture per printable, not shared sheets: more custom, about today's cost.
    3. Printables with words (clue cards, logs, order slips) are picture-first with very few words, and Nutmeg reads them aloud in the scene.
    4. Old saved games stay as they are and replay without new images.
    5. A set shortlist per suggested game. Claude may swap in up to 2 types for the theme twist, and picks freely for made-up games.
  - **Badges are in every kit,** and every item has a job in a scene (standing rule; SetupCoverage moves to item ids). Saved-game schema 4 decodes unknown kit names tolerantly.
- **Why:** kits looked the same every game, some items didn't fit the game (tickets for a spy game, a price list for a treasure hunt), and the art had overlapping frames.
- **Who decided:** Haylee (direction + the five answers); the library and the variants are from Claude's research.
