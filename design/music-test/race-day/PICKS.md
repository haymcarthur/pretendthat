# Race day: the picks (2026-11-20, Claude's call by analysis)

Asked for: E major / E minor, 120 BPM. 2 takes per segment. Nobody can listen in the agent sandbox, so the set is chosen by measurement with the method of the earlier families (ffmpeg ebur128, librosa beat grid, CQT chroma with Krumhansl key profiles, chroma similarity between takes; win endings by the sounding notes at the end). Script: `tools/process_music_calm2.py`. No extra AI calls.

Every take is at exactly 120 BPM (a 120 BPM bar is exactly 96,000 samples, so no resampling). The calms are very steady (spread 0.25–0.5 dB) and close to each other (chroma 0.98–0.996).

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | The clearest E major (0.81) and the steadiest (spread 0.25 dB). |
| calm2 | **calm2-1** | E major 0.64 / A major 0.70 (A is E's IV, the same notes but one), chroma 0.985 to calm-1; calm2-2 has no clear key (B major 0.46). |
| tense | **tense-2** | The clear E minor (0.92), chroma 0.98 to calm-1. tense-1 reads E major (0.78). |
| win | **win-2** | The only take that ends on E: the final hit (~10 s) is E/G/B, then the ring-out reads E/B (open fifth, E major in the chroma) down to −65 dB. win-1 ends on B major (the dominant: it sounds unfinished). **Listen check:** the final hit has a G (minor colour) before the major-leaning ring-out; it opens with a ~1.5 s swell. |

Chroma similarity of the set: calm↔calm2 0.985, calm↔tense 0.98, calm↔win 0.984, tense↔win 0.991.

## Measurements of every take

"Asked key" = correlation with the key the prompt asked for. Spread = std of per-second RMS over the body; drift = level change start→end of the body; grid = librosa beat-grid residual.

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| **calm-1** | -12.2 | 1.4 | -0.4 | 119.996 | 2.3 | E maj (0.81) | 0.81 | 0.25 | 0.2 | — |
| calm-2 | -13.5 | 1.8 | -0.6 | 119.997 | 2.0 | E maj (0.67) | 0.67 | 0.33 | 0.4 | — |
| **calm2-1** | -12.7 | 1.5 | -0.1 | 119.998 | 2.1 | A maj (0.70) | 0.64 | 0.31 | 0.3 | — |
| calm2-2 | -13.3 | 1.3 | 0.1 | 119.99 | 4.7 | B maj (0.46) | 0.44 | 0.5 | 0.3 | — |
| tense-1 | -12.4 | 1.2 | -0.5 | 119.993 | 1.9 | E maj (0.78) | 0.61 | 0.27 | 0.7 | — |
| **tense-2** | -14.2 | 1.5 | -0.3 | 119.992 | 1.9 | E min (0.92) | 0.92 | 0.35 | 0.5 | — |
| win-1 | -13.3 | 1.5 | -0.4 | 120.012 | 1.6 | E maj (0.46) | 0.46 | 0.31 | — | end: D#3/B3/D#4/F#4/B4/D#5; last 1 s: F#3/B3/D#4/F#4/B4/D#5/F#5/B5 |
| **win-2** | -10.7 | 6.2 | -0.2 | 120.008 | 1.6 | E min (0.77) | 0.40 | 4.23 | — | end: E3/G3/E4/G4/E5/G5/B5/E6; last 1 s: E3/B3 |

## Processing (tools/process_music_calm2.py, reproducible)

- **calm**: calm-1.mp3 at 120.0 BPM (grid fit 119.996), from 3.5132 s (bar 1 after the downbeat, at an upward zero crossing), **20 bars = 40.000 s** (already a whole number of AAC frames).
- **calm2**: calm2-1.mp3 at 120.0 BPM (grid fit 119.998), from 4.5121 s (bar 2 after the downbeat, at an upward zero crossing), **20 bars = 40.000 s** (already a whole number of AAC frames).
- **tense**: tense-2.mp3 at 120.0 BPM (grid fit 119.992), from 1.513 s (bar 0 after the downbeat, at an upward zero crossing), **16 bars = 32.000 s** (already a whole number of AAC frames).
- **win**: the whole win-2.mp3 (leading 0.188 s of silence trimmed), 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm/calm2 −16 / tense −15 / win −16 LUFS, then the look-ahead limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| race-day/calm.m4a | 40.00 s (20 bars) | -15.9 | -3.1 | 491 KB |
| race-day/calm2.m4a | 40.00 s (20 bars) | -15.9 | -1.4 | 491 KB |
| race-day/tense.m4a | 32.00 s (16 bars) | -15.4 | -1.5 | 395 KB |
| race-day/win.m4a | 14.81 s | -15.7 | -4.2 | 183 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot):

| loop | RMS jump last→first 200 ms | the source's own jump there | log-mel distance (source's own) |
|---|---|---|---|
| calm | +3.64 dB | +6.93 dB | 0.494 (1.123) |
| calm2 | +2.12 dB | +4.63 dB | 0.852 (0.781) |
| tense | +2.61 dB | +4.41 dB | 0.384 (0.652) |

Listen check: `processed/loop-test-calm-x3.m4a`, `processed/loop-test-calm2-x3.m4a`, `processed/loop-test-tense-x3.m4a` (each loop 3x), and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 40.0 s and 80.0 s; A→B RMS +3.32 dB, B→A +2.45 dB). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
