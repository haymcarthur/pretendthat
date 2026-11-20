# Scene music (one scene with music, 2026-11-21)

**Everything in this folder is a PLACEHOLDER except `space-adventure/` and `chime.m4a`** (real music, see the end) (soft synthesized tones from `tools/make_placeholder_music.py`).
Replace each file with the real AI-made music, keeping the same names. Plan and licensing:
`thinking/research/2026-11-21-ai-music-options.md`.

## Layout

```
Music/
  chime.m4a                 the ONE shared event chime (2–4 s), before every event
  <family>/calm.m4a         calm loop (1.5–2 min, seamless)
  <family>/tense.m4a        tense loop (1–1.5 min, seamless, same key/tempo/instruments as calm)
  <family>/win.m4a          win ending (15–25 s, plays once at the finale)
```

Families (the guide picks one; `MusicFamily` in NutmegCore/OneScene.swift):

| folder | pill label | fits |
|---|---|---|
| `space-adventure` | Space adventure | rockets, the Moon, planets, aliens, robots |
| `jungle-outdoors` | Jungle adventure | jungle, safari, camping, farm, zoo, dinosaurs, gardens |
| `magical` | Magic kingdom | castles, fairies, wizards, dragons, unicorns, knights |
| `cozy-shop` | Cozy shop | bakery, restaurant, shop, vet, doctor, school (the default) |
| `spooky-silly` | Silly spooky | silly ghosts, monsters, haunted houses, mystery (never scary) |
| `under-the-sea` | Under the sea | ocean, pirates, mermaids, submarines, beach |
| `desert-western` | Wild west | cowboys, ranch, desert, horses, sheriffs |

## Rules

- AAC in `.m4a` (44.1 kHz stereo, ~96 kbps for the real music), loudness about −16 LUFS (tense may sit ~1 LU louder),
  −1.5 dBTP. The app ducks the music about −12 dB under Nutmeg's voice and the chime (`MusicMix`).
- Loops must be seamless: whole bars, no fade at the start or end (the app loops them with `numberOfLoops = -1`).
  Check by playing three times in a row.
- **Missing files are fine:** a missing segment is silent, a missing family is a silent scene, a missing chime is just no
  chime. The scene clock and Nutmeg's events run either way.
- This folder is a **folder reference** in `project.yml` (the sub-folders are kept in the app bundle; the seven families
  share file names). Run `xcodegen` after adding or renaming files.

## Real music bundled so far

- **`space-adventure/` and `chime.m4a` are the REAL music** (2026-11-21): calm-2 / tense-3 / win-4 / chime-1 of the
  ElevenLabs takes, picked and measured in `design/music-test/space-adventure/PICKS.md`. Don't re-run
  `tools/make_placeholder_music.py` over them (it writes every family and the chime).
- Made by `tools/process_music.py` (ffmpeg + numpy + librosa, no AI calls): calm 20 bars = 48.0 s, tense 16 bars =
  38.4 s at 100 BPM; calm/win −16 LUFS, tense −15, chime −15; true peak ≤ −1 dBTP after decoding; AAC-LC 96 kbps,
  **48 kHz** stereo (the takes are 48 kHz and iOS hardware runs at 48 kHz, so no resampling).
- Loops are sample-exact: an even bar count is a whole number of AAC frames at 48 kHz, and each file is encoded with
  its own tail in front, then cut back with an MP4 edit list (1024 priming samples), so the decoded file is exactly
  the loop with no start click. If a seam is ever heard on a device, re-check `AVAudioPlayer` looping first; the
  file itself measures clean (PICKS.md, `design/music-test/space-adventure/processed/loop-test-*-x3.m4a`).
