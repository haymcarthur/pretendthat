# Space adventure: the picks (2026-11-21, Claude's call by analysis)

Haylee listened to all 16 takes and said they all sound good; she asked us to pair them. Nobody can listen in the
agent sandbox, so the pairing is by measurement (ffmpeg ebur128 + librosa 1.0 beat tracking, CQT chroma,
Krumhansl key profiles). No AI calls.

## Picks

| segment | pick | why |
|---|---|---|
| calm | **calm-2** | Clearest C major of the four (key correlation 0.95; the others 0.70–0.88). Best chroma match to the chosen tense (0.954) and win (0.931). Steady level (per-second RMS spread 1.1 dB). calm-4 is steadier (0.75 dB) but matches win-4 poorly (0.81). |
| tense | **tense-3** | Steadiest energy of the four (0.56 dB spread, LRA 1.2), and the closest chroma to calm-2 (0.954). It sits between C minor and C major (0.71 / 0.70): a C pedal with minor colour. Its strongest pulse is triplets (134 = 4/3 × 100 BPM) over a 100 BPM beat grid, which gives the drive. tense-1 has unsteady beats (beat-interval spread 24 ms), tense-2 crescendos and tense-4 drifts down 3 dB. |
| win | **win-4** | The only take that ends on the home chord: final bass C, top notes C/G (win-1 ends on G, win-2 on D, win-3 on Cmaj7 after 9 s of near-silence). A 2 s swell into a steady body (C major 0.90), then a clean ~2 s ring-out to −62 dB. |
| chime | **chime-1** | Cleanest attack: 90 % of its peak in 4.9 ms, then a smooth, single decay (the others swell for 90–260 ms or are already mid-note at sample 0). In key (C major; the notes C, D, E). Runner-up: chime-4 (best key match, 0.96, but a soft, flat 0.6 s arpeggio). |

All of calm, tense and win were measured at **100.0 BPM** (beat grid fit: 99.997 / 99.994 / 99.97 BPM, residual under 2 ms).

## Measurements of every take

Tempo from librosa (100.4 is its tempogram bin for 100); exact grids were fit for the picks only.
"RMS spread" is the standard deviation of per-second RMS over the body. Chroma similarity is the cosine between the
mean CQT chroma vectors.

| take | length | LUFS | LRA | TP dBTP | tempo | key (corr.) | RMS spread dB | seam as delivered (RMS jump, last→first 200 ms) |
|---|---|---|---|---|---|---|---|---|
| calm-1 | 60 s | −16.1 | 1.8 | −0.8 | 100 | C maj (0.70) | 1.10 | +58 dB (fades out) |
| **calm-2** | 60 s | −14.3 | 2.0 | −0.1 | 100 | C maj (0.95) | 1.11 | +74 dB (fades out) |
| calm-3 | 60 s | −14.4 | 2.4 | −0.3 | 100 | C maj (0.85) | 2.3 (pulsing) | +45 dB (fades out) |
| calm-4 | 60 s | −13.7 | 0.7 | −0.1 | 100 | C maj (0.88) | 0.75 | +34 dB (fades out) |
| tense-1 | 45 s | −15.8 | 2.0 | −1.0 | 100 (unsteady) | C min (0.65) | 1.73 | +8.0 dB |
| tense-2 | 45 s | −15.7 | 2.9 | +0.2 | 100 | C min (0.56) | crescendo | +2.1 dB |
| **tense-3** | 45 s | −13.6 | 1.2 | −0.3 | 100 (triplet pulse) | C min/maj (0.71/0.70) | 0.56 | +4.7 dB |
| tense-4 | 45 s | −16.2 | 1.3 | −0.9 | 100 | C min (0.56) | 0.68 (drifts) | +0.2 dB |
| win-1 | 15 s | −15.1 | 6.1 | −2.3 | 100 | ends on G | — | — |
| win-2 | 15 s | −10.0 | 10.3 | −0.5 | 100 | ends on D | — | — |
| win-3 | 15 s | −16.9 | 15.0 | 0.0 | 100 | ends Cmaj7, quiet 9 s intro | — | — |
| **win-4** | 15 s | −12.7 | 3.6 | −1.0 | 100 | ends on C | — | — |
| **chime-1** | 1.48 s | −17.8 | — | −0.6 | — | C maj (C, D, E) | attack 4.9 ms | — |
| chime-2 | 1.48 s | −21.9 | — | −8.4 | — | E min | attack 91 ms | — |
| chime-3 | 1.48 s | −16.6 | — | −1.7 | — | C maj | attack 263 ms | — |
| chime-4 | 1.48 s | −21.2 | — | −4.8 | — | C maj (0.96) | flat 0.6 s | — |

