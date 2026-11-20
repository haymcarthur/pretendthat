# Silly spooky: the picks (2026-11-21, Claude's call by analysis)

Asked for: E minor (calm and tense), E major win, 108 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-2** | The clearest E minor (0.86; calm-1 and calm-3 lean E major, calm-4 is in C minor), steady (spread 0.85 dB), and the closest match to tense-4 (0.961). |
| tense | **tense-4** | The clearest E minor of the tense takes (0.74) and the steadiest: spread 0.57 dB, grid residual 1.6 ms. tense-3 has a broken beat grid (137 ms), tense-2 is major/minor-ambiguous. |
| win | **win-4** | E major (0.88) ending on a clean root-position E major triad (bass E, top E/G#/B). win-1 adds an F on top, win-2/3 end on a B bass. Opens with 0.53 s of silence (trimmed). |

Chroma similarity of the trio: calm-2↔tense-4 0.961, calm-2↔win-4 0.952, tense-4↔win-4 0.942.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| calm-1 | -13.4 | 1.6 | 0.4 | 107.99 | 3.1 | E maj (0.80) | 0.69 | 1.47 | 0.1 | — |
| **calm-2** | -16.8 | 2.1 | -0.6 | 108.00 | 1.8 | E min (0.86) | 0.86 | 0.85 | 1.4 | — |
| calm-3 | -13.4 | 0.7 | -0.4 | 108.00 | 3.2 | E maj (0.56) | 0.55 | 0.59 | -0.1 | — |
| calm-4 | -17.3 | 1.8 | -0.9 | 107.99 | 2.8 | C min (0.77) | 0.18 | 0.9 | 0.3 | — |
| tense-1 | -14.4 | 1.9 | -0.3 | 108.00 | 1.9 | E min (0.56) | 0.56 | 1.03 | 2.6 | — |
| tense-2 | -17.2 | 1.5 | -0.8 | 108.03 | 3.4 | E maj (0.63) | 0.63 | 0.88 | -0.5 | — |
| tense-3 | -16.0 | 1.1 | -1.2 | 107.17 | 136.5 | E min (0.70) | 0.7 | 0.65 | -0.9 | — |
| **tense-4** | -15.2 | 1.2 | -1.2 | 108.00 | 1.6 | E min (0.74) | 0.74 | 0.57 | -0.4 | — |
| win-1 | -13.0 | 2.5 | -0.3 | 108.00 | 2.7 | E maj (0.86) | 0.86 | — | — | bass E2, top E/B/F |
| win-2 | -15.8 | 4.4 | -1.3 | 107.98 | 1.6 | B maj (0.87) | 0.72 | — | — | bass B2, top B/E/Eb |
| win-3 | -18.7 | 4.0 | -2.4 | 107.99 | 5.2 | E maj (0.88) | 0.88 | — | — | bass B2, top B/E/Ab |
| **win-4** | -15.0 | 2.8 | -1.4 | 107.97 | 2.6 | E maj (0.88) | 0.88 | — | — | bass E2, top E/Ab/B |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-2.mp3 at 108.0 BPM (grid fit 107.996), from 2.237 s (bar 1 after the downbeat, at an upward zero crossing), **20 bars = 44.459 s**, resampled 320 ppm (2,133,333 → 2,134,016 samples) to a whole number of AAC frames.
- **tense**: tense-4.mp3 at 108.0 BPM (grid fit 107.997), from 4.183 s (bar 1 after the downbeat, at an upward zero crossing), **16 bars = 35.563 s**, resampled 200 ppm (1,706,667 → 1,707,008 samples) to a whole number of AAC frames.
- **win**: the whole win-4.mp3 with 0.529 s of leading silence trimmed, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| spooky-silly/calm.m4a | 44.46 s (20 bars) | -16.3 | -1.3 | 550 KB |
| spooky-silly/tense.m4a | 35.56 s (16 bars) | -15.0 | -1.5 | 436 KB |
| spooky-silly/win.m4a | 14.47 s | -16.1 | -2.2 | 179 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | +13.3 dB | +12.4 dB | 4.49 dB (2.84) | 1.169 (1.201) |
| tense | -1.2 dB | +0.2 dB | 0.67 dB (2.8) | 1.101 (0.908) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 44.5 s and 88.9 s) and `processed/loop-test-tense-x3.m4a` (seams at 35.6 s and 71.1 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.
