# iCloud sync for saved games ships in 1.0, for everyone

- **Date:** 2026-11-17
- **Decision:** Build round D4 (saved games sync through the family's own private iCloud) before the first App Store release. It's for everyone: free preview, Show Pass and Season Pass. Not a Season Pass extra.
- **Why:** families switch between iPad and iPhone; passes already follow the Apple ID, so games should too.
- **Claude's calls (Haylee can change):** CloudKit private database (CKSyncEngine) in the container iCloud.co.crimsonfoundry.pretendthat; a delete on one device deletes everywhere; signed out of iCloud = works as today, on-device only, no nagging; sync is silent (no settings switch); stored content stays game content only (the D1 privacy test still holds). The privacy label doesn't change (a user's private iCloud isn't developer collection). The privacy policy's "we plan to add syncing" line becomes present tense.
- **Order:** starts after the no-swords round merges (one build agent at a time).
- **Note:** iCloud needs the company team (66898X3HH3); the personal-team `.dev` device build can't use CloudKit, so that build stays local-only.
- **Who decided:** Haylee (before launch, everyone); Claude (the how).
