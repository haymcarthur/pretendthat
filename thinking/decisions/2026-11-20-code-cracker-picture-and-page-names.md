# Code Cracker gets an AI picture and the kit's colors; a page never loses its name to an absent role

**Date:** 2026-11-20 · **Who decided:** Haylee ("add some AI elements and make the colors match"; the friend bug); how: Claude's calls

**Code Cracker (the code decoder page):**
- It stays app-drawn: the key and the secret messages must match symbol for symbol, which image models still get wrong (round 46).
- New: the image model draws ONE picture for it (`KitPagePrompt.decoderPicture`): the game's characters cracking a code, a wide strip across the middle of the page, with NO words, letters, numbers or symbols. The app trims the white paper around it (`PictureTrim`) and prints it under the messages. Both sets, like every page (color, and the coloring version).
- It's a bonus, never a wait: the page doesn't wait for it, never shows the Try again tile, and prints as before if it never comes (`KitArtService.isMissing` and `pictureState` still skip the decoder; `KitPageView` always draws the decoder app-side).
- Colors: the color set now uses the kit's AI palette (the style line every AI page is drawn in): a sunny yellow ribbon, key boxes in yellow / coral / lime / sky blue, dark purple outlines and number dots. The coloring set stays black on white.
- Cost: one more image per style per game that has the decoder (it doesn't count toward the 6-page image budget).

**"Put a friend in the corner":** the AI wrote "Put the Code Cracker in the corner" (the page). A role was also named "Code Cracker", and at 3 kids that role wasn't playing, so `PlayCast.unname` swapped its name for "a friend" everywhere, the page's name included. Now `unname` takes the kit's page titles as `keep` (both compose paths), so a page keeps its name.

**Missions vs clues:** Haylee checked: the two card pages really are different (act-out missions vs hidden clues). No change.

**Checked:** NutmegCore tests; the decoder rendered in both sets with a sample picture (`-PTRenderKitPages`). Not seen yet with a real AI picture (next live game).
