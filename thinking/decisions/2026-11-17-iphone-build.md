# iPhone build: one universal app, every screen in portrait on the phone, the iPad unchanged (2026-11-17)

**Date:** 2026-11-17 · **Decided by:** Haylee (build the iPhone version; her feedback on the phone mockups in
[ideas/2026-11-15-iphone-version.md](../ideas/2026-11-15-iphone-version.md): no pointing, the stage grows when nothing is
below her, a full-height chat sheet that covers her with the pill on top, no mute). How it was built is Claude's call, noted.

## What's built
- **One universal app:** `TARGETED_DEVICE_FAMILY: "1,2"` (app + UI tests) in project.yml. iPhone is **portrait only**
  (`UISupportedInterfaceOrientations~iphone`, as the mockups); the iPad stays landscape only, full screen.
- **One layout decision, `LayoutMetrics`** (`PretendThat/DesignSystem/LayoutMetrics.swift`): RootView reads the
  horizontal size class once (`.compact` = iPhone portrait; the full-screen landscape iPad is always `.regular`) and
  injects `\.layoutMetrics`, so sheets and covers get the same answer. `.pad` returns the iPad's existing numbers.
  No `userInterfaceIdiom` checks for layout; the only device check is the device word in text (`PTDevice.noun`).
  NutmegCore geometry that runs without the environment treats a portrait stage as the phone (`PTStage.isPortrait`).
- **Stage (NutmegCore `PTStageFrame.phoneRegion`, `PTStageCamera.phoneLayout`, `PTPhoneStage.split`, tested in
  `PhoneStageTests`):** Nutmeg stands whole-body in her box on top, feet on its bottom edge (the floor moves with her
  camera, as on the iPad); the content zone is under her, above the pill. **Nothing below her: the box is the whole
  stage and she grows to fill it** (mockup screen 2). With a card, she keeps at least 150 pt. The writing moment frames
  her head, clipboard and writing paw. On the iPad `phoneRegion` is nil and every framing is the old math.
- **No pointing on the phone:** `AppModel.gesture(.point)` is a no-op on the phone, and while a card is below her she
  holds her clipboard (`clipboardBoth`, the existing pose: gestures only play over idle). The End is not a card: she
  celebrates there.
- **Top bar:** the X and a **compact horizontal step rail** in one row under the valance (mockups). Same pictures, ↺
  marks, taps and voice go_to_step.
- **Control pill:** the same three buttons, a little smaller (side 58, mic 82), always on top.
- **Chat:** a **full-height sheet** under the top bar that covers the stage, down to the bottom edge; its text field
  sits above the pill (the pill stays on top). Same step tabs (Props / Print / Scene / cover) and pinned cards.
- **Screens:** start (Grown-ups pill over the logo card, bigger chest, two toys, New game at the bottom; Saved games
  under it), the bookshelf (`bookshelf-iphone.svg` + its slots JSON: 4 shelves of 2, 8 a page, Nutmeg sitting on top in
  the existing `sit` pose, back arrow, dots, yellow arrow), prop hunt (one big card: picture, name, what it becomes,
  ✓ / ✗, a pager of dots), Print (the two sets side by side as one-row fans, printer + ▶ under them; page preview fills
  the width, chevrons under it), story / setup / play / clean-up (the scene paper and rows under her (a denser phone tier, 44 pt 🔊), a 56 pt ▶ Next
  scene), The End (⭐ / 🏠 under her), leave dialog (buttons stacked), onboarding v2 (art card on top, text column
  scrolling under it; How it works = the four cards in one column), Grown-ups + gate + plans (sheets; plan cards stack
  on the phone), report a problem, speech-model sheet, Wi-Fi note.
- **Printing from iPhone:** the same `KitPrinter` print sheet (no popover anchor needed; it presents as a sheet).
- **Words:** grown-up text says "this iPhone" on a phone (`DeviceWord.noun` in NutmegCore, default "iPad", set at
  launch); iPhone mic/speech permission strings (`~iphone` keys). Kid text unchanged.
- **Voice:** unchanged path: every line through `NutmegSpeaker` (coral, Varispeed 1.20), never system TTS.

## Claude's calls
- **She stays visible while the chat sheet covers the stage:** her small live head (the real layered art, lip-synced,
  `PTNutmegAvatar`) sits in the sheet's header, so she is never heard unless she's on screen. No new art.
- **The floor on the phone has an apron:** the oval's top curve is the horizon and the floor runs on to the bottom edge
  behind the cards and the pill (mockups), instead of an oval floating in the sky.
