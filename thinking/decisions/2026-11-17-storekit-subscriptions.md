# Round 38: StoreKit subscriptions, show allowances, relay show counts

**Date:** 2026-11-17 · **Decided by:** Haylee (plans, prices, intro offers, allowances, "no gate in onboarding",
"Nutmeg never sells to kids": [paid-app direction](2026-11-15-paid-app-direction.md), latest entries win). How it was
built is Claude's call, noted.

## What's built
- **Products (one place: NutmegCore `StoreProducts`):** one subscription group **PretendThat Passes**:

  | Product ID | Plan | Price | Intro offer | Group level |
  |---|---|---|---|---|
  | `app.pretendthat.showpass.monthly` | Show Pass, monthly | $14.99/mo | **$9.99/mo, pay as you go, 12 months** | 2 |
  | `app.pretendthat.showpass.yearly` | Show Pass, yearly | $149.99/yr | none | 2 |
  | `app.pretendthat.seasonpass.monthly` | Season Pass, monthly | $29.99/mo | **$19.99/mo, pay as you go, 12 months** | 1 |
  | `app.pretendthat.seasonpass.yearly` | Season Pass, yearly | $299.99/yr | none | 1 |

  Local testing: `StoreKit/PretendThat.storekit` (same IDs and prices), set as the scheme's StoreKit configuration
  in `project.yml` (Run from Xcode uses it). The prices in `PlanCatalog` stay only as the fallback text before the
  App Store answers.
- **Entitlements (`App/PTStore.swift`, `PTPurchases`):** `Transaction.currentEntitlements` + a `Transaction.updates`
  listener from launch (renewals, Ask to Buy approvals, refunds and purchases elsewhere; every verified transaction is
  finished). The best verified, unrevoked, unexpired plan wins (Season over Show).
- **Allowance (NutmegCore `ShowAllowance`, `PlanShowCounter`, `ShowWindow`):** Free Preview 2 new shows in total;
  Show Pass 10 and Season Pass 30 per **month**; replays never count and are never blocked. A paid plan counts in
  monthly windows anchored on the period's purchase date (a yearly plan still gets its shows per month). On the iPad:
  `pt.shows.window` (tier + window start) and `pt.shows.used` (a number). Nothing about kids.
- **New game gate:** consent → shows left → start; Free Preview used up → `.needsPlan`; plan month used up →
  `.outOfShows`. Kids see only "That's all the new shows for now! Ask a grown-up." (no prices, no plan names) and the
  Grown-ups button → the gate → the plans sheet ("This month's new shows are used up… More new shows arrive Dec 3";
  Show Pass users get Season Pass pre-selected).
- **Purchase UI (real products):** the plans sheet and the new **Grown-ups → Plans** row (both behind the gate) show
  StoreKit's localized prices, the intro price only when eligible ("$9.99/month, for 12 months, then $14.99/month"),
  Monthly/Yearly, "Your plan: Show Pass, 9 of 10 new shows left this month", Buy, Restore (`AppStore.sync`), Manage
  subscription (`showManageSubscriptions`), Terms, Privacy. **Onboarding page 6** keeps "Start my Free Preview" as the
  main button and adds a Monthly/Yearly switch and a "Get Show Pass / Get Season Pass" button on each card, with **no
  gate** (Haylee); a purchase goes straight to the hand-off page. Outcomes: purchased, pending (Ask to Buy: "Waiting
  for approval…", the plan starts when the update arrives), cancelled ("Nothing was bought"), failed (offline, not
  allowed, unverified, product missing), refunded/revoked (the listener drops the plan).
- **Relay show counts (code only; not deployed):** `POST /v1/shows/start` verifies StoreKit's JWS (the plan's signed
  transaction, or the AppTransaction for the Free Preview) up to the pinned **Apple Root CA - G3**, checks Apple's
  marker extensions, bundle ID, product, expiry and revocation, then counts in Workers KV under
  `HMAC(SHOWS_SECRET, originalTransactionId | appTransactionId)` per month and returns a 6-hour **show ticket** that
  the app attaches (`X-PT-Show`) to that show's Claude and image calls. `SHOW_LIMITS` = off (default, 404) / count /
  enforce. App flag `RELAY_SHOW_LIMITS = NO` in Relay.xcconfig; with YES, a 404, an error or no network all mean
  "allow". Deploy steps: relay/README.md → "Show counts".

## Claude's calls
- **Yearly plans have no intro offer.** The decision gives yearly prices but no yearly intro. Note: during the intro
  year, monthly costs less than yearly (12 × $9.99 = $119.88 < $149.99; 12 × $19.99 = $239.88 < $299.99). See the
  open question.
- **Group levels:** Season Pass level 1, Show Pass level 2, so a switch is an upgrade/downgrade, never two plans. The
  intro offer is once per group per Apple ID (after one, the other plan shows its regular price; verified).
- **Monthly windows from the purchase date**, not calendar months; an upgrade starts a fresh window (generous).
- **The plan count is per iPad** (UserDefaults); a family with two iPads gets the plan on both via the Apple ID and
  each counts locally. The relay count (when on) is the per-subscription truth.
- **Free Preview stays in UserDefaults** (round 33): a reinstall resets it locally; the relay count closes that gap.
- **No app account token** on purchases (nothing ties a purchase to a person).
- **Relay over KV, not a Durable Object:** simpler and free; a soft cap (two shows at the same instant may both pass).
- **Relay enforcement point is the paid calls**, not the start call: a forged or missing proof gets no ticket, so
  under `enforce` its Claude/image calls get 402.
