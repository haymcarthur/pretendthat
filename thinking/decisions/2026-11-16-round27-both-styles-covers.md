# Round 27: every kit page in both styles, the choice on Print, a bookshelf cover per game

**Date:** 2026-11-16. **Who decided:** Haylee asked for items 1–3 (queue, round 27; item 4, the mockups, is done
separately). The implementation details are Claude's calls, noted here.

## 1. Both styles, drawn during the hunt (Haylee)
- Every kit page (badge sheet, sign, money, tickets, menu, cut-out sheet, skipped props' cut-outs) is drawn TWICE:
  full color and the outline coloring page, two separate image calls with the same prompts as round 20's two
  styles, the same safety suffix and `moderation: auto`. Slicing (badges, cut-outs) works for both.
- **Claude's calls:** one `KitArtService` per style (`colorArt`, `outlineArt`) plus a `CoverArtService`, all sharing
  ONE `AsyncLimiter` (3 at once). The color jobs are queued first (it's the default), then outline, then the cover.
- **Stored:** a saved game keeps both sets. No new JSON field: the color set keeps the plain art keys (`img:`/`cut:`),
  the outline set is `o`-prefixed (`oimg:`/`ocut:`), and `printStyle` now means "the style of the plain keys"
  (round 27 saves: full color). A game saved before round 27 has one set (its old style) and its replay offers just
  that one.

## 2. The Print screen shows both sets (Haylee)
- Both fans on the Print screen, the chosen one on a white card with a thick yellow ring and a ✓ on its chip; the
  chips have no words (four colored dots = color, four outline circles = outline). Default: color.
- Tapping a set chooses it; tapping a page chooses its set AND opens the preview. The printer prints the chosen set
  for the current player count (live: "print: the outline set, 6 page(s)").
- Voice: new session tool **`choose_print_set`** (`color` / `outline`), offered on Print for first plays and replays
  ("color", "in color" → color; "we'll color them", "the outline ones", "plain", "coloring pages" → outline). Her line:
  "The outline ones, to color yourselves! Tap the printer when you're ready!" / "Color it is! …".
- Her Print line: "Your kit is ready! Want them in color, or plain to color yourself? Tap the ones you like, then the
  printer! Tap the green play button when you're set!" The bundled clip of it was re-recorded from her real voice.
- Pages still drawing: a white veil + spinner on that page, a progress bar on its set's chip, and the printer dims
  with a spinner until the CHOSEN set is final (voice "print it" then gets "Almost ready! Those pages are still
  drawing."). The papers come out once one set is final.
- **Claude's call (layout):** the two sets are stacked in the card zone (color on top), each one tighter row of pages
  like a hand of cards, instead of left/right. The shared card zone is ~350 pt wide (round 14's one card size), so
  side by side left ~60 pt pages; stacked keeps them ~110 pt, about the old size. Easy to flip if Haylee wants them
  literally side by side (it would need a wider kit zone, i.e. Nutmeg further left).
- The chat-open pinned kit card shows the chosen set only.

## 3. The bookshelf cover (Haylee)
- One extra full-color, square (1024×1024), text-free picture of the game's scene. The prompt says "No words, no
  letters, no numbers, no title, no signs or labels with writing, no text of any kind" + the safety suffix
  (`CoverArt.prompt`). Drawn during the hunt (queued after both sets), kept only if the game is saved (cover.jpg, a
  600 px square JPEG); an unsaved game drops it with the rest.
- Fallback: no cover → the color sign page, then the outline sign page (at Save, and on the shelf for a game with
  no cover.jpg). The shelf cards are all one square size (the shortest shelf opening); the name stays on the
  shelf-edge label. The Grown-ups list thumbnails use the same picture.

## Measured (typed live runs, PT-R15-iPad, personal keys = direct to OpenAI, not via the relay)
| | Before (round 26, measured from the per-image average) | After (round 27, measured) |
|---|---|---|
| Images per game | 6 (+1 per skipped prop) | 13 (+2 per skipped prop): 12 pages + 1 cover |
| Image cost per game | ≈ $0.13 | **$0.28** (13 images, 3,208 in + 8,792 out tokens); $0.33 with 1 skip (15) |
- That's about **+$0.15 a game**, more than the queue's +$0.07 guess: these low-quality calls average ~2.2¢ an image
  (output tokens at $30/1M), not ~0.6¢.
- **Time:** the pages were written 8–9 s into the hunt; the cover (last in the queue) landed 41 s after the hunt
  started, so all 13 hunt-time images were in ~33 s after the pages were written. Run 1 (3 props, typed, the fastest
  a hunt goes): Print reached at 51 s, everything already drawn, kit final 0.6 s after Print (the play guide). Run 4
  (4 cards, 1 skipped): Print at 56 s; the two skipped-prop cut-outs (one per style) can only start when the hunt
  ends, so the kit was final 6.8 s after Print (that wait existed before for the one skip cut-out too). **Typical
  2–4 prop hunts with real kids take minutes, so both sets and the cover are ready by Print**; a 2-prop typed hunt
  (~40 s) would be about even with the last images.
- **Relay rate:** peak 13 and 15 image requests in any minute (limit 40/min), **0 × 429**. The relay doesn't change.
- Before wasn't re-run live; "before" = 6 images × the measured per-image average.

## Live checks (typed turns as voice)
- New game "Magic Bakery on the Moon", 2 players, 3 props → Print shows both sets (color chosen) → "We'll color them"
  → `choose_print_set` → outline highlighted, her line → printer → the iOS print sheet with the outline set (2 badges)
  → play through → ⭐ save: 32 art files (16 color + 16 outline), the generated cover, 3.2 MB.
- Bookshelf: the new game's cover card and an older (pre-round-27) save showing its sign page, same square size.
- Replay → "Two of us" → hunt → Print offers both sets again → "The outline ones please" → outline → print sheet;
  **0 image calls, 0 Claude calls** on the replay.
- Fast hunt with a skip (pirates): the skipped prop's cut-out appears in both sets' cut-out sheets.
- Screenshots: `/tmp/pt-round27/` (02 both sets, 03 outline chosen, 04 print sheet, 05 bookshelf covers, 07–09
  replay Print, 11 fast hunt, 12 Grown-ups list, cover-moonbeam.jpg).

## Tests
- NutmegCore 382 green; `Round27Tests` (both-style jobs, styled keys + old saves, voice words → set, selection default
  and Print-only, one-set replays, the Print line, the no-text cover prompt, cover fallback, the SavedGame round trip
  with both sets + cover, per-minute peak). Relay unchanged (no redeploy).

## Not verified
- The "still drawing" veil/progress bar live (in these runs every set was final by the time the papers came out; the
  reveal waits for one set). Spoken (mic) choices; VoiceOver on the set chips; the chat-open pinned card; a real
  printout; the relay path itself (the live runs used direct keys).

## Follow-up: bigger shelf cards (Haylee, "make them bigger", 2026-11-16)
- The square cards (~79 pt) left most of each compartment empty. Now the 3 cards FILL the compartment like mockup
  states 3–4: height = 90% of the shortest compartment opening (top of opening to the board's front edge), the same on
  every shelf, standing on the board (bottom halfway between its back and front edges, the arched top row too);
  width = 3 cards with 4 even gaps (3.5% of the opening each). On the 11" iPad that is about **130 × 84 pt** (was
  ~79 × 79). **Claude's call:** the cards are landscape like the mockup, so the square cover is centre-cropped to fill
  the card (the cover has no text, so nothing important is lost); the sign-page and prop-sticker fallbacks are unchanged.
- Paging, page dots, the back arrow and the shelf-edge labels are unchanged. Grown-ups list thumbnails unchanged.
- DEBUG: `-PTDemo shelf` seeds 5 games (env `PT_SEED_COUNT` for more, `PT_SEED_COVER` = a cover JPEG on every other
  one) and opens the bookshelf. Screenshots: `/tmp/pt-shelffix/` (before-shelf, after-shelf, after-shelf-full-page1
  with 10 games + paging, after-grownups-list). NutmegCore 382 green.
