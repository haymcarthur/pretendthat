# Analytics build: TelemetryDeck anonymous counts (2026-11-17)

**Date:** 2026-11-17 · **Decided by:** Haylee (TelemetryDeck + Apple App Store analytics, the hard rule "never anything
about kids", no ad tracking / IDFA / ATT; [analytics decision](2026-11-16-analytics-telemetrydeck.md)). How it was built,
and the default-OFF switch, are Claude's calls, noted.

## What's built
- **SDK:** TelemetryDeck Swift SDK **2.14.2, pinned exactly** (`exactVersion` in project.yml; released 2026-08-01, the
  latest stable; 3.0 is still beta). Product `TelemetryDeck` on the app target only (NutmegCore has no dependency).
  **List it on the Code Camp team profile:** "TelemetryDeck SwiftSDK 2.14.2 (MIT) + TelemetryDeck service".
- **One wrapper:** `PretendThat/App/Analytics.swift` (`Analytics.configure / setSharing / send`) is the only file that
  imports TelemetryDeck, and it only sends `AnalyticsEvent` from NutmegCore (`NutmegCore/Sources/NutmegCore/Analytics.swift`).
- **Events are a fixed enum; every parameter is a fixed enum** (`AnalyticsValue`: String raw values, CaseIterable). No
  event can hold a String, number, date or id. The game's title is reduced **on the iPad** to one of 8 categories
  (`GameCategory.from(title:)`: food, shop, care, travel, adventure, community, show, other); the title never leaves.
- **Most anonymous configuration:** `defaultUser` = a **random per-install UUID** the app makes (`pt.analytics.installID`),
  never identifierForVendor (the SDK's default). TelemetryDeck SHA-256-hashes it again before sending. It's **deleted when
  sharing is turned off**, so turning it back on looks like a new, unrelated install. `sessionStatsEnabled = false` (no
  retention counters on the iPad). No custom user ids, no IDFA, no ATT, no AdSupport. The SDK still adds its standard
  device context (model, iPadOS/app version, language/region/time zone, screen size, accessibility flags) to each signal;
  none of it is about the kid.
- **Test mode:** Debug builds `testMode = true` (TelemetryDeck shows them only in Test mode); Release `false`.
- **No app ID = no-op:** the ID comes from the build setting `TELEMETRYDECK_APP_ID` → Info.plist `TelemetryDeckAppID`.
  Empty (the default), missing or unexpanded → `Analytics` never starts the SDK; `send` only logs "(not sent: no app ID)"
  in Debug.

## Where Haylee pastes the app ID (morning)
1. TelemetryDeck dashboard → create the app "PretendThat" → copy its **App ID** (a UUID).
2. Open **`Analytics.xcconfig`** (repo root) and set `TELEMETRYDECK_APP_ID = <the UUID>`. Commit it (not a secret; it
   ships in every build, like the relay token). Both Debug and Release include this file.
3. Rebuild (no `xcodegen` needed). Debug runs appear under **Test mode** in the dashboard; TestFlight/App Store under live.
4. In the app, a grown-up still has to turn the switch on (below) before anything is sent.

## The grown-up switch: default OFF (Claude's call)
- **Why OFF:** PretendThat is directed to children (COPPA applies even outside the Kids Category). Apple 1.3/5.1.4 bar
  third-party analytics in Kids Category apps and ask for care with kids' data elsewhere; the FTC's "support for internal
  operations" exception may cover anonymous product analytics, but a persistent identifier plus a third party is exactly
  what a reviewer or the FTC would question. Default OFF with an explicit grown-up opt-in is the safe reading; it costs
  data volume, not compliance. Revisit after the lawyer / Safe Harbor review (compliance research #3).
- **Onboarding page 4 (Private by design):** one short line with a switch, OFF: "Share anonymous usage counts (never
  anything about your child)". It does not block "I agree" or "Not now".
- **Grown-ups → About what we save:** the same switch at the top, footer: "Off unless you turn it on. It sends simple
  counts, like "a game reached Print" or "a plan was bought", to help us improve PretendThat. Never names, voices, words
  or anything about your child. No ads, no tracking." (behind the grown-up gate, like the rest of Grown-ups).
- Turning it off calls `TelemetryDeck.terminate()` and deletes the install id; on calls `initialize` with a new one.

## The full event list (signal → parameters; every value from a fixed list)
| Signal | Parameters | Sent when |
|---|---|---|
| `Onboarding.pageReached` | page: hello / howItWorks / needs / privacy / aiDeclined / microphone / plans / handOff | each first-launch onboarding page (not "Replay the intro") |
| `Onboarding.aiConsent` | answer: yes / no | I agree / Not now |
| `Onboarding.microphone` | answer: yes / no | the mic page's system prompts answered |
| `Onboarding.finished` | exit: firstGame / home / closedWithoutConsent; duration | the flow ends |
| `Paywall.shown` | source: onboarding / grownUps / showsUsedUp | onboarding page 6, Grown-ups → Plans, the plans sheet after the gate |
| `Purchase.started` | plan: showPass / seasonPass / freePreview / unknown; period: monthly / yearly / unknown | Buy tapped |
| `Purchase.finished` | plan; period; result: succeeded / pending / cancelled / failedNetwork / failedNotAllowed / failedUnverified / failedProductMissing / failedOther | StoreKit answered |
| `Purchase.restore` | result: restored / nothingToRestore / cancelled / offline / unavailable / failed | Restore purchases |
| `Game.started` | (none) | a NEW game (counted show) begins |
| `Replay.started` | category | a saved game's replay begins |
| `Game.stepReached` | step: pick / props / print / play; kind: new / replay; players | first time per game |
| `Game.kitPrinted` | set: fullColor / colorIn; players | the printer, once per game |
| `Game.sceneReached` | scene: story / setup / play1 / play2 / play3 / playMore / cleanup; kind; players | first time per game |
| `Game.finished` | kind; players; category; duration | The End, once per game |
| `Game.saved` | players; category | the star saved the game |
| `GrownUps.reportProblemOpened` | (none) | Grown-ups → Report a problem opened |
| `Error.occurred` | category: aiUnavailable / voiceConnectFailed / speechUnavailable / saveFailed | fallback game, voice didn't connect, on-device speech missing, save failed (game errors once per game) |
| `TelemetryDeck.Session.started` | (SDK's own) | app launch / foreground after 5 min, only while sharing is on |

Buckets: **players** unknown (before the count) / one / twoToThree / fourPlus; **duration** under1m / from1to5m /
from5to15m / from15to30m / from30to60m / over60m; **category** food / shop / care / travel / adventure / community /
show / other.

## Privacy manifest and App Store answers
- `PrivacyInfo.xcprivacy`: added **Product Interaction** and **Device ID**, both not linked, not tracking, purpose
  Analytics (Device ID because the SDK's own bundled manifest declares it, and Apple merges both into the privacy report;
  ours is a random per-install id, but the label should match the report). Tracking stays false, no tracking domains.
- App Privacy answers updated in [setup-rows-and-compliance](2026-11-17-setup-rows-and-compliance.md) (Haylee's to-do):
  Usage Data → Product Interaction (Analytics, not linked, no tracking) + Identifiers → Device ID (same). Tracking: No.
- **Apple App Store analytics:** no code; App Store Connect → Analytics shows installs, sessions, crashes and retention
  for users who opted in to share with developers.
- **Privacy policy draft:** `/Users/haymcarthur/pretendthat-site` branch `privacy-additions`, commit **be5f230** (not
  pushed): "No ads or tracking; optional anonymous usage counts" section (what's sent, what never is, the random id,
  TelemetryDeck as a partner, how to turn it off, Apple's App Analytics), the short version line, the partners list, the
  retention list and the COPPA paragraph. `[CONFIRM: TelemetryDeck retention + DPA]` brackets to fill.

## Tests (NutmegCore `AnalyticsTests`, 9 tests; full suite 510 passed)
- Every event in the whole space (every combination, >500) has a known name; every key is known; every value is in that
  key's fixed list and is a short ASCII word; no key collides with TelemetryDeck's reserved names.
- Reflection: every associated value of every event is an `AnalyticsValue` enum, never String/Int/Double/Date/UUID.
- A title with kids' names ("Emma and Liam's Sparkly Unicorn Bakery") goes out as `category: food`, and no word of it is
  in the signal. Every suggested game maps to a real category.
- Buckets, the per-game tracker (each step/scene once, The End once, print once, errors once, replays reset), the switch
  (OFF by default, id removed when off, a new id when back on), empty/unexpanded app IDs = nil, Info.plist + manifest.
- UI test `PretendThatUITests/AnalyticsOnboardingTests`: a first-launch onboarding with a dummy ID; the switch starts OFF.

## Verified
- `swift test`: 510 tests, 51 suites passed (9 new in `AnalyticsTests`).
- **Debug** build (PT-R15 sim) and **Release** build (generic simulator) succeed; `tools/check-release-keys.sh`: "no
  personal keys"; Release Info.plist `TelemetryDeckAppID` is empty → no-op; `PrivacyInfo.xcprivacy` + the SDK's
  `TelemetryDeck_TelemetryDeck.bundle` are in the app. No Secrets.xcconfig was needed (the shared relay).
- **Onboarding** (iPad Pro 13" sim, `AnalyticsOnboardingTests`, dummy ID, Test mode): the switch starts OFF and pages
  hello → privacy log "(not sent: sharing off)"; after the grown-up turns it on: `ANALYTICS started (test mode)`, then
  pageReached microphone, aiConsent yes, microphone yes, pageReached plans, Paywall.shown onboarding, pageReached handOff,
  Onboarding.finished exit home duration under1m. Log: /tmp/pt-analytics/onboarding-log.txt.
- **One live game** (PT-R15, `-PTLive` typed bakery-for-farm-animals, 2 players, dummy ID, Test mode): Game.started;
  stepReached pick (players unknown), props, print (twoToThree); kitPrinted fullColor; stepReached play; sceneReached
  story, setup, play1, play2, play3, cleanup; Game.finished category **food** (the title never sent), from1to5m, new,
  twoToThree; Game.saved food twoToThree. The SDK connected to nom.telemetrydeck.com/v2 (the dummy ID is rejected
  there; that's expected). Log: /tmp/pt-analytics/game-console.log.
- **No app ID:** `ANALYTICS no app ID: off (no-op)` even with sharing on; no connection to telemetrydeck.com. An earlier
  run before the fix below logged "(not sent: no app ID)" for each event.
- Fix during verification: `Analytics.configure` moved to `AppModel.init` (the debug drivers run before the launch
  check, so a `-PTLive` game wasn't counted).
- Both simulators were left with sharing OFF (`-PTAnalyticsOff`). Debug flags: `-PTAnalyticsAppID <id>`,
  `-PTAnalyticsOn`, `-PTAnalyticsOff`.
- Not verified: purchase/restore/report/paywall-from-Grown-ups events on the simulator (wired in `PTPurchases.purchase`,
  `PTStore.restore`, `GUPlansView`, `PlansSheet`, `GUReportView`; mapping unit-tested), and real delivery to a real
  TelemetryDeck app (needs Haylee's ID).
