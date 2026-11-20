# Jungle adventure: the picks (2026-11-21, Claude's call by analysis)

Asked for: D major / D minor, 96 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-4** | Clearest D major (0.96; the others 0.82–0.85, calm-3 drifted to C major). Steady (RMS spread 1.07 dB), best chroma match to both the tense (0.934) and win (0.963) picks. |
| tense | **tense-1** | The clearest D minor (0.82) and the steadiest: spread 0.58 dB, no drift, beat grid residual 1.8 ms. tense-2 has a broken beat grid (186 ms), tense-4 swells 3.9 dB, tense-3 is weakly keyed (0.66). |
| win | **win-4** | Ends on a clean D major triad in root position (bass D, top D/A/F#). win-1 ends on A, win-3 on F, win-2 adds a C# (maj7). It is the quietest take (−21.6 LUFS) and opens with 0.6 s of silence: both fixed in processing (gain, lead trim). |

Chroma similarity of the trio: calm-4↔tense-1 0.934, calm-4↔win-4 0.963, tense-1↔win-4 0.975.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| calm-1 | -15.1 | 2.5 | -0.1 | 96.00 | 2.5 | D maj (0.82) | 0.82 | 1.79 | 1.2 | — |
| calm-2 | -11.6 | 4.0 | -0.2 | 95.99 | 2.9 | D maj (0.85) | 0.85 | 1.63 | 4.0 | — |
| calm-3 | -14.5 | 1.2 | -1.1 | 96.00 | 1.9 | C maj (0.90) | 0.2 | 0.51 | 1.1 | — |
| **calm-4** | -12.8 | 2.1 | -0.6 | 96.00 | 2.2 | D maj (0.96) | 0.96 | 1.07 | 2.3 | — |
| **tense-1** | -16.3 | 1.0 | -1.3 | 96.00 | 1.8 | D min (0.82) | 0.82 | 0.58 | 0.4 | — |
| tense-2 | -15.0 | 1.2 | -1.2 | 95.89 | 185.6 | D min (0.59) | 0.59 | 0.58 | 0.8 | — |
| tense-3 | -17.3 | 1.6 | -2.1 | 96.00 | 1.8 | D min (0.66) | 0.66 | 1.81 | -0.1 | — |
| tense-4 | -15.4 | 3.5 | -1.0 | 95.97 | 17.6 | D min (0.75) | 0.75 | 1.39 | 3.9 | — |
| win-1 | -16.1 | 7.2 | -0.6 | 95.98 | 2.3 | A maj (0.85) | 0.53 | — | — | bass A1, top A/E/Ab |
| win-2 | -11.6 | 10.9 | -0.3 | 96.02 | 2.1 | D maj (0.90) | 0.9 | — | — | bass D2, top D/C#/A |
| win-3 | -13.3 | 2.5 | -0.3 | 95.97 | 2.1 | F maj (0.77) | 0.05 | — | — | bass F2, top F/A/F# |
| **win-4** | -21.6 | 6.4 | -4.1 | 96.02 | 2.3 | D maj (0.89) | 0.89 | — | — | bass D3, top D/A/F# |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-4.mp3 at 96.0 BPM (grid fit 96.0), from 3.764 s (bar 1 after the downbeat, at an upward zero crossing), **16 bars = 40.000 s** (1,920,000 samples, already a whole number of AAC frames).
- **tense**: tense-1.mp3 at 96.0 BPM (grid fit 95.999), from 1.260 s (bar 0 after the downbeat, at an upward zero crossing), **16 bars = 40.000 s** (1,920,000 samples, already a whole number of AAC frames).
- **win**: the whole win-4.mp3 with 0.617 s of leading silence trimmed, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| jungle-outdoors/calm.m4a | 40.00 s (16 bars) | -16.0 | -2.7 | 492 KB |
| jungle-outdoors/tense.m4a | 40.00 s (16 bars) | -15.1 | -1.0 | 492 KB |
| jungle-outdoors/win.m4a | 14.38 s | -16.3 | -1.5 | 178 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | +4.0 dB | +7.9 dB | 0.44 dB (1.49) | 1.111 (0.966) |
| tense | +9.3 dB | +8.1 dB | 4.65 dB (3.79) | 1.149 (1.263) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 40.0 s and 80.0 s) and `processed/loop-test-tense-x3.m4a` (seams at 40.0 s and 80.0 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-4) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-1.** D major (0.92), the closest chroma to calm A (0.987), 96.0 BPM. calm2-2 swells 4.3 dB over the take.

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-4 (calm A) | -12.8 | 2.1 | 96.0 | 2.2 | D maj (0.96) | 0.96 | 1.11 | 1.6 | — |
| **calm2-1** | -13.9 | 2.5 | 95.996 | 1.9 | D maj (0.92) | 0.92 | 1.53 | 2.6 | 0.987 |
| calm2-2 | -14.1 | 4.2 | 95.996 | 2.8 | D maj (0.86) | 0.86 | 1.74 | 4.3 | 0.95 |

Processed: calm2-1.mp3 at 96.0 BPM (fit 95.996), from 1.8899 s, **20 bars = 50.01 s**, resampled 107 ppm to a whole number of AAC frames; `calm2.m4a` -16.0 LUFS, -1.6 dBTP, 613 KB. Seam (decoded loop): RMS jump -5.46 dB, mel 1.155 (the source's own bar line there: 0.46 dB, 0.805).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 40.0 s and 90.01 s; calm -16.0 / calm2 -16.0 LUFS; join A→B RMS -2.39 dB, mel 1.534; B→A +0.9 dB, mel 1.242). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.
