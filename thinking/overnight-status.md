# Overnight status (night of 2026-11-16)

Updated as each step finishes. Newest at the bottom.

## Done
- **Round 34 merged + pushed** (455 tests pass). Replays reuse the first play's prop lines (no "Next," / "still have"); replay Props looks identical to a new game (checked side by side); in-app speech model download (iPadOS 26+, starts quietly at onboarding's mic step); short tasks + whole-row tap; scene openings now 5–9 s (were 20–24 s); returning greeting 5.5 s (was ~9 s). Details: decisions/2026-11-16-round34.md.
- **Onboarding voice:** the clips were fine; onboarding played her through a different audio setup than the game. Fix is in step 2 (research/2026-11-16-onboarding-voice-investigation.md).

- **Installed** round 34 on your iPad and simulator. (Fixed a build break first: the generated Xcode project still listed 4 deleted greeting clips; I regenerated it with xcodegen.)

- **Round 35 prep merged + pushed** (464 tests pass). Onboarding now plays Nutmeg through the same speaker path as the game (measured ×1.196–1.200, no mic prompt before the Mic page). The old system-voice fallback is deleted: with no clip she stays quiet. Mini voice and Sonnet guide are built but OFF until you approve. Details: decisions/2026-11-16-round35-prep.md.

## In progress
- Step 3: onboarding v2 (full-screen pages from the approved mockup).

## Needs you in the morning
- **Listen to the voice A/B:** open design/voice-ab-v2/index.html (8 pairs, A/B hidden, reveal key at the bottom). Both are coral at 1.20 (server confirmed the voice; rate measured ×1.19–1.20). Note: on 3 lines the mini sounded flatter/lower in pitch. If it passes, I flip the mini on.
- **Redeploy the relay** (it now allows Sonnet 5.5 and the mini voice): `cd relay && npx wrangler deploy`.
- Try round 34 on the iPad: the speech model download, the new prop lines and the short greeting.
