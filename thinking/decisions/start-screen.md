# Start screen: curtains, toy chest, Nutmeg pops out, logo

Date: 2026-11-13 · Decided by: Haylee (concept, sequence, art); Claude's call on details below.

**Decision.** The Hello screen is replaced by a toy-chest scene (PTToyChestScene): soft sky (Theme.startSky, #CDEBF5; swap to teal #A8DDD6 there), cream floor, static stage stars. Opening (~4 s, tap skips, Reduce Motion fades to the end): closed curtains gather to tied-back frames under the valance → chest wiggles → lid pops (squash/stretch, closed→open swap) → 6 toys tossed in arcs onto the floor → Nutmeg hops up out of the chest and waves → title card with Haylee's logo builds in (letters pop 60 ms apart, "that" fades, marks pop) beside a big yellow start button. No step rail or control pill.

**Claude's calls.**
- Toy style check: all 8 new toys match the household props (flat fills, no outline, one shade tone, same palette); all kept. Toy set = 8 toys + stuffed animal + toy car; 6 random per launch.
- Layering: open lid → body → Nutmeg clipped at the opening's front edge (art y 372) → closed lid. Alignment in design/export/startscreen/alignment.json.
- Tagline "Let's play pretend!" dropped from the card once the logo arrived (cleaner); PTTitleCard still takes an optional tagline.
- Logo colors snapped to brand coral/purple/yellow (purple 531F67 and yellow FEC202 were outside ±12 but clearly meant as brand); green and teal kept; letter holes (P, R, a) cut out so the logo works on any background. "that" is now brand purple, not the darker source purple.
- Toy yellow FED22D was left as-is (outside the ±12 snap rule).
- Grown-ups gate moved to the top-right over the curtain, clear of the toys.
