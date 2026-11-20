# Robot lab: the picks (2026-11-20, Claude's call by analysis)

Asked for: C major / C minor, 108 BPM. 2 takes per segment. Nobody can listen in the agent sandbox, so the set is chosen by measurement with the method of the earlier families (ffmpeg ebur128, librosa beat grid, CQT chroma with Krumhansl key profiles, chroma similarity between takes; win endings by the sounding notes at the end). Script: `tools/process_music_calm2.py`. No extra AI calls.

Every take is at exactly 108 BPM and centred on C, as asked.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | The clearer C major of the two (0.67 vs 0.48) and the closest to the tense pick (0.978). |
| calm2 | **calm2-1** | C major (0.79), chroma 0.945 to calm-1. calm2-2 has no clear key (best 0.34). |
| tense | **tense-1** | The clear C minor (0.83), chroma 0.978 to calm-1, steady (spread 0.85 dB). tense-2 is major/minor-ambiguous (0.61 / 0.59). |
| win | **win-1** | C major (0.91); its last second is C/G/E (a C chord) after a final hit at ~13.3 s, then a short, clean ring-out to −85 dB. win-2 is a clearer C major overall (0.95) but its last chord leans F/E (IV). **Listen check:** the ring-out is short (~1.3 s), so the ending is crisp rather than grand. |

Chroma similarity of the set: calm↔calm2 0.945, calm↔tense 0.978, calm↔win 0.966, tense↔win 0.943.

## Measurements of every take

"Asked key" = correlation with the key the prompt asked for. Spread = std of per-second RMS over the body; drift = level change start→end of the body; grid = librosa beat-grid residual.

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| **calm-1** | -14.1 | 1.4 | -0.1 | 108.0 | 2.0 | C maj (0.67) | 0.67 | 0.82 | 1.1 | — |
| calm-2 | -14.0 | 1.0 | -1.0 | 107.997 | 1.7 | C maj (0.47) | 0.47 | 0.62 | 0.3 | — |
| **calm2-1** | -14.2 | 2.2 | -0.7 | 108.0 | 2.0 | C maj (0.79) | 0.79 | 1.0 | 0.6 | — |
| calm2-2 | -13.0 | 1.5 | -0.1 | 107.997 | 1.9 | G maj (0.34) | 0.33 | 0.58 | 0.8 | — |
| **tense-1** | -14.7 | 1.6 | -0.2 | 108.0 | 1.7 | C min (0.83) | 0.83 | 0.85 | -1.1 | — |
| tense-2 | -15.8 | 1.7 | -1.2 | 107.992 | 1.8 | C min (0.61) | 0.61 | 0.49 | 0.2 | — |
| **win-1** | -14.6 | 4.1 | 0.3 | 108.022 | 2.4 | C maj (0.91) | 0.91 | 2.33 | — | end: G3/G4; last 1 s: G3/G4 |
| win-2 | -15.4 | 1.3 | -1.2 | 107.989 | 1.7 | C maj (0.95) | 0.95 | 0.68 | — | end: F3/C4/F4/E5; last 1 s: C4/F4/E5 |

## Processing (tools/process_music_calm2.py, reproducible)

- **calm**: calm-1.mp3 at 108.0 BPM (grid fit 108.0), from 3.0696 s (bar 1 after the downbeat, at an upward zero crossing), **24 bars = 53.333 s** (already a whole number of AAC frames).
- **calm2**: calm2-1.mp3 at 108.0 BPM (grid fit 108.0), from 1.953 s (bar 0 after the downbeat, at an upward zero crossing), **20 bars = 44.459 s**, resampled 320 ppm to a whole number of AAC frames.
- **tense**: tense-1.mp3 at 108.0 BPM (grid fit 108.0), from 1.6769 s (bar 0 after the downbeat, at an upward zero crossing), **16 bars = 35.563 s**, resampled 200 ppm to a whole number of AAC frames.
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm/calm2 −16 / tense −15 / win −16 LUFS, then the look-ahead limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| robot-lab/calm.m4a | 53.33 s (24 bars) | -16.0 | -1.5 | 660 KB |
| robot-lab/calm2.m4a | 44.46 s (20 bars) | -16.0 | -1.7 | 547 KB |
| robot-lab/tense.m4a | 35.56 s (16 bars) | -15.1 | -1.1 | 440 KB |
| robot-lab/win.m4a | 15.00 s | -16.2 | -1.3 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot):

| loop | RMS jump last→first 200 ms | the source's own jump there | log-mel distance (source's own) |
|---|---|---|---|
| calm | +1.82 dB | +4.47 dB | 0.771 (0.906) |
| calm2 | +2.29 dB | +4.45 dB | 1.286 (1.228) |
| tense | +6.37 dB | +5.36 dB | 1.068 (0.952) |

Listen check: `processed/loop-test-calm-x3.m4a`, `processed/loop-test-calm2-x3.m4a`, `processed/loop-test-tense-x3.m4a` (each loop 3x), and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 53.33 s and 97.79 s; A→B RMS +3.2 dB, B→A +0.91 dB). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
