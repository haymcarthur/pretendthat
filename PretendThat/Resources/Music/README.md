# Scene music (one scene with music, 2026-11-21)

**The seven original families and `chime.m4a` are real music now** (see the end); anything still made by `tools/make_placeholder_music.py` is a soft synthesized placeholder.
Replace each file with the real AI-made music, keeping the same names. Plan and licensing:
`thinking/research/2026-11-21-ai-music-options.md`.

## Layout

```
Music/
  chime.m4a                 the ONE shared event chime (2–4 s), before every event
  <family>/calm.m4a         calm loop (1.5–2 min, seamless)
  <family>/calm2.m4a        second calm loop (same key/tempo/instruments, another melody); the app alternates
                            calm and calm2 when calm2 exists (2026-11-20, every family has one)
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
| `under-the-sea` | Under the sea | ocean, mermaids, submarines, beach, sea animals |
| `desert-western` | Wild west | cowboys, ranch, desert, horses, sheriffs |
| `superhero-city` | Superhero city | superheroes, capes, saving the city, sidekicks, silly villains |
| `pirate-adventure` | Pirate adventure | pirates, treasure hunts, pirate ships, parrots, treasure maps |
| `rescue-team` | Rescue team | firefighters, police, paramedics, lifeguards, rescue missions |
| `snowy-north` | Snowy north | snow, winter, the Arctic, penguins, igloos, the North Pole, ice (music in C, 96 BPM) |
| `robot-lab` | Robot lab | robots, labs, science, inventors, time machines (C, 108 BPM) |
| `circus-carnival` | Circus & carnival | circus, carnival, fair, clowns, magic shows, jugglers, ringmasters (F, 112 BPM) |
| `race-day` | Race day | races, race cars, sports, olympics, soccer, track (E, 120 BPM) |
| `superhero-city` | Superhero city | superheroes, capes, saving the city, sidekicks, silly villains |
| `pirate-adventure` | Pirate adventure | pirates, treasure hunts, pirate ships, parrots, treasure maps |
| `rescue-team` | Rescue team | firefighters, police, paramedics, lifeguards, rescue missions |

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
- **The other six original families are REAL music too** (2026-11-21): jungle-outdoors, magical, cozy-shop,
  spooky-silly, under-the-sea, desert-western, one ElevenLabs flow each (4 takes per segment), picked by analysis in
  `design/music-test/<family>/PICKS.md` (prompts in `PROMPTS.md`). Made by `tools/process_music_families.py` (the same
  method; tempo measured per take, and loops whose bar length isn't a whole number of AAC frames are resampled by
  under 0.05 % to the next whole frame, so they stay sample-exact). Calm loops 37–48 s, tense 29–42 s.
  Under the sea came out in C major / C minor (no take was in the A major asked for).

## 2026-11-20: calm2 for every family, four new families, two new wins

- **`calm2.m4a` in all 14 families:** a second calm loop in calm A's measured key and tempo with the same instruments
  and another melody, made so a 10-minute scene repeats less. The app alternates calm → calm2 → calm … at loop
  ends when `calm2.m4a` exists (`MusicPlayer`, each loop scheduled on the device clock at the other's end; `CalmLoop`) (both start on a downbeat at the same tempo, so the switch lands on a bar line). Both
  −16 LUFS. Check by ear with `design/music-test/<family>/processed/loop-test-calm-aba.m4a`. **Magic kingdom's calm2
  is in C major** (the dominant of calm A's F; the only take, the other generation failed): listen, and delete it if
  it jars (a missing calm2 just means calm loops alone).
- **Four new families**, each calm / calm2 / tense / win: `snowy-north` (asked A major, came out in C), `robot-lab`,
  `circus-carnival` (no tense came out in minor; its tense is a busy major), `race-day`. Picks and measurements in
  `design/music-test/<family>/PICKS.md`.
- **New wins** for `superhero-city` (a clear C major cadence and ring-out) and `magical` (bright, strong F major,
  replacing the soft one).
- Made by `tools/process_music_calm2.py` (the method of `tools/process_music_families.py`, no AI calls). Calm loops
  27.7–53.3 s, tense 30–35.6 s. All the music is now about 23 MB.
