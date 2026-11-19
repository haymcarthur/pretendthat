# Printables match test: draw the outline page first, then color it with the image EDIT endpoint

Date: 2026-11-17. Test only, no app code changed, nothing committed.

## Setup
- Theme "Moon Bakery" (setting "a bakery on the moon"), 4 players. Round 47 badges always draw all 6 ranked roles, so
  2 extra roles were added: Head Baker, Cupcake Chef, Delivery Rover, Customer, Cashier, Taste Tester.
- Printables: badges (lanyard, the round 47 3 × 2 strict grid of 6), sign (door), menu (menu card), tickets
  (admission, 6 passes 001–006).
- **The outline prompts come from the real app code.** A small Swift package that depends on NutmegCore by path
  (`scripts/promptgen-*.swift`) builds `KitItem`s and calls `KitPagePrompt.prompt(for:ctx:style: .colorIn)`. The exact
  prompts it produced are in `prompts.json` (`outline` per type, plus both style lines). Item titles, lines and pictures
  were written by hand to look like a sanitized kit (no Claude call).
- Calls: `scripts/run.py`, straight to api.openai.com with the personal key from Secrets.xcconfig, read inside the
  script (never printed or logged). The per-call log is `calls.jsonl` (token counts only).

## Params (the same as the app)
- Model `gpt-image-2.6-flare` (ImageClient.models[0]), size `1024x1536`, quality `low` (ImageQuality.kit), png,
  moderation auto, n 1.
- Outline: POST /v1/images/generations with the app's outline (colorIn) prompt.
- Color: POST /v1/images/edits (multipart), `image` = the outline PNG, same model, size and quality.
  **`input_fidelity: "high"` is not supported:** the API answered 400 "The model 'gpt-image-2.6-flare' does not
  support the 'input_fidelity' parameter". The script then sent the same call without it. Those 400s produced no
  image and no usage, so I counted them as not billed. That is an assumption; I didn't check the billing dashboard.

## Edit prompts (exact)
`<COLOR_STYLE>` is the app's `KitPagePrompt.style(.fullColor)` without its "Art style for the whole kit: " prefix:
"bright, friendly flat vector cartoon like a modern kids' picture-book app: bold clean dark purple outlines, flat cheerful
fills in coral red, sunny yellow, lime green, sky blue, deep purple and cream, soft rounded shapes, no gradients, no
shading texture, no photo effects, lots of white paper. Ink-friendly: color sits on white, no full-page dark background."

**v1** (all 4 pages):
> Color in this exact coloring page with the kit's color style: `<COLOR_STYLE>` Do not change, move, add or remove any
> line, shape, character or letter; only fill the white areas with flat colors.

**v2** (one retune, used for the 2 retries: tickets and sign):
> This is a finished coloring page. Color it in, exactly like a child filling a coloring book with flat paint: keep every
> existing line exactly where it is and fill only the enclosed shapes. Color style: `<COLOR_STYLE>` Copy every word,
> letter and number exactly as it is drawn, character for character (for example "002" stays "002"); never redraw, flip
> or rewrite any text. Keep the thin gray dashed cut lines exactly as they are. Keep the paper background and the big
> empty areas white or a pale cream; no full dark or saturated background fill. Do not change, move, add or remove any
> line, shape, character or letter.

## Cost (10 billed image calls, the cap)
Prices are the ones the project already uses (thinking/research/2026-11-16-cost-per-game-v2.md): text in $5, image in
$8 and image out $30 per 1M tokens. I didn't re-check them live; the token counts come from each response's `usage`.

| Call | text in | image in | out | $ |
|---|---|---|---|---|
| outline sign / badges / menu / tickets | 402 / 679 / 525 / 534 | 0 | 664 each | 0.0219 / 0.0233 / 0.0225 / 0.0226 |
| color v1 × 4 (edit) | 132 | 1536 | 664 | 0.0329 each |
| color v2 × 2 (tickets, sign) | 221 | 1536 | 664 | 0.0333 each |
| **Total, 10 calls** | | | | **≈ $0.289** |

