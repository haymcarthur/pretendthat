# Under the sea: the picks (2026-11-21, Claude's call by analysis)

Asked for: A major / A minor, 92 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-4** | **None of the four calm takes came out in A major** (D major, D minor, Ab major, C major). So the pick is the most coherent trio instead: calm-4 is a clear C major (0.88) with a level that holds (spread 1.64, drift −1.5 dB). calm-2 (D major) crescendos 5.4 dB, calm-3 is in Ab. |
| tense | **tense-3** | C minor (0.80): the parallel minor of calm-4, which is exactly the recipe, just in C rather than A. The steadiest of the four (spread 0.37 dB, LRA 1.0) and the best match to calm-4 (0.924). tense-1 is a clean A minor but matches calm-4 less and no calm take is in A. |
| win | **win-2** | C major ending on a clean C major triad (top C/G/E), matching calm-4 (0.926). win-4 also ends in C but on a B (Cmaj7). win-2 is quiet (−20.4 LUFS), lifted in processing. |

Chroma similarity of the trio: calm-4↔tense-3 0.924, calm-4↔win-2 0.926, tense-3↔win-2 0.895.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| calm-1 | -14.6 | 2.1 | -0.5 | 92.00 | 4.9 | D min (0.65) | 0.15 | 1.32 | 1.5 | — |
| calm-2 | -13.6 | 4.4 | -1.0 | 92.00 | 2.5 | D maj (0.90) | 0.66 | 2.29 | 5.4 | — |
| calm-3 | -14.9 | 2.8 | -1.2 | 91.99 | 3.7 | Ab maj (0.82) | -0.32 | 2.18 | 4.8 | — |
| **calm-4** | -14.0 | 1.6 | -0.8 | 92.00 | 2.0 | C maj (0.88) | -0.18 | 1.64 | -1.5 | — |
| tense-1 | -13.7 | 2.5 | -0.3 | 92.00 | 1.9 | A min (0.88) | 0.88 | 1.01 | 0.6 | — |
| tense-2 | -13.4 | 3.5 | -0.5 | 92.00 | 2.1 | A min (0.77) | 0.77 | 1.3 | 3.0 | — |
| **tense-3** | -12.6 | 1.0 | -0.0 | 92.00 | 1.8 | C min (0.80) | 0.37 | 0.37 | 0.3 | — |
| tense-4 | -12.5 | 3.3 | -0.2 | 92.00 | 2.0 | A min (0.75) | 0.75 | 1.68 | 3.9 | — |
| win-1 | -15.3 | 6.2 | -2.6 | 91.99 | 1.9 | D maj (0.89) | 0.56 | — | — | bass D3, top D/A/F# |
| **win-2** | -20.4 | 4.7 | -4.7 | 91.99 | 1.9 | C maj (0.91) | -0.26 | — | — | bass C4, top C/G/E |
| win-3 | -13.0 | 4.8 | -0.9 | 92.04 | 1.9 | C# maj (0.90) | -0.02 | — | — | bass C♯4, top C#/Ab/F |
| win-4 | -15.1 | 5.0 | -0.5 | 91.89 | 4.2 | C maj (0.87) | -0.18 | — | — | bass C2, top C/G/B |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-4.mp3 at 92.0 BPM (grid fit 91.995), from 1.315 s (bar 0 after the downbeat, at an upward zero crossing), **16 bars = 41.749 s**, resampled 245 ppm (2,003,478 → 2,003,968 samples) to a whole number of AAC frames.
- **tense**: tense-3.mp3 at 92.0 BPM (grid fit 91.998), from 0.010 s (bar 0 after the downbeat, at an upward zero crossing), **16 bars = 41.749 s**, resampled 245 ppm (2,003,478 → 2,003,968 samples) to a whole number of AAC frames.
- **win**: the whole win-2.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| under-the-sea/calm.m4a | 41.75 s (16 bars) | -16.0 | -2.9 | 514 KB |
| under-the-sea/tense.m4a | 41.75 s (16 bars) | -15.0 | -2.1 | 514 KB |
| under-the-sea/win.m4a | 15.00 s | -16.1 | -1.5 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | +7.2 dB | +9.0 dB | 2.93 dB (2.81) | 1.279 (1.382) |
| tense | +3.5 dB | +5.7 dB | 1.96 dB (4.44) | 0.753 (0.752) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 41.7 s and 83.5 s) and `processed/loop-test-tense-x3.m4a` (seams at 41.7 s and 83.5 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
