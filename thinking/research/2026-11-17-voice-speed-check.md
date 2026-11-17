# Voice speed check: why the A/B samples "don't sound like 1.2" (2026-11-17)

**By:** Claude (investigation only; no app code, rate or flags changed). **Trigger:** Haylee listened to
design/voice-ab-v2/ and said again that the samples "still don't sound like 1.2" (mini approved on that condition,
decisions/2026-11-17-mini-voice-approved.md).

**Listening page for Haylee:** [design/voice-speed-check/index.html](../../design/voice-speed-check/index.html)

## Short answer (plain words)
- **The samples really are 1.20, and they're exactly what the app plays.** Speed and pitch both sit at about ×1.20
  over her raw voice. They match the app on both test simulators sample for sample.
- **The app has played her at 1.20 on the simulator the whole time, and that includes the build before round 25.**
  The "1.1025 bug" that round 25 found was mostly a mislabeled recording, not a slower voice. The engine was rendering
  48 kHz audio but labeling it 44.1 kHz, so the measurement read slow. The wall-clock check below shows the old build
  was already using up her voice at ×1.20. (Round 25's re-wire is still good hygiene, and it changes nothing audible.)
- **So the gap isn't a speed bug. It's what "1.2" means to her ear.** The likely causes, in order:
  1. **Which take she heard.** Coral's own pitch changes a lot from line to line. The median pitch of the raw takes
     runs 203 to 381 Hz. At ×1.20, a low take (the mini's prop line, 203 Hz → 243 Hz) sounds much lower than a bright
     one (the full model's "Hi again!", 381 Hz → 457 Hz). The voice she approved on 11-13 was live, excited chat
     replies. The A/B lines are scripted read-outs, and on 3 lines the mini read them lower and flatter.
  2. **Where she listens.** She knows Nutmeg from the iPad's small built-in speaker on a play-and-record session.
     That sounds thinner and higher than the same file on a laptop or headphones, which is how she heard the A/B page.
  3. **Her "1.2" may just be a different number.** She tuned it by ear with the slider on 11-13. The ladder will show
     whether she really wants 1.25 to 1.30.
- **Nothing here is a code bug, so there's no branch.** The next step is her pick on the listening page.

## What was checked

### 1. The A/B files themselves
- Every v2 file is AAC, 2 channels, 48 kHz in the header. The audio in them is the mixer tap, which runs at 48 kHz.
  The engine log for that run showed the session, output hardware, mixer → output link and mixer all at 48 kHz. That
  means no label mismatch.
- They were captured **after** Varispeed, at the mixer output. That's the last point inside the app before the speaker.
- The m4a encode didn't change speed or pitch. 00-reference.m4a against the bundled raw clip
  (`common-2a6c3f89…aac`, getAGrownUp): voiced span 5.664 s → 4.672 s (×1.21), median F0 258.1 → 313.7 Hz (×1.215).
  The 16 v2 captures: span ×1.191 to ×1.201 (round 35 prep).

### 2. What "1.20" meant when she approved it
- Approved on 2026-11-13 evening (commit c695a1c, decisions/conversation-voice.md). She used the Grown-ups slider
  with live preview on the simulator and coral's **live conversation replies**. That build had the same graph as the
  round 25 "old" build: player → Varispeed → mixer, an implicit mixer → output link, no 48 kHz preference, server
  speed 1.0, model gpt-realtime-2.1.
- **Round 25 re-check with wall-clock time** (/private/tmp/pt-round25 tap runs, PT-R15, 60 s live runs):

  | run | out tap header | raw voice used | tap start → stop (wall) | raw used per wall second | heard |
  |---|---|---|---|---|---|
  | tap-old (pre-D3a build) | 44.1 kHz | 52.05 s | ≈ 43.5 s | ≈ 28,700 /s | **×1.197** |
  | tap-head (HEAD before fix) | 44.1 kHz | 51.71 s | ≈ 43.2 s | ≈ 28,730 /s | **×1.197** |
  | tap-fix (after fix) | 48 kHz | 51.88 s | ≈ 43.4 s | ≈ 28,660 /s | **×1.194** |

  The "44.1 kHz" out files hold about 47,800 to 47,900 frames per wall second. That's 48 kHz audio with a 44.1 label.
  Read at the label, they look like ×1.10. Played at the real rate, they're ×1.20. In all three builds the Varispeed
  pulled raw audio at 1.20 × 24 kHz per wall second, which can only happen if she was heard at 1.20. (Wall time is
  from the TAPOUT log line to the copy timestamp minus the script's 1 s sleep, so about ±1 s. The 1.10 vs 1.20 gap is
  about 4 s, so the result holds.)
- **What follows:** round 25's report that "her voice wasn't as high" was not caused by the rate, just like today's
  report. Both times the rate measured 1.20 and her ear still said "lower". That points to the takes (her pitch varies
  from line to line and session to session) or to the listening device, not the pipeline.

### 3. Server speed, instructions, model
- Server `speed` is 1.0 then and now (`Realtime.apiSpeed` forces 1.0 whenever Varispeed is on; v2 log:
  `voice coral, speed 1` on both models).
- The voice style is the same as on 11-13 ("bright and high … a quick pace"). Only "playful giggles" was dropped. The
  full instructions grew to about 16 k characters, but the voice style text is the same.
- Raw pitch (median F0) of **live** sessions: 267 Hz (11-15 old build), 281 Hz (11-15 fixed), 296 Hz (11-16).
  Scripted v2 takes: full 254 to 381 Hz, mini 203 to 296 Hz, with three mini takes lower than any full take. The model
  isn't speaking slower overall, but individual scripted takes, mostly on mini, come out lower and flatter, and
  Varispeed carries that through.

### 4. The real app on the simulators (2026-11-17, main @ 7983537, Debug, no keys, `-PTResetOnboarding -PTTapOut`)
- **iPad Pro 13" (72917D45):** `VOICEFMT onboarding: session PlayAndRecord/Default 48000, output hw 48000, mixer→output
  link 48000, mixer out 48000, input 48000, vp off → heard ×1.200`. Tap: raw 5.664 s / 258.1 Hz → out 4.736 s /
  313.7 Hz.
- **PT-R15 (D6FFF58F):** the same log line, and the same numbers exactly.
- These match 00-reference.m4a and the page's "1.20" row (4.624 s / 313.7 Hz). The simulator app sounds the same as
  the samples. The whole chain runs at 48 kHz, so nothing in it can shift the rate.
- **Not checked:** Haylee's physical iPad and her simulator AF512F6A (off limits). On a device, the round 25/33
  relink guard and the VOICEFMT log cover a rate mismatch. One `VOICEFMT` line from her iPad would confirm it.

## The listening page (design/voice-speed-check/)
- Line 1: the bundled onboarding clip (getAGrownUp). Line 2: "The End" (full model, the raw v2 capture).
- Each line plays at Varispeed 1.00 / 1.10 / 1.15 / **1.20 (the app today)** / 1.25 / 1.30 / 1.35 / 1.40 (resampled,
  so pitch and speed move together, as in the app). Made with ffmpeg `asetrate=24000×r,aresample=48000`. It's
  level-matched to −20 dB mean so loudness doesn't bias the pick.
- Line 1 also has the **app's real output** (tapped inside the running app on the iPad Pro 13" sim) and the A/B v2
  reference, both left at their recorded level.
- Extras: "faster only" (atempo 1.20, normal pitch) and "higher only" (+1.20 pitch at normal speed) for each line,
  in case "1.2" to her mostly means one of the two.
- Blind mode shuffles the ladder and labels the rows with letters, with a Reveal button.
- Check: the page's 1.20 row measures 4.624 s / 313.7 Hz against the app's 4.608 s / 313.7 Hz. All 22 files load.

## What to do with her answer
- **She picks 1.20:** the speed is right. The issue is take quality or device. Two follow-ups: for mini, re-record or
  reject low takes (a pitch floor on recorded clips, for example a median F0 under about 240 Hz raw gets re-asked),
  and compare on the iPad speaker.
- **She picks 1.25 to 1.30:** change `Realtime.defaultVarispeedRate` (one constant, plus `SpeakerGraphTests` and the
  clip timing comment). Bundled and saved clips are stored before Varispeed, so they follow the new rate
  automatically. That's her call, not changed here.
- **She picks "faster only" or "higher only":** that's a pitch-method change (TimePitch has artifacts; see
  conversation-voice.md for why Varispeed won). Discuss before building.
- Separately, the mini's lower takes are real (3 of 8 lines). If her pick is 1.20, the mini flag should wait until
  the take pitch gets checked.
