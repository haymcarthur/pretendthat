# Round 5: writing moment, clipboardBoth layers, new wave/point/celebrate

- **Date:** 2026-11-13 (night)
- **Decided by:** Haylee (design, timing, framing); Claude's calls noted

## Writing moment (replaces every coloring approach; supersedes the "no coloring beats" part of revert-animation.md)
1. When: once while choosing ROLES (after the player count), ONCE before the FIRST prop (she plans the whole prop list;
   later props come one at a time with no writing), and while the KIT is made. Planning beats ≥ 1.8 s (roles ~2.3 s);
   the kit writes ≥ 3.2 s and until every page is final. (Haylee; "props once" correction 2026-11-13.)
2. Look: clipboardBoth pose; focus EYES with the happy face's closed smile (`NutmegFace.writing`, focus mouth replaced);
   a TIGHT close shot: the screen's bottom edge at the clipboard clip (canvas y 790), so no arm or paw pixels show;
   only the crayon's top end pokes up above the clipboard, wiggling (~0.26 s rotation around the hidden tip, small
   offset, slow drift); tiny head nods; the control pill fades out while she writes (Claude's call: it covered the
   clipboard top); hunt cards hide. Reduce Motion: no wiggle/nods.
3. Sound: tools/make_scribble.py → Resources/scribble.wav (filtered noise bursts), looped quietly (0.16), ducked to
   0.05 under her voice.
4. Then she looks up (happy), the crayon slides down out of frame, the camera returns to the normal shot, she announces.
5. Mechanism: Realtime tool `start_planning` (roles / props); the function result is held until the beat ends. App
   fallback (Claude's call): if the model skips it, set_roles and the first show_next_prop still get the beat.

## Art
- clipboardBoth split into body / clipboard / paws (Figma layer split; boolean subtract of existing shapes only),
  stacked body → head → face → headset → (crayon) → clipboard → paws. Head scale 0.93, offset (−12, −18) on this pose.
- New wave / point / celebrate bodies (Figma cleanup of images 35 / 36 / 37) replace the old ones (old: *.v4bak.svg).

## Kit screen
- Hold to print / Let's play sit ABOVE the page fan (and above the thumbnails in the chat-open pinned card). (Haylee)
- Page preview: one white sheet, rounded corners, one shadow; AI art normalized to paper white (tone curve) and drawn
  flat (multiply); full sheets (sign, menu) fill the content area edge to edge. (Haylee)
- Fix: AI art is ALWAYS aspect-fit (never cropped), full sheets as large as fits; print-path PDF checked with
  `-PTFakeArt -PTPDFOut` (DEBUG; /tmp/pt-round5/pdf-sheet.png). Paper-white curve lifts ≥ 84% luminance to white.
- The pages step reuses the prop-card step's camera exactly (huntFrame; pages in the hunt card's zone, buttons stacked
  above the fan when narrow). (Haylee)
