# Planning beats: coloring on the clipboard

- **Date:** 2026-11-13
- **Decided by:** Haylee (behavior); implementation details Claude's call

1. Realtime tool `start_planning(topic)` (roles | props | kit). Before announcing the roles or the next prop she says a
   short lead-in ("Hmm, let me plan that on my clipboard…") and calls it.
2. The app finishes her lead-in, switches to the coloring pose with the focus face (eyes down; nutmeg-face-focus) and
   the crayon layer (nutmeg-coloring-crayon, over the head, scribbling on a ~0.25 s cycle) for 2.5–3.5 s, then she
   looks up (excited face) and the pose pops back to idle with the clipboard. Only then is the function result sent,
   so the model continues and announces the plan: the pending result is the pause. Automatic replies are off during
   the beat (room noise or a kid can't start a turn mid-beat); kid input waits for the announcement.
3. Kit generation uses the same coloring loop until every page is final.
4. A beat never changes the camera by itself. In the close-up, the coloring pose aims a little lower so the top of the
   clipboard and the crayon stay in frame (a pan, not a zoom).
