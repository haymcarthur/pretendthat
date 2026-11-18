# AI-drawn printable pages: prompt recipes + live test (2026-11-17)

**Why:** Haylee called round 45's look (AI draws a small picture, the app draws the cards, borders and text) a regression: "too plain, form-like". New direction to test before any rebuild: the image model draws the **whole printable page** (frame, decorations, layout, every word) and the app draws nothing on top. The type library, per-game shortlists and layout variants stay, but as **prompt recipes**. Safety nets: short exact quoted words in prompts, and later an on-device Apple Vision text check that redraws a garbled page once.

**This was a prompt test only.** No app code changed. Gallery: `design/printables-ai-test/index.html` (every page large, with game, type, color/outline, OCR result, prompt), contact sheet `design/printables-ai-test/contact-sheet.png`, scripts in `design/printables-ai-test/scripts/`.

## Result in one paragraph
All 17 pages came back usable, and **no quoted word was misspelled** (checked by eye on every page). Apple Vision OCR read 13 of 17 pages exactly. The other 4 pages were also correct: OCR misread them ("$3" in hollow bubble letters as "S3", "3A" with a Cyrillic "З", the blank Name line read as "Name:_", and "inside the" read as one word). A tolerant match (ignore spaces, underscores and "!", map look-alike letters, S before a digit = $) passes **17 of 17**. The look is much richer than round 45's: real lanyard tags with ribbons, a scroll map, a hanging door sign, notepad order slips, and coins and bills that look like a set. **Cost: about 2.2¢ a page.** 19 calls were billed (17 saved, 2 lost when the connection dropped mid-download): $0.379 measured for the 17, about $0.42 with the 2 lost ones.

## How it was run (rule 7)
- **Path:** the deployed relay, the app's way. `POST https://<RELAY_HOST>/v1/images/generations` with the `X-PT-Token` header, values read from `Relay.xcconfig`. Haylee's personal keys were not used. No Claude and no voice calls.
- **Model and settings from the app:** `ImageClient.models` order (`gpt-image-2.6-flare` → `2.5-flare` → `gpt-image-2`; 2.6-flare answered every time), `ImageQuality.kit = "low"`, `n: 1`, `output_format: png`, `moderation: auto`. Size **1024x1536**: the app's portrait size, and the closest one to a US Letter page.
- **Two practical notes for the scripts:**
  - Cloudflare answered Python's default user agent with a 403, so the script sends a generic `User-Agent`.
  - Python's reader twice got "connection reset" while downloading the ~2 MB answer from the relay (the image was made and billed, but lost). Switching to curl fixed it. The app uses URLSession, so this is likely a client problem, not a relay one. Worth checking if the app ever logs a lost image.
- **OCR:** `scripts/ocr.swift` (`VNRecognizeTextRequest`, `.accurate`, language correction off, en-US), scored by `scripts/score.py` (strict, then tolerant).

## The recipe template
Every recipe is the same five blocks, joined in this order: **PAGE + game + STYLE + the type's layout + WORDS + (CUT) + SAFE**. The shared blocks are the same for every page in a kit, so the kit looks like one set.

**PAGE** (every page):
> A printable US Letter portrait page (8.5 by 11 inches) for a kids' pretend-play game, drawn flat and straight-on and filling the whole image: the page itself, not a photo or mockup of paper. Plain white paper with a clean white margin of about half an inch on every side where nothing is drawn, so it prints on a home printer. The game is "<game title>".

**STYLE, color** (shared style line, the same on every page of a kit):
> Art style for the whole kit: bright, friendly flat vector cartoon like a modern kids' picture-book app: bold clean dark purple outlines, flat cheerful fills in coral red, sunny yellow, lime green, sky blue, deep purple and cream, soft rounded shapes, no gradients, no shading texture, no photo effects, lots of white paper. Ink-friendly: color sits on white, no full-page dark background.

