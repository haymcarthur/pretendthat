# Magic kingdom music: prompts (2026-11-21)

ElevenLabs flow **"Magic kingdom music"**, flow id `wdnRvjnCcvFyYAPpiwuf`. Model `eleven_music_v2_5`, node type `music`,
`{"lyrics_type": "instrumental", "instrumental": true}`, run once with the default 4 takes per node
(Creator plan, Haylee's credits). Same recipe as space adventure (decisions/2026-11-21-one-scene-music-beats.md); no chime
node (the shared `Music/chime.m4a` is used). No artists, films, franchises or famous songs named.

Cost: calm 900 + tense 675 + win 225 credits per take, x4 = 7,200 credits for the family.

| segment | node id | length | files | generation ids (take 1-4) |
|---|---|---|---|---|
| Calm loop | `R6yV558AaLQKkjs4VFmq` | 60 s | calm-1..4.mp3 | `Vew1ScG2oHCD3PKG1YZZ`, `awMTjpJUsdTdScieVhoA`, `2Dl86iP45QCeND8Wqhl7`, `8Nw23VhRUfPUoISaWobY` |
| Tense loop | `7yKuDQNmHWc9xMHMMHtP` | 45 s | tense-1..4.mp3 | `AFkEbhmr9sVMFbSfe7I8`, `5dZ30fRDz9uW1f11ALb6`, `T53cbLS1qBxUtiEaSRGl`, `sl8WtP0qtLs4gcdwlYRL` |
| Win ending | `ai0cDOAHqmAkVjttrtf6` | 15 s | win-1..4.mp3 | `I8CCuqfUL2STBLMmOKEe`, `kzBQ0kzi6wDluFayNdej`, `Q02Dxqu3xFIr7OC4xbfX`, `ZSag6BcrDQFILkhdN6sJ` |

`loop-test-<calm|tense>-N.mp3` are the raw takes played 3x in a row (`ffmpeg -i "concat:a|a|a" -c copy`); the takes fade
out, so these dip at each seam. The processed loops are in `processed/` (see PICKS.md).

## Calm loop (60 s)

> Playful, gentle kids' magic kingdom fairy-tale instrumental in F major at 90 BPM: celesta melody, harp arpeggios, flute, light strings, soft chimes. Sparkly, wondering and warm, like a friendly enchanted castle. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Tense loop (45 s)

> Playful kids' magic kingdom fairy-tale instrumental in F minor at 90 BPM, the urgent version of a playful theme: driving tremolo and pizzicato strings, soft timpani, mysterious celesta runs, harp and flute. Exciting, playful suspense, hurry-up energy, never scary or dark. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Win ending (15 s)

> Triumphant kids' magic kingdom finale in F major at 90 BPM: celesta, harp, flute and strings joined by a bright cheerful fanfare of brass and sparkling chimes, building to a big happy celebration and ending on one clear, final major chord.
