# Superhero city: the picks (2026-11-21, Claude's call by analysis)

2 takes per segment (flow `nA4iFu6YdytPTl9Xbduj`, prompts in [PROMPTS.md](PROMPTS.md)). Nobody can listen in the
agent sandbox, so the pairing is by measurement (ffmpeg ebur128, librosa CQT chroma + Krumhansl key profiles, a comb
beat-grid fit, harmonic-change downbeats), as for space adventure. Script: `tools/process_music_more.py`. No extra AI calls.

**Note:** the model ignored "B-flat". Every take came out centred on **C** (calm C major, tense D minor / C minor, win
on C), so the family is in C, the same as space adventure. All takes are exactly **112.0 BPM** 4/4 (comb fit
111.99–112.00).

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | Clearest downbeats of the two (harmonic change on beat 1: 1.0 vs 0.07–0.12 on the others), steady level (RMS spread 0.88 dB, drift +0.8 dB), and the best chroma match to both tense (0.895) and win-1 (0.971). Best loop seam: mel distance 0.36 (calm-2's best is 0.58). calm-2 is a clearer C major (0.80 vs 0.59) but climbs +2 dB over its last 20 s. |
| tense | **tense-1** | D minor (0.82): the same notes as C major (its ii chord), so the switch from calm is smooth. Steady across the whole take (drift +0.8 dB), so it gives a 16-bar loop (34.3 s, seam score 0.34). tense-2 is the closer C minor (chroma 0.978 to calm-1) but drops 3 dB halfway with a near-break at 26 s, leaving only an 8-bar (17 s) loop: too repetitive for a tense stretch. |
| win | **win-1** | The only take that ends: the last chord is C/G (C4 G4 C5 G5, bass on C), then a clean ring-out to −57 dB by 14.5 s. win-2 is in A major and is still at full level when the file stops (a cut, not an ending). |

## Measurements of every take

| take | length | LUFS | LRA | peak dBFS | key (corr.) | RMS spread dB | drift dB |
|---|---|---|---|---|---|---|---|
| **calm-1** | 60 s | −10.9 | 2.2 | −0.2 | C maj (0.59) | 0.88 | +0.8 |
| calm-2 | 60 s | −16.3 | 2.7 | −2.9 | C maj (0.80) | 0.95 | +2.1 |
| **tense-1** | 45 s | −14.3 | 1.7 | −0.8 | D min (0.82) | 1.19 | +0.8 |
| tense-2 | 45 s | −14.1 | 2.3 | −0.9 | C min (0.65) | 1.52 | −3.0 (break at 26 s) |
| **win-1** | 15 s | −13.2 | 1.4 | −0.4 | C min/maj (0.81/0.77), ends C/G | — | — |
| win-2 | 15 s | −12.3 | 1.6 | 0.0 | A maj (0.84), no ending | — | — |

Chroma similarity: calm-1↔tense-1 0.895, calm-1↔win-1 0.971, tense-1↔win-1 0.923 (calm-1↔tense-2 0.978,
calm-2↔tense-1 0.758).

## Processing (`python3 tools/process_music_more.py process superhero-city`)

- **calm**: calm-1 from 15.040 s (beat 28, a downbeat), **20 bars = 42.86 s**. **tense**: tense-1 from 6.468 s
  (beat 12), **16 bars = 34.28 s**. Both chosen from every downbeat start × 4-bar-phrase length by the closest match
  between the 250 ms after the loop end and the loop head (log-mel + RMS), stopping before any fade.
- Same method as space (30 ms equal-power seam crossfade, static gain, circular look-ahead limiter, AAC-LC 96 kbps
  48 kHz with an edit list), plus one step: 112 BPM bars are not whole AAC frames, so each loop is resampled
  circularly (FFT) to the nearest whole 1024-sample frame count (calm −0.005 %, tense +0.009 % speed: inaudible).
  The decoded .m4a is exactly the loop (checked).
- **win**: the whole take, 3 ms fade-in, 20 ms fade-out.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| superhero-city/calm.m4a | 42.86 s (20 bars) | −16.0 | −5.2 | 525 KB |
| superhero-city/tense.m4a | 34.28 s (16 bars) | −15.1 | −1.7 | 420 KB |
| superhero-city/win.m4a | 15.0 s | −15.9 | −2.8 | 187 KB |

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step | HF (>8 kHz) first 10 ms vs other bar starts |
|---|---|---|---|---|
| calm | +2.5 dB | +2.3 dB | 0.55 dB | −43.0 dB vs median −42.1 (range −43.9…−38.9) |
| tense | +4.3 dB | +3.7 dB | 1.2 dB | −45.8 dB vs median −44.7 (range −47.9…−37.5) |

The seams look like ordinary bar lines. Listen: `processed/loop-test-calm-x3.m4a` (seams 0:42.9, 1:25.7),
`processed/loop-test-tense-x3.m4a` (0:34.3, 1:08.6). Full numbers: `processed/measurements.json`.

## Calm B loop (calm2, 2026-11-20, Claude's call by analysis)

A second calm loop that the app alternates with calm A (calm-1) so a 10-minute scene repeats less. Prompted in calm A's measured key and tempo with the same instruments ("a second, gentle variation of the same theme... a different melody and arrangement"); flow `dSxe4hBC3cnsB5nMN5GN`, 2 takes, 900 credits each. Prompt: PROMPTS.md. Script: `tools/process_music_calm2.py`.

**Pick: calm2-1.** Both takes are C major. calm2-1 is the closest chroma to calm A (0.996: the same loose C major as A), calm2-2 is a clearer C (0.89) and steadier but further from A (0.948).

| take | LUFS | LRA | BPM (fit) | grid ms | key | A's key corr. | spread dB | drift dB | chroma vs A |
|---|---|---|---|---|---|---|---|---|---|
| calm-1 (calm A) | -10.9 | 2.2 | 111.999 | 3.5 | C maj (0.59) | 0.59 | 0.89 | 0.9 | — |
| **calm2-1** | -12.4 | 2.2 | 111.999 | 2.4 | C maj (0.60) | 0.60 | 1.02 | 2.0 | 0.996 |
| calm2-2 | -11.3 | 0.6 | 112.001 | 2.3 | C maj (0.89) | 0.89 | 0.33 | -0.5 | 0.948 |

Processed: calm2-1.mp3 at 112.0 BPM (fit 111.999), from 8.0572 s, **20 bars = 42.86 s**, resampled 36 ppm to a whole number of AAC frames; `calm2.m4a` -16.0 LUFS, -2.9 dBTP, 525 KB. Seam (decoded loop): RMS jump 1.83 dB, mel 0.492 (the source's own bar line there: 7.19 dB, 1.302).

Listen check: `processed/loop-test-calm2-x3.m4a` and `processed/loop-test-calm-aba.m4a` (calm, calm2, calm; joins at 42.86 s and 85.72 s; calm -16.0 / calm2 -16.0 LUFS; join A→B RMS +1.81 dB, mel 1.024; B→A +2.53 dB, mel 1.185). Both loops start on a downbeat at the same tempo, so a switch at a loop end lands on a bar line.

## Win redo (2026-11-20, Claude's call by analysis): **replaced** with win-redo-1

The old win-1 ends on C/G but its last chords mix C minor colour (Eb, C#) and it cuts from −5 to −26 dB in its last second. Two new takes (flow `0E0ZhST9V8YYLYwyDEyQ`, 225 credits each), prompted in C major at the family's measured 112 BPM, "ending clearly on one strong, final C major chord that rings out" (PROMPTS.md).

| take | LUFS | LRA | BPM | key (corr.) | per-second level, last 6 s (dB vs loudest) | sounding at the end |
|---|---|---|---|---|---|---|
| win-1 (old) | −13.2 | 1.4 | 112.00 | C min / C maj (0.81 / 0.79) | −3, −1, −3, 0, −5, −26 | C4 C5 G5 C6 F6 A6 (last second: B, C, C#, Bb in the chroma) |
| **win-redo-1** | −12.2 | 14.5 | 112.02 | E min / C maj (0.65 / 0.55) over the whole take | −8, −17, −25, −33, −43, −56 | **C major triad**: C4 E4 G4 C5 G5; G-major bar (V) at 8–9 s, then C major 0.83–0.86 for the whole ring-out |
| win-redo-2 | −13.7 | 10.3 | 111.97 | F maj / C maj (0.67 / 0.54) | −7, −10, −11, −13, −25, −54 | open C fifth (G3 C4 G4), a held chord then a faster fade |

**Pick: win-redo-1.** A clear V→I cadence into a C major triad at ~8.5 s, then a smooth natural ring-out (about 8–10 dB a second) to −86 dB: the cleanest, most "finished" ending of the three. Processed with the same method (`python3 tools/process_music_calm2.py win superhero-city win-redo-1`): `win.m4a` −15.9 LUFS, −3.5 dBTP, 15.0 s, 186 KB. Its LRA is high because a third of the take is the ring-out. **Listen check:** the body before the cadence is short (~8.5 s of fanfare).
