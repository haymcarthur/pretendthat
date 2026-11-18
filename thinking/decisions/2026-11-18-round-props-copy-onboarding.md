# Round 2026-11-18: prop multiples, copy, onboarding spacing, iPhone Nutmeg, peek layering, saved-page toggle, short shelf titles

- **Date:** 2026-11-18
- **Who decided:** Haylee (what each item should do, from the queue); Claude's calls noted below.
- **Verified:** `swift test` 727 tests pass (was 709+), app builds; demo-mode screenshots, no keys, before/after in `/tmp/pt-round-1118/{before,after}` (iPhone 18 Pro, iPhone 17e, iPad Pro 11" in landscape). No API calls, no clip recorded (no bundled clip's words changed).

## 1. Props can come in multiples ("up to N")
- Each prop carries a quantity RULE (`PropQuantity`): one (default), one per player, or a fixed number. `show_next_prop` has an optional `how_many` ("one", "per_player", "2"…"6"). The app clamps it: per player = the player count (max 6); fixed max 6; anything not on the multiples list (couch, rug, wagon, crayons…) is always one (Claude's call: an allow-list of everyday things families have several of).
- Stored as the rule, never a count (`Prop.quantity`, `SavedProp.quantity` = "perPlayer" / "3"; a single prop encodes exactly as before), so a replay with a different count scales by itself.
- Card: "Up to 4 plastic cups" with a yellow "×4" badge on the picture (iPad card, chat panel list, phone card). Nutmeg (app-said prop line): "Can you find up to four plastic cups? One for each player, if you have them! They'll be the tea cups!" (numbers spelled out); the first prop's button help says "when you find some … if you don't have any". The model-spoken path gets the same "up to" instruction. ✓ = found some. No "we only have 2" step (Haylee's update).
- Rows and the play guide say the plural ("the plastic cups", never a number, since replays change it).
- Claude's call: a replay with a different count says different words, so that line has no recorded clip on the replay (it falls back like any new line).

## 2. Copy
- Onboarding page 1: "Plan it, print it, play it". How it works, parallel: "Plan a game by talking with Nutmeg" · "Hunt for props around the house" · "Print a kit made for your game" · "Act it out together, scene by scene".
- The system prompt's "step back so the play happens off the screen" → "Nutmeg sets each scene and the kids act it out together in the room". README updated. A test scans every app string literal for "off the screen" / "steps back".
- No bundled clip said any changed words, so nothing was re-recorded ($0). CLAUDE.md still has the old sentence (agents don't edit it): Haylee may want to update it.

## 3. Onboarding spacing
- Art + heading + body are one block, a little above the middle of the free space (one share of leftover room above, two below); heading 18 pt under the art; a clear gap above the button. The art takes up to 300 pt (phone) / 380 pt (iPad) first, never the whole leftover space. Still falls back to a scroll view at huge text sizes.

## 4. iPhone Nutmeg placement
- Alone on the stage (e.g. the Play story with no bar), a width-limited Nutmeg is now centered vertically in her box instead of standing on its bottom edge; the floor follows her camera. The start-screen hand-off uses the same math, so it still matches.
- Peek arms: see 5.

## 5. Peek layering + saved page toggle
- The rig head moved into the peek's FRONT layer, drawn after the paws: the shoulders tuck under her cheeks, the head is always in front and the arms read as attached. Fixed by layering only (no shape edits, no new art needed).
- Saved game page: the Color / Black & white buttons are words only (dot / ring icons removed) so the label fits everywhere. Not visible in the demo (its seeded games have one set), so not screenshotted.

## 6. Short shelf titles + bigger iPhone shelf (added mid-round, Haylee)
- `set_theme` asks for `short_title` (1–3 words, ≤ 18 characters). New saved games are titled with it; when missing or too long, the full title is cut sensibly (`GameTitles.shelf`: leading "The/A/An" off, the tail from a linking word off, ≤ 3 words / 18 chars, never mid-word). The kit, pages and recap keep the full title.
- Existing saved games keep their saved title; the shelf label shows the short cut (nothing rewritten).
- iPhone shelf ~10% bigger (Nutmeg a bit smaller on top, smaller arrows beside the dots), labels bigger (one line). The shelf art's tall shape limits how much bigger it can get on the phone.
- Claude's call to note: the "sounds like a game you have" match compares saved titles; a cut title that dropped the twist ("Airplane" from "Airplane to the Beach") matches less. The AI's short title normally keeps the twist ("Beach Airplane").

## Follow-ups (same day, coordinator + Haylee)
- **Cups only from cup-like things (Claude's call):** the demo's fresh-prop swap had turned "the tea cups" into a pot / basket, because the general "cup" rule accepted any round container. New `drinkware` tag (cup, plastic cups, measuring cup, small bowl) and a "drink cup" rule (cup, mug, goblet, teacup, glass, tumbler…): pots, buckets, baskets and boxes can no longer be cups (test `cupsAreOnlyCupLikeItems`). Pots/baskets keep their other uses (cauldron, treasure chest).
- **Multiples demo:** `-PTDemo convHuntMany` now shows exactly "Up to 4 plastic cups" (4 players, ×4 badge) and her chat line, without the shortlist / fresh-prop checks swapping the demo pick (`debugShowProp`, demo only).
- **Peek paws rest on the card (Haylee):** the paws layer (with its arms) is lifted by its overhang (`NutmegPeek.pawLift`, an offset, no shape edits) so the paw bottoms sit on the card's top edge; the card no longer pads its title for the paws. Checked on iPhone 18 Pro and iPhone 17e with 4, 5 and 6 rows. A tiny cream sliver at the right paw's edge is in the art itself.
- **Saved page toggle verified** with a real two-set game (Pet Hotel): both word-only buttons fit on iPhone 18 Pro, iPhone 17e and iPad, Color and Black & white both shown (`PT_PAGE_STYLE=colorIn` demo env).
- Screenshots: `/tmp/pt-round-1118/after2/`.
