# Overnight status (night of 2026-11-16)

Updated as each step finishes. Newest at the bottom.

## Done
- **Round 34 merged + pushed** (455 tests pass). Replays reuse the first play's prop lines (no "Next," / "still have"); replay Props looks identical to a new game (checked side by side); in-app speech model download (iPadOS 26+, starts quietly at onboarding's mic step); short tasks + whole-row tap; scene openings now 5–9 s (were 20–24 s); returning greeting 5.5 s (was ~9 s). Details: decisions/2026-11-16-round34.md.
- **Onboarding voice:** the clips were fine; onboarding played her through a different audio setup than the game. Fix is in step 2 (research/2026-11-16-onboarding-voice-investigation.md).

- **Installed** round 34 on your iPad and simulator. (Fixed a build break first: the generated Xcode project still listed 4 deleted greeting clips; I regenerated it with xcodegen.)

- **Round 35 prep merged + pushed** (464 tests pass). Onboarding now plays Nutmeg through the same speaker path as the game (measured ×1.196–1.200, no mic prompt before the Mic page). The old system-voice fallback is deleted: with no clip she stays quiet. Mini voice and Sonnet guide are built but OFF until you approve. Details: decisions/2026-11-16-round35-prep.md.

- **Onboarding v2 merged + pushed** (467 tests pass). Seven full-screen pages matching the mockup (side-by-side checks: /tmp/pt-onb2/compare-01…07). No gate. "Start our first game" goes straight onto the stage with Nutmeg talking; "Go to the home page" is silent. Only page 1 has a voice clip (round 33's hand-off clip was dropped). Small differences: SF Rounded wraps a couple of titles differently; the How it works cards have a bit of extra space on the 13". To see it on your iPad: Grown-ups → Replay the intro (or delete and reinstall for the true first launch). Details: decisions/2026-11-16-onboarding-v2-build.md.

- **Round 36 merged + pushed** (478 tests pass). New arc: story opener → setup scene → 3 play scenes → clean-up scene → The End. Every prop and printout is checked in code to have a job (test games: bakery with 3 kids, space station solo; nothing unused). Replays reuse the recorded story/setup lines with zero AI calls. Cost: about +7.5¢ per new game (guide 5.6¢ → 7.9¢, plus ~4¢ of voice). Screens: /tmp/pt-round36/. One flaw I caught: with few players, a setup row crams many items into one long task labeled "...and more"; fixing that first in the next round. Details: decisions/2026-11-16-round36-story-setup-cleanup-build.md.

- **Round 37 merged + pushed** (491 tests pass). Setup/clean-up rows: a role can have several short rows (max 2 items each, real 2–7 word labels, never "and more"); solo gets ~4 rows. Compliance: privacy manifest, the encryption answer, Grown-ups → Report a problem (email with only the game title and that text; nothing on kid screens), "Nutmeg is an AI helper" in About. Privacy policy additions drafted on branch `privacy-additions` in the site repo (NOT published; fill the bracketed bits). Your App Store Connect answers: decisions/2026-11-17-setup-rows-and-compliance.md.

## In progress
- Step 6: StoreKit subscriptions (real products with a local test file, show allowances, paywall, restore) + relay show-count code for you to deploy. Also checking whether the blue "C" letter on scene rows in one test (instead of the character art) is a bug.

## Needs you in the morning
- **Listen to the voice A/B:** open design/voice-ab-v2/index.html (8 pairs, A/B hidden, reveal key at the bottom). Both are coral at 1.20 (server confirmed the voice; rate measured ×1.19–1.20). Note: on 3 lines the mini sounded flatter/lower in pitch. If it passes, I flip the mini on.
- **Redeploy the relay** (it now allows Sonnet 5.5 and the mini voice): `cd relay && npx wrangler deploy`.
- Try round 34 on the iPad: the speech model download, the new prop lines and the short greeting.
