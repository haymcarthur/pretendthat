# Magic kingdom: the picks (2026-11-21, Claude's call by analysis)

Asked for: F major / F minor, 90 BPM. Nobody can listen in the agent sandbox, so the trio is chosen by measurement with the space-adventure
method (design/music-test/space-adventure/PICKS.md): ffmpeg ebur128, librosa 1.0 beat tracking + a least-squares beat grid,
CQT chroma with Krumhansl key profiles, chroma cosine similarity between takes. No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-2** | Clearest F major (0.97), flattest level (drift 0.1 dB, spread 1.12). calm-1 ends in a long fade, calm-3 leans D minor. |
| tense | **tense-2** | F minor (0.85) with the steadier level (spread 1.09 dB vs 1.51 for tense-3) and the best chroma match to calm-2 (0.896). tense-1 sits in C minor, tense-4 in B minor. |
| win | **win-1** | The only take in F: it ends on the F major chord (top C/F/A). win-2 and win-4 are in C major and end on C, win-3 is in D major. It is soft (−26.3 LUFS, a gentle celesta-and-harp finale rather than a big fanfare); processing lifts it to −16 LUFS. **Listen check:** if it feels too gentle, win-2 (C major, bigger) is the fallback. |

Chroma similarity of the trio: calm-2↔tense-2 0.896, calm-2↔win-1 0.947, tense-2↔win-1 0.932.

## Measurements of every take

Key = best Krumhansl match (correlation). "Asked key" = correlation with the key the prompt asked for (calm: the asked major, or
E minor for spooky; tense: its parallel minor; win: the major). Spread = std of per-second RMS over the body; drift = level
change start→end of the body; grid = beat-grid residual (a big number means the beat wanders).

| take | LUFS | LRA | TP dBTP | BPM (fit) | grid ms | key | asked key | spread dB | drift dB | ends on (win) |
|---|---|---|---|---|---|---|---|---|---|---|
| calm-1 | -13.0 | 4.5 | -0.6 | 90.00 | 4.0 | F maj (0.93) | 0.93 | 1.86 | 3.4 | — |
| **calm-2** | -13.6 | 1.7 | -1.4 | 90.00 | 3.5 | F maj (0.97) | 0.97 | 1.12 | 0.1 | — |
| calm-3 | -14.6 | 2.4 | -1.1 | 90.00 | 0.0 | D min (0.97) | 0.74 | 1.12 | 1.9 | — |
| calm-4 | -12.1 | 2.1 | -0.7 | 90.00 | 2.7 | F maj (0.90) | 0.9 | 0.9 | 1.5 | — |
| tense-1 | -18.0 | 2.1 | -1.1 | 89.99 | 2.3 | C min (0.70) | 0.49 | 1.21 | 1.1 | — |
| **tense-2** | -17.2 | 1.8 | -1.7 | 90.01 | 2.5 | F min (0.85) | 0.85 | 1.09 | 1.6 | — |
| tense-3 | -18.3 | 2.3 | -2.8 | 89.99 | 2.2 | F min (0.88) | 0.88 | 1.51 | 0.4 | — |
| tense-4 | -14.6 | 3.0 | -1.2 | 90.00 | 2.0 | B min (0.72) | -0.46 | 1.16 | 2.2 | — |
| **win-1** | -26.3 | 5.3 | -9.5 | 90.08 | 2.4 | F maj (0.84) | 0.84 | — | — | bass C4, top C/F/A |
| win-2 | -11.8 | 2.8 | -1.0 | 90.05 | 3.0 | C maj (0.87) | 0.45 | — | — | bass C2, top C/G/B |
| win-3 | -12.9 | 5.8 | -0.1 | 89.97 | 4.0 | D maj (0.92) | -0.16 | — | — | bass A2, top D/A/C# |
| win-4 | -13.7 | 4.1 | -1.2 | 89.97 | 3.8 | C maj (0.89) | 0.42 | — | — | bass C2, top C/G/E |

## Processing (tools/process_music_families.py, reproducible)

- **calm**: calm-2.mp3 at 90.0 BPM (grid fit 89.999), from 4.016 s (bar 1 after the downbeat, at an upward zero crossing), **16 bars = 42.667 s** (2,048,000 samples, already a whole number of AAC frames).
- **tense**: tense-2.mp3 at 90.0 BPM (grid fit 90.008), from 2.018 s (bar 0 after the downbeat, at an upward zero crossing), **12 bars = 32.000 s** (1,536,000 samples, already a whole number of AAC frames).
- **win**: the whole win-1.mp3, 3 ms fade-in, 20 ms fade-out.
- Loops: the 30 ms past the loop end equal-power crossfaded into the head; static gain to calm −16 / tense −15 / win −16 LUFS, then the look-ahead
  limiter (circular for loops) until the decoded file's true peak is ≤ −1 dBTP; AAC-LC 96 kbps 48 kHz with an MP4 edit list (as for space).

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| magical/calm.m4a | 42.67 s (16 bars) | -16.1 | -4.0 | 522 KB |
| magical/tense.m4a | 32.00 s (12 bars) | -15.1 | -1.3 | 391 KB |
| magical/win.m4a | 15.00 s | -16.2 | -1.2 | 185 KB |

