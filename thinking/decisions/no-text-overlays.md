# No caption cards or loading text

- **Date:** 2026-11-13
- **Decided by:** Haylee

1. Removed everywhere: the white speech-text card (PTSpeechBubble) and every loading label with dots
   (PTWorkingIndicator: "Nutmeg is making your kit…", "Drawing your pictures…", "Picking jobs…", "Finding props…").
   Both components and their gallery entries are deleted. Nutmeg's voice and animation carry it; the chat panel still
   shows her words when it's open.
2. Kit loading: she colors on her clipboard (coloring pose, focus face, crayon) for as long as generation takes, shown
   big (hero column). After ~20 s and ~40 s of waiting she says one short reassuring line each time, never more.
3. The papers stay hidden until EVERY page's final art has landed or definitively fallen back (`KitArtService.finished`);
   never the fallback first and then a swap. Then she looks up and the papers fly off the clipboard.
4. Known gap: the classic print layout doesn't have the conversation camera, so the "zoom in on her face" during kit
   loading is approximated by the big hero column.
