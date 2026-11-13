# Kit recipe: 6 fixed item types, AI fills in the specifics

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** Every printable kit has the same 6 item types, in this order; Claude chooses the titles, wording, numbers and what goes on each for the game:
1. **Role name badges**: one per player, with a blank name banner the app fills in.
2. **A sign to hang up**: the place's name ("Cozy Café", "Sky Airlines Gate 3").
3. **Play money**: a sheet of bills themed to the game (8 per page).
4. **Tickets/passes**: whatever fits (boarding passes, appointment cards, room keycards, order tickets, admission tickets); one per player.
5. **A menu/program/flyer**: a menu for food games, otherwise a price list or services sheet.
6. **Prop cut-outs**: one page of 6–8 themed items (food for food games; tools for doctor/vet/engineer; luggage and snacks for airplane).

6 item types, at most 7 pages (`KitLayout.maxPages`). Supersedes "2–4 item types, ≤ 6 pages" (spec §5, §6).

**How:** `KitRecipe` (NutmegCore) is an enum in the Claude kit schema (`recipe` on each item); `Sanitizer` orders the items by recipe and fixes each one's shape (size, perPlayer, copies); `Validate` asks once more if any type is missing; `KitArtPrompt` has a prompt per recipe (sign, bill, menu, cut-out page, badge, ticket). The bundled airplane kit follows the recipe. Live check 2026-11-13: restaurant (2 players) → all 6 types first try, 6 pages.

**Why:** A predictable, complete kit every time (money, tickets, a sign, a menu, cut-outs and badges are exactly what kids try to make themselves), with the AI's creativity where it counts: the details.
