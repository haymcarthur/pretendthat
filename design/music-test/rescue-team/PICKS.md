# Rescue team: the picks (2026-11-21, Claude's call by analysis)

2 takes per segment (flow `YimWW6V0WHSIw52SZGRm`, prompts in [PROMPTS.md](PROMPTS.md)). Paired by measurement
(ffmpeg ebur128, CQT chroma + Krumhansl keys, comb beat-grid fit, harmonic-change downbeats), as for space adventure.
Script: `tools/process_music_more.py`. No extra AI calls.

The cleanest family of the three: every take is in **G** (major / minor as asked) at exactly **108.0 BPM** 4/4 (comb
fit 107.99–108.00), with clear downbeats (harmonic change on beat 1: 1.0 vs ≤ 0.4), and the six takes are all close
in chroma (0.96–0.99).

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | Clearer G major (0.71 vs 0.63), closest to win-1 (chroma 0.986 vs 0.959) and the best loop seams (mel 0.34 vs calm-2's best 0.54). calm-2 is steadier (RMS spread 0.49 dB, LRA 0.8) but loops worse. |
| tense | **tense-2** | Clearer G minor (0.66 vs 0.51), closest to win-1 (0.982), best seam (0.38 vs tense-1's 0.44). Both are equally steady (0.50 / 0.52 dB). |
| win | **win-1** | Ends on a G chord (G1 in the bass, B3, G4), then rings out to −86 dB. win-2 ends on D (D, A, C#): the dominant, not home. |

## Measurements of every take

| take | length | LUFS | LRA | peak dBFS | key (corr.) | RMS spread dB | drift dB |
|---|---|---|---|---|---|---|---|
| **calm-1** | 60 s | −12.6 | 2.1 | −0.4 | G maj (0.71) | 0.96 | +0.2 |
| calm-2 | 60 s | −11.9 | 0.8 | +0.1 | G maj (0.63) | 0.49 | +0.2 |
| tense-1 | 45 s | −12.4 | 0.7 | −0.5 | G min (0.51) | 0.52 | +0.2 |
| **tense-2** | 45 s | −12.1 | 1.0 | −0.1 | G min (0.66) | 0.50 | +0.8 |
| **win-1** | 15 s | −14.0 | 4.1 | −0.5 | G maj (0.69), ends on G | — | — |
| win-2 | 15 s | −12.7 | 2.8 | −0.2 | G maj (0.82), ends on D | — | — |

Chroma similarity: calm-1↔tense-2 0.978, calm-1↔win-1 0.986, tense-2↔win-1 0.982.

## Processing (`python3 tools/process_music_more.py process rescue-team`)

- **calm**: calm-1 from 6.682 s (beat 12, a downbeat), **16 bars = 35.56 s**. **tense**: tense-2 from 15.577 s
  (beat 28), **12 bars = 26.67 s**. Chosen from every downbeat start × 4-bar-phrase length by the head/after-end
  match (log-mel + RMS), stopping before any fade.
- Same method as space, plus a circular FFT resample to whole AAC frames (−0.009 % / +0.004 % speed: inaudible);
  the decoded .m4a is exactly the loop (checked). **win**: whole take, 3 ms fade-in, 20 ms fade-out.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| rescue-team/calm.m4a | 35.56 s (16 bars) | −15.9 | −1.9 | 440 KB |
| rescue-team/tense.m4a | 26.67 s (12 bars) | −15.0 | −1.8 | 328 KB |
| rescue-team/win.m4a | 15.0 s | −15.8 | −1.2 | 187 KB |

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step | HF (>8 kHz) first 10 ms vs other bar starts |
|---|---|---|---|---|
| calm | +3.9 dB | +3.2 dB | 2.2 dB | −42.8 dB vs median −41.7 (range −44.2…−37.8) |
| tense | +1.4 dB | +2.4 dB | 2.1 dB | −40.9 dB vs median −38.5 (range −40.5…−36.5) |

The seams look like ordinary bar lines (no HF spike, level jumps within ~0.7 dB of the music's own). Listen:
`processed/loop-test-calm-x3.m4a` (seams 0:35.6, 1:11.1), `processed/loop-test-tense-x3.m4a` (0:26.7, 0:53.3).

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-1) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-1.** G major (0.93), the closest chroma to calm A (0.994) and very steady (LRA 0.5, spread 0.54 dB).

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-1 (calm A) | -12.6 | 2.1 | 107.998 | 1.9 | G maj (0.71) | 0.71 | 0.95 | 0.0 | — |
| **calm2-1** | -13.0 | 0.5 | 108.0 | 2.0 | G maj (0.93) | 0.93 | 0.54 | -0.3 | 0.994 |
| calm2-2 | -12.9 | 1.3 | 107.994 | 2.4 | G maj (0.72) | 0.72 | 0.69 | 0.2 | 0.979 |

Processed: calm2-1.mp3 at 108.0 BPM (fit 108.0), from 8.3429 s, **20 bars = 44.46 s**, resampled 320 ppm to a whole number of AAC frames; `calm2.m4a` -16.0 LUFS, -1.1 dBTP, 549 KB. Seam (decoded loop): RMS jump 4.28 dB, mel 0.603 (the source's own bar line there: 6.83 dB, 0.692).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 35.56 s and 80.02 s; calm -15.9 / calm2 -16.0 LUFS; join A→B RMS +2.36 dB, mel 0.933; B→A +5.77 dB, mel 1.569). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.