- **`-PTNoAI`** (DEBUG): no AI clients at all, so UI tests and store checks spend nothing.

## Setup-row "C" check (from /tmp/pt-round37/setup-solo.png)
**Not a bug.** That shot is `-PTDemo scene2`, which turns image calls off unless `-PTDemoArt` is passed, so no badge
sheet is drawn and `PTCharacterPicture` shows its documented fallback, the role's color chip with its first letter
("C" = Captain, mapped correctly). Rounds 36/37 didn't touch the row picture path (`PlayScreens` →
`characterPicture` → the color badge slice by role index; last changed in round 34), and the setup rows use the same
`step.role` mapping.

## Checks
- NutmegCore `swift test` green (incl. `Round38SubscriptionTests`: IDs, allowances/prices, entitlement rules, monthly
  windows over a year, the counter, the gate, purchase wording, price text, relay request/decisions, the ticket header).
- Relay `npm test` green (64: JWS chain with a test root, tampering, unmarked leaf, chain order, KV counter, tickets,
  402 limit, Free Preview 2, count mode, ticket required on Claude/images only under enforce) + `tsc` + wrangler dry run.
- UI tests on PT-R15 with SKTestSession (`PretendThatUITests/StoreKitFlowTests`), screenshots /tmp/pt-round38/:
  all 7 pass on PT-R15 and on iPad Pro 13" (`-PTNoAI`, so no AI calls). 01–05 Free Preview: 2 new shows, the 3rd
  → kid card → gate → "Your Free Preview is used up" with "$9.99/month, for 12 months, then $14.99/month" → buy Show
  Pass → "10 of 10 new shows left this month" → a new show → "9 of 10". 06 Show Pass month used up → "This month's new
  shows are used up". 07–08 Restore → "Restored"; cancel (auto-renew off) + expire → Free Preview. 09–10 Ask to Buy →
  "Waiting for approval…" → approved → Show Pass. 11–12 Season Pass (regular $29.99: intro already used in the group)
  → refund → Free Preview. 13 a replay with the Free Preview used up starts (never blocked) and the count stays 2.
  14–15 onboarding page 6 with StoreKit prices → Get Show Pass (no gate) → the hand-off page. Run:
  `xcodebuild test -scheme PretendThat -destination 'platform=iOS Simulator,id=<sim>' -only-testing:PretendThatUITests`.
- Debug build (tests) + Release build: "Release key check: no personal keys in the Info.plist." No Secrets.xcconfig
  was used.
- **Not verified:** Apple's real purchase sheet and sandbox (needs the App Store Connect products), the relay against
  real Apple-signed JWS (needs a sandbox purchase; the chain logic is tested with a look-alike test chain), VoiceOver
  and the largest text sizes on the plans screens, the onboarding page 6 layout with very long localized prices.

## Haylee's App Store Connect checklist
1. **Agreements:** sign the Paid Applications agreement; bank and tax forms (needed before any subscription works).
2. **Subscriptions → Subscription Groups → create "PretendThat Passes"** (group display name for the store, e.g.
   "PretendThat Passes").
3. **Create 4 auto-renewable subscriptions** in that group with exactly these IDs (they can never be reused):
   `app.pretendthat.showpass.monthly` (1 month), `app.pretendthat.showpass.yearly` (1 year),
   `app.pretendthat.seasonpass.monthly` (1 month), `app.pretendthat.seasonpass.yearly` (1 year).
   Reference names: "Show Pass Monthly", etc. Display names: "Show Pass" / "Season Pass"; descriptions: "10 new shows
   a month, unlimited replays" / "Up to 30 new shows a month, unlimited replays". Family Sharing: off (Claude's
   default; turning it on is a one-way switch).
4. **Levels:** drag Season Pass (both) to level 1 and Show Pass (both) to level 2.
5. **Prices (US, base country United States):** Show Pass $14.99/mo, $149.99/yr; Season Pass $29.99/mo, $299.99/yr.
   Availability: United States only.
6. **Introductory offers:** Show Pass monthly: Pay as you go, $9.99, 1 month × **12 periods**, new subscribers.
   Season Pass monthly: Pay as you go, $19.99, 1 month × **12 periods**. (Yearly: none, unless Haylee decides
   otherwise.)
7. **Review information per subscription:** a screenshot of the paywall (use /tmp/pt-round38/03… or 14…, the
   Grown-ups → Plans screen) and a review note: "Plans are behind a grown-up gate (hold 2 s, then tap the number spelled
   out). In first-launch onboarding page 6 the plans are shown to the parent without the gate. Free Preview = 2 free
   new shows, no purchase. Replays are always free. Restore: Grown-ups → Restore purchases or Plans → Restore."
8. **App Store listing:** the auto-renew text is already in the app (plans footer); Terms (EULA) and Privacy links
   are on the plans screens; add the subscription info to the description (price, length, auto-renew).
9. **Sandbox testers:** Users and Access → Sandbox → add a tester; on the iPad, Settings → Developer → Sandbox
   Account. Test intro pricing, Ask to Buy, renewals (sandbox months are minutes).
10. **App Store Server Notifications:** not needed (no server state beyond the relay counter).
11. **Relay show counts:** after the products exist, follow relay/README.md → "Show counts" (KV namespace,
    SHOWS_SECRET, `SHOW_LIMITS = "count"`, then `RELAY_SHOW_LIMITS = YES`).
12. **Team profile (Code Camp):** add Apple StoreKit 2 / StoreKitTest (Apple) and Cloudflare Workers KV.
