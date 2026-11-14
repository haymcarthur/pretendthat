# Round 14: UI fixes from Haylee's full-game test

**Date:** 2026-11-14 (~01:55–02:15) · **Decided by:** Haylee (the 6 items in queue-next-app-round.md "Round 14");
item 7 (thinking face) added by the coordinator from Haylee's review of round 13. Implementation details are Claude's
calls, noted.

## 1. Chat open: stage centered, floor fully in frame (Haylee)
- **Root cause (found):** `PTStageView` built the floor from the CURRENT stage size, but round 11 computes the camera's
  reference (arrival) framing on the full chat-closed stage. With the chat open the stage is ~392 pt narrower, so the
  floor sat ~200 pt left of her: "floor cut off on the left". Fixed: the floor comes from `referenceSize` too.
- **Preset fix (NutmegCore/StageCamera.swift):** new `PTStageFrame.fitClosed`. With the chat open, a fit-closed framing
  is the chat-CLOSED framing (computed on the full reference stage) scaled down uniformly to fit the free stage left of
  the panel (24 pt side margin) and centered there: same proportions as chat closed, floor fully in frame. Used by
  `propCardChat` (the closed counterpart is the centered medium shot with the thumbnail row) and `talk`. Applies to
  every phase on those presets (conversation, sleeping, prop card, kit pages, checklist, hand-off, finale), not per
  screen. Claude's call: the close-up's floor is still wider than the narrow stage (it's only the strip under her), but
  it is centered under her now.
- This deliberately relaxes round 11's "never smaller than the hunt medium shot" with the chat open: the minimum is the
  closed minimum × the fit (Haylee asked for the closed proportions with the whole floor in frame). Test updated.

## 2. Sleeping grounded (Haylee)
- The sit art's seat ended at canvas y ~1237, ~70 px above the floor line (1306): she floated. The sit body (and the
  head, neck plug and face focus with it) move down 62 px (`NutmegPose.sitDrop`) so her seat rests on the floor.
- Her contact shadow is per pose (`NutmegPose.shadow`): seated it's wider (560 px) and centered under the seat (x 668).
- The clipboard is split out of the sit art (`tools/split_sit_clipboard.py`, a mechanical layer split by its yellow/
  orange fills, like round 8's clipboard split; no redraw; original kept as nutmeg-body-sit.before-r14.svg) into
  `nutmeg-sit-clipboard`, drawn behind her 125 px right of where the art had it, so it lies on the floor at her hip.

## 3. Bigger cards, one card-size system (Haylee)
- The kit pages / checklist / hand-off / The End were laid out for 460 pt and SCALED into a ~240 pt zone (×0.52–0.65).
  Now `PTStageDirector.cardZoneWidth` (30% of the reference stage, 300–420 pt; ≈ 363 pt on 11") is the one card size:
  the prop-card preset places Nutmeg (at her minimum medium scale) so the zone right of her is exactly that wide, and
  the content draws at its NATURAL size in it (it only scales below 300 pt).
- The prop hunt keeps her clear of the done stack (Claude's call: done chips 160 → 140 pt), so its zone is ~270 pt
  (active card was 242). The other prop-card phases have nothing on her left, so she stands further left there; print
  → play still moves only the content (both use the no-stack variant). `frame(phase:)` passes `doneStack: hunt`.
- Sizes vs /tmp/pt-round10 (11" sim): checklist ~250 → ~360 pt wide; hand-off card ~390 (round 10) / ~240 (round 11+)
  → ~360 pt; kit fan ~30% bigger; The End at full 64 pt; prop card 242 → ~270 pt.

## 4. Checklist | Chat tabs in the chat panel (Haylee)
- During play, when the step has a checklist or hand-off card, the panel shows a two-segment pill "Checklist" |
  "Chat" under its header. Checklist = the full-size card (same `PTSceneChecklist` as the stage, no summary row, no
  collapse; scrolls if a long scene needs it; Done! under it). Chat = the transcript + text field (the field shows on
  the Chat tab only, Claude's call). Prop / kit / finale pinned cards are unchanged.
- `PTChatTabState` (NutmegCore/ChatTabs.swift): a new card (each hand-off and each scene) opens on Checklist; within one
  card it stays where the kid put it. Unit-tested (ChatTabsTests).
- The picture next to the checklist TITLE is gone everywhere (stage and panel); pictures only next to each step.

## 5. "I'm the ___!" one size (Haylee)
- The stage hand-off card now uses the same role button as the panel (34 pt, full card width, scales to fit), and the
  same 26 pt "Pass the iPad to…" line; no more scale-down, so both read the same.

## 6. Long checklist never clips (Haylee)
- `SceneView` measures its content (hidden copies at each density tier) and sizes the paper to it; the title wraps to
  2 lines; it picks the first tier that fits the stage (pictures 52 → 30 and padding shrink before text 22 → 18 pt).
  Checked with a Sunset-style scene (`-PTDemo sceneLong`: 2-line title, 6 long steps): title and last row and Done!
  all visible.

## 7. Thinking face not grumpy (coordinator, from Haylee's review)
- `NutmegFace.thinking` keeps its eyes (open, looking up and aside) and the head tilt, but uses the listening face's
  small soft mouth instead of its own "^" that read as a frown. Existing assets only.
- Couldn't reproduce the closed eyes from round 13's screenshot with `-PTState thinking` (eyes are open); it was most
  likely a blink frame, which now reads fine with the softer mouth. Not verified in a live voice turn.

## Tests
- 178 green (was 174 at round 13): + chatOpenFitsTheClosedFramingWithTheWholeFloor, cardZoneIsTheSharedSize,
  2 ChatTabsTests. Floor-ratio and preset tests kept (preset table unchanged; the hunt's done-stack variant added to
  the allowed frames; min-scale test accounts for the chat-open fit; hunt test checks the zone instead of a fixed width).

## Screenshots (/tmp/pt-round14/)
- grid.png (4 per row): talk closed/open, sleep closed/open, prop card closed/open, kit closed/open, checklist closed /
  Checklist tab / Chat tab, hand-off closed/open, The End closed/open, long checklist closed/open, thinking face,
  sleep in the talk close-up with chat open. Singles alongside; before/ = round 13 baseline.
- Debug args added: `-PTDemo sceneLong`, `-PTChatTabChat`.

## Not verified
- 13" iPad (tests cover the math only); a live voice game end to end; Reduce Motion; the tab switching animation while
  Nutmeg talks; the sit clipboard during the sit → stand pop (it fades with the pose).
