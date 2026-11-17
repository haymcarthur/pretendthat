# Voice clips match: clips get exactly the live processing, bundled lines re-recorded

- **Date:** 2026-11-17
- **Trigger (Haylee):** "The voice sounds great. However, we need to re-record the previous saved messages so it
  matches." Later: "don't worry about my saved games" (no migration, no re-recording of clips in existing saved games).
- **Decision:** every clip (bundled, recorded in a game, saved with a game) gets EXACTLY the live voice's processing:
  Signalsmith plain +2, then Varispeed 1.20. No per-clip pitch move, no formant matching. A take outside her live band
  is re-recorded, not pitch-corrected. All 13 bundled CommonClips were re-recorded. Claude's calls (below), on the
  coordinator's leaning, verified by measurement.
- **Listen:** [design/voice-clips-match/index.html](../../design/voice-clips-match/index.html) (clip → live line, before vs after,
  5 lines + one capture from the app on the simulator).

## What was off
- The voice pitch build moved each clip toward 298.6 Hz raw by its own amount (−4.9 to +5.0 st on the bundled clips)
  and, when that amount wasn't +2, placed its formants at the live +2 separately (Signalsmith formant shift). The pitch
  then matched (greeting 368 Hz vs live 353 heard), but the clips sounded processed: a −4 st pitch move with formants
  held at +2 is a 6 st pitch/formant split the live voice never has; the low "saved game" take went up 5 st.
- The cause underneath was the takes themselves: 6 of 13 bundled clips were far from her ordinary live pitch (raw
  medians 376, 395, 365, 323, 315 Hz: the greetings and "How many friends"; 224 Hz: "This is a saved game"). Coral
  says excited lines bright: the live A/B take of "Hi again!" is 386 Hz raw too, while her ordinary live lines are
  234–280.
- **Ruled out:** AAC 32 kbps. Raw, it cuts the top end (centroid 3300 → 2550 Hz), but through the app's chain the heard
  centroid is the same for the raw line and its 32 or 64 kbps AAC (2595 vs 2592 / 2596 Hz, line 02).

## What changed (code)
- `ClipPitch` (NutmegCore/VoicePitch.swift): `plan(shift)` = the live plan, for every clip. Removed the per-clip target,
  clamp and `matchLiveFormants`. New bands around the live raw median 266 Hz: `matchRange` ±2.5 st ≈ 230–307 Hz (bundled
  clips, the re-take check), `keepRange` ±4 st ≈ 211–335 Hz (lines recorded in a game). `keeps(hz)`, `distance(hz)`.
- `NutmegSpeaker.playClip`: the live plan, logged as "same as live".
- `ClipStore.store` [Claude's call]: a line recorded during a game whose take is outside `keepRange` isn't kept, so a
  replay says it live again and keeps that take if it's in range (re-record instead of correct). Unmeasured (very
  short) lines are kept. Cost: one live response on the replay for such a line.
- `-PTRecordCommon all` (DEBUG): re-records every bundled line in the game's own session (full model, coral, the
  game's instructions, the same `sayExactly` + transcript gate); a take outside `matchRange` is taken again (3 takes),
  the take nearest 266 Hz is written. `-PTRecordCommon redo`: only the bundled lines still out of band, up to 5 takes.
  Logs the session's usage.
- Saved games (Haylee: don't worry about them): no migration, no schema change. Their clips are raw coral takes, so they
  now simply get the live +2 like everything else. Outlier takes in them stay as they are.

## Re-recording (PT-R15 simulator, live API)
- Run 1 (`all`): 13 lines, 17 takes. Re-takes: "This is a saved game" (201 → 236), "Hooray, a new show" (376 → 297),
  "Yay, you're back" (378, 360, 413: all out). Run 2 (`redo`): "Yay, you're back" 271 on the first take.
- New raw medians (PitchTracker): 236–297 Hz, all 13 inside 230–307. Old: 224–395.
- **API cost:** 18 Realtime responses, ≈ $0.16 + $0.03 = **≈ $0.20** (estimated from the session's token counts, not
  billing). No other calls. Secrets.xcconfig was copied into the worktree for the two runs and deleted; the Debug build
  was rebuilt without it afterwards. Haylee's simulator AF512F6A and her iPad were not touched.

## Measurements (offline, through the app's chain: shifter → player → SpeakerGraph Varispeed 1.20 → 48 kHz)
| Line | Old: raw → heard (per-clip move) | New: raw → heard (+2) |
|---|---|---|
| Welcome back (greeting) | 376 → 366 | 260 → 350 |
| Hi again | 395 → 358 | 272 → 366 |
| How many friends | 365 → 356 | 288 → 384 |
| This is a saved game | 224 → 361 | 241 → 329 |
| Yay, you're back | 323 → 372 | 272 → 369 |
| Live lines 01–08 (+2) | | 338–384 heard (the "Hi again" live take: 505) |

- Timbre (cepstral distance to the 7 ordinary live lines, tools/voice_measure.swift): the greetings got closer
  (Welcome back 17.1 → 9.5, Hi again 17.5 → 10.8, Yay 17.9 → 13.2, saved game 14.3 → 11.4); the live lines themselves
  sit at 4–13. The two shortest clips (1–2 s) moved around (Almost ready 19.3 → 15.5, No problem 19.3 → 28.8): too few
  frames for this measure to mean much; listen.
- On the simulator (`-PTVoiceRender` with `-PTTapOut`, no API): the new greeting clip at 356 Hz heard, then live line
  03 at 381 Hz: 1.2 st apart, with no pitch move on the clip.
- New takes sit a little above her live median (most 285–297 raw vs 262): in band, about +0.5 to +1 st brighter on
  average than an ordinary live line.

## Tests and builds
- `swift test` (NutmegCore): 527 pass. Changed: `clipsGetExactlyTheLiveProcessing`, `thePitchBandsSitAroundTheLiveVoice`,
  `everyBundledClipIsInTheLiveBand` (all 13 within 230–307), `theGreetingClipSoundsLikeTheLiveVoice`. New env-gated
  `VoiceClipsMatchMeasure.measureClipsAndLive` (PT_MEASURE_IN / PT_MEASURE_OUT) for the numbers and renders above.
- `xcodegen generate`; Debug iPad (PT-R15) + iPhone (PTi-iPhone18Pro), Release iPad + iPhone: all succeed; the Release
  key check is clean ("no personal keys in the Info.plist").

## Not verified
- Listening by ear, and on the iPad.
- A full live game with the new rule that drops out-of-band game takes (unit-tested in `ClipPitch.keeps`, not run live).

## Haylee listened (2026-11-17)
- On her iPad/simulator: "Sounds right". The voice pitch work is final.
