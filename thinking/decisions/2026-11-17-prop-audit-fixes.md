# Prop audit fixes + real variety (Haylee approved all)

- **Date:** 2026-11-17
- **Decisions (Haylee: "yes to all"):**
  - **The six fixes to the existing round-24 PropFit** (research/2026-11-17-prop-audit.md):
    1. Read the head word correctly.
    2. Add the missing use words.
    3. Tighter tags: where it's worn, size, fabric, disc/ball/ring.
    4. Fix the swap bug.
    5. No repeats.
    6. Fix the bundled game and drop the copied examples.
  - **Her answers to the audit's questions:**
    - A stuffed animal is only ever a creature (pet, patient, baby, passenger).
    - When nothing else fits, the prop becomes a pretend prop with a cut-out.
    - Flexible items (box, blanket, towel, bowl, tray…) may keep creative unknown uses; identity items are strict.
    - Remove the lamp. The jump rope is only a floor shape (river, finish line).
    - Prefer everyday things over toy-ish items for the first prop and for fallbacks.
- **Hardened repeat rule (Haylee):**
  - Within one hunt: never the same item twice, never the same pretend use twice.
  - Enforced in code on every path: show_next_prop, swap_prop, the fallbacks, Claude's tap-path list, replays.
- **Variety (Haylee: "box is always used"):**
  - Round 30's RecentPropMemory only *nudges*, with a note in the roles result plus a fresher swap.
  - The model also copies the fixed examples in its instructions (box, bowl).
  - Fix: the app picks each game's prop **shortlist**, like it does for game ideas. Per game it samples ~8 library items that fit the game's needed uses, weighted away from the last 5 games and avoiding over-used items (box, bowl, blanket, pillow). The model must choose from the shortlist (or its alternates). Fixed prop examples are removed from the instructions.
  - Hard cap: an item used in each of the last 2 games is excluded unless nothing else fits.
- **Who decided:** Haylee. The shortlist mechanism is Claude's proposal.
