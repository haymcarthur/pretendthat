# Silly spooky music: prompts (2026-11-21)

ElevenLabs flow **"Silly spooky music"**, flow id `fqb6SqvdwNbLrPikYYFO`. Model `eleven_music_v2_5`, node type `music`,
`{"lyrics_type": "instrumental", "instrumental": true}`, run once with the default 4 takes per node
(Creator plan, Haylee's credits). Same recipe as space adventure (decisions/2026-11-21-one-scene-music-beats.md); no chime
node (the shared `Music/chime.m4a` is used). No artists, films, franchises or famous songs named.

Cost: calm 900 + tense 675 + win 225 credits per take, x4 = 7,200 credits for the family.

| segment | node id | length | files | generation ids (take 1-4) |
|---|---|---|---|---|
| Calm loop | `X7vWPptErcw7iRLMlr5B` | 60 s | calm-1..4.mp3 | `Gv9mES9aKSco8ysDIXXB`, `Xb2BB3rknTquPSHzgVGq`, `iBhD5ckNug8Nx2zI4Gjy`, `qRaLhA1SZ0v99yxKMOpi` |
| Tense loop | `AaugV2sO9hUT9ijZjvfS` | 45 s | tense-1..4.mp3 | `9TVHtgOZ2yqe3sXHXNmE`, `50VW6D8Jd41OC7294uHr`, `v4KEc4Rrvfx9OruMDty5`, `N6WkydWCP9Whd7BCc699` |
| Win ending | `6XRrRbtdViIZiiA1Geo8` | 15 s | win-1..4.mp3 | `xyb3TBIKOw4lwZyJvpX1`, `8bdbaZNOki5PgcbPDg7G`, `oowQvshVMRzKKqxhblN0`, `b5tv1hfOD6dU1r1hl6m3` |

`loop-test-<calm|tense>-N.mp3` are the raw takes played 3x in a row (`ffmpeg -i "concat:a|a|a" -c copy`); the takes fade
out, so these dip at each seam. The processed loops are in `processed/` (see PICKS.md).

## Calm loop (60 s)

> Playful, goofy kids' silly spooky instrumental in E minor at 108 BPM: bassoon melody, pizzicato strings, harpsichord, a wobbly synth, finger snaps. Silly-mysterious and light, tiptoeing like cartoon friends sneaking through a funny haunted house, never scary. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Tense loop (45 s)

> Playful, goofy kids' silly spooky instrumental in E minor at 108 BPM, the urgent version of a playful theme: a driving, faster-feeling tiptoe chase with xylophone runs, bouncy tuba, pizzicato strings, bassoon and wobbly synth, still silly. Exciting, playful suspense, hurry-up energy, never scary or dark. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Win ending (15 s)

> Triumphant kids' silly spooky finale in E major at 108 BPM: bassoon, pizzicato strings, harpsichord, xylophone and bouncy tuba joined by a bright cheerful fanfare, building to a big happy celebration and ending on one clear, final major chord.

## Calm B loop (calm2, 60 s, 2026-11-20)

ElevenLabs flow **"PretendThat calm B loops"** `dSxe4hBC3cnsB5nMN5GN` (one node per family, run once with 2 takes, 900 credits a take). Model `eleven_music_v2_5`, `{"duration_seconds": 60, "lyrics_type": "instrumental", "instrumental": true}`. Files: calm2-1..2.mp3; generation ids `yV3g7WnOY9IWGlT4w3Li`, `8RyLCeeDmddpbiLaVY03`. In calm A's measured key and tempo (PICKS.md).

> A second, gentle variation of the same theme: playful, goofy kids' silly spooky instrumental in E minor at 108 BPM, with bassoon, pizzicato strings, harpsichord, a wobbly synth and finger snaps, playing a different melody and arrangement. Silly-mysterious and light, tiptoeing like cartoon friends sneaking through a funny haunted house, never scary. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.
