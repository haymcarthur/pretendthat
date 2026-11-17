# Overnight status (night of 2026-11-16)

Updated as each step finishes. Newest at the bottom.

## Done
- **Round 34 merged + pushed** (455 tests pass). Replays reuse the first play's prop lines (no "Next," / "still have"); replay Props looks identical to a new game (checked side by side); in-app speech model download (iPadOS 26+, starts quietly at onboarding's mic step); short tasks + whole-row tap; scene openings now 5–9 s (were 20–24 s); returning greeting 5.5 s (was ~9 s). Details: decisions/2026-11-16-round34.md.
- **Onboarding voice:** the clips were fine; onboarding played her through a different audio setup than the game. Fix is in step 2 (research/2026-11-16-onboarding-voice-investigation.md).

- **Installed** round 34 on your iPad and simulator. (Fixed a build break first: the generated Xcode project still listed 4 deleted greeting clips; I regenerated it with xcodegen.)

## In progress
- Step 2: onboarding voice fix, system-TTS fallback removed, mini voice + Sonnet behind flags (off), new voice A/B samples.

## Needs you in the morning
- Try round 34 on the iPad: the speech model download, the new prop lines and the short greeting.