**STYLE, outline** (the coloring-page version; same layout text, only this block changes):
> Art style for the whole kit: coloring-page version of a friendly flat vector cartoon: black outlines only on white paper, thick clean even lines, soft rounded shapes, no color, no gray, no shading, no filled black areas, every shape open for a 5-year-old to color in. Letters are bold outlined bubble letters that can be colored in too.

**WORDS** (the exact-words net; the list comes from the kit, with the repeat count when a word appears on every copy):
> The ONLY words on the page, spelled exactly letter for letter: "A", "B", …. [e.g. "Name:" appears once on every badge (4 times).] Big, clear, rounded print letters, easy for a 5-year-old to read, dark on a light background, never curved along a path, never tiny. No other words, letters, numbers or signatures anywhere.

**CUT** (sheets that get cut apart):
> Thin gray dashed cut lines around each piece, with wide white gutters between pieces so scissors fit.

**SAFE:** today's `ImageSafety.suffix` (no guns, knives, blood, real people, brands, logos; a toy sword is fine).

### Per-type layout blocks (the variable part)
`<…>` comes from the kit (Claude's item fields). Words in quotes are the only text on the page.

1. **Role badges, lanyard variant.** A sheet of exactly N lanyard name badges (2×2 for 4, 3×2 for 6, 2 on top and 1 centered for 3), all the same size. Each is a tall rounded tag with a punched hole and a clip at the top center, a themed border, a character picture for the role in the upper half (`<what they wear/hold>`), the role title on a ribbon banner, and at the bottom **"Name:" followed by a long blank line**. Words: the role titles + "Name:" × N. Plus CUT. (Pin variant: round badges with the same rows. ID-card variant: landscape cards with the picture on the left and the title and Name line on the right.)
2. **Place sign, door variant.** ONE big door sign filling the page: a tall rounded board hanging from a string, a themed frame. Across the top in huge letters "`<place>`", a big cheerful picture of `<place picture>` in the middle, and "`<tagline>`" on a ribbon near the bottom. (Banner variant: landscape pennant string. Marquee: light-bulb border.)
3. **Treasure map.** ONE old-paper scroll map of `<place>` seen from above. A winding dashed path visits the N stops in order. Each stop is a big landmark drawing with its name on a small flag or plaque: "`<stop 1>`" … "`<stop N>`". A big red X at the last stop, a compass rose with no letters, and the title "`<title>`" on a ribbon.
4. **Clue cards sheet.** Exactly N cards in a 2-column grid, each a rounded card with a themed border (rope, stars, shells), a number in a circle in the corner, a picture hint of `<hint>`, and the clue "`<clue>`" under it. Words: the clues + the numbers 1…N. Plus CUT.
5. **Menu card.** ONE menu page with a themed frame (forks, spoons, hearts, checkered corners), the place name "`<place>`", the big word "Menu", then one row per dish: a small picture on the left, "`<dish>`", a dotted leader, and "`<$price>`" on the right. (Board variant: chalkboard frame with light letters. Program variant: acts with no prices.)
6. **Order slips sheet.** Exactly 4 identical notepad slips (2×2) with a spiral top. Each has "Order", then "Table" and a small empty box, then one row per dish: an empty tick box, a tiny picture and "`<dish>`". Words: "Order", "Table" and the dishes (4 copies). Plus CUT.
7. **Coins / money sheet.** Coins: exactly 12 identical round coins (3×4) with "`<money name>`" across the top. Each coin has a thick rim, `<emblem>` and a big "1"; dashed circle cut lines. Bills: exactly 8 identical bills (2×4) with a fancy border, `<emblem>` in an oval, "$1" in two corners, and "`<money name>`" on each. (Tokens variant: the coin layout with a star rim and no number.)
8. **Tickets / passes, a different number per copy.** Exactly N passes (2 columns), ticket shapes with notched corners and a perforated stub. Each shows "`<title>`" and a small picture of `<picture>`, and on the stub its own number, "in this order left to right, top to bottom: "01", "02", …", with "Each number appears on exactly one pass". The app writes the number list (01–08, 1A–4B, Room 101…).
9. **Cut-outs sheet.** Exactly N big props in a 2-column grid, in order (`<things>`), each one object filling its cell with a thick white cut-around border and a dashed cut line. The title "`<title>`" is across the top, and the props themselves have no writing.

The other library types follow the same pattern (log = ruled lines with a header picture; medals = N ribbons with award titles; passport = a fold-in-half booklet with stamp boxes; labels = N tags; control panel = buttons with 1–2 word names around a window picture). The decoder stays app-drawn (its symbols must be exact).

## What was generated (17 pages, all gpt-image-2.6-flare, low, 1024x1536)
| Page | Game | Type | Style | OCR strict | OCR tolerant | By eye |
|---|---|---|---|---|---|---|
| pirate-badges | Treasure hunt (Captain, Map Reader, Clue Finder, Lookout) | Badges, lanyard | color | exact | exact | correct |
| pirate-map | Treasure hunt | Treasure map (Big Rock, Palm Tree, Cave, Treasure) | color | exact | exact | correct |
| pirate-clues | Treasure hunt | 4 clue cards | color | exact | exact | correct |
| pirate-coins | Treasure hunt | 12 coins "Island Gold" | color | exact | exact | correct |
| pirate-passes | Treasure hunt | 8 "Ship Pass" numbered 01–08 | color | exact | exact | correct, each number once, in order |
| pirate-cutouts | Treasure hunt | Cut-outs "Hunt Gear" | color | exact | exact | correct |
| cafe-badges | Restaurant (Chef, Waiter, Customer) | Badges, lanyard | color | exact | exact | correct |
| cafe-sign | Restaurant | Door sign "Cozy Café" / "Now Open" | color | exact | exact | correct (accent right) |
| cafe-menu | Restaurant | Menu card (4 dishes, $1–$4) | color | exact | exact | correct |
| cafe-slips | Restaurant | 4 order slips | color | exact | exact | correct |
| cafe-bills | Restaurant | 8 bills "Cozy Bucks" $1 | color | exact | exact | correct |
| cafe-cutouts | Restaurant | Cut-outs "Pretend Food" | color | exact | exact | correct |
| pirate-badges-outline | Treasure hunt | Badges, lanyard | outline | exact | exact | correct |
| cafe-menu-outline | Restaurant | Menu card | outline | "$3" read "S3" | exact | correct |
| stress-badges6 | Treasure hunt, 6 players (+ First Mate, Ship's Cook) | Badges, lanyard | color | "Name:" 3/6 (read "Name:_") | exact | correct |
| stress-clues6 | Treasure hunt, 6 clues of 4–5 words | Clue cards | color | "inside the" read "insidethe" | exact | correct |
| stress-boarding | Treasure hunt | 8 "Boarding Pass" 1A–4B | color | "3A" read with Cyrillic "З" | exact | correct |

## What looked good
- **It no longer looks like a form.** Each type has its own real-world shape: lanyard tags with clips and ribbons, a curled scroll map, a hanging door sign with an awning shop, notepad slips with spiral rings, coins with rims, tickets with stubs. This is the "printable kit you'd buy on Etsy" look.
- **One kit reads as one set.** The shared STYLE line gives the same purple outlines, cream cards and yellow ribbons on every pirate page, and the same awning and checker motifs on the café pages. The model also picks a motif per kit by itself (rope + shells for pirates, awnings for the café).
- **Text is reliable when it's short.** No misspellings, even with 6 badges × 2 lines, 4–5-word clues, an apostrophe, an accent and 8 different codes. Per-copy numbers come out in the right order, each once.
- **Badges match the roles.** The character holds the right thing (key, map, magnifier, spyglass + parrot, chef's spoon, waiter's tray). "Name:" plus a blank line is on every badge.
- **Outline versions are real coloring pages** with the same layout and open shapes. The menu used hollow bubble letters, as asked. The badges used plain letters.
- **Fast:** 6–9 s a page, about the same as today.

## Problems and risks for a rebuild
1. **Margins are ignored.** Pages run to within a few pixels of the image edge, even though the prompt asks for half an inch. **Fix in the app, not the prompt:** print the 2:3 image fitted inside the printable area (on Letter that is about 6.7 × 10 in, centered), which gives real margins for free. 1024x1536 isn't Letter-shaped anyway (2:3 vs about 1:1.29).
2. **The OCR net needs tolerant matching.** A strict check would have redrawn 4 good pages (about 9¢ wasted, plus waiting time). Match ignoring spaces, underscores and punctuation, map look-alike letters (Cyrillic, S/$, maybe O/0, l/1), and count repeats. Bubble-letter outline pages are the weakest for OCR. Check the words on the color page, and on the outline page only when the color page was redrawn. Redraw once at most, then keep the better of the two.
3. **Round 45's slicing reuse breaks.** Today the badge sheet slice IS the role character in scene rows, and the cut-out slices are checklist pictures. A whole page has frames, titles and cut lines in it. The options:
   - slice by the known grid and accept the frame in the picture;
   - crop the picture area of each cell;
   - keep a separate small sticker per role/prop (more images).

   This needs a decision before the rebuild.
4. **Badge count = kid count.** The sheet is drawn for exactly N roles (3, 4 and 6 all worked). Replays and "generate for 6" need the badge page drawn per role count, or always 6 with extras.
5. **Pirate skulls.** The model put a skull and crossbones on pirate hats, flags and tickets on its own. It's mild cartoon style, but if Haylee wants none, add "no skulls" to SAFE for pirate games.
6. **Words still come from Claude.** The prompt recipe is only as safe as the strings it quotes. Keep the round 45 line limits (1–3 words per stop or dish, at most about 5 words per clue) and the moderation check on every quoted string. Longer than that hasn't been tested.
7. **No saved-game impact tested.** Old kits keep their art as before.

## Cost
- Measured: 17 pages, 7,972 input + 11,288 output tokens = **$0.379** (2.23¢ a page). The 2 pages lost to dropped downloads were probably billed too: **about $0.42 in total for 19 calls**.
- **Per game, if a whole page is one image:** 6 printables × (color + outline) + cover = 13 images ≈ **$0.29**. That's the same as round 45's 13 images ($0.285–0.304), because round 45 already used one image per printable per set. Adding a redraw-once net costs about 2.2¢ per redraw. Expect few redraws with tolerant matching.

## Recommendation (for Haylee)
The whole-page look is clearly better and the text held up at the app's own (low) quality. If she likes the gallery, the rebuild would:
1. Turn `KitArtPrompt` into recipe builders (the 9 above + the remaining types). Keep `PrintShortlist`, the variants and `RecentPrintMemory`.
2. Print each page as one image fitted inside the margins (drop the `LibraryPages` drawing).
3. Add the Vision tolerant-match check with one redraw.
4. Settle how scene rows and checklists get role and prop pictures (problem 3).

Open questions for Haylee:
- Do outline pages use bubble letters (to color) or plain letters (easier to read and OCR)?
- Are skulls OK in pirate kits?

## Files
- Gallery: `design/printables-ai-test/index.html`. Contact sheet: `design/printables-ai-test/contact-sheet.png`.
- Pages: `design/printables-ai-test/*.png`. Each page's `*.json` holds its prompt, words, model, tokens and cost. `ocr-results.json` holds the OCR results.
- Scripts: `design/printables-ai-test/scripts/` (`recipes.py` = the recipes as code, `generate.py`, `ocr.swift`, `score.py`, `contact.swift`, `gallery.py`). They read the relay host and token from `Relay.xcconfig`; nothing secret is stored in them.
