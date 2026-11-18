# iCloud sync for saved games ships in 1.0, for everyone

- **Date:** 2026-11-17
- **Decision:** Build round D4 (saved games sync through the family's own private iCloud) before the first App Store release. It's for everyone: free preview, Show Pass and Season Pass. Not a Season Pass extra.
- **Why:** families switch between iPad and iPhone; passes already follow the Apple ID, so games should too.
- **Claude's calls (Haylee can change):** CloudKit private database (CKSyncEngine) in the container iCloud.co.crimsonfoundry.pretendthat; a delete on one device deletes everywhere; signed out of iCloud = works as today, on-device only, no nagging; sync is silent (no settings switch); stored content stays game content only (the D1 privacy test still holds). The privacy label doesn't change (a user's private iCloud isn't developer collection). The privacy policy's "we plan to add syncing" line becomes present tense.
- **Order:** starts after the no-swords round merges (one build agent at a time).
- **Note:** iCloud needs the company team (66898X3HH3); the personal-team `.dev` device build can't use CloudKit, so that build stays local-only.
- **Who decided:** Haylee (before launch, everyone); Claude (the how).

## What was built (round D4, 2026-11-17)

**Design.** Local files stay the source of truth; sync mirrors them.
- **CKSyncEngine** (iOS 17, the deployment target) on the private database of `iCloud.co.crimsonfoundry.pretendthat`,
  custom zone `SavedGames`, one record per game (record type `SavedGame`, record name = the game's UUID). Fields:
  `schemaVersion` (Int64), `modifiedAt` (Date), `game` (Asset: game.json), `fileNames` (String list) + `files` (Asset
  list): art/*.heic, cover.jpg, clips/*.aac. Exactly the saved game's folder, nothing else (allowed names are checked
  going up and coming down).
- **Code:** `NutmegCore/GameSync.swift` (CloudKit-free: what goes up, merge, deletes, the ledger),
  `NutmegCore/GameRecordMapper.swift` (CKRecord mapping), `PretendThat/App/CloudSync.swift` (the CKSyncEngine delegate,
  account checks), `SavedGameStore.onLocalChange` (save, update, replay touch, new clip, delete tell the sync; games that
  came from iCloud don't, so nothing echoes back).
- **Merge (Claude's call): last writer wins for the whole game,** by `modifiedAt` (when the device last changed it). A
  conflicting save (CKError serverRecordChanged) keeps the newer one on both sides. Clips added on two devices at once:
  one device's set wins (rare; noted).
- **Deletes:** a delete on any device deletes everywhere, and beats an edit (a save whose record is gone → the game is
  deleted here too). A game deleted here is never brought back by an incoming copy while its delete is pending.
- **Unchanged pictures aren't re-sent:** the ledger keeps a SHA-256 per file of what the server has; a replay (only
  `lastPlayedAt` changes) sends game.json only, and the server keeps its files.
- **No iCloud** (signed out, iCloud off for the app, restricted): the engine is never created; the app works on the
  device exactly as before, no messages. On `CKAccountChanged` → available, the engine starts and every local game
  uploads. Sign-out keeps every local game. Switching accounts keeps local games and uploads them to the new account.
  A deleted/reset zone → local games upload again (Claude's call: the device copy is the source of truth, kids lose
  nothing).
- **Newer schema from a newer app version:** written to disk, skipped by the shelf until the app updates (same as D1).
- **Bookkeeping** (game ids, stamps, file hashes; never content): Application Support/SavedGamesSync (ledger.json,
  engine-state.json, cached record system fields). Upload copies: Caches/SavedGamesSyncOutbox (cleared after sending).
- **The personal-team `.dev` build:** project.yml looks the entitlements and the container up by team
  (`CODE_SIGN_ENTITLEMENTS = $(PT_ENTITLEMENTS_$(DEVELOPMENT_TEAM))`, same for `PT_CLOUDKIT_CONTAINER` → Info.plist
  `PTCloudKitContainer`). With `DEVELOPMENT_TEAM=TSM76TQF46` there are no iCloud entitlements and the container is empty,
  so CloudKit is never touched. Debug demo runs (`-PTDemo`, `-PTNoAI`, `-PTNoSync`) never sync either (`-PTSync` forces it).
- **Entitlements** (PretendThat/Resources/PretendThat.entitlements): iCloud CloudKit with the container, and
  `aps-environment` (CKSyncEngine's silent pushes). Info.plist: `UIBackgroundModes = remote-notification`. The app also
  fetches when it comes to the front.
- **Copy:** Grown-ups → About what we save: "Synced through your family's iCloud"; the Saved games footer and "You're
  in charge" say a delete removes the game from the other devices too. Privacy manifest comment updated (no new data
  type: the user's private iCloud isn't developer collection). The privacy policy page lives on the website, not in this
  repo: Haylee changes "we plan to add syncing" to present tense.

**Tests.** NutmegCore 669 green (+14: `RoundD4CloudSyncTests` with a fake cloud and two fake devices: a game made on
one appears on the other with art, cover and clips; delete everywhere; delete beats edit; newest save wins both ways;
replay sends only game.json; a later clip syncs; signed out works and uploads later; pending work survives a relaunch;
newer-schema and foreign/broken records; the CKRecord mapping incl. changed keys; **the privacy test** on what is sent
(record fields, file names, game.json keys, no kid text in any byte or in the ledger); the About copy).
Simulator (new throwaway "PT-D4-iCloud-iPad", no Apple ID): launches, logs "no account available: saved games stay on
this device", seeding 5 games, the bookshelf and Grown-ups delete-all work as before (screenshots /tmp/pt-roundD4/).
The `.dev` variant builds with no iCloud entitlement, logs "no container in this build", and saves locally.

**Not tested:** real CloudKit (needs a device or simulator signed in to iCloud with the company team's container).

### Haylee: before TestFlight
1. **Developer portal** (or let Xcode do it): Certificates, IDs & Profiles → Identifiers → iCloud Containers → `+` →
   `iCloud.co.crimsonfoundry.pretendthat`. Then the App ID `co.crimsonfoundry.pretendthat` → enable **iCloud**
   (CloudKit, assign that container) and **Push Notifications**. In Xcode (company team signed in) → target →
   Signing & Capabilities: iCloud should show CloudKit with the container ticked; if it's red, press the refresh button
   (automatic signing creates the container and updates the profile).
2. **Create the schema in Development:** run a Debug build from Xcode on your iPad (signed in to iCloud) and let one game
   save. That creates the `SavedGames` zone and the `SavedGame` record type in the Development environment.
3. **Deploy the schema to Production:** icloud.developer.apple.com → CloudKit Console → the container → Schema →
   **Deploy Schema Changes**. TestFlight and App Store builds use Production; without this step they can't save records.
4. **Two-device test on TestFlight:** install the build on an iPad and an iPhone signed in to the same Apple ID (iCloud
   on; Settings → [your name] → iCloud → Saved to iCloud / Apps using iCloud → PretendThat on). Make a game on the iPad
   (wait for its kit), keep the app open ~30 s, then open the app on the iPhone (or bring it to the front): the game is
   on the bookshelf with its cover and pages. Replay it on the iPhone, back on the iPad the shelf order follows. Delete
   it in Grown-ups on the iPhone; bring the iPad app forward: it's gone. Also: turn iCloud off for PretendThat on one
   device, make a game (it saves locally, no message), turn iCloud back on → it appears on the other device.
5. Privacy policy page: present tense for syncing.
