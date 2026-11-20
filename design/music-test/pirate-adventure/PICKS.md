# Pirate adventure: the picks (2026-11-21, Claude's call by analysis)

2 takes per segment (flow `pMe79qLavzwshqdLARgD`, prompts in [PROMPTS.md](PROMPTS.md)). Paired by measurement
(ffmpeg ebur128, CQT chroma + Krumhansl keys, comb beat-grid fit, harmonic-change downbeats), as for space adventure.
Script: `tools/process_music_more.py`. No extra AI calls.

**Meter:** every take is exactly **104.0 BPM** (comb fit 103.99–104.00) with straight eighth subdivisions, not
triplets: the "6/8 swing" came out as a 6-beat drum pattern (onset repeat strongest at 6 beats) over chords that move
every 4 beats (chroma repeat 0.37–0.45 at 4 beats vs 0.09–0.21 at 3). So the loops are whole **12-beat units**, which
keeps both the drum pattern and the chords in step at the seam.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-1** | Much better loop seams (mel distance 0.36–0.38 vs calm-2's best 0.66–0.72). D major (0.86). Its first 18 s sit 1.4 dB louder; the loop comes from the steady part after that (21.7–49.3 s). calm-2 is the clearer D major (0.94) but no 12-beat loop of it matches its head well. |
| tense | **tense-1** | The only tense take with a clear D centre (D 0.72; tense-2 has no clear key, best 0.30). Closest to calm-1 and win-1 (chroma 0.951 / 0.982). Its loop comes from the fuller second half (14.7–42.4 s, after a +1.5 dB step at 15 s), seam score 0.42. It reads D major more than D minor (0.72 vs 0.52), so the urgency is in the fast fiddle and stomp, not the mode. |
| win | **win-1** | Ends on a full D major chord (D3 D4 F#4 A4 D5) and rings out to −74 dB, starting straight on the music. win-2 also ends on D (an open D/A), but opens with 0.5 s of silence and fades slowly from 10.5 s (LRA 14). |

## Measurements of every take

| take | length | LUFS | LRA | peak dBFS | key (corr.) | RMS spread dB | drift dB |
|---|---|---|---|---|---|---|---|
| **calm-1** | 60 s | −12.8 | 1.9 | 0.0 | D maj (0.86) | 0.80 | −2.0 (louder first 18 s) |
| calm-2 | 60 s | −12.7 | 2.0 | −0.7 | D maj (0.94) | 0.95 | +1.6 |
| **tense-1** | 45 s | −13.5 | 2.1 | +0.1 | D maj (0.72) / D min (0.52) | 0.96 | +2.3 (step at 15 s) |
| tense-2 | 45 s | −14.3 | 1.0 | −1.2 | unclear (B min 0.30) | 0.70 | +0.5 |
| **win-1** | 15 s | −13.8 | 1.8 | −0.8 | D maj (0.83), ends D major | — | — |
| win-2 | 15 s | −14.5 | 14.0 | −1.3 | ends open D/A, 0.5 s silent start | — | — |

Chroma similarity: calm-1↔tense-1 0.951, calm-1↔win-1 0.958, tense-1↔win-1 0.982.

## Processing (`python3 tools/process_music_more.py process pirate-adventure`)

- **calm**: calm-1 from 21.653 s (beat 37, a downbeat), **48 beats = 27.69 s**. **tense**: tense-1 from 14.732 s
  (beat 25), **48 beats = 27.69 s**. Chosen from every downbeat start × 12-beat-unit length by the head/after-end
  match (log-mel + RMS), stopping before any fade.
- Same method as space, plus a circular FFT resample to whole AAC frames (+0.002 % / +0.012 % speed: inaudible);
  the decoded .m4a is exactly the loop (checked). **win**: whole take, 3 ms fade-in, 20 ms fade-out.

## Results (decoded .m4a)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| pirate-adventure/calm.m4a | 27.69 s (48 beats) | −16.0 | −3.8 | 339 KB |
| pirate-adventure/tense.m4a | 27.69 s (48 beats) | −15.0 | −1.4 | 340 KB |
| pirate-adventure/win.m4a | 15.0 s | −15.9 | −3.0 | 186 KB |

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step | HF (>8 kHz) first 10 ms vs other bar starts |
|---|---|---|---|---|
| calm | −0.1 dB | −1.0 dB | 0.14 dB | −34.1 dB vs median −37.8 (range −39.5…−34.4) |
| tense | −2.0 dB | −2.2 dB | 0.05 dB | −35.5 dB vs median −35.7 (range −38.3…−33.4) |

The calm seam's HF sits 0.3 dB above the loudest other bar start (no level step, so most likely a hand-drum hit on
the downbeat; worth one listen). Listen: `processed/loop-test-calm-x3.m4a` (seams 0:27.7, 0:55.4),
`processed/loop-test-tense-x3.m4a` (same). The loops are short (27.7 s): if they feel repetitive in a family test,
a 72-beat calm-1 loop (41.5 s from 5.5 s) is the next-best seam (score 0.64 vs 0.48).
