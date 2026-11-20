# Snowy north: the picks (2026-11-20, Claude's call by analysis)

Asked for: A major / A minor, 96 BPM. 2 takes per segment. Nobody can listen in the agent sandbox, so the set is chosen by measurement with the method of the earlier families (ffmpeg ebur128, librosa beat grid, CQT chroma with Krumhansl key profiles, chroma similarity between takes; win endings by the sounding notes at the end). Script: `tools/process_music_calm2.py`. No extra AI calls.

**Note:** the model ignored "A major" (as it did for under the sea). No take is in A: the calms came out in C, G and C# minor, the tenses in C minor and D minor, the wins in C and D. The coherent set is **C**: calm-1, calm2-2, tense-1 and win-1 are all in C (chroma 0.95–0.98 to each other), so the family is in C major / C minor.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | C major (0.87) and the closest match to the C-minor tense (0.955) and the C win (0.978). calm-2 is in G major and matches nothing else. |
| calm2 | **calm2-2** | C major (0.95), chroma 0.964 to calm-1, 96.0 BPM. calm2-1 is in C# minor / A major (0.63 to calm-1). |
| tense | **tense-1** | C minor (0.82), the parallel minor of calm-1 (chroma 0.955). tense-2 is in D minor. |
| win | **win-1** | Ends on C (C4 + C5 at the body end, C/G/B in the ring-out; −5 → −22 → −46 dB over the last 3 s) after a C major body; chroma 0.978 to calm-1. win-2 is in D major. |

Chroma similarity of the set: calm↔calm2 0.964, calm↔tense 0.955, calm↔win 0.978, tense↔win 0.963.

## Measurements of every take

"Asked key" = correlation with the key the prompt asked for. Spread = std of per-second RMS over the body; drift = level change start→end of the body; grid = librosa beat-grid residual.

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| **calm-1** | -13.6 | 3.4 | -0.8 | 95.999 | 1.7 | C maj (0.87) | -0.33 | 1.23 | 2.2 | — |
| calm-2 | -13.5 | 1.6 | -0.2 | 95.997 | 2.8 | G maj (0.87) | 0.09 | 1.37 | 0.7 | — |
| calm2-1 | -13.0 | 1.7 | -0.4 | 95.997 | 2.0 | C# min (0.82) | 0.77 | 1.64 | 0.9 | — |
| **calm2-2** | -13.9 | 2.1 | -0.6 | 95.998 | 1.9 | C maj (0.95) | -0.15 | 1.24 | 2.1 | — |
| **tense-1** | -15.5 | 2.0 | -1.1 | 96.0 | 4.3 | C min (0.82) | 0.29 | 1.55 | 1.2 | — |
| tense-2 | -15.2 | 1.4 | -0.3 | 96.003 | 2.4 | D min (0.72) | -0.02 | 1.47 | 0.7 | — |
| **win-1** | -12.6 | 3.2 | -1.0 | 96.044 | 3.8 | C maj (0.84) | -0.33 | 0.77 | — | end: C4/C5; last 1 s: C4/C5 |
| win-2 | -11.2 | 4.2 | -0.6 | 95.97 | 2.7 | D maj (0.88) | 0.51 | 1.11 | — | end: A3/F#4/D5/F#5/D6; last 1 s: A#4/D5/F#5 |

## Processing (tools/process_music_calm2.py, reproducible)

- **calm**: calm-1.mp3 at 96.0 BPM (grid fit 95.999), from 5.9554 s (bar 2 after the downbeat, at an upward zero crossing), **20 bars = 50.005 s**, resampled 107 ppm to a whole number of AAC frames.
- **calm2**: calm2-2.mp3 at 96.0 BPM (grid fit 95.998), from 5.0203 s (bar 2 after the downbeat, at an upward zero crossing), **16 bars = 40.000 s** (already a whole number of AAC frames).
- **tense**: tense-1.mp3 at 96.0 BPM (grid fit 96.0), from 3.145 s (bar 1 after the downbeat, at an upward zero crossing), **12 bars = 30.016 s**, resampled 533 ppm to a whole number of AAC frames.
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm/calm2 −16 / tense −15 / win −16 LUFS, then the look-ahead limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| snowy-north/calm.m4a | 50.01 s (20 bars) | -16.0 | -2.4 | 612 KB |
| snowy-north/calm2.m4a | 40.00 s (16 bars) | -16.1 | -2.7 | 490 KB |
| snowy-north/tense.m4a | 30.02 s (12 bars) | -15.1 | -1.2 | 367 KB |
| snowy-north/win.m4a | 15.00 s | -16.1 | -4.1 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot):

| loop | RMS jump last→first 200 ms | the source's own jump there | log-mel distance (source's own) |
|---|---|---|---|
| calm | +0.11 dB | +3.55 dB | 0.91 (1.056) |
| calm2 | +5.82 dB | +8.75 dB | 1.176 (1.738) |
| tense | +1.22 dB | +1.72 dB | 0.803 (0.935) |

Listen check: `processed/loop-test-calm-x3.m4a`, `processed/loop-test-calm2-x3.m4a`, `processed/loop-test-tense-x3.m4a` (each loop 3x), and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 50.01 s and 90.01 s; A→B RMS +2.47 dB, B→A +3.46 dB). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
