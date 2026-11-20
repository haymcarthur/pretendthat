# Wild west: the picks (2026-11-21, Claude's call by analysis)

Asked for: E major / E minor, 100 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | E major (0.83) with the steadiest level of the four (spread 0.59 dB, LRA 1.2) and a tight beat grid (3.4 ms). calm-2 is a stronger E major (0.92) but its beats wander (15.5 ms), which matters for a loop; calm-3 is in D. |
| tense | **tense-1** | E minor (0.77), and the only steady one: spread 0.55 dB, LRA 0.9, grid 2.0 ms. tense-2/3 swing over 2 dB and fade out, tense-4 drifts 4.5 dB and leans D major. |
| win | **win-1** | Every win ends on E major. win-1 ends on a root-position triad (bass E2, top E/B/G#) after a big hit at ~10.5 s with a ~4 s ring-out. win-4 adds a D# (maj7), win-3 is flatter and quieter (LRA 2.9). |

Chroma similarity of the trio: calm-1↔tense-1 0.943, calm-1↔win-1 0.914, tense-1↔win-1 0.921.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| **calm-1** | -13.9 | 1.2 | -0.4 | 100.00 | 3.4 | E maj (0.83) | 0.83 | 0.59 | 0.9 | — |
| calm-2 | -14.2 | 2.5 | -1.0 | 100.01 | 15.5 | E maj (0.92) | 0.92 | 1.28 | -0.9 | — |
| calm-3 | -13.0 | 2.5 | -0.2 | 99.99 | 4.2 | D maj (0.82) | 0.01 | 1.32 | 1.8 | — |
| calm-4 | -13.7 | 2.5 | -0.9 | 100.00 | 4.3 | C# min (0.77) | 0.69 | 1.04 | 2.0 | — |
| **tense-1** | -13.7 | 0.9 | -1.2 | 100.00 | 2.0 | E min (0.77) | 0.77 | 0.55 | -0.1 | — |
| tense-2 | -16.3 | 3.0 | -1.5 | 100.00 | 3.6 | E min (0.75) | 0.75 | 2.33 | -0.7 | — |
| tense-3 | -16.0 | 1.8 | -2.2 | 100.00 | 4.0 | E min (0.76) | 0.76 | 2.12 | -1.9 | — |
| tense-4 | -15.0 | 2.7 | -0.5 | 100.00 | 3.2 | D maj (0.83) | 0.41 | 2.09 | -4.5 | — |
| **win-1** | -13.2 | 14.9 | -1.5 | 100.03 | 1.7 | E maj (0.85) | 0.85 | — | — | bass E2, top E/B/Ab |
| win-2 | -12.9 | 12.9 | -0.6 | 99.94 | 3.7 | E maj (0.78) | 0.78 | — | — | bass E2, top E/B/Ab |
| win-3 | -18.7 | 2.9 | -3.2 | 99.92 | 5.5 | E maj (0.88) | 0.88 | — | — | bass E3, top E/B/Ab |
| win-4 | -16.2 | 14.0 | -1.3 | 99.89 | 5.1 | E maj (0.81) | 0.81 | — | — | bass E2, top E/B/Eb |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-1.mp3 at 100.0 BPM (grid fit 99.996), from 8.717 s (bar 3 after the downbeat, at an upward zero crossing), **20 bars = 48.000 s** (2,304,000 samples, already a whole number of AAC frames).
- **tense**: tense-1.mp3 at 100.0 BPM (grid fit 99.998), from 8.411 s (bar 3 after the downbeat, at an upward zero crossing), **12 bars = 28.800 s** (1,382,400 samples, already a whole number of AAC frames).
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| desert-western/calm.m4a | 48.00 s (20 bars) | -16.0 | -2.8 | 588 KB |
| desert-western/tense.m4a | 28.80 s (12 bars) | -15.1 | -2.3 | 353 KB |
| desert-western/win.m4a | 15.00 s | -16.0 | -3.9 | 186 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | -6.6 dB | -4.1 dB | 1.09 dB (0.59) | 1.216 (1.009) |
| tense | +9.9 dB | +12.2 dB | 2.97 dB (5.34) | 1.249 (1.1) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 48.0 s and 96.0 s) and `processed/loop-test-tense-x3.m4a` (seams at 28.8 s and 57.6 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-1) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-2.** E major (0.80) like calm A, chroma 0.96, the tightest beat grid (1.4 ms). calm2-1 leans B major (the dominant).

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-1 (calm A) | -13.9 | 1.2 | 99.996 | 3.4 | E maj (0.84) | 0.84 | 0.84 | 0.8 | — |
| calm2-1 | -13.4 | 1.3 | 99.999 | 4.8 | B maj (0.74) | 0.58 | 0.96 | -0.9 | 0.93 |
| **calm2-2** | -13.4 | 1.3 | 100.0 | 1.4 | E maj (0.80) | 0.80 | 1.03 | -0.8 | 0.96 |

Processed: calm2-2.mp3 at 100.0 BPM (fit 100.0), from 4.8137 s, **20 bars = 48.00 s**; `calm2.m4a` -16.0 LUFS, -3.0 dBTP, 588 KB. Seam (decoded loop): RMS jump 9.13 dB, mel 1.183 (the source's own bar line there: 12.76 dB, 0.961).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 48.0 s and 96.0 s; calm -16.0 / calm2 -16.0 LUFS; join A→B RMS +0.21 dB, mel 1.186; B→A +2.3 dB, mel 0.847). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.
