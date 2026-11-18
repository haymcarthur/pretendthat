# Overnight run (Haylee, 2026-11-17 night)

- Haylee authorized Claude to: merge the current app round after checking it; **run the relay redeploy** (`cd relay && npx wrangler deploy`); run ONE live game (printables check, cost per game, black-and-white pages for the site); retake screenshots and lay out the 6 App Store slides; archive and upload the first TestFlight build; fill TestFlight Test Information, create the "Friends & Family" external group with a public link capped at 15, and **submit the build for Beta App Review**. She shares the link herself once Apple approves.
- Not done overnight (needs her): the iCloud schema step (run once from Xcode on her iPad signed into iCloud, then CloudKit Console → Deploy Schema Changes). Until then TestFlight builds can't sync.
- Who decided: Haylee.

- **Relay deployed overnight (Claude, with Haylee OK), 2026-11-18:** version b93de830: /v1/images/edits + pass sizes 5/20.

- **Upload blocked (Claude, overnight):** archive 1.0 (1) built and signed OK (commit 4535754) and is in Xcode Organizer, but `xcodebuild -exportArchive` upload failed: "App Store Connect access for 66898X3HH3 is required. Ensure that your Apple Account usernames and passwords are correct in Accounts settings." Needs Haylee: Xcode → Settings → Accounts (re-sign in if it asks), then Window → Organizer → the archive → Distribute App → TestFlight & App Store → Upload. Beta review submission waits for that.

- **Update (Haylee, 2026-11-18 morning):** hold uploads and beta review while she plays with the app; batch her changes, then upload one build and submit for beta review together. Build 3 is uploaded (full TestFlight) but NOT submitted for beta review; Friends & Family group exists with no build.
