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

## Polish round (2026-11-13 evening, Haylee: "the intro feels glitchy")

- Launch screen = the closed curtains (LaunchScreen.storyboard showing launch-curtains.png, a render of
  `PTCurtain(progress: 0)`), so launch → curtains is seamless; no purple. Asset-catalog images did not render in the
  launch screen on the iOS 27.2 simulator; a loose PNG does. Regenerate the PNG if the closed curtains change
  (`-PTStartAt 0`, screenshot, resize to 1210×834).
- Curtains: one continuous motion. Each half is a path (`PTCurtainShape`) that slides out while its inner bottom corner
  sweeps up to the tie-back; coral with darker folds that bunch up; a gold tie grows in at the end. Right = left
  mirrored. No alpha, no art swap. (Claude's call: drawn in code instead of the curtain SVGs, which can't morph.)
- Timing (slowed again, Haylee: "too fast"; ~6.8 s): hold 0.15 → curtains 1.8 (ease-in-out) → beat → wiggle 0.6 →
  lid pop 0.35 → toys one at a time (0.3 s apart, 0.6 s arcs) → beat → Nutmeg jump ~0.65 (chest crouch, overshoot to
  her knees above the rim, drop, squash) → card + logo 0.5 (card scales up in place; letters 40 ms apart) → button
  0.2. Tap skips. All views persistent; beats only change offset/scale/opacity/path.
- One set of hardware per state: the importer splits chest-body's clasp (chest-clasp) and its top corner brackets +
  the tab under the clasp (chest-rim) into layers shown only while the lid is open; the open lid's clasp copy is
  dropped. Interim until Haylee's new chest body without top hardware (an SVG edit removing them left gaps and was
  reverted to chest-body.svg.bak-hardware, which keeps the lighter interior). Chest interior lightened
  (8D332E → D9574A back wall, 782629 → C94A3E sides; originals kept as .svg.bak).
- Layout: logo card centered at the top, sized so it never reaches her ears; big yellow "Let's play!" pill under the
  chest; toys kept inside the floor and clear of the curtains and the button.
- Floor and app icon: icon option A (design/icon/options-v3/icon-A.png; previous kept as AppIcon-1024-v2.png).
- Settings: a tiny faint gear (30 pt, appears after the intro; `Theme.showSettingsGear` turns it off) plus a 2-second
  press on the logo card.
- Floor: warm wood `Theme.stageFloor` EBC29A with rim `stageFloorEdge` D9A97B (cream toys blended into the old cream
  floor).