- **Content heights** per kind (hunt 268, print 340, scene by rows, The End 232, cover 270) live in `LayoutMetrics`;
  `PTPhoneStage.split` clamps them so she always keeps 150 pt.
- **The mockup's one-card-at-a-time hunt** shows the current prop; found / pretend ones are dots in the pager (the full
  list is in the chat sheet's Props tab, as on the iPad).
- **Rail at the top** (mockups), not the bottom: the pill owns the bottom.
- **Debug only:** `-PTSkipAuth` (fresh simulators never raise the system prompts), `-PTLeaveDialog`, `#waithunt`.

## Deviations from the phone mockups (they predate later iPad rounds)
- Pick: no "Say yes" speech bubble (round 26/no-text-overlays: voice only); she fills the stage instead.
- Play: no checklist sheet, hand-off card or Done: the current ensemble scene card (rows + 🔊 + ▶ Next scene) sits
  under her (round 29/36), and the story opener is her alone.
- Print: both sets (color + outline, round 27) side by side instead of one fan.
- The End and the start screen match; the bookshelf's Nutmeg uses the existing sit pose (clipboard on the floor beside
  her in that art) instead of the mockup's clipboard-on-lap drawing (no new art).

## Verification
- `swift test` (NutmegCore): 510 Swift Testing tests + 5 new `PhoneStageTests`, all pass.
- Builds: Debug iPhone + iPad simulator; **Release** generic iOS device and simulator; the Release key check reports
  "no personal keys in the Info.plist".
- UI tests on iPhone: onboarding (`AnalyticsOnboardingTests`) passes on the 17e, the 18 Pro and an erased 17e; all 7
  StoreKit flows (`StoreKitFlowTests`: Free Preview → paywall → Show Pass, month used up, restore/expire, Ask to Buy,
  refund, free replays, onboarding plans page) pass on an erased iPhone 17e. (On a simulator that already holds a
  test purchase, test1 can't start from the Free Preview; that's simulator state, the iPad behaves the same.) test7 now
  expects the device word ("Hand the iPhone to your child").
- **Live, real voice and real AI, on both phones (18 Pro and 17e):** pick "a pirate ship" → theme → 2 kids → yes → the
  one-card hunt (✓ / ✗, a missing prop) → kit drawn → **the iOS print sheet opens from the printer button** → story →
  setup (opens by itself) → 3 play scenes → clean-up → The End → ⭐ saved (cover + 12 recorded lines) → bookshelf. A
  replay on both phones (shelf → saved game → "Two!" by voice → the same hunt card → Print → setup → playthrough to The
  End with only 🏠). Every line through NutmegSpeaker (coral, Varispeed 1.20 in the pre-connect log), her lines saved
  as clips on the replay. Screens: /tmp/pt-iphone/live-large, live-small, replay-large, replay-small.
- **Bug found and fixed on the way:** the phone's start screen froze on its closed curtains (and the app looked hung
  at home) because the safe-area insets were read from the UIKit window during a view update; they're now measured by
  SwiftUI once in RootView and injected (`\.ptSafeInsets`).
- **iPad unchanged:** 37 iPad Pro 13" screens before (main + the debug flags) vs after (the final build):
  /tmp/pt-iphone/ipad-before, ipad-after, diffs in /tmp/pt-iphone/ipad-diff (summary.txt: % of pixels that differ).
  Grown-ups / sheets / gate 0.003–0.13%; game and onboarding screens differ only along Nutmeg's outline (her breathing,
  blink and mouth at the moment of the shot, red in the diff images); no chrome, card or text moved. The two plans
  screens differ by StoreKit state on the simulator (a test purchase in between), not layout.
- Known: a setup or clean-up scene with 5+ rows scrolls on the 17e (as 6-row scenes do on the iPad); 4 rows fit.
- Screenshots: /tmp/pt-iphone/large (iPhone 18 Pro) and /tmp/pt-iphone/small (iPhone 17e), contact sheet
  /tmp/pt-iphone/contact-sheet.jpg: start, start with saved games, bookshelf, talk, confirm, hunt, hunt + chat, writing,
  print, page preview, print + chat, story, setup scene, long scene, scene + chat, chat tab, The End, The End + chat,
  leave dialog, speech-model sheet, onboarding pages 1–7 + declined, Grown-ups gate (number and hold), menu, saved
  games, plans, about what we save, help, report a problem, AI partners.
