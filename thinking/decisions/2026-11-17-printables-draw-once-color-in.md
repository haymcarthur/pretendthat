# Printables: draw the coloring page once, then color it in

- **Date:** 2026-11-17
- **Decision:** Each printable is drawn ONCE as the black-and-white coloring page; the color page is made from that exact image with the image EDIT endpoint ("color in, change nothing"). Color and black-and-white then match except for color. Costs ~1.1¢ more per page (the outline goes back in as input), ~6–7¢ a 6-page kit. Test: design/printables-match-test/ (≈$0.29).
- **Guardrails (Haylee: "as long as we can put guardrails around some of the light color choices"):** she rejected the color menu (cream/pale item names and title) and the white sign with yellow "Bakery". Every word on a color page must be strong, readable color:
  1. Prompt rule: letters are filled with dark ink (deep purple/ink) or a saturated brand color with a dark outline; never white, cream, pale yellow or pastel letter fills; never yellow text on white; keep the paper/board white (no ink-heavy full-page fills).
  2. Automatic check: the word check (Vision) already finds the text on the color page; also measure contrast between letter fill and the background inside each text box; too light → one redraw with the contrast note; still light → keep the page but log it.
  3. Keep the word check on the color page (the test once turned "002" into "202").
- **Who decided:** Haylee (adopt, guardrails); Claude (how the guardrails work).

- **Update (Haylee, 2026-11-18):** remove the automatic pale-letter re-color (it cost ~10¢ a game and fixed nothing in the live test). Keep the no-pale-letters rule in the color prompt.
