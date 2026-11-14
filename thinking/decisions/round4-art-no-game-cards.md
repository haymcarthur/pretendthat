# Round 4 art (new head, idle, celebrate) and no game-idea cards

- **Date:** 2026-11-13 (night)
- **Decided by:** Haylee (cleanup-only rule; no game-idea cards); placement and fallback wording Claude's call

1. Figma (cleanup only, duplicates of image 33/32/34 [Vectorized]): white background removed, colors snapped within
   ±12, no specks needed deleting. New frames nutmeg-head-base-v4, nutmeg-headset-v4 (headset moved out, unchanged),
   nutmeg-body-idle-v4, nutmeg-body-celebrate-v4. Head scaled 0.741 to fit the current faces (face patch and nose within
   ~6 px; ears differ ~20 px, new proportions). Bodies scaled 0.79, feet on y 1311, neck under the chin. Old exports kept
   as *.v3.svg.
2. App: the head-base arm cut-out workaround is gone (the new head has no arm). Neck plug uses the new fur AD5E36;
   ground shadow and paper origin follow the new idle body. Head offsets unchanged (+12; checked idle, point, wave, sit,
   clipboardBoth, celebrate: no gap or lump).
3. Art problems reported, not patched: fur B35C34/B05C33 snapped to AD5E36 (the old bodies point/wave/sit stay A0623A,
   a slightly different brown); idle vest 55157C (15 off, unsnapped); celebrate belly is white (FFFEFE, cream is 47 off);
   paw pads FE7573 and nose highlight FE8886 unsnapped; the coral stem under the nose is back in the new head; celebrate's
   raised clipboard and arms sit completely behind the head at matching scale (clipboard never visible).
4. No game-idea cards: step 1 shows no tiles and no "Hold the mic" caption. If Realtime fails, Nutmeg says the ideas out
   loud (GameIdeas.spoken names every idea) with the backup voice; the kid answers by voice or the chat panel.
