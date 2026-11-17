# Round 32: the Grown-ups menu

**Date:** 2026-11-16 · **Decided by:** Haylee (the menu and its 8 rows: the spec queued as "Round 29: Grown-ups menu
restructure" in [the queue](../queue-next-app-round.md), plus the round 32 brief). Details are Claude's calls, noted.
Builds on [round D2](2026-11-15-roundD2-grownups-delete.md) (the gate is unchanged) and the
[compliance list](../research/2026-11-16-app-store-compliance.md) items 9, 10 and 12.

## What's built
- **Behind the same D2 gate** (hold 2 s, tap the spelled number), the Grown-ups sheet is now a **menu**: a
  `NavigationStack` + inset-grouped `List` of rows (colored icon, title, one-line description), in four groups:
  1. **Saved games** → its own screen: a scrolling list (a wide 3:2 cover thumbnail or the prop stickers, the name,
     "Saved <date>", the size), swipe to delete, a trash button, and the confirm ("Delete Pet Vet? / This can't be
     undone."). A header shows "5 games · 567 KB" and a **Newest / Name** segmented sort (remembered on this iPad).
  2. **Manage subscription** → a short explainer, a "Your plan" card ("No active plan yet" until products exist; the
     plan name once an entitlement exists) and **Open Apple's subscription settings**
     (`AppStore.showManageSubscriptions(in:)`; on failure a note points to Settings → your name → Subscriptions).
  3. **Restore purchases** → an explainer and a button that runs `AppStore.sync()` with a progress state ("Checking
     with the App Store…"), then a result ("Restored…", "Nothing to restore yet…", cancelled, offline, App Store
     unavailable, or a generic error). VoiceOver announces the result.
  4. **Privacy policy** → pretendthat.app/privacy in an in-app Safari view (`SFSafariViewController`).
  5. **About what we save** → the plain-language screen, updated for round 31 (voices become words on the iPad and
     are never sent; only words go to our AI partners, OpenAI and Anthropic; names removed first; saved games are game
     content only; saved on this iPad; no accounts, ads or tracking; you're in charge).
  6. **Terms of use** → pretendthat.app/terms in the in-app Safari view (the page 404s until it's published; draft at
     [research/2026-11-16-terms-draft.html](../research/2026-11-16-terms-draft.html)).
  7. **Help & contact** → "Open the help page" (pretendthat.app/support) and "Billing and refunds go through Apple."
     with a link to reportaproblem.apple.com, both in the in-app Safari view.
  8. **Replay the intro** → hidden (`GrownUpsFeatures.replayIntro = false`); it calls the stub
     `AppModel.replayParentIntro()` (logs, closes Grown-ups). Round 33 flips the flag and fills in the stub.
- The old single-page layout (saved games + about on one list, the "Coming soon" section E placeholders and the
  `storeSections` flag) is gone.

## Claude's calls
- **Web rows open the in-app Safari view directly** instead of pushing a screen first (one tap fewer;
  `SFSafariViewController` shouldn't sit inside our navigation bar). They show a Safari glyph instead of a chevron.
- **The sheet uses the page size on iPadOS 18+** (`presentationSizing(.page)`), so the whole menu fits; iOS 17 keeps
  the form sheet (the list scrolls). The Safari view uses the same size.
- **Dynamic Type:** the grown-up screens use text styles (`.title3`, `.body`, … in the rounded face) instead of the
  kids' fixed sizes; icons and thumbnails use `@ScaledMetric`; a saved-game row stacks vertically at accessibility
  sizes. Each row is one VoiceOver element; a saved game has a "Delete" action and the trash is labeled
  "Delete <title>".
- **The Manage button stays enabled with no plan** (a family that restores mid-session can still use it).
- **StoreKit stays in the app** (`App/PTStore.swift`); the wording and mapping are in NutmegCore (`PlanStatus`,
  `RestoreOutcome`, `RestoreFailure`, `SavedGameSort`, `GrownUpsLinks`) so they're tested. `AppStore.canMakePayments`
  false maps to "unavailable"; `StoreKitError.userCancelled` → cancelled, `.networkError` or a URL error → offline.
- The sort is stored with `@AppStorage` (a view setting, nothing about kids).

## Tests and checks
- NutmegCore **green** (`Round32GrownUpsMenuTests`: menu rows/groups and the hidden intro row, HTTPS links, the
  round 31 copy, newest and name sorts (case, accents, numbers, ties), plan status, the restore result mapping).
  D2's sections test was replaced by the menu test.
- Simulator PT-R15-iPad, 5 seeded games (`-PTDemo seed5`), screenshots in `/tmp/pt-round32/`: the menu, the menu
  with the intro row, Saved games (newest and by name), the delete confirm, Manage subscription, Restore (idle and a
  result), About what we save, Help & contact, the privacy page and the terms page (404) in Safari.
- DEBUG hooks: `-PTGrownUps <section rawValue>|menu|confirm`, `-PTReplayIntroRow`, `-PTRestoreShowResult`,
  `-PTAutoStore` (runs Manage / Restore on open, for the simulator check).
- **Not verified:** Apple's real subscription sheet and `AppStore.sync()` with a signed-in Apple ID or a StoreKit
  configuration file (no products exist). In the simulator (no Apple ID), both Manage and Restore bring up Apple's
  sign-in prompt and the app stays responsive (shots 10 and 11); nothing was entered, so the cancel and result paths
  after a real sync weren't exercised live (the mapping is unit-tested). Also not checked: VoiceOver and the largest
  Dynamic Type sizes by hand, swipe-to-delete by hand. The in-app Safari view stays a form sheet inside the page sheet
  (the page sizing didn't take for the nested sheet).
