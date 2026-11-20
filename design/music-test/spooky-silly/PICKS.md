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

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-2) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-1.** E minor (0.90), the closest chroma to calm A (0.991), 108.0 BPM. calm2-2 drifted to B major.

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-2 (calm A) | -16.8 | 2.1 | 107.996 | 1.8 | E min (0.85) | 0.85 | 1.15 | 0.9 | — |
| **calm2-1** | -17.6 | 3.0 | 108.009 | 4.8 | E min (0.90) | 0.90 | 1.29 | 2.0 | 0.991 |
| calm2-2 | -15.5 | 1.3 | 107.999 | 1.8 | B maj (0.76) | 0.53 | 0.83 | -0.8 | 0.92 |

Processed: calm2-1.mp3 at 108.0 BPM (fit 108.009), from 2.2406 s, **20 bars = 44.46 s**, resampled 320 ppm to a whole number of AAC frames; `calm2.m4a` -16.0 LUFS, -1.3 dBTP, 548 KB. Seam (decoded loop): RMS jump 4.01 dB, mel 1.69 (the source's own bar line there: 4.07 dB, 1.771).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 44.46 s and 88.92 s; calm -16.3 / calm2 -16.0 LUFS; join A→B RMS +7.46 dB, mel 1.68; B→A +9.82 dB, mel 1.861). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.
