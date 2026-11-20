# Cozy shop music: prompts (2026-11-21)

ElevenLabs flow **"Cozy shop music"**, flow id `XOMk9REhiTVWDKJqTeOT`. Model `eleven_music_v2_5`, node type `music`,
`{"lyrics_type": "instrumental", "instrumental": true}`, run once with the default 4 takes per node
(Creator plan, Haylee's credits). Same recipe as space adventure (decisions/2026-11-21-one-scene-music-beats.md); no chime
node (the shared `Music/chime.m4a` is used). No artists, films, franchises or famous songs named.

Cost: calm 900 + tense 675 + win 225 credits per take, x4 = 7,200 credits for the family.

| segment | node id | length | files | generation ids (take 1-4) |
|---|---|---|---|---|
| Calm loop | `3DLbTPgq7EGgLmm9bAHj` | 60 s | calm-1..4.mp3 | `F2obnUfTfVS2B9p2Wh7Y`, `8v83QxF8A2ZZQ3CAPSTh`, `skG14JyNnR6u8DW9HYzu`, `A8IRpYQlGvOnrpHxNaoB` |
| Tense loop | `42BWCvRE0LpIEYhOitM2` | 45 s | tense-1..4.mp3 | `n5MAv2vkjeewte45O0w7`, `t7jbb6iDMQH30Ry6g6C1`, `NriRzIOAuPBh9nzyWJHC`, `kFSWOPxhyrquuPmnsXXp` |
| Win ending | `2kscZ4C0Q2kVAi56bf7v` | 15 s | win-1..4.mp3 | `wLZGD6IKn2cO33CA6ESR`, `jWQGhbi9nZQLQcnABjoS`, `o9S0XJohTSzvmHhCOAlc`, `D5jUzVO3hQUTmCzQfd7Z` |

`loop-test-<calm|tense>-N.mp3` are the raw takes played 3x in a row (`ffmpeg -i "concat:a|a|a" -c copy`); the takes fade
out, so these dip at each seam. The processed loops are in `processed/` (see PICKS.md).

## Calm loop (60 s)

> Playful, gentle kids' cozy shop instrumental in G major at 104 BPM: ukulele strums, light piano, upright bass, brushed drums, warm clarinet melody. Friendly, bouncy and homey, like a little corner shop on a sunny morning. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Tense loop (45 s)

> Playful kids' cozy shop instrumental in G minor at 104 BPM, the urgent version of a playful theme: driving bouncy fast piano, a ticking woodblock like a clock, pizzicato strings, upright bass, ukulele and clarinet, busy rush energy. Exciting, playful suspense, hurry-up energy, never scary or dark. Keep the energy even and steady the whole time, with no big intro, build-up or ending, so it can loop as background music under a voice.

## Win ending (15 s)

> Triumphant kids' cozy shop finale in G major at 104 BPM: ukulele, piano, upright bass, brushed drums and clarinet joined by a bright cheerful fanfare of horns, building to a big happy celebration and ending on one clear, final major chord.