An edit costs about 3.3¢ against about 2.2¢ for a generated page; the extra ≈1.1¢ is the outline image going back in as
1536 input tokens. A 6-printable kit's color set would cost ≈ 6.6¢ more per game (≈ $0.31 → ≈ $0.38).

## Per page: do they match?
- **Badges (v1): a very close match.**
  - The same 6 characters in the same poses and the same props (bread, cupcake, rover, register, coin). The same
    clip, moons, stars, ribbons and "Name: ___" lines. All 6 titles are spelled right and sit in the same places.
  - Drift: (1) the faint gray dashed cut rectangles around each badge are gone in color; (2) the space helmets turned
    into orange/brown hair-like fills (a coloring choice, not a line change); (3) the moon ground is lime green
    (reads as grass); (4) a few tiny stray specks.
  - The layout is identical, so `SheetCells` cutting should behave the same (the dashes are optional there).
- **Sign: lines and letters match exactly (v1 and v2).**
  - v1 filled the whole board sky blue. That is a lot of ink and goes against "lots of white paper / no full-page
    dark background". There is also a small orange smudge in the frosting.
  - v2 keeps the board white and fills only the shapes. That is better for ink, but the yellow "Bakery" on white is
    low contrast (hard for a kid to read, and maybe for the word check).
- **Menu (v1): essentially identical.** Every word and price ($1/$2/$2/$1), the dotted leaders, the pictures, the
  checkered corners, the spoon/fork and the hearts are all in the same places. The letters stay cream-filled outlined
  bubble letters (readable, but not the solid dark letters the color style normally gets). The best result of the four.
- **Tickets, v1: a real text drift.**
  - Pass 2's "002" came out as "202": the leading 0 was rewritten as a mirrored 2. Every other word and number was
    right, and the layout and pictures matched.
  - For the app this is a serious failure mode: the edit can change a word that was correct on the outline page.
    The color page would still need the word check, and a redraw costs another edit.
- **Tickets, v2: every number is right (001–006).**
  - The lines, rockets, cake boxes, moons, stars and dashed cut lines all match. Each stub got its own color.
  - New drift: a red/coral fill band now sits behind "Bakery Pass" at the top of each pass. No such shape exists in
    the outline, so the model painted a region that wasn't there. That is small, but it isn't "only fill the shapes".
- **Cut-apart sheets:** the gutters and piece positions are pixel-identical in every color page, so the same cut
  should fit both sets.

## Compared with today's color style (r47 airplane pages, bottom row of compare.png)
- **Today's color pages look richer and read better:**
  - Solid dark letters on light banners.
  - Full little scenes (sky bands, islands, planes, characters).
  - Thicker, more confident purple outlines.
- **The edited pages look like "a coloring page that got colored in", because that is what they are:**
  - Simpler line art, with outlined bubble letters filled cream, yellow or red instead of solid dark text.
  - Thinner, uniform outlines and fewer details.
  - They're cheerful and clean, and the menu and badges look good. But next to today's color set they are plainer,
    and some text is less readable (yellow "Bakery" in v2, cream letters on the menu and tickets v1).
- The matching problem is solved by this approach: lines, characters, layout and nearly all text are the same. The
  cost is a slightly plainer color look, about 1.1¢ more per page, and an occasional changed character or invented
  fill region.

## Recommendation (Claude's read, for Haylee to decide)
- The approach works: 3 of 4 pages matched on the first try, and the 4th matched with the tuned prompt.
- If adopted:
  - Use the v2 prompt.
  - Keep the word check on the COLOR page. It's needed now: an edit can corrupt text, as the 002→202 case shows.
    The outline page then only needs reading when the color page misses.
  - Consider asking the outline prompt for solid-fillable but darker lettering, so the colored version reads better.
- `input_fidelity` isn't available on gpt-image-2.6-flare, so there is no fidelity knob to lean on.

## Files
- outline-badges.png, outline-sign.png, outline-menu.png, outline-tickets.png
- color-badges.png, color-sign.png, color-menu.png, color-tickets.png (edit v1)
- color-sign-v2.png, color-tickets-v2.png (edit v2 retries)
- compare.png (each row: outline | color v1 | color v2 where there is one; the last row is the r47 reference pages)
- prompts.json, calls.jsonl, scripts/ (run.py, the promptgen Swift files)
