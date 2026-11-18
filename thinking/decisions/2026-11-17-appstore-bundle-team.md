# App Store bundle ID and team

**Date:** 2026-11-17 · **Decided by:** Haylee (App Store Connect record under her company team, the new bundle ID,
the company team for App Store builds). How it is wired is Claude's call, noted.

## Decision
- **Bundle ID:** `co.crimsonfoundry.pretendthat` (was `app.pretendthat.ios`). UI tests:
  `co.crimsonfoundry.pretendthat.uitests`. `bundleIdPrefix` in `project.yml` is `co.crimsonfoundry`.
- **Subscription product IDs stay** `app.pretendthat.showpass.monthly` / `.yearly` and
  `app.pretendthat.seasonpass.monthly` / `.yearly` (NutmegCore `StoreProducts`, `StoreKit/PretendThat.storekit`,
  the relay's `PLAN_SHOWS`). Product IDs don't have to share the bundle ID's prefix.
- **Team:** `DEVELOPMENT_TEAM = 66898X3HH3` (Tittl LLC → Crimson Foundry LLC) on both targets, every configuration,
  automatic signing.
- **Version:** `MARKETING_VERSION = 1.0`, `CURRENT_PROJECT_VERSION = 1` in `project.yml`; Info.plist now reads
  `$(MARKETING_VERSION)` / `$(CURRENT_PROJECT_VERSION)` instead of hard-coded strings. Raise the build number for
  every upload.
- **Relay:** `BUNDLE_IDS` in `relay/src/shows.ts` accepts `co.crimsonfoundry.pretendthat` and, for the transition,
  `app.pretendthat.ios` (no store build ever used the old ID, so it can be dropped later). Code only; Haylee deploys
  (`cd relay && npx wrangler deploy`).

## Claude's calls
- **One team for Debug and Release** (not Release only). The company owns the bundle ID, so the personal team can't
  sign it in any configuration anyway. A personal-team device build passes both overrides on the command line:
  `DEVELOPMENT_TEAM=TSM76TQF46 PRODUCT_BUNDLE_IDENTIFIER=co.crimsonfoundry.pretendthat.dev` (README → "Signing,
  device builds and App Store archives"). Simulator builds don't need the team's account.
- **Icons:** the single 1024 universal icon (no alpha) stays; Xcode generates the iPhone/iPad sizes
  (AppIcon60x60@2x, AppIcon76x76@2x~ipad) and the archive's Info.plist lists them. LaunchScreen.storyboard present.

## Checked
- `xcodegen`, NutmegCore `swift test` (649 passed), relay `npm test` (65 passed, one new transition test),
  Debug + Release simulator builds (Release key check passes), unsigned Release device archive succeeds.
- Signed archive with `-allowProvisioningUpdates` fails as expected: `No Account for Team "66898X3HH3"` (this Mac's
  Xcode only has the personal Apple ID).

## What Haylee does to upload
1. Xcode → Settings → Accounts → + → Apple ID → sign in with the Apple ID that is on the Crimson Foundry team
   (support@tittl.ai), then pick the team once so Xcode creates the distribution certificate.
2. `xcodegen`, open `PretendThat.xcodeproj`, Product → Archive (any iOS device), or the `xcodebuild archive` line in
   the README.
3. Organizer → Distribute App → App Store Connect → Upload.
4. Deploy the relay so show counts accept the new bundle ID.
