# Circus & carnival: the picks (2026-11-20, Claude's call by analysis)

Asked for: F major / F minor, 112 BPM. 2 takes per segment. Nobody can listen in the agent sandbox, so the set is chosen by measurement with the method of the earlier families (ffmpeg ebur128, librosa beat grid, CQT chroma with Krumhansl key profiles, chroma similarity between takes; win endings by the sounding notes at the end). Script: `tools/process_music_calm2.py`. No extra AI calls.

**Note:** neither tense take came out in F minor (tense-1 is C/F major, tense-2 is F major with a broken beat grid), so the urgency is in the quick oompah and snare rolls, not the mode (as for pirate adventure). All takes are 112.0 BPM (comb fit 111.99–112.01).

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | F major (0.89), the closest to the win (0.982). librosa's beat list wobbles on its oompah off-beats (41 ms residual), but the comb grid holds at 112.006 BPM, so the loop is placed on the comb grid (`OVERRIDE` in the script), with a seam close to the music's own bar line. calm-2 is steadier but in C major. |
| calm2 | **calm2-2** | F major (0.84) like calm-1 (chroma 0.967). It swells 2.9 dB over the take, so the loop uses a steady 20-bar stretch. calm2-1 is steadier but in C major (0.93). |
| tense | **tense-1** | The only usable tense: steady (spread 0.57 dB, grid 2.3 ms), C/F major (0.70 / 0.65), chroma 0.969 to calm-1. tense-2's beat grid is broken (166 ms) and its level swings (spread 3.9 dB). **Listen check:** it may sound more busy than urgent. |
| win | **win-1** | Ends on F major (F3, F4, A4, F5) with a clean ring-out (−3 → −26 → −46 dB), chroma 0.982 to calm-1. win-2 is in D major. |

Chroma similarity of the set: calm↔calm2 0.967, calm↔tense 0.969, calm↔win 0.982, tense↔win 0.971.

## Measurements of every take

"Asked key" = correlation with the key the prompt asked for. Spread = std of per-second RMS over the body; drift = level change start→end of the body; grid = librosa beat-grid residual.

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| **calm-1** | -12.6 | 3.5 | -0.9 | 112.027 | 40.7 | F maj (0.89) | 0.89 | 1.3 | 1.6 | — |
| calm-2 | -15.2 | 0.8 | -1.3 | 112.005 | 2.3 | C maj (0.88) | 0.69 | 0.56 | -0.3 | — |
| calm2-1 | -15.1 | 1.0 | -0.9 | 112.0 | 2.6 | C maj (0.93) | 0.56 | 0.54 | 0.2 | — |
| **calm2-2** | -13.7 | 4.6 | -0.5 | 112.0 | 4.3 | F maj (0.84) | 0.84 | 1.77 | 2.9 | — |
| **tense-1** | -15.6 | 0.7 | -1.0 | 112.004 | 2.3 | C maj (0.70) | 0.52 | 0.57 | -0.4 | — |
| tense-2 | -17.4 | 8.4 | -1.8 | 111.95 | 166.5 | F maj (0.69) | 0.25 | 3.89 | 0.4 | — |
| **win-1** | -15.3 | 2.1 | -1.1 | 112.014 | 2.6 | C maj (0.82) | 0.79 | 0.44 | — | end: F3/G3/C4/F4/G4/A4/F5/A5/C6; last 1 s: F3/F4/A4/F5 |
| win-2 | -16.4 | 2.3 | -0.9 | 112.051 | 3.5 | D maj (0.67) | 0.02 | 0.48 | — | end: A3/D4/F#4; last 1 s: D3/D4/F#4/A4 |

## Processing (tools/process_music_calm2.py, reproducible)

- **calm**: calm-1.mp3 on the comb grid at 112.0 BPM, from 7.7923 s (beat 14), **24 bars = 51.435 s**, speed change -0.0119 % to a whole number of AAC frames.
- **calm2**: calm2-2.mp3 at 112.0 BPM (grid fit 112.0), from 2.1548 s (bar 1 after the downbeat, at an upward zero crossing), **20 bars = 42.859 s**, resampled 36 ppm to a whole number of AAC frames.
- **tense**: tense-1.mp3 at 112.0 BPM (grid fit 112.004), from 2.4249 s (bar 1 after the downbeat, at an upward zero crossing), **16 bars = 34.304 s**, resampled 534 ppm to a whole number of AAC frames.
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm/calm2 −16 / tense −15 / win −16 LUFS, then the look-ahead limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| circus-carnival/calm.m4a | 51.43 s (24 bars) | -16.1 | -3.5 | 634 KB |
| circus-carnival/calm2.m4a | 42.86 s (20 bars) | -16.0 | -2.4 | 528 KB |
| circus-carnival/tense.m4a | 34.30 s (16 bars) | -15.6 | -1.6 | 427 KB |
| circus-carnival/win.m4a | 15.00 s | -16.0 | -1.3 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot):

| loop | RMS jump last→first 200 ms | the source's own jump there | log-mel distance (source's own) |
|---|---|---|---|
| calm | +1.2 dB | +1.32 dB | 1.06 (0.965) |
| calm2 | +12.54 dB | +16.63 dB | 1.782 (1.99) |
| tense | -3.16 dB | -3.3 dB | 1.25 (1.246) |

Listen check: `processed/loop-test-calm-x3.m4a`, `processed/loop-test-calm2-x3.m4a`, `processed/loop-test-tense-x3.m4a` (each loop 3x), and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 51.43 s and 94.29 s; A→B RMS +2.57 dB, B→A +11.18 dB). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
