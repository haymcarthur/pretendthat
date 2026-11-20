# Under the sea music: prompts (2026-11-21)

ElevenLabs flow **"Under the sea music"**, flow id `5mIplQQFVw5LvBDkNcdg`. Model `eleven_music_v2_5`, node type `music`,
`{"lyrics_type": "instrumental", "instrumental": true}`, run once with the default 4 takes per node
(Creator plan, Haylee's credits). Same recipe as space adventure (decisions/2026-11-21-one-scene-music-beats.md); no chime
node (the shared `Music/chime.m4a` is used). No artists, films, franchises or famous songs named.

Cost: calm 900 + tense 675 + win 225 credits per take, x4 = 7,200 credits for the family.

| segment | node id | length | files | generation ids (take 1-4) |
|---|---|---|---|---|
| Calm loop | `V88tSM83RQzqJwftrXet` | 60 s | calm-1..4.mp3 | `zzXhbnhj7FhWAQNQeFPU`, `L5Arp8job1eJFXWuA3nQ`, `yGh6w8KjQ0TiNTOpY1rS`, `OrQXgrShYu839A5zAnO2` |
| Tense loop | `KlGphfMsLFUryRfO0YeW` | 45 s | tense-1..4.mp3 | `hzbw0GAEGrqAQZG68atC`, `nUcc3h0oNJp19JQseTC7`, `UR3Uf6ibjWFCGRTAm3OM`, `Kx1rqNv3UHUmUfRDdkU5` |
| Win ending | `Kc2EK60pUfguunPBIcnD` | 15 s | win-1..4.mp3 | `yP1g2WeCHr1CWfGcffuV`, `qevYZd4BscEy5S1aQJtT`, `Prl5s6dQOAuog6fYUiQi`, `mhULSMDmuefpPLMWjgmZ` |

`loop-test-<calm|tense>-N.mp3` are the raw takes played 3x in a row (`ffmpeg -i "concat:a|a|a" -c copy`); the takes fade
out, so these dip at each seam. The processed loops are in `processed/` (see PICKS.md).

## Calm loop (60 s)

> Playful, gentle kids' underwater ocean adventure instrumental in A major at 92 BPM: vibraphone melody, harp glissandos, bubbly soft synth, gentle marimba, warm bass. Floaty, calm and full of wonder, like swimming with friendly fish past a sunny coral reef. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Tense loop (45 s)

> Playful kids' underwater ocean adventure instrumental in A minor at 92 BPM, the urgent version of a playful theme: driving pulsing synth bass, quick vibraphone patterns, swelling strings, harp and marimba. Exciting, playful suspense, hurry-up energy, never scary or dark. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Win ending (15 s)

> Triumphant kids' underwater ocean adventure finale in A major at 92 BPM: vibraphone, harp, marimba and bubbly synth joined by a bright cheerful fanfare of brass and strings, building to a big happy celebration and ending on one clear, final major chord.