Every calm take fades out over its last ~2 s, so none loops as delivered (the old loop-test-calm files have a dip
at each seam). Chroma similarity of the chosen trio: calm-2↔tense-3 0.954, calm-2↔win-4 0.931, tense-3↔win-4 0.874;
chime-1↔calm-2 0.863.

## Processing (tools/process_music.py, reproducible)

- **calm**: calm-2 from 7.213 s (bar 4's downbeat, at an upward zero crossing), **20 bars = 48.000 s**
  (2,304,000 samples). Chosen from every start bar 0–3 × length 8–29 bars by the closest match between the 250 ms
  after the loop end and the loop's head (log-mel distance + RMS), keeping 4-bar phrases and stopping before the fade.
- **tense**: tense-3 from its first downbeat (9.5 ms), **16 bars = 38.400 s** (1,843,200 samples).
- Both loops: the 30 ms just past the loop end is equal-power crossfaded into the head. Even bar counts are an exact
  number of AAC frames at 48 kHz, so the decoded .m4a is exactly the loop length (checked).
- **win**: the whole 15 s take, 3 ms fade-in and a 20 ms fade-out to true zero at the end of its ring-out.
- **chime**: 1.5 ms fade-in (it starts on the hit), 30 ms fade-out.
- Loudness: static gain, then a look-ahead peak limiter (circular for loops) only where peaks pass the ceiling.
- AAC-LC 96 kbps, 48 kHz stereo (the takes are 48 kHz; iOS hardware runs at 48 kHz, so no resampling).
  ffmpeg's AAC encoder smears the first frames of a file (10 dB more error, a click at every loop), so every file is
  encoded with real context in front (the loop's own tail, or silence) and cut back with an MP4 edit list (1024
  priming samples, the standard Apple layout).

## Results (measured on the decoded .m4a files)

| file | length | LUFS | TP dBTP | size |
|---|---|---|---|---|
| space-adventure/calm.m4a | 48.0 s (20 bars) | −16.1 | −1.8 | 592 KB |
| space-adventure/tense.m4a | 38.4 s (16 bars) | −15.0 (1 LU over calm, per the research) | −1.1 | 474 KB |
| space-adventure/win.m4a | 15.0 s | −16.0 | −3.6 | 185 KB |
| chime.m4a | 1.48 s | −15.0 (target −14; the limiter only trims the 5 ms hit) | −1.6 | 21 KB |

Total 1.27 MB for the family + chime.

**Seams (decoded .m4a vs the music's own bar line at the same spot):**

| loop | RMS jump last→first 200 ms | the source's own jump there | 10 ms RMS step at the seam | HF (>8 kHz) in the first 10 ms vs other bar starts |
|---|---|---|---|---|
| calm | +9.8 dB | +10.7 dB (the downbeat) | 0.8 dB (raw cut: 6.4) | −44 dB vs median −38 (range −44…−34) |
| tense | +2.7 dB | +2.4 dB | 2.7 dB | −36 dB vs median −35 (range −38…−31) |

The seam looks like any other bar line: no HF spike (a click would show there) and no level step beyond the
downbeat's own. Listen check: `processed/loop-test-calm-x3.m4a` (seams at 0:48 and 1:36) and
`processed/loop-test-tense-x3.m4a` (seams at 0:38.4 and 1:16.8). Full numbers: `processed/measurements.json`.
