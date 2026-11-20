# Start screen exit: Nutmeg in front of the curtains from the tap on

**Date:** 2026-11-20 · **Who decided:** Haylee (the fix); how: Claude's call

**Decision:** On New game, the toy chest (with Nutmeg in it) moves in front of the curtains the moment the exit starts (`PTStartScreen.scene`: the chest layer gets `zIndex(1)` once `e >= 0`), so the zoom shows her in front, exactly as the game stage draws her.

**Why:** Haylee: pressing New game or starting a saved game zoomed in on Nutmeg behind the curtains, then she switched to in front. The start screen drew the chest under `PTCurtain`; the game stage draws her above its proscenium, so the hand-off swapped her layer.

**Checked** (throwaway simulators, demo, no keys): New game on iPhone and iPad (screenshot bursts): she stays in front through the zoom, no switch. A saved game (saved page → Play with Nutmeg) cuts straight to the stage with her in front on both; no switch seen there.

**Also found:** with `-PTNoAI` a saved game takes ~8 s to leave its page (the voice connect times out first). Demo mode only.