**Seams** (decoded loop vs the music's own bar line at the same spot; a seam that looks like the source's bar line is a clean loop):

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam (raw cut) | log-mel distance (source's own) |
|---|---|---|---|---|
| calm | +4.5 dB | +7.2 dB | 2.2 dB (3.92) | 1.126 (1.002) |
| tense | +5.5 dB | +3.4 dB | 0.72 dB (1.79) | 0.768 (1.037) |

Listen check: `processed/loop-test-calm-x3.m4a` (seams at 42.7 s and 85.3 s) and `processed/loop-test-tense-x3.m4a` (seams at 32.0 s and 64.0 s). Full numbers: `processed/measurements.json`. Prompts: PROMPTS.md.

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-2) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-1.** **The only take** (the second generation failed on ElevenLabs' side and was not re-run). It is 90.0 BPM with the same instruments, but it centres on **C major** (0.96), the dominant of calm A's F major (chroma vs A 0.895), so it may sound like a lift to a new key when it follows calm A. **Needs Haylee's ear;** if it jars, delete `magical/calm2.m4a` and the app keeps looping calm A.

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-2 (calm A) | -13.6 | 1.7 | 89.999 | 3.5 | F maj (0.97) | 0.97 | 1.39 | -0.2 | — |
| **calm2-1** | -13.5 | 2.5 | 90.002 | 1.4 | C maj (0.96) | 0.69 | 1.4 | 1.8 | 0.895 |

Processed: calm2-1.mp3 at 90.0 BPM (fit 90.002), from 6.6833 s, **16 bars = 42.67 s**; `calm2.m4a` -16.0 LUFS, -3.7 dBTP, 524 KB. Seam (decoded loop): RMS jump 2.01 dB, mel 1.366 (the source's own bar line there: 7.22 dB, 1.265).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 42.67 s and 85.33 s; calm -16.1 / calm2 -16.0 LUFS; join A→B RMS +2.39 dB, mel 1.839; B→A +4.16 dB, mel 1.418). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.

## Win redo (2026-11-20, Claude's call by analysis): **replaced** with win-redo-1

The old win-1 was the only take in F but soft (−26.3 LUFS raw, a gentle celesta-and-harp finale). Two new takes (flow `0E0ZhST9V8YYLYwyDEyQ`, 225 credits each), prompted brighter and stronger in F major at 90 BPM, "ending on one clear, final F major chord that rings out" (PROMPTS.md).

| take | LUFS | LRA | TP | key (corr.) | per-second level, last 7 s (dB vs loudest) | sounding at the end |
|---|---|---|---|---|---|---|
| win-1 (old) | −26.3 | 5.3 | −9.5 | C maj / F maj (0.85 / 0.83) | — (fades from ~12 s: −7, −13, −28) | F3 C4 F4 C5 F5 C6 F6 (no A until the last second) |
| **win-redo-1** | −12.0 | 14.3 | −0.2 | **F maj (0.85)** | −10, −12, −15, −25, −36, −47, −65 | **F major**: F3 C4 F4 C5 F5 A5 C6 F6 A6; F major 0.81–0.88 from 6 s to 14 s |
| win-redo-2 | −12.5 | 5.1 | −1.3 | F maj (0.84) | −1, −1, −5, −24, −52 (and a dip to −16 dB at 6–8 s) | F major with a strong E (Fmaj7 colour) all through |

**Pick: win-redo-1.** Strong (−12 LUFS raw, 14 dB louder than the old take), clearly in F, with a full F major chord (F, A, C) at ~8 s and a long, smooth natural ring-out to −65 dB. win-redo-2 is louder for longer but sits on F major 7 (a bright but unresolved colour), has a mid-take break and fades faster. It opens with a ~2 s cymbal-and-strings swell out of silence (0.46 s of silence trimmed). Processed with the same method (`python3 tools/process_music_calm2.py win magical win-redo-1`): `win.m4a` −15.9 LUFS, −2.6 dBTP, 14.54 s, 181 KB. **Listen check:** the swell means the fanfare proper starts ~2 s in.
