# Jungle adventure music: prompts (2026-11-21)

ElevenLabs flow **"Jungle adventure music"**, flow id `tkgLagkpKz8Xr17acQ9x`. Model `eleven_music_v2_5`, node type `music`,
`{"lyrics_type": "instrumental", "instrumental": true}`, run once with the default 4 takes per node
(Creator plan, Haylee's credits). Same recipe as space adventure (decisions/2026-11-21-one-scene-music-beats.md); no chime
node (the shared `Music/chime.m4a` is used). No artists, films, franchises or famous songs named.

Cost: calm 900 + tense 675 + win 225 credits per take, x4 = 7,200 credits for the family.

| segment | node id | length | files | generation ids (take 1-4) |
|---|---|---|---|---|
| Calm loop | `D6gdGmZk186qHBw9AxDe` | 60 s | calm-1..4.mp3 | `zjdP6QwjBsmvwEXVn2fv`, `6PR7tFVuQ9kInwQm4Cff`, `LyfRI82WxNyCUzdkZtvI`, `zNhSdQNIJ3bRjOidtBfC` |
| Tense loop | `RIMyjisM25VzVMvqv8Lx` | 45 s | tense-1..4.mp3 | `9AKMkyl8jXTbh9WVNQHC`, `ai6Nmxh29ETyFlkS7dHD`, `Avpba19XtzfG1rAwuOp4`, `rAULOLkbpDjTZaCmFPhz` |
| Win ending | `VKDpmbZt0WfptbhgsIzN` | 15 s | win-1..4.mp3 | `tL0jzlBKbtgBZczNMyQg`, `XDtF2irLXNGm4nBdbq7C`, `l9RFlmJB7zacuwP9dTSO`, `3P74qNu35jsMaZiTcHDI` |

`loop-test-<calm|tense>-N.mp3` are the raw takes played 3x in a row (`ffmpeg -i "concat:a|a|a" -c copy`); the takes fade
out, so these dip at each seam. The processed loops are in `processed/` (see PICKS.md).

## Calm loop (60 s)

> Playful, gentle kids' jungle adventure instrumental in D major at 96 BPM: marimba melody, shakers and bongos, wooden flute, plucked acoustic guitar, warm pads. Curious, sunny and friendly, like exploring a leafy path. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Tense loop (45 s)

> Playful kids' jungle adventure instrumental in D minor at 96 BPM, the urgent version of a playful theme: driving low marimba ostinato, djembe, staccato strings, shakers and wooden flute. Exciting, playful suspense, hurry-up energy, never scary or dark. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Win ending (15 s)

> Triumphant kids' jungle adventure finale in D major at 96 BPM: marimba, bongos, wooden flute and acoustic guitar joined by a bright cheerful fanfare of brass and strings, building to a big happy celebration and ending on one clear, final major chord.

## Calm B loop (calm2, 60 s, 2026-11-20)

ElevenLabs flow **"PretendThat calm B loops"** `dSxe4hBC3cnsB5nMN5GN` (one node per family, run once with 2 takes, 900 credits a take). Model `eleven_music_v2_5`, `{"duration_seconds": 60, "lyrics_type": "instrumental", "instrumental": true}`. Files: calm2-1..2.mp3; generation ids `1irLg4Uol6n7u2Do5ZJd`, `MDbdVEe8rBZPaX2mCAuv`. In calm A's measured key and tempo (PICKS.md).

> A second, gentle variation of the same theme: playful, gentle kids' jungle adventure instrumental in D major at 96 BPM, with marimba, shakers and bongos, wooden flute, plucked acoustic guitar and warm pads, playing a different melody and arrangement. Curious, sunny and friendly, like exploring a leafy path. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.
