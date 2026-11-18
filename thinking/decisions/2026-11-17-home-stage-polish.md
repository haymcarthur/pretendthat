# Home stage polish: logo in front of the curtains, Grown-ups gear, perky dangling sit on the iPhone bookshelf

**Date:** 2026-11-17
**Who decided:** Haylee (the three changes, from her iPhone screenshot). Claude's calls are marked below.

## What changed
1. **Logo card in front of the curtains** (iPhone and iPad). The start screen draws the title card after the curtain
   panels, so the curtains no longer cover the card's left and right edges. The card pops in with Nutmeg after the
   curtains have opened, so it is in front for the whole choreography; the round 11 timing is unchanged.
   (`PTStartScreen.scene`)
2. **Grown-ups → a gear icon only**, tucked into the top-trailing corner, in front of the curtain and valance
   (`PTGrownUpsGear` replaces `PTGrownUpsPill`). VoiceOver label "Grown-ups" (hint unchanged), the same gate behind
   it (`model.openGrownUps()`), new identifier `home.grownUps`. Fades in with the buttons and away on the exit as before.
   The start screen was the only screen with the pill (the bookshelf has only Back).
3. **iPhone bookshelf: Nutmeg sits on the shelf's top with her legs dangling** over its front edge, clipboard on her
   lap, looking down at the games (mockup screen 7). `ShelfView` draws the mockup's perky-sit still instead of the
   rig's knees-hugged nap `.sit`. The iPad bookshelf is unchanged (she stands on the stage beside the shelf, pointing
   at it, excited face; it looks right).

## Claude's calls
- **Gear look:** the app's icon-button style (`PTIconButton`: white circle, ink `gearshape.fill`, soft shadow), the
  same as the bookshelf's Back button, so it reads over the red curtain and the valance. 48 pt on iPhone (14 pt from
  the edge), 56 pt on iPad (22 pt from the edges). Top = just under the safe area (iPhone: safe top + 4, at least
  16; iPad: safe top + 8, at least 22), so it clears the Dynamic Island and the rounded screen corner.
- **iPhone card position:** the card sits one gap under the gear's row (`max(gear bottom, valance) + 8`). On the
  iPhone 18 Pro that is about where it was; on the small iPhone (SE size, no safe-area top with the status bar
  hidden) it moves up ~38 pt, since the old pill row is gone. The phone is too narrow for the gear beside the card.
- **Art for the dangling sit:** the existing `onboarding-nutmeg-sit-perky` PNG has an opaque light-blue background
  (no alpha), so it can't sit on the stage. The bookshelf uses the mockup's own vector file
  `design/mockups/iphone/img/nutmeg-sit-perky-focus.svg` (the focus face, eyes down at the games), copied unchanged
  into the asset catalog as `shelf-nutmeg-sit-perky` (vector). No art drawn or edited. It's a still (no blinking or
  breathing); the rig has no perky sit.
- **Placement:** from the mockup: her canvas is centered on the shelf, the shelf's top edge is 82.4% down her canvas
  (her seat), so her legs hang in front of the shelf's crown. Same height as before (20% of the screen, max 190 pt).

## Checked
Before/after screenshots on new throwaway simulators (iPhone 18 Pro, iPhone SE 3rd gen, iPad Air 11-inch M4), demo
mode only (`-PTDemo seed5|hello|shelf -PTNoAI -PTSkipAuth`, `-PTStartAt 3.4` for mid-pop), no keys:
`/tmp/pt-home-polish/before/` and `/tmp/pt-home-polish/after/`. NutmegCore tests: 669 pass.

## Follow-up
- Retake the App Store home-screen screenshots (the first set shows the old logo layering and the pill).
