# Cozy shop: the picks (2026-11-21, Claude's call by analysis)

Asked for: G major / G minor, 104 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-4** | G major (0.87) with by far the steadiest level (spread 0.76 dB, drift 0.5) and the best match to win-1 (0.98). calm-2 leans D major, calm-3 crescendos 3.9 dB. |
| tense | **tense-2** | The only real G minor of the four (0.83); the others drifted to D or G major (tense-4 is steadier but major, 0.74, which loses the "uh-oh" colour). It fades out at the very end, so the loop stops well before that. |
| win | **win-1** | Ends on G major in root position (bass G, top G/B/D) after a steady, bright body. win-4 ends on G/B bass (first inversion), win-2/3 on a C# bass. Its beat grid wobbles (25 ms) but a one-shot needn't line up with a bar grid. |

Chroma similarity of the trio: calm-4↔tense-2 0.903, calm-4↔win-1 0.98, tense-2↔win-1 0.91.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| calm-1 | -14.6 | 1.7 | -0.4 | 104.00 | 6.1 | G maj (0.85) | 0.85 | 1.3 | 2.3 | — |
| calm-2 | -14.2 | 1.8 | -0.1 | 104.00 | 3.6 | D maj (0.80) | 0.79 | 1.2 | -0.6 | — |
| calm-3 | -12.4 | 2.8 | -0.1 | 103.99 | 4.3 | G maj (0.88) | 0.88 | 1.76 | 3.9 | — |
| **calm-4** | -12.9 | 2.0 | -0.3 | 104.00 | 4.0 | G maj (0.87) | 0.87 | 0.76 | 0.5 | — |
| tense-1 | -18.0 | 1.5 | -1.3 | 104.00 | 1.8 | D maj (0.76) | 0.57 | 2.17 | 0.2 | — |
| **tense-2** | -15.1 | 2.4 | -1.2 | 104.00 | 1.9 | G min (0.83) | 0.83 | 1.2 | 2.3 | — |
| tense-3 | -19.3 | 1.9 | -3.2 | 104.00 | 2.3 | D maj (0.80) | 0.55 | 1.37 | 0.2 | — |
| tense-4 | -14.4 | 0.9 | -0.2 | 104.00 | 1.8 | G maj (0.74) | 0.6 | 0.63 | -0.8 | — |
| **win-1** | -13.9 | 2.1 | -1.1 | 104.55 | 25.1 | G maj (0.84) | 0.84 | — | — | bass G2, top G/B/D |
| win-2 | -14.7 | 10.4 | -1.1 | 104.00 | 1.6 | G maj (0.73) | 0.73 | — | — | bass C♯2, top G/D/C |
| win-3 | -13.4 | 1.8 | -0.9 | 106.98 | 68.9 | G maj (0.86) | 0.86 | — | — | bass C♯2, top G/D/C# |
| win-4 | -15.3 | 6.6 | -1.4 | 103.99 | 2.6 | G maj (0.80) | 0.8 | — | — | bass B1, top G/B/D |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-4.mp3 at 104.0 BPM (grid fit 103.997), from 6.944 s (bar 3 after the downbeat, at an upward zero crossing), **16 bars = 36.928 s**, resampled 133 ppm (1,772,308 → 1,772,544 samples) to a whole number of AAC frames.
- **tense**: tense-2.mp3 at 104.0 BPM (grid fit 103.999), from 3.475 s (bar 1 after the downbeat, at an upward zero crossing), **16 bars = 36.928 s**, resampled 133 ppm (1,772,308 → 1,772,544 samples) to a whole number of AAC frames.
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| cozy-shop/calm.m4a | 36.93 s (16 bars) | -16.0 | -2.9 | 452 KB |
| cozy-shop/tense.m4a | 36.93 s (16 bars) | -15.0 | -1.2 | 452 KB |
| cozy-shop/win.m4a | 15.00 s | -16.1 | -3.0 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | +5.1 dB | +7.6 dB | 3.16 dB (2.95) | 0.841 (0.9) |
| tense | +6.9 dB | +5.6 dB | 0.28 dB (1.85) | 0.835 (0.703) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 36.9 s and 73.9 s) and `processed/loop-test-tense-x3.m4a` (seams at 36.9 s and 73.9 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
