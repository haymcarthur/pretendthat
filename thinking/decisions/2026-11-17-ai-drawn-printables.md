# Printables: the AI draws the whole page (replaces round 45's app-drawn look)

- **Date:** 2026-11-17
- **Decision (Haylee):** round 45's app-drawn cards/borders/text looked plain and form-like (a regression). Rebuild so the AI draws each WHOLE printable page (frame, decorations, layout, all words) from a per-type prompt recipe; the app draws nothing on top. Approved after the prompt test (design/printables-ai-test/, research/2026-11-17-ai-drawn-printables-test.md): 17 pages, 0 misspellings, about 2.2¢ a page.
- **Kept from round 45:** the 17-type library, the per-game shortlists, the layout variants (now prompt variants), the variant rotation, every item used in scenes and in setup/clean-up rows, the no-printed-props rule, and schema 4/3 compatibility.
- **Claude's calls (Haylee approved the rebuild with these as recommended):**
  1. No skulls/crossbones: friendly pirates (kids 4–8, App Store).
  2. Coloring pages use bubble letters.
  3. One small picture-only "character sheet" per kit for the in-app scene rows and prop cards (+2–4¢ a game), since whole pages can't be sliced cleanly.
  4. The app fits each 2:3 page inside the printable area (the model ignores margin requests).
  5. A forgiving on-device OCR check (Apple Vision; ignores spaces/underscores/"!", maps look-alikes, S before a digit = $) redraws a page once only when a quoted word is truly wrong.
