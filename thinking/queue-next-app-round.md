# STATUS (2026-11-14 ~01:20): rounds 1–11 DONE (round 11 = decisions/round11-start-and-transitions.md). Before: rounds 1–10 DONE (round 10 = decisions/round10-review-fixes.md; round 9 = decisions/round9-sleepy-and-lock.md). Earlier: rounds 1–8 DONE (round 8 = decisions/round8-art-polish.md; items below marked DONE R8). Next: round 9 (sleepy Nutmeg + lock). Was: round 8 = art (tie-backs, writing body + zoom out, new wave w/ arm in front, clipboard-both clipboard, clipboard above head in all poses, star sparkle). Round 9 = sleepy Nutmeg + game survives lock. Rules for each in decisions/2026-11-13-*.md.

# Queue: next app round (held until the current build round reports)

Art ready in design/export/ to import:
- nutmeg/nutmeg-head-base.svg: left-ear shadow fixed (thin crescent inside ear; old band removed). Backup: nutmeg-head-base.before-ear.svg
- nutmeg/nutmeg-face-yay.svg, nutmeg-face-nap.svg: closed eyes aligned to open-eye positions (blinks)
- (pending) all 9 faces with new straight-looking eyes + focus face (Figma agent in progress)
- (pending) crayon + gripping paw pieces for the coloring pose (waiting on Haylee's ChatGPT art)
- startscreen/chest-body.svg: new box art (sent to the build already)

## Round 3 (after round 2 reports)
- Crayon v3: nutmeg-body-coloring.svg (v3), nutmeg-coloring-crayon.svg, NEW nutmeg-coloring-fingers.svg. Stack: body → crayon → fingers → head → face.
- JOINTED-ARM RIG (Haylee approved 2026-11-13): parts in design/export/rig/ + rig.json (body bases stand/jump/sit, tail, upper/forearms L/R with joint caps, hands open/grip/point/fingers-front, clipboard, crayon). Build a NutmegRig view behind a Grown-ups toggle ("Jointed Nutmeg", default OFF until verified); keep whole-pose Nutmeg as the fallback. Poses become joint-angle presets (idle, wave, point, celebrate w/ clipboard, coloring, both-hands clipboard in-between) with spring interpolation between them; props attach to hands.

## Updated after revert (2026-11-13 evening)
- Rig and coloring beats CANCELLED (see decisions/revert-animation.md). Whole poses only.
- NEW whole pose: nutmeg-body-clipboard-both.svg (clipboard held in front with both hands). Use as the in-between when she brings out the clipboard (e.g., before the kit reveal / while making the kit) — pop-swap like other gestures.
- Pending art from Haylee (ChatGPT regen, not Figma patches): a clean head (smooth chin rim, subtle ear shadows, brown neck).

## Round 3 done (2026-11-13 night)
- Imported head-base (new), nutmeg-headset (own top layer), idle (new), clipboard-both; clipboardBoth pose during kit making.
- Art issues for Haylee (not patched): head-base silhouette includes the idle body's hanging right arm (app masks it); thin light sliver along the idle body's right vest edge; clipboard-both fur AD5E36 / clipboard FEC726 more than ±12 from the palette (left as drawn).

## Round 5 (after round 4)
- New headless WAVE + POINT bodies (Haylee regenerating) → cleanup/import.
- WRITING animation, new approach: close shot framing head + top of clipboard (hands out of frame), clipboardBoth pose, crayon-v3 layer wiggling with only its top visible, scribble sound, focus face; then look up → normal view. (When: kit-making; planning moments TBD by Haylee.)
- Fresh screenshot pass of the CURRENT app for the deck: conversation, prop hunt, kit reveal (papers), play step (checklist/hand-off), start screen with tiny gear. Then update slides 3 (all four step cards) and 5 (waving Nutmeg with new art).
- WRITING moment runs EVERY time she is planning (roles, each prop, kit), even if quick — short beat so it flows (Haylee 2026-11-13).
- clipboardBoth pose fixes: head too big/low/offset on this pose → per-pose head scale + offset (torso is ~55px taller; neck top 734 vs 789). LAYERING: split the clipboard-both art into body / clipboard / hands layers (layer split only, no reshaping), stack body → head → face → headset → CLIPBOARD → HANDS, so the clipboard sits in front of her chin/face and her paws grip in front of it.
- Wave + point headless bodies are VECTORIZED in Figma (newest images) → cleanup/import in round 5.
- Celebrate (from round 4) looks off: arms overhead get hidden behind her big head, belly is white not cream. Haylee to regenerate with arms out wide at shoulder height (clipboard in one hand) → round 5.
- Curtain TIE-BACKS: replace the code-drawn yellow pill with Haylee's new tie-back art (left/right, rope + tassel) layered on top of the gathered curtains; appear as the curtains finish opening. (Round 6)

## Round 6 additions (Haylee 2026-11-13, late)
- PUSH-TO-TALK (decisions/2026-11-13-push-to-talk.md): turn off server VAD / always-on mic. Hold the big red mic button → stream audio; release → commit buffer + request response. Transcript only gets what was said while holding. Remove addressee-detection / create_response:false hunt logic (no longer needed). Clear "hold to talk" affordance (pressed state, pulsing ring while listening). Typing in chat still works.
- CONTROL PILL: chat button LEFT · big red mic CENTER (larger than the others) · close RIGHT.
- EXIT WARNING: tapping close shows a friendly confirm ("If you leave now, you'll have to start a new game.") with Stay / Leave.
- PRINT: remove hold-to-print; single tap opens the iOS print screen (decisions/2026-11-13-single-tap-print.md).
- WRITING BODY: when Haylee's new one-paw-writing body is vectorized → import and zoom the writing shot out to show head + clipboard + writing paw (decisions/2026-11-13-writing-body.md).
- PROP CARD DESCRIPTION TRUNCATED ("a serving tray for delivering orders acro…"): never truncate. Remove the line limit / let the card grow (or use minimumScaleFactor as a last resort), AND tell the model to keep a prop's description short (≤ ~6 words, kid-friendly, e.g. "for carrying snacks to passengers"). Check with the longest real descriptions. (Haylee 2026-11-13)
- CONFETTI Z-ORDER: when the kit is ready and the chat panel is open, the confetti draws BEHIND the chat panel. Confetti should be the top overlay (above chat panel, step rail, control pill), non-interactive (allowsHitTesting false). (Haylee 2026-11-13)

## Round 7
- Writing body import (cleanup agent output) + zoom writing shot out.
- Tie-backs art import (replace code-drawn pill).
- New wave body + standalone clipboard (Haylee regenerating) → cleanup/import.
- **DONE R8** STAR SPARKLE (Haylee 2026-11-13): the stage stars/sparkles gently pulse, one at a time in sequence. One sparkles (a small scale-up ~1.0→1.12 + slight brightness/rotation twinkle, ~0.6s, ease in/out), then a few seconds later the next one, then the third, looping. Subtle, never all at once. Respect Reduce Motion (static).
- **DONE R8** Writing body art is cleaned up AND recolored to the palette (fur AD5E36, shade 9C4727, vest 55157C, clipboard FEB80B, belly FFE9CF; crayon browns → reds). Files: nutmeg-body-writing.svg, nutmeg-writing-crayon.svg, nutmeg-writing-fingers.svg (stack body → crayon → fingers). Per-pose body transform: scale 0.69 anchored at (625,436), then offset (+14,+330) canvas px; head stays at the idle values. Backups: *.before-recolor.svg.
- Wave: Haylee is regenerating with the LEFT arm waving (viewer's right) so the clipboard stays in the same hand as idle. Don't import the previous right-arm wave.
- **DONE R8** CLIPBOARD ABOVE HEAD in idle (and any pose where she holds the clipboard at her side: idle, point, wave, celebrate, sit): while breathing, the head bob covers the top corner of the clipboard clip. Split the clipboard (+ the paw gripping it, if the paw overlaps the clipboard) out of each body SVG into its own layer (layer split only, no reshaping, like the clipboardboth split) and stack body → head → face → headset → clipboard → gripping paw. The clipboard must move with the body (not the head bob). Check the existing nutmeg-clipboard-front/back.svg first. (Haylee 2026-11-13)
- **DONE R8** TIE-BACKS READY: design/export/stage/tieback-left.svg / tieback-right.svg (viewBox 709x627). Replace the Capsule in PTCurtain.half() (PTStartScreen.swift). Width ≈ 1.1 × m.visible, height = width × 627/709, no rotation; knot centered on (tieX, tieY): left knot unit point (0.852, 0.270), right (0.148, 0.270). The right curtain half is mirrored → draw tieback-left inside the mirrored half (or tieback-right outside the mirror). Keep the scale grow-in. Check on the start screen AND the stage curtains. Check PNG: scratchpad/tieback-check.png.
- FRESH SUGGESTIONS EVERY SESSION (Haylee 2026-11-13): questions stay the same and in the same order, but the example games/themes she suggests must vary each time (now she always says rocket ship / pancake restaurant / jungle explorer). Fix in code, not just the prompt: keep a big curated list in NutmegCore (~40 game ideas, plus theme twists per game type), randomly pick 3 games at session start (and 3 twists once the game is chosen, e.g., via the set_game tool result), and inject them into the session instructions/tool output as "suggest these today". Avoid repeating the previous session's picks (store only the last picks locally in UserDefaults; nothing about kids). Add a unit test that the sampler returns varied, non-repeating picks.
- PLAYER COUNT WORDING (Haylee 2026-11-13): don't offer a closed list ("just you, or two, or three friends?") — it sounds like that's the max. Ask open: "How many friends are playing today?" (roles still adapt to any number).
- NO PERMISSION CHECKS (Haylee 2026-11-13): never ask "Sound good?" / "Okay?" / "Ready?" after stating roles. State the roles and go straight into the first prop in the same turn. Only real questions: game, theme, how many kids, and the per-prop found-it question. Update instructions + any tool descriptions; add/adjust conversation tests.
- Check the "Hold the red button whenever you're ready!" nudge timing: in Haylee's test it showed up as its own bubble after nearly every question. Confirm it really waits ~20s of silence, fires once per question, and consider not adding it to the transcript.
- HEAD: no new head needed. Haylee is fine with the pink nose line (2026-11-13); the old complaint was the black line, already removed. Nose-stem item CANCELLED.
- **DONE R8** CLIPBOARD-BOTH: new complete clipboard is in design/export/nutmeg/nutmeg-clipboardboth-clipboard.svg (no holes). Re-import into Assets.xcassets (tools/import_art.py). Note: the paws layer has tiny orange slivers under each paw (leftover old clipboard edge) — check at app size; fine to leave if invisible.
- **DONE R8** NEW WAVE (Haylee chose arm-in-front): nutmeg-body-wave.svg (body, no clipboard/arm), nutmeg-wave-arm.svg, nutmeg-wave-clipboard.svg. Transform for all three: matrix [0.876,0,0,0.876,104.2,250.0] (scale 0.876 @ neck (610.5,589), offset +28.5,+177). Stack: body → head → face → headset → wave-arm → clipboard. During the wave pose, DON'T bob the head upward independently (it opens a gap at the chin/shoulder); bob head+body together or only downward. Feet run ~4px past canvas bottom; make sure the frame doesn't clip them.

## Round 9 (after art round 8)
- **DONE R9** SLEEPY NUTMEG (Haylee 2026-11-13): if the kid doesn't answer for a while during the conversation (after the one reminder, ~30s more of silence), Nutmeg sits down (sit pose), then her eyes droop and she falls asleep (nap face, slow deep breathing). No text overlays. Pressing the mic or typing wakes her: quick happy pop back to idle, then she continues where she left off (no re-greeting). Don't do this during the writing moment, kit generation, or the play step.
- **DONE R9** KEEP THE GAME ALIVE THROUGH LOCK/BACKGROUND (Haylee 2026-11-13): locking the iPad or switching apps must not end the game; only fully closing the app does. Keep all game state (step, game, theme, roles, props found, kit pages/images) in memory. On returning to the foreground, silently reconnect the Realtime session with the current state injected into the instructions; no re-greeting, no repeated question. If kit generation was in flight, finish or retry it on return (use a UIApplication background task to let in-flight requests finish). Stop mic/audio cleanly on background. Coloring the printed pages can take a long time, so a game left in the Print/Play step for 30+ minutes must still be there. Decide on idle timer: keep the screen awake during conversation/kit generation; allow auto-lock in the Play step. (Persisting to disk is NOT in scope; see ideas/save-game-to-disk.md.)
- **DONE R8 (voice confirm DONE R9: confirm_handoff tool)** HAND-OFF CARD IS CONFUSING (Haylee 2026-11-13: "I don't get what 'Tap your badge' means"). PTHandoffCard (PTComponents.swift): the orange role pill is the tap target but doesn't look like a button, and "badge" collides with the printed name badges. Change: pill text "I'm the Conductor!" + arrow (clearly a button, press state), remove "Tap your badge!", say "iPad" not "tablet" ("Pass the iPad to the Conductor!"). Nutmeg also speaks it ("Pass the iPad to the Conductor! Conductor, tap your name when you've got it!"), and saying "I'm the Conductor" into the mic confirms too (tool). Claude's suggestion; confirm with Haylee if she objects.
- **DONE R8** PLAY CHECKLIST SIZE (Haylee 2026-11-13): with the chat open, the scene checklist on stage is tiny, and it scrolls/cuts off ("Cheer for the Star Castle!" is clipped). Fix: (1) never scroll: size the card to fit all items (scenes have ~4–6 steps); shrink row padding/picture size before shrinking text, and keep text ≥ 17pt; (2) with the chat open, match the prop card's chat-open treatment: either a larger stage card in the space left of the chat panel, or pin the checklist at the top of the chat panel like the prop/kit cards. Pick whichever keeps it biggest and readable, and keep "Done!" a real full-size button. Check with the chat open and closed, on 11" and 13".
- **DONE R8** START SCREEN TOYS (Haylee 2026-11-13): toys take too long to come out of the chest. Keep each toy's own pop-out animation the SAME speed; just shrink the stagger between toys so they overlap more and come out closer together (e.g., cut the delay between toys to ~1/3 of today's). Total sequence noticeably shorter, each toy's motion unchanged.

## Round 10 (Haylee's review of round 8, 2026-11-14 ~00:30) — DONE R10 (decisions/round10-review-fixes.md; item 3 changed to: twinkle removed)
1. CLIPBOARD-FRONT LAYER TOO BIG: on idle (start-screen chest and stage) the front layer brought her ARM up in front of her chin/face along with the clipboard. Front layer = clipboard board + clip ONLY (plus just the fingers that wrap the board's front edge, if any). The arm itself stays behind the head. Re-check idle, point, celebrate (and the start-screen tail-less copies). **DONE R10.**
2. TIE-BACKS: move them inward so the tassels aren't cut off by the screen edge (whole tassel visible on both sides, start screen + stage). **DONE R10.**
3. STAR TWINKLE (revised by Haylee): bigger (~1.0→1.3 + bright glint) but NOT on a fixed beat. Randomize: each star waits a random 2–6s between twinkles, so sometimes two overlap slightly and sometimes there's a longer pause. Vary each twinkle's size/duration a little too. Never all at once on purpose. **DONE R10 (changed: twinkle REMOVED, stars static).**
4. WRITING SHOT: now too zoomed out. Go about halfway between round 7's tight crop and round 8's wide shot (head + top 2/3 of clipboard + writing paw). Also the crayon shows a notch/indent in the clipboard edge as it wiggles (the clipboard edge was drawn over the crayon tip in the original art, so moving the crayon reveals the cut). Fix with layering/clipping only, e.g., keep the crayon tip under a small clipboard-edge overlay or reduce wiggle so the tip stays inside the cut. No redraw. **DONE R10.**
5. ROLES → PROP PAUSE too long: cut the gap after the roles line to ~0.4s (currently 1s + latency). (Conversation timing; touch only that constant.) **DONE R10.**
6. TRANSITIONS FEEL PHASED: camera zoom in/out, Nutmeg moving, and cards/props entering happen one after another. Make them move together in one shared animation (same start, same spring/duration). **DONE R10.**
7. CHECKLIST, CHAT CLOSED: the stage/Nutmeg sit differently than in the prop-card step. Use exactly the prop-card step's camera/Nutmeg/floor framing. **DONE R10.**
8. CHECKLIST, CHAT OPEN: the pinned checklist takes nearly the whole chat panel and the transcript is barely visible. Make the pinned card compact (smaller rows, smaller pictures, title on one line) and cap it at ~50% of the panel height. If the steps don't fit, collapse to a summary row ("Set the Rainbow Table · 1 of 4 ✓", tap to expand) rather than scrolling. **DONE R10.**
9. REMOVE THE "GO PLAY!" SCREEN (Haylee: it doesn't make sense). The play step is just the scene checklist. "Done!" is always visible; if tapped before every step is checked, it quickly checks the remaining steps for the kid (a short check animation), then moves straight to the next "Pass the iPad to the …" hand-off card (after the last scene: the finale). Drop the napping/Go play/Next scene/Help screen. If Help, Nutmeg! is worth keeping, the mic covers it. (Claude's call between Haylee's two options: auto-check-on-Done, so kids who skip checking aren't stuck.) **DONE R10.**
10. UNDO DONE (Haylee): after Done! moves to the "Pass the iPad" card, a clear "← Back to the checklist" button on the hand-off card returns to the previous scene's checklist, restoring the checkmarks exactly as they were before Done auto-checked them (keep a snapshot). Available until the next role taps "I'm the …!". Also allow un-checking individual steps on the checklist (tap again). **DONE R10.**
11. HAND-OFF CARD, CHAT OPEN (Haylee): the "Pass the iPad to the Captain!" card is tiny on stage when the chat is open. Treat it like the prop/kit/checklist cards: with the chat open, pin it at the top of the chat panel at full readable size (big "I'm the Captain! →" button plus the "← Back to the checklist" button from item 10). Same full-size card on stage when the chat is closed. General rule: every interactive card (prop, kit, checklist, hand-off) uses one shared chat-open treatment; nothing shrinks to fit the stage gap. **DONE R10.**

## Round 11 (Haylee 2026-11-14 ~00:50) — ALL DONE R11 incl. the stage audit (decisions/round11-start-and-transitions.md)
- START SCREEN CHOREOGRAPHY: (1) the toy chest starts shaking WHILE the curtains are drawing back (not after). (2) When Nutmeg pops out of the chest, the PretendThat logo and the Let's play! button come in AT THE SAME TIME as her pop, with the same duration/spring as Nutmeg's pop-up. No staggered logo/button entrances afterward. Toys keep the round 8 tighter stagger.
- TRANSITIONS STILL PHASED (Haylee): after pressing Let's play! (start screen → game, and also the Print → Play "Let's play!"), many elements adjust one after another. Every transition must move as ONE animation: camera/zoom, Nutmeg, floor, step rail, control pill, chat panel, cards, all starting together on the shared Theme.stageMove spring. Audit every phase change (start→game, game→theme…, props→kit, kit→print, print→play, scene→hand-off, finale) for chained/sequenced animations, delays, or `DispatchQueue.asyncAfter`/`.delay` staggers, and remove them. Record a 10 fps frame strip of start→game and print→play to prove it.
- STAGE AUDIT (Haylee 2026-11-14 ~01:05, added to round 11): keyboard must not re-zoom/move the stage (keyboard just covers it; only the chat input rises); floor/Nutmeg/props share one camera transform (floor never oversized); one named set of camera presets based on the approved prop-card framing, used by every phase × chat open/closed/keyboard; table + screenshot grid.

## Round 12 (small, right after round 11) — DONE R12 (decisions/round10-review-fixes.md, "Round 12")
- WRITING CLIPBOARD NOTCH (Haylee 2026-11-14 ~01:10, second report): the clipboard still shows an indent/notch where the crayon tip was cut out, visible as the crayon moves. Fix: (1) make the board SOLID: the notch is geometry left by the vectorizer subtracting the crayon tip from the board path; close it by removing the notch from the board path (repair the board outline to a straight edge; Haylee explicitly asked for "just solid", so this mechanical path repair is authorized, not an art redraw). (2) Layering: split the clipboard board out of nutmeg-body-writing.svg into nutmeg-writing-clipboard.svg and stack body → crayon → CLIPBOARD → fingers, so the crayon tip sits BEHIND the board edge while the paw/fingers stay in front. (3) Also check a small red sliver at the clipboard's right edge behind the holding paw (crayon art piece peeking out); hide it via the same layering. Verify with 2x crops across the wiggle range. **DONE R12.**

## Round 13 — DONE R13: voice consistency, lag, loading state, "pretend that" in play — see decisions/round13-voice-latency.md
## Round 14 (UI, after 13) — Haylee's full-game test 2026-11-14 ~01:25 — DONE R14 (decisions/round14-ui-fixes.md)
1. STAGE OFF WITH CHAT OPEN: with the chat open the stage floor is cut off on the left / Nutmeg sits low and to the left (see her screenshots: conversation, sleeping, checklist-chat, hand-off-chat). Fix the chat-open preset so Nutmeg and the floor are centered in the stage area left of the panel with the floor fully in frame, same proportions as chat closed. **DONE R14.**
2. SLEEPING LOOKS FLOATING: in the sit/asleep pose she appears to float (feet/bottom not on the floor; shadow mismatch) and the clipboard lies on the floor far away. Ground the sit pose on the floor with a matching shadow. **DONE R14.**
3. THINGS GOT SMALLER: the kit pages (print step), the active prop card, the checklist, the pass-the-iPad card and The End are noticeably smaller than before (chat closed). Restore them to their earlier, larger sizes (round 8/10 sizes), keeping one shared card size system. **DONE R14.**
4. CHECKLIST IN THE CHAT PANEL: Haylee doesn't like how the pinned list looks/behaves. Replace with TABS at the top of the chat panel when there's a checklist (or hand-off): "Checklist" | "Chat". Checklist tab shows the full-size checklist (no collapsing summary row); Chat tab shows the transcript. Default to Checklist when a scene starts. Also remove the image next to the checklist TITLE (keep pictures only next to each item), everywhere (stage and panel). **DONE R14.**
5. "I'M THE ___" BUTTON SIZE: in the chat panel it's much bigger than on the stage card. Make the stage card and the panel version the same size (use the bigger, readable one consistently, scaled to fit). **DONE R14.**
6. LAST CHECKLIST CUT OFF: "Sunset Closing Time" scene: the title is clipped at the top and the last checkbox at the bottom on the stage card. Never clip: size the card to its content (title can wrap to 2 lines) within the stage, shrinking pictures/padding before text. **DONE R14.**
7. (coordinator) THINKING FACE looked grumpy (closed eyes + frown): use an existing curious face, keep the tilt. **DONE R14.**
## Round 15 (Haylee's test of round 14, 2026-11-14 morning) — DONE R15 (decisions/2026-11-14-round15-skip-kit-checklist-curtains.md)
1. "DON'T HAVE" TWICE: the second tap moved the card aside in silence. She must reassure out loud ("That's okay, we'll just pretend that..." + a quick substitute), then the next prop; one reply, in the chat. **DONE R15** (a tap during her running reply lost its request; fixed in ResponseGate/RealtimeSession).
2. KIT COMMENTARY ALWAYS THE SAME: 30+ lines per real page kind, random, no repeats, only about pages being made. **DONE R15** (42 lines).
3. CHECKLIST CHECK-OFFS: short varied "good job" + next step; overall congrats on the last check or an early Done!; one reply per action, no overlap, in the chat. **DONE R15.**
4. FLOOR IN FRONT OF THE CURTAINS (The End, any pulled-back camera): curtains/valance/tie-backs always above the floor. **DONE R15.**
## Round 16 (Haylee's daughter's test, 2026-11-14 morning) — DONE R16 (decisions/2026-11-14-round16-handoff-speech-repeat.md)
1. NEVER HAND OFF IN SILENCE: whenever a button appears or the screen waits on the kid, Nutmeg says the next step out loud with the real button labels (print ready, hand-off card, checklist appearing, The End; audit found Back to the checklist too). One line, in the chat. **DONE R16.**
2. CHECKLIST "HEAR IT AGAIN": speaker pill (stage card beside Done!, chat panel's Checklist tab under Done!) reads the title + the unchecked steps (all if all checked); cancels a stale cheer, debounced, one reply per tap. No Back existed on the checklist card to move (noted). **DONE R16.**
## Round 17 (Haylee, 2026-11-14 before the freeze) — DONE R17 (decisions/2026-11-14-round17-close-corner-repeat-pill.md)
1. MOVE THE X: the close (X) leaves the control pill for the screen's top-left corner (56 pt white circle, below the valance, above the step rail); same leave warning. **DONE R17.**
2. REPEAT IN THE PILL: speaker button in the X's old slot ("Hear it again"): checklist read-aloud during play (round 16 behavior), else her last line again (same voice, no duplicate bubble); dimmed when nothing to repeat or she's busy. **DONE R17.**
3. REMOVE round 16's checklist "Hear it again" pills (stage card + chat panel tab); Done! back to its round 15 layout. **DONE R17.**

## Round 21 (2026-11-15, Haylee, after testing round 20): DONE (see [decision](decisions/2026-11-15-round21-lag-buttons-keyboard.md))
1. Lag: measured (typed turns 2.1–2.7 s vs round 13's 1.2–1.6 s, from round 19's blocking moderation); moderation now runs in parallel with her reply (typed 1.2–1.5 s, taps 1.6–1.7 s); kit art decode off the main thread. **DONE R21.**
2. Choice buttons (confirm, color) at the top of the stage, her close-up clear of them. **DONE R21.**
3. Keyboard: chat scrolls to the bottom, Nutmeg never rezooms (window-resize cause), no keyboard bounce after send. **DONE R21.**

## Round 20 (queued 2026-11-15, Haylee): DONE (see [decision](decisions/2026-11-15-round20-color-prefetch-settings-cost.md))
1. **Color choice:** before the kit is made, Nutmeg asks: full color, or color it yourself? With full color, the image prompts ask for full-color art (no line-art-only instructions). With "color it yourself", keep the current thick-outline coloring pages. Big buttons plus voice.
2. **Shorter kit wait (Claude's proposal; Haylee to confirm):** ask the color question right after the round 19 confirm step, before roles, so the kit can start generating **in the background during the prop hunt**. Badges, sign, money, tickets and menu don't depend on which props are found. Only the cut-outs for skipped props wait until the hunt ends. Also fire the image calls in parallel. When the kid reaches Print, most pages should already be done, and the remaining wait keeps the existing commentary.
3. **Remove the settings button** (the parent gear and ParentSettingsView). Lock in the current defaults, so demo users can't change anything.
4. **Roles → props wording (Haylee):** after naming the roles, Nutmeg no longer says "Pick who's who!". Instead she says a short transition such as "Now it's time to hunt for props!", then shows the first prop card, points, and talks about it. This replaces the role-wording rule in decisions/2026-11-13-conversation-rules-late.md ("We need a X, a Y… Pick who's who!" becomes "We need a X, a Y… Now it's time to hunt for props!"). Update the prompts, any app-written lines and the tests that expect "Pick who's who".
5. **Cost saver: stable Realtime tools (Haylee, from research/2026-11-15-cost-per-game.md lever 1):** send the identical `tools` array and stable instructions on every Realtime session/response, so OpenAI's prompt cache applies. Any per-step guidance goes in a later message, not the cached prefix. Expected about -$0.45 a game. Verify with `response.done` usage (cached_tokens) in a live run, and log only the token counts, never content.
6. **Cost saver: cheaper images (Haylee, lever 3):** lower the image quality (try "low", compare against "medium" on a sample kit, and keep low only if lines stay crisp enough to color), and/or draw all the cut-outs as ONE image sheet instead of 6–8 separate images. Expected about -$0.30–0.50 a game. Show Haylee before/after sample pages.

## Round 19 (2026-11-15, Haylee): DONE
1. Crayon movement back: crayon + fingers rock together around the wrist. **DONE R19.**
2. Corrections update everything (one title source, set_* re-callable at any step, kit remade at print) + recap/confirm step with Yes / Change buttons. **DONE R19.**
3. Any tap that moves on stops her speech (every response cancelled by id, player cleared, chat line cut); New game goes home silently. **DONE R19.**
4. Kid-safety guardrails: instructions, local filter + OpenAI moderation on kid and generated text, image safety suffix + moderation auto, relay /v1/moderations (needs redeploy). **DONE R19.** See [decision](decisions/2026-11-15-round19-crayon-corrections-bargein-guardrails.md).

## Round 22 (queued 2026-11-15, Haylee)
1. **The Repeat button's icon doesn't read as "repeat".** Use a clearer replay icon in the control pill (for example SF Symbol `arrow.counterclockwise` or `arrow.trianglehead.counterclockwise`; pick what reads as "again" for a 4-year-old) and keep the "Hear it again" accessibility label. **DONE R22** (speaker inside a counterclockwise replay ring).
2. **Sleeping Nutmeg sits ON her clipboard.** In the sit/doze pose the clipboard layer lands under her seat. Reposition the sit-pose clipboard (layer transform or alignment only, no art redraw) so it rests beside her or leans on her lap, not under her. **DONE R22.** See [decision](decisions/2026-11-15-round22-repeat-icon-sleep-clipboard.md).

## Round 25 (2026-11-15, Haylee, after testing a replay): DONE (see [decision](decisions/2026-11-15-round25-no-draw-checklist-fix-end.md))
1. Remove the no-printer Draw it! path entirely (printer question, Draw it! card, Save printables, Draw it instead, DrawGuide, set_printer/draw_step). Every game prints. Add back only if lots of feedback about no printer. **DONE R25.**
2. The step is "Print" again with a printer icon (was Paper + crayon). **DONE R25.**
3. The "x" checklist bug (one scene titled "x", props in no step) and 3b (replay 1 → 2: no checklist for the second player): same root cause, a cut-short guide kept by a non-fatal check. `GuideRepair` + a retry. **DONE R25.**
4. The End: no Back to the checklist; the rail's Play step (finished, ↺) goes back; voice too. **DONE R25.**
5. Fewer buttons (obvious ones): replay Print = Print everything / Just the badges / Let's play!; replay Props = one toggle per card. **DONE R25.**
6. Button audit screenshots for the next conversation: /tmp/pt-buttons/sheet.png + inventory.md. **DONE R25.**
7. (Mid-round) Her voice wasn't as high: the mixer → output link was 44.1 kHz on a 48 kHz session (effective rate 1.10 on the old and new builds); now wired at the hardware rate (1.20). **DONE R25.**
Next: the full button audit with Haylee.

## Round 24 (queued 2026-11-15, Haylee): DONE (see [decision](decisions/2026-11-15-round24-props-sense-printer-path.md))
1. **Props must make sense (bug):** a bowl was suggested "as a pirate map". Add guardrails so each household item → pretend-use pairing is plausible by shape or function (a bowl can be a helmet, a steering wheel or a treasure bowl; a map should be paper, a towel or a pillowcase). Claude's proposal:
   (a) Extend PropLibrary with each household item's plausible pretend uses (shape/function tags: round, flat, long, soft, container, wearable, sheet-like…), and match each pretend need to items with compatible tags.
   (b) Claude's schema adds a short kid-friendly "why it works" reason ("A bowl is round like a captain's hat!"), and the validator rejects pairs whose tags don't fit, then retries once and falls back to a curated pair.
   (c) Nutmeg can say the reason when presenting the card.
   Tests: a table of good and bad pairs. **DONE R24.**
2. **Printer question + no-printer path (Haylee, 2026-11-15):**
   - **Ask early:** right after the confirm step, before the color question, Nutmeg asks "Do you have a printer?" (Yes / No buttons plus voice).
   - **Yes:** the color question and the normal kit (round 20 flow).
   - **No:** skip kit IMAGE generation entirely (it also saves cost). Claude writes a VERY SIMPLE draw-your-own guide instead: one or two shapes per piece that a 4-year-old can draw ("Draw a big star. Write a 1 in the middle." / "Draw a circle and color it gold for a coin"), with at most about 5 pieces.
   - **The Print step becomes "Draw it!":** Nutmeg walks through each piece one at a time, with a simple built-in icon of the shape (reuse the PrintSymbols/PropLibrary icons, no AI images), Next/Repeat buttons, and voice. It's much simpler than the printed kit.
   - **"Save printables for later" button** on that step: generates the normal kit and opens the share sheet (Save to Files / send to a grown-up) to print elsewhere.
   - The App Store copy says "Works best with a printer; no printer needed."
   - Tests for the state machine and the simple-guide schema limits.
   **DONE R24** (App Store copy line still to write when the store listing is made).

## Round 23 (2026-11-15, Haylee): DONE
0. Repeat uses Haylee's own "Hear it again" icon (Figma cleanup, vector template asset). **DONE R23.**
1. Players 1–6 with a cheerful cap line; badges = exactly the player count; one $1 bill page and $1–$5 menu prices. **DONE R23** ("More money" built, then removed by Haylee).
2. Back-navigation: picture step rail with go-back marks, voice go_to_step (tool-first after the hunt). **DONE R23** (Print again buttons built, then removed by Haylee: the rail is enough).
3. Mid-round (Haylee): steps renamed Pick · Props · Paper · Play (paper + crayon icon); no Skip on the props grid; no arrows on prop cards; she no longer points at an empty card zone. **DONE R23.** See [decision](decisions/2026-11-15-round23-icon-kit-fixes-backnav.md).

## Round 27 (queued 2026-11-16, Haylee): kit in both styles + bookshelf covers
1. **Generate every kit page in BOTH full color and outline** (two separate image calls per page, both during the prop hunt, parallel ≤3, with the existing safety suffix and moderation). Cost is about +$0.07 a game at low quality. **DONE R27** (measured +$0.15 a game: ~2.2¢ an image).
2. **The Print screen shows both sets side by side** (the color fan and the outline fan). The kid/grown-up taps one to choose, then prints. Voice works too ("color" / "we'll color them"). Pages still drawing show as in progress. The replay Print screen offers the same choice. **DONE R27** (the sets are stacked in the card zone, Claude's call: see the decision).
3. **A bookshelf cover image per game:** one extra full-color square image of the game's scene, with NO text in the image, generated during the hunt and kept only if the game is saved. All bookshelf cards use the cover (the same size for every game), with the name on the shelf-edge label. Fallback: the color sign page. **DONE R27.** See [decision](decisions/2026-11-16-round27-both-styles-covers.md).
4. **Update the iPad and iPhone mockups** to show cover cards on the bookshelves.
(Round 26 removed the color question; the kit defaults to outline until this round.)

## Round 29 (queued 2026-11-16, Haylee): Grown-ups menu restructure
The Grown-ups page (behind the gate) becomes a MENU of rows; tapping one opens its own screen:
1. **Saved games:** a list of just the games (cover thumbnail, name, date, size) with delete and confirm. It scales to many games (scrolling list, optional search/sort if long).
2. **Manage subscription:** opens Apple's subscription management sheet (StoreKit `showManageSubscriptions` / `AppStore.showManageSubscriptions(in:)`), with a friendly empty state until plans exist.
3. **Restore purchases:** `AppStore.sync()` with a result message (StoreKit 2; no products yet, so it just reports nothing to restore).
4. **Privacy policy:** opens pretendthat.app/privacy (a new page on the site; Claude drafts it from the real data practices: no accounts, no kid data, game content only on device/iCloud later, the relay forwards to OpenAI/Anthropic, nothing logged). External links stay behind the gate.
5. **About what we save:** the current plain privacy copy, on its own screen.
6. **Terms of use:** Apple requires terms for subscriptions (the standard Apple EULA link or our own page on the site).
7. **Help & contact:** a support email or page (needs Haylee's support address).
Rows for E (subscription and restore) become fully functional when the paid app is built; this round adds the structure and the Apple sheets.

## Next after round 28 (Haylee, 2026-11-16): re-measure the cost per game
Measure the REAL cost per new game on the current build: typed live runs of 2–3 full games (3 and 5 players, one skipped prop), plus one replay. Count Realtime tokens (text/audio in/out, cached), Claude tokens, image calls (both styles plus the cover) and moderation calls, using `response.done` usage and the API usage fields (counts only, never content). Price them with the CURRENT official prices (claude-api skill for Claude; OpenAI's pricing page, cited). Compare against research/2026-11-15-cost-per-game.md. Then a side-by-side test of the smaller realtime voice model (report only, no switch). Output: research/2026-11-16-cost-per-game-v2.md, plus the margin table for Show Pass and Season Pass, monthly and yearly.

## Round 29a (queued 2026-11-16, Haylee): hand-off art: **SUPERSEDED by [ensemble scenes](decisions/2026-11-16-ensemble-scenes.md), built in [round 29](decisions/2026-11-16-round29-ensemble-scenes-build.md)** (no hand-off card; the character crop moved into the scene rows; the 4-steps-per-role play structure below is replaced by 3 scenes × one task per role)
- The hand-off card shows the role's badge as a full badge (lanyard frame + two blank name boxes), which looks odd. Instead show ONLY the character illustration from the color badge: crop it to the art between the blank boxes (no badge frame, no blank fields). Remove the white rectangle card too: the character art floats on the stage (soft rounded edges or a circle crop with a gentle shadow; Claude's call), with the green ✓ below it and the small role name. Fallback is the role color chip.
(Waits until the cost-measurement agent finishes, since it uses the same simulator and build folder.)
- **Play structure (Haylee, 2026-11-16), which replaces round 28's 4 scenes × 2 steps:** each role's checklist has **4 steps**. With 2 or more players, cycle through every playing role **twice** (2 scenes × each role's 4-step turn). With **1 player**, give **3 checklists of 4 steps**. Generate 3 scenes × 4 steps for all 6 ranked roles, so any count from 1 to 6 works with no AI call: multi-player uses scenes 1–2, solo uses scenes 1–3. GuideRepair and the real-props validator keep applying. This is about 50% more guide text (72 vs 48 steps); measure the Claude cost change.

## Round 30 (queued 2026-11-16, Haylee): step tabs in the chat panel
The chat panel gets a step tab on every step, like Play's Checklist | Chat:
- **Props:** a **Props | Chat** tab pair. The Props tab lists the hunt's props as cards (the current one highlighted with ✓/✗; found ones checked; missing ones showing their pretend stand-in), updating live as they're checked off.
- **Print:** a **Print | Chat** tab pair. The Print tab holds the full print panel: both sets (color and outline) with the selection, the pages, the 🖨️ printer and the ▶ play button, roomier than the stage card.
- **Play:** the round 29 Scene | Chat (the scene rows with 🔊 and Next scene).
- **Pick:** Chat only (nothing to show), unless a saved-game replay shows the cover.
- Opening the panel defaults to the step tab; the transcript is one tap away. With the chat open, the stage hides its duplicate card (as round 14 did for the checklist). Kid-sized tabs with icons.
(Starts after round 29, which is reworking the Play panel.)
- **Props per game (Haylee, 2026-11-16):** a firm **4 props for 1–2 players and 5 for 3+** (today it's 3–5, often 3). Update the prompt/schema limits, the hunt and the tests.
- **Prop anti-repeat (Haylee, 2026-11-16):** remember the prop IDs suggested in the last ~5 games (UserDefaults; prop IDs only, never kid data, like Suggestions does for game ideas) and steer the prop prompt/selection away from recent ones (prefer unused props that fit). Tests.
- **New prop art (in progress):** about 28 new household props are being generated in ChatGPT (two sprite sheets). Once vectorized: slice, add them to the library with shape/function tags and plausible pretend uses (paper → map, paper towel tube → telescope/microphone, etc.), and verify.
- **URGENT before any release/TestFlight build (from the compliance research):** Release builds must NOT include personal keys. project.yml uses Relay.xcconfig for Release, and that `#include?`s Secrets.xcconfig, so OPENAI/ANTHROPIC keys would ship in the app and bypass the relay. Fix: a separate Release xcconfig with only RELAY_HOST/RELAY_TOKEN (no Secrets include), plus a build-phase check that fails a Release build if OPENAI_API_KEY or ANTHROPIC_API_KEY is non-empty in Info.plist. Debug keeps personal keys for dev.

## Round 31 (queued 2026-11-16, Haylee): on-device speech · **built 2026-11-16, see decisions/2026-11-16-round31-on-device-speech-build.md (accuracy + recognizer time still to check on the iPad)**
See decisions/2026-11-16-on-device-speech.md. Kid audio is transcribed on the device; only text goes to the Realtime session as text turns; Nutmeg's voice output is unchanged. Starts after round 30.
- **Mic press feels delayed (Haylee, 2026-11-16):** the recording state shows late after pressing the mic. Show it INSTANTLY on touch-down (optimistic UI: the red/listening look and a haptic tick), and start or warm the audio input in parallel. Keep the input engine pre-warmed while the game is open so capture starts at once. Buffer from touch-down so the first syllable isn't lost. Measure touch-down → visible state (target under 50 ms) and touch-down → first captured audio, before and after. (Part of round 31, since it reworks the mic pipeline.)

## Autonomous run plan (Haylee, 2026-11-16, while away)
Once round 29 and the cost measurement finish, run these back to back, one build agent at a time (each starts when the previous is checked, pushed and installed):
1. **Round 30:** release-key safety, the chat panel step tabs, 4/5 props, prop anti-repeat, the 30 new props wired in.
2. **Round 31:** on-device speech (text-only turns) plus the instant mic press.
3. **Round 32 (DONE 2026-11-16, see decisions/2026-11-16-round32-grownups-menu.md):** the Grown-ups menu restructure (Round 29 spec above: Saved games, Manage subscription (Apple sheet), Restore (AppStore.sync), Privacy policy link, About what we save, Terms, Help & contact → pretendthat.app/support). Add a /terms page on the site if needed (Apple standard EULA link plus a short page).
4. **Round 33:** parent onboarding per research/2026-11-16-onboarding-research.md and Haylee's decisions: the gate on screen 1, how it works, private by design plus REQUIRED AI consent (decline → explain it's needed and how to enable it later in Grown-ups), the mic explainer, then the plans screen (Free Preview the main button; Show Pass/Season Pass shown but purchase wired later with StoreKit), and the hand-off. Nutmeg speaks only on screen 1 and at the hand-off. Replayable from Grown-ups.
Everything else (StoreKit, compliance items, iCloud, iPhone) waits for Haylee.

## Round 34 (queued 2026-11-16, Haylee): replay prop lines
- On a replay's Props step, Nutmeg says "Next, do you still have…?" for every item, which is repetitive. Instead, replays use the SAME prop lines as the first play ("Can you find a plate? It'll be the steering wheel!"), ideally the exact recorded clips from the first play (D3b), so it sounds identical and costs nothing. Never ask "do you still have".
- Drop the repeated "Next," lead-in on BOTH first plays and replays. Vary the connectors (or none): for example "Can you find a chair? It'll be the plane seats!", "Ooh, a chair would make great plane seats. Can you find one?" The app-written/scripted hunt lines rotate a few phrasings; the first line can keep "First,".
- Make sure first-play prop lines are recorded as clips keyed by prop+use, so replays reuse them (a new prop/use on a replay, e.g. an alternate, is said live once and then saved).
- **Same look on replays (Haylee, 2026-11-16):** replays must LOOK identical to new games, especially for kids, with nothing moving. The replay Props step should use the exact same prop card component, position, size and ✓/✗ buttons as the first-play hunt, with the same done-prop stack, the same Props | Chat tab and the same camera/pose. Audit every step (Pick, Props, Print, Play, The End) side by side, new game vs replay, with screenshot pairs, and remove any replay-only layouts. Differences allowed only where the content truly differs (e.g. Pick on a replay shows the cover and asks the count by voice).
- **In-app speech model download (Haylee, 2026-11-16):** replace the "go to Settings › Dictation" note. On iPadOS versions that support it (the SpeechAnalyzer/SpeechTranscriber + AssetInventory APIs, iOS 26+), the app downloads the on-device English model itself via a friendly one-tap grown-up screen with progress ("Nutmeg needs to learn to listen, one time, about a minute on Wi-Fi"). Start the download quietly during parent onboarding at the mic step, so it's usually ready before the first press. Only older OS versions fall back to the Settings instructions. (The simulator can't load the model; verify on the real iPad.)
- **Scene tasks: short and broad on screen, specifics spoken (Haylee, 2026-11-16):**
  - Each role's ON-SCREEN task is SHORT and BROAD (about 3–7 words), e.g. "Get the pet ready to go home".
  - The 🔊 SPOKEN version adds 1–2 concrete example ideas using their props/kit, e.g. "It's time to get the pet ready to go home! You could write its name on the Pet Visit Pass and hand over the leash."
  - The guide schema gets two fields per role task: `short` (shown) and `say` (spoken). GuideRepair enforces the length of `short` and the real props in both.
  - Scene open: Nutmeg does NOT read every role's task. She says the scene setup ("Pretend that…") plus a brief cue ("Tap your speaker when you're ready to hear your job!"), and each kid taps their own 🔊 to hear their `say` line.
  - Repeat (the pill) re-says the setup and cue, not all the tasks. Voice "what do I do, Pet Trainer?" can read that role's `say`.
- **Whole scene row is tappable (Haylee, 2026-11-16):** tapping ANYWHERE on a role's row (character picture, task text, or 🔊) plays that role's spoken task, not just the speaker button. Give it a clear pressed state and keep the 🔊 as the visual cue. The row is one big accessibility element ("Hear the Pet Trainer's job"). Apply the same "whole card is the target" rule wherever kids tap (prop cards: the card's ✓/✗ stay separate; scene rows; Print set cards).

## Round 35 (queued 2026-11-16, Haylee): ship the cost cuts
- Turn on the mini realtime model for scripted sayExactly lines (round v3 `-PTMiniLines` becomes the default); clip keys include the model.
- **VOICE MATCH IS A HARD REQUIREMENT (Haylee):** in the v3 A/B samples, the mini clips used the WRONG voice. The mini session must use the exact same voice (coral), the same voice-style instructions (Realtime.voiceStyle) and the same VoiceConfig as the main session, and ALL mini audio must play through NutmegSpeaker at Varispeed 1.20, exactly like the main model. Add a single source of truth for the voice settings (one VoiceConfig used by both sessions; a unit test that fails if they differ), and an offline render test that mini lines play at 1.20. Before turning it on, regenerate the A/B samples THROUGH THE APP'S REAL PLAYBACK PIPELINE (captured output, at 1.20) into design/voice-ab-v2/ for Haylee to approve by ear; don't ship mini until she approves.
- Route the play guide and per-prop weave Claude calls to claude-sonnet-5-5 (`-PTClaudeModels` becomes the default); kit pages stay on Opus.
- Relay: add `claude-sonnet-5-5` to CLAUDE_MODELS and the mini realtime model to the client_secrets allow-list (second secret type if needed); tests; Haylee redeploys.
- Re-measure the cost per game after round 34's shorter scene openings plus these cuts.

## Onboarding v2 (Haylee, 2026-11-16, after trying round 33)
- **No grown-up gate at the start** (Haylee): open on "Hi, grown-up!"; the gate stays on the Grown-ups menu and later purchases.
- **Full-screen, step-by-step pages** (like her references: one idea per page, big illustration, short title plus one line, progress dots/bar, Back, a big Next button), NOT a dialog over the home page. Use Nutmeg poses/scenes as the illustrations, in the theater style.
- **After the hand-off:** either go STRAIGHT into the first game (the stage, Nutmeg visible and talking), or "Go to the home page" with NO talking. Never voice without visible Nutmeg.
- **The voice sounded different during onboarding:** check the bundled onboarding/greeting clips (recorded with the right voice? played at 1.20 through NutmegSpeaker?). Haylee hears changes on the device that the simulator measurements didn't show.
- Mockup first for Haylee's approval, then build.

## Overnight plan (Haylee, 2026-11-16, before bed). Build rounds one at a time, in order
1. Merge/push/install round 34 when it lands.
2. Round 35 prep + onboarding voice fix: mini voice + Sonnet guide/weave BEHIND A FLAG (off); A/B v2 samples through the real pipeline (coral, 1.20) in design/voice-ab-v2/ for Haylee's ear; fix the onboarding voice difference.
3. Onboarding v2 per design/mockups/onboarding-v2/ pages 1–7 (one-page How it works; Haylee approved). No gate at start.
4. Compliance: PrivacyInfo.xcprivacy, ITSAppUsesNonExemptEncryption, "Report this" for AI content, Nutmeg's computer-helper disclosure, privacy-policy additions as a site draft (not published).
5. StoreKit subscriptions (Free Preview / Show Pass / Season Pass, intro prices, local .storekit file) + relay anonymous show-count code (Haylee deploys).
6. Analytics: TelemetryDeck (anonymous counts, no IDs, nothing about kids), ready for Haylee's app ID; plus Apple App Store analytics (no code).
7. iPhone version (last; touches most screens). Mockups in design/mockups/iphone/.
Waiting on Haylee: voice approval by ear, relay redeploy, TelemetryDeck app ID, paid dev account.
- Step 2 addendum (voice investigation, research/2026-11-16-onboarding-voice-investigation.md): onboarding clips are fine and play at 1.20; the difference is onboarding's own engine + `.playback/.spokenAudio` session vs the game's `.playAndRecord` 48 kHz path. Fix: play onboarding through NutmegSpeaker / the game's session setup (no mic prompt before the Mic page). ALSO remove the leftover system-TTS fallback (`AppModel.speak`, `repeatTapped`): Nutmeg must never use system TTS.

## Round 36 (queued 2026-11-16, Haylee): story opener + setup scene + clean-up scene. Overnight step 3b (after onboarding v2)
Game arc becomes: Print → **story opener** → **setup scene** → 3 play scenes → **clean-up scene** → The End.
- **Story opener** (after printing, before the first checklist): Nutmeg tells a short story (~15 s, 3–4 sentences): where we are, who they are, what's about to happen. Nutmeg on stage, voiced.
- **Setup scene (always scene 1):** one quick task per role that walks them through setting up with their props AND the printed/cut pieces. **Every prop and every printed item must be used intentionally, with a clear purpose; nothing random or unused** (Haylee). Validate in code: every found/swapped prop and every kit page is referenced in the setup tasks (or, if more items than roles, later scenes); regenerate/repair if not. Kit pages should be generated with a purpose that the setup scene then uses.
- **3 play scenes** unchanged (they play with what they set up; tasks may refer back to set-up items).
- **Clean-up scene (always last):** in-story framing ("the bakery closes for the night: put the bowls back in the kitchen"), one quick task per role; puts real props away.
- Keep setup and clean-up short (one easy task per role) to limit game length.
- Replays: story + setup + clean-up lines recorded and reused like other clips (replay parity).
- Cost estimate: +$0.05–0.10 per new game (3 extra voiced lines; guide tokens < 1¢); replays ~free. Re-measure after.
- Marketing: "it even helps them clean up" for the App Store page / site (draft, don't publish).

## Auto-save round (queued 2026-11-17, Haylee: auto-save for everyone, experience approved, NO cap on saved games): DONE in round 39 (see [decision](decisions/2026-11-17-round39.md))
- Count the show when the kit is made, not at Let's play! (decisions/2026-11-17-autosave-and-count-at-kit.md).
- Save every new game automatically when the kit is made; update the save as play goes (recorded lines, cover).
- No Save button anywhere and no "save?" question on leaving.
- The one moment: when the kit is ready, the game's cover card shrinks and slides into a small bookshelf (picture, no words) and Nutmeg says one short line ("I put it on your bookshelf!"). Same for every game.
- The End: star button removed; Play it again + Home. Nutmeg mentions the bookshelf.
- Leave dialog (X): before the kit, as today (nothing counted, nothing saved). After the kit: shows the game's cover going onto the shelf; Keep playing / Leave. Drop "you'll start a new game next time".
- Bookshelf: a game left halfway looks the same as a finished one; replays start at the beginning.
- "Sounds like a game you have" (Haylee): at the Pick confirm ("Yes, let's go!"), before anything is made or counted, match the game type + theme against saved games on the iPad (no AI call). If one is close, show its cover card and Nutmeg says "We already have <title> on your shelf! Want to play that one?" Two big picture buttons: play that one (replay) / make a new one. Suggest, never block.
- No cap on saved games (Haylee). Grown-ups → Saved games shows how much space they take.
- Grown-ups → Saved games (Haylee): checkboxes are ON by default (no Select button); check games, press Delete (with a confirm) as the main experience. Add a "Last played" sort next to Newest / Name, each row shows its size, and a search bar by name (grown-ups only; the kids' bookshelf stays pictures + arrows).
- Bookshelf order (Claude's suggestion, Haylee may veto): most recently played first (lastPlayedAt), so favorites stay up front; no search or filters.
- Testing: demo mode, no keys (CLAUDE.md rule 7).

## Voice pitch round (queued 2026-11-17, Haylee: Signalsmith plain +2)
- NutmegSpeaker: Varispeed 1.20 → Signalsmith Stretch +2 semitones (formant preservation OFF) for live lines. Add Signalsmith Stretch + Signalsmith Linear (MIT) as a dependency; credit them in Grown-ups → About.
- Clips (bundled and recorded) get their own per-clip adjustment toward the target pitch so they're never raised twice; add a pitch check for every clip.
- Reset the shifter on cancel and barge-in; flush at line end; keep lip sync aligned (about 60 ms added).
- Render reference: design/voice-pitch-test-2/ (plain Signalsmith +2). Research: research/2026-11-17-voice-pitch-test-2.md.
- Testing: no live games needed beyond one at most (CLAUDE.md rule 7); compare the offline render against the in-app output. Haylee listens on the iPad before it's final.

## Bug: 10-second pause after "found it" (queued 2026-11-17, Haylee: fix it): FIXED in round 39
- After a spoken or typed "found it", the next prop line waits about 10–11 s. Cause (from the Claude-brain spike): `sayAppPropLine` waits up to 10 s while the session is busy, and the busy state stays on after a tool-first pass with no spoken follow-up. Card taps don't hit it. Seen in every recent log. Details: research/2026-11-17-claude-brain-spike.md.

## Brand round (queued 2026-11-17, Haylee): Poppins on the grown-up side: APP PART DONE in round 39 (the site is still to do)
- App: bundle Poppins (OFL; ship the license text); onboarding + Grown-ups use Poppins (headings SemiBold 600 with tight letter spacing, body Regular/Medium) with Dynamic Type; kid screens unchanged. Credit in About.
- Site (separate repo /Users/haymcarthur/pretendthat-site): rebuild with Tailwind + a component kit, Poppins, layout from Haylee's Figma examples (illustrated hero with phone, colored story bands, 3-up cards, FAQ, big closing CTA, chunky footer). Decision: decisions/2026-11-17-brand-font-poppins.md; sampler: design/brand-fonts/.

## Small fix: writing hand's shadow moves with the hand (queued 2026-11-17, Haylee: only if low risk): SKIPPED in round 39 (the shadow is in the body art, not the fingers layer; see the decision)
- In the coloring/writing pose the crayon + `nutmeg-writing-fingers` layer rock around the wrist (NutmegCharacter `crayon(t:px:)`, `writingRock`). The fingers layer includes the dark shadow on her purple shirt, so the shadow moves with the hand and the shirt line misaligns.
- Fix: move the shadow paths (unchanged) out of nutmeg-writing-fingers.svg into a separate static layer drawn at the same place without the rock. No redrawing, so it stays within the art rule. Check: a still frame (rock 0) is pixel-identical before and after; moving frames keep the shadow fixed. If it can't be done without touching the art itself, stop and report.

## Chat sheet on the iPhone (queued 2026-11-17, Haylee, from her iPhone 18 Pro screenshot): DONE in round 40 (see [decision](decisions/2026-11-17-round40.md))
- When the chat is open, hide the control pill (repeat / mic / chat). Today it sits on top of the "Type to Nutmeg" field. Closing the chat (the chevron) brings the pill back. Claude's call: hide it, rather than moving it, because typing is the chat's input and the mic is one tap away after closing.
- The chat becomes a shelf: edge to edge, no side margins, attached to the bottom of the screen (rounded top corners only). It still starts under the X + step rail.
- Nutmeg's live head in the chat header: crop it to her FACE so her mouth is clearly visible while she talks. The ears can be cut off; the circle can be just her face. Lip sync must stay visible. Apply the same crop wherever this live head appears.
- Scope: iPhone layout. The iPad chat panel stays as it is unless Haylee says otherwise.

## Setup scene rows: goals, not item lists (queued 2026-11-17, Haylee, after her first iPhone game): DONE in round 40 (see [decision](decisions/2026-11-17-round40.md))
- What she saw: with 2 players the setup rows were still too granular ("Hang up the sign", "Put out the chart"), and they mentioned only printed things, no household props. With 4 players the rows were bigger ("Set up the tickets and bed"), which is closer, but the labels still read as lists of items.
- Want: each row is a short GOAL in the game's world, e.g. "Get the pet room ready". The specifics come in Nutmeg's spoken line for that row (the speaker button, or when she reads the checklist): "Get the pet room ready by hanging up the sign and setting up the pet bed."
- Every household prop AND every printed item must be used on purpose in some row's spoken specifics. This is Haylee's standing rule, and the code check from round 36 must cover props too. A 2-player game must mention its props.
- Row count: roughly one goal per role. A solo or 2-player game gets a few goal rows, not many small ones. This replaces round 37's max-2-items-per-row and real 2–7 word item labels; labels become goals of 2–6 words.
- Replays keep the saved rows and recorded lines (replay parity). The same applies to the clean-up scene ("Close up the clinic" plus spoken specifics).

## Bug: replay Pick card cuts off the bottom of the game cover on iPhone (queued 2026-11-17, Haylee): FIXED in round 40
- On a replay, the Pick step's cover image (e.g. the sea-clinic scene) is cropped at the bottom in its card on the iPhone. Show the whole cover (fit, or size the card to the cover's aspect ratio). Check the iPad too.

## iPhone stage looks odd when Nutmeg is shrunk (queued 2026-11-17, Haylee, screenshot of a setup scene): DONE in round 40 ("settle" shipped; zoom-out compared, see the decision)
- What looks off when she shrinks to make room for a card (Claude's read of her screenshot):
  - Her round platform floats in the middle of the screen.
  - The sky backdrop ends in a hard line at her feet, with a big flat tan floor below.
  - The curtain tie-backs peek out halfway down, behind the card's edges.
- Want: the stage reads as one whole scene at every size. Nutmeg can shrink, but the backdrop, floor, platform and curtains stay composed: the horizon sits where it naturally would, the platform is in scale with her, and the tie-backs are either visible in a sensible spot or hidden, never half-covered.
- Options for the builder to compare in screenshots: scale the whole stage scene with her (camera zoom-out) rather than shrinking her inside a fixed scene, or have the card cover the lower stage cleanly. iPhone only; iPad unchanged. Show before/after for a setup scene (4 rows), a 2-row scene, the hunt card and The End.

## Writing hand: proper fix (queued 2026-11-17, Haylee chose the proper fix over shrinking the rock): DONE in round 41 (the simple fix: the one shadow path in its own static layer; new body not needed, see [decision](decisions/2026-11-17-round41.md))
- **FOUND IT (2026-11-17, Haylee's eye, confirmed by Claude):** nutmeg-writing-crayon.svg contains ONE dark purple path (fill #470D62, the vest-shadow color). That is the shadow cast on her vest, and it rocks with the crayon, so the shadow and the vest line move with the hand. Simplest fix FIRST: move that one path, unchanged, out of the crayon SVG into a new static layer (e.g. nutmeg-writing-crayon-shadow), drawn in the same place right under the crayon, with no rock. Check before/after frames at −3.2°/0/+3.2° (the still frame must be pixel-identical). If that alone looks right to Haylee, the new-body work below is NOT needed; keep it only as a fallback.
- Round 39 found that the "moving shadow" is the rocking fingers + crayon layer uncovering the writing BODY's own paw edge and crease underneath. It is not a shadow inside the fingers layer.
- UPDATE 2026-11-17: Haylee's vectorized new body is at design/export/writing-pose/new-body-writing.svg (same 1178×1335 canvas; the arm ends at the hand, with no paw underneath). The fingers layer is only the FINGERS. The fist and palm live in the old body, which is why the new body + fingers looked like a floating hand. Build it like this: the moving hand group = the old body's FIST paths (moved exactly as they are, with no redrawing, from nutmeg-body-writing.svg into a new hand layer) + crayon + fingers, rocking together around the wrist; the body underneath = the new body. Claude's rough mock (raster clip, not exact) is in design/export/writing-pose/mock-hand-rock-0/1/2.png and shows the idea works: vest under the fist and no hidden paw. Its star fragment and the hard edge at the wrist come from the rough clip only; the real build takes exact paths, keeps the star and belly in the body, and checks the wrist seam at ±3.2°.
- Original plan, for the record: Haylee regenerates the writing body in ChatGPT, then vectorizes it in Figma (art rule). The new body is the same pose, but with no paw under the fingers layer: the clipboard and vest continue where the hand sits, with a clean wrist. The existing fingers + crayon layer stays on top and keeps the same wrist pivot. The builder swaps in the new nutmeg-body-writing, checks that a still frame matches today, and checks that the rock at ±3.2° shows nothing odd.

## Record the new lines as built-in clips (queued 2026-11-17, Haylee OK'd the recording cost): DONE in round 42 (only the new End line, per the no-shelf-moment decision; 1 take in band, see [decision](decisions/2026-11-17-round42.md))
- Record with `-PTRecordCommon` (a few cents) on PT-R15 only, within the pitch band.
- Wording (Haylee approved 2026-11-17):
  - First game ever, shelf still empty: "I'm saving our game, so we can play it again anytime!"
  - Later games: "I put it on your bookshelf!"
  - The End: "The end! What a show! Take a bow! Tap the arrow to play it again, or the house to go home!" ("It's on your bookshelf" is dropped.)
- Record all three as built-in clips. Old saved games that lack the End line keep working: offline, she pauses as before.
- Reference for the writing-hand regeneration: design/export/writing-pose/writing-body-with-hand.png (the headless body + crayon + fingers, as composed in the app) and writing-body-only.png (the body layer alone; it shows the paw under the hand).

## Bug: 4th role button cut off by the curtain tie-back on iPad (queued 2026-11-17, found by the site agent): FIXED in round 41 (two columns for 4–6 roles; iPad 11"/13" + iPhone)
- On the iPad's replay Pick step with 4 players, the 4th role button (role tiles: Captain / Passenger / Flight Attendant / ...) is partly covered by the curtain tie-back. Check 4–6 players on iPad 11" and 13", and on iPhone; keep every role tile fully visible and tappable.

## Bug: Nutmeg too zoomed out on iPad when the chat panel is open (queued 2026-11-17, Haylee, screenshot during Props): FIXED in round 41 (the talking framing with the panel open)
- With the chat panel open on iPad, the stage camera pulls back, so Nutmeg stands small on a big platform. Keep her framed like the normal talking view: zoomed in, with her full body comfortably filling the stage area left of the panel. iPad only; the iPhone chat shelf is handled separately.

## Prop sense + prop variety (queued 2026-11-17, Haylee: the prop audit, "only soft or flat things can be cloths", "box is always used"): DONE in round 43
- Built as decisions/2026-11-17-round43.md: the audit's F1–F6 (cloths need fabric, identity items, swap/replay fixes, prompts), the hard no-repeat rule, and the per-game prop shortlist.

## Suggestions feel stuck (queued 2026-11-17, Haylee): FIXED in round 42 (the returning greeting said only 2; fixed examples removed; last 3 sessions avoided; checked in live logs)
- What she sees: Nutmeg opens with only TWO game ideas ("Maybe a bakery or a doctor's office?") but gives three theme twists, and the twists feel like the same ones every time (e.g. "nighttime under the stars, up in the clouds, or with robots").
- What the code has: NutmegCore/Suggestions.swift holds 42 games and 32 twists. The app samples 3 of each (games at session start, injected into the instructions; twists in the set_game result) and avoids last session's picks.
- Suspects (Claude, not yet verified):
  1. The returning greeting (round 34's short clip, "Welcome back! What should we play today?") means the live follow-up may not use the injected 3 games, so the model falls back to its own classics (bakery, doctor's office) and says two.
  2. The instructions' fixed example line in RealtimeProtocol.swift ("Maybe a hotel, a pirate ship, or a pet groomer?" / "Maybe teddy bears, a pirate island, or up in the clouds?") pulls the model toward the same picks.
  3. The memory only avoids the LAST session's picks, so with a small effective pool repeats come back fast.
- Fix: always say exactly the 3 sampled games and 3 sampled twists (pass them as exact words, or make them app-said lines). Remove or neutralize the fixed examples. Avoid repeats over the last ~3 sessions. Verify in logs over 3 sessions (cheap test: typed turns, at most one live session per rule 7).

## Site follow-ups (2026-11-17, Haylee)
- After the printables overhaul ships, replace the site's Step 3 print fan with pages from the new kit, rendered from a real saved game with the agent's KitPageView harness (scratchpad/ptcopy, -PTNoAI).
- Swap in the four-game bookshelf shots once the two extra cover-only games are ready.

## Printables overhaul (queued 2026-11-17, Haylee approved): DONE in round 45 (decisions/2026-11-17-round45.md)
- Spec: decisions/2026-11-17-printables-library.md + research/2026-11-17-printables-library.md + design/printables-library/index.html.
- Big enough to be a round on its own. Build the picture-only art rule and app-drawn text first (it fixes the double frames on its own), then the library, the per-game shortlists and the variants. Test with no keys via fixtures; at most one live game (rule 7) for a real kit.

## Haylee's answers on round 40 (2026-11-17)
- Keep the soft tinted rows. No done/checked state: the rows aren't checklists anymore, just things kids can listen to. Row counts are right: fewer players get more rows each, 3+ players get one each.

## Bugs from Haylee's fresh-install test (2026-11-17): ALL DONE (1, 3, 5, 6 in [round 41](decisions/2026-11-17-round41.md); 2, 4 in [round 42](decisions/2026-11-17-round42.md))
1. **iPhone chat + keyboard:** when the keyboard opens, the chat shelf rises to sit on top of the keyboard, leaving a gap. The shelf must stay flush with the screen bottom, white behind the keyboard; only the input row moves up above the keyboard.
2. **Props must never be things the kit prints:** Nutmeg asked for "Paper → boarding passes", but boarding passes come from the print step. The prop hunt must never ask for an item whose pretend use is something the kit will print (tickets, passes, money, menus, signs, badges, maps, ...). Enforce in the prompt and in code (cross-check prop uses against kit item types), with a test.
3. **Curtains during a game:** on the start screen the side curtains run to the bottom of the screen; during a game they stop short above the floor. Make the in-game curtains reach the bottom like the start screen (iPhone and iPad).
4. **Remove the bookshelf moment entirely:** no "I put it on your bookshelf!" line, no first-game line, no card-to-shelf animation at kit time. The auto-save still happens silently. The End line becomes: "The end! What a show! Take a bow! This game is saved, so you can play it again later. Tap the arrow to play it again, or the house to go home!" (no "bookshelf" anywhere kids hear it). This replaces the queued wording. Record only this End line as a built-in clip.
5. **Step rail too close to the top** (iPhone), especially the active step's ring. Add breathing room below the Dynamic Island / safe area.
6. **iPad: Nutmeg zooms out during steps with a panel or card** (props hunt, chat panel). She should stay framed like the plain talking view. Same as the queued "too zoomed out on iPad when the chat panel is open" item.

## Rename "show" → "game" everywhere (queued 2026-11-17, Haylee): APP PART DONE in round 44 (see [decision](decisions/2026-11-17-round44.md)); the site is still to do
- App: plans/paywall, Grown-ups → Plans, the kids' "out of new games" line, onboarding, analytics event labels only if user-visible. "Replays" become "playing a saved game again". Keep StoreKit product IDs; update the display names and descriptions in StoreProducts and the .storekit file, and note any App Store Connect text Haylee must change.
- Site: same wording on home, pricing, FAQ, terms and privacy ("new game", "2 free games", "10 new games a month").

## Usage counts: remove the switch (queued 2026-11-17, Haylee): DONE in round 44
- Remove the "Share anonymous usage counts" switch from onboarding and from Grown-ups → About what we save. Analytics are always on (anonymous TelemetryDeck counts), and the About text says so in one line. Migrate existing installs to on. Update the analytics tests. Remove "15–25 min" from onboarding.

## From Haylee's answers on rounds 41/42 (2026-11-17)
- **DONE R44: Chat open = no card on the stage.** While the chat panel/shelf is open, the current card (hunt card, print fans, scene rows) lives only in the chat's own tab (Props / Setup / ...), never on the stage too, and Nutmeg keeps the talking close-up. Verify iPad and iPhone; fix anything that still draws the card on stage while the chat is open.
- **DONE R44: Leave dialog:** remove the little card-going-onto-the-shelf picture (after the kit, and on replays). Just the question and the two buttons.
- **Prop sense:** DONE in round 43 (decisions/2026-11-17-round43.md).

## Round 44 (queued 2026-11-17, Haylee approved onboarding v3): DONE (see [decision](decisions/2026-11-17-round44.md))
1. Onboarding v3 exactly as the mockup design/mockups/onboarding-v3/ (6 pages; spec in ideas/2026-11-17-onboarding-v3.md + decisions/2026-11-17-onboarding-v3-feedback.md), Poppins, purple buttons, no scrolling on the iPhone 17e. Season Pass "30 new games a month".
2. Rename "show" → "game" everywhere in the app (section above).
3. Remove the usage-counts switch (section above).
4. Chat open = no card on the stage; leave dialog without the shelf picture (section "From Haylee's answers on rounds 41/42").

## Relay redeployed (Haylee, 2026-11-17, version 8ed4aa7c): turn on the mini voice for scripted lines: DEFAULT ON in round 44 (the live pitch check is still to do: the one live run used a stale build)
- The relay now allows the mini Realtime model and Sonnet 5.5. SHOW_LIMITS is "off" until the subscriptions exist.
- Haylee approved the mini voice for scripted lines (decisions/2026-11-17-mini-voice-approved.md); the voice now matches 1.20 + Signalsmith +2. Round 44: make `-PTMiniLines` the default (scripted/app lines spoken by gpt-realtime-2.1-mini through the same NutmegSpeaker). Verify with one short live check that the pitch stays in band.
- The Sonnet 5.5 guide/weave (`-PTSonnetGuide`) is still waiting on Haylee's OK (cost v3: saves about $0.09 a game, no quality loss found).

## Round 44 additions (Haylee, 2026-11-17): DONE in round 44
- Yearly intro prices $99.99 (Show Pass) / $199.99 (Season Pass) for the first year: StoreKit config + StoreProducts + Plans/paywall copy (decisions/2026-11-17-yearly-intro-sonnet.md).
- Make the Sonnet 5.5 play guide + weave the default (`-PTSonnetGuide`).

## Next round (queued 2026-11-17, Haylee): home stage polish, after the iCloud round merges: DONE 2026-11-17 (decisions/2026-11-17-home-stage-polish.md)
1. **Logo in front of the curtains** on the home stage, iPhone and iPad. Today the white logo card sits behind the curtain panels (the curtains cover its left and right edges). The logo (and its card, if kept) layers above the curtains.
2. **Grown-ups button → a gear icon only**, tucked into the top corner (iPhone and iPad). No "Grown-ups" text; keep VoiceOver label "Grown-ups" and the same grown-ups check behind it. Clear of the Dynamic Island / status bar and the curtain valance.
3. **Bookshelf (iPhone): Nutmeg sits with her legs dangling**, as in the iPhone mockup screen 7 (design/mockups/iphone/img/nutmeg-sit-perky-focus.svg; the same perky-sit art is already in the app as `onboarding-nutmeg-sit-perky`). Today ShelfView uses the rig's `.sit` pose (knees hugged, the nap sit), which looks glitched perched on the shelf top. Legs hang over the shelf's front edge, clipboard on her lap, looking down at the games. (Encryption key: already done in round 37, ITSAppUsesNonExemptEncryption NO.)
- After this round: retake the App Store home-screen screenshots (the first set shows the old logo and button).

## Marketing site restyle (queued 2026-11-17, Haylee): after she approves the App Store slides
- Restyle pretendthat.app (/Users/haymcarthur/pretendthat-site) to match the App Store images (decisions/2026-11-17-appstore-image-style.md, the "Cheat Day" reference): white backgrounds, one coral accent word per heading (colored text, not pills), light-gray sublines, straight phone frames with real screenshots cropped by section edges, 1–2 floating UI chips with soft shadows, alternating left/right layouts, lots of white space.
- Use the NEW screenshots and the new AI-drawn kit pages (round 46/47) from design/appstore-screens/raw-v2 + cards-v2: hero, the 4 steps (step 3's print fan and step 4's scene card refreshed), saved games, pricing.
- Keep the content, pages, header/footer, Poppins, cache-busting and the no-email/no-tracking rules. Preview before publishing; Haylee approves before it goes live.
- **Site Print section (Haylee, 2026-11-17):** the full-color kit sheets feel like they're from another app and clash with the site. Keep the stack/fan of printables, but make them ALL the black-and-white (outline / coloring-page) versions. Use pages from the new moon bakery game (round 46/47 printables, made by the screenshot agent's live game), not the old Vet Clinic pages. Wait for those pages.

## iPhone play scene: Nutmeg peeks over the scene card (queued 2026-11-17, Haylee): DONE 2026-11-17 (decisions/2026-11-17-peek-and-replay-pick.md)
- On iPhone, when a scene's action rows are showing, Nutmeg is too small (a little figure on the stage above the card). Instead she **peeks over the top edge of the scene card, paws on the card's edge, looking DOWN at the list**, like the logo art (asset `logo-nutmeg-top`: head, shoulders, paws over the letters).
- Looking down: use the rig's head with the **focus face** (eyes down) so she still blinks and her mouth moves when she talks; the peek body/paws come from existing art (logo-nutmeg-top or rig parts). Don't draw or patch art (Haylee's rule: regenerate, never patch). If the parts can't be combined cleanly, report back with options instead of editing art.
- She should be BIG (wider than now, ~60–70% of the card width), centered over the card's title, ears clear of the step rail/top bar.
- Scope: iPhone play scenes only (setup, scenes, clean-up rows). Haylee (2026-11-17): prop hunt and kit-ready screens are fine as they are; do NOT change them.
- **Art is ready:** design/nutmeg/peek/nutmeg-peek-parts.svg (1536×1024, from Haylee's Figma frame 22:2509, extracted read-only, no edits): groups `tail`, `body` (vest, shoulders, star), `head` (ears, face, headset), `paw-left`, `paw-right`. Body is cut flat at the bottom (sits behind the card edge); paws go in front of the edge. Use `body`+`tail`+paws with the rig head (focus face) on top, aligned to where `head` sits.
- After: retake the App Store play-scene screenshot (05).

## Replay Pick: no number tiles, ever (queued 2026-11-17, Haylee): DONE 2026-11-17 (decisions/2026-11-17-peek-and-replay-pick.md; offline replays never block and no plain-paper props are in the same round)
- Haylee: "Even if they don't have internet they can just type in their answer right? So we shouldn't have that screen." Remove the 1–6 tiles from the replay Pick (ReplayScreens.swift, shown today when `model.noVoiceSession`).
- Without a voice session (offline, voice down, no keys), the kid still answers by **typing** (keyboard button) or **speaking** (on-device speech recognition works offline): parse the count **on the device** ("3", "three", "we have four", "me and my sister" = 2 is a nice-to-have; NumberWords exists in GrownUps.swift) and call `replayPick(n)`. Nutmeg's question is her recorded clip, so nothing needs the internet. Out-of-range (0 or >6): her recorded "1 to 6" nudge if one exists, else a gentle text prompt.
- Make sure the chat/keyboard and the mic both work in that state on replays, and that it can't dead-end. Tests for the parser and the no-voice replay path.
- Same round as the iPhone peek-over-the-card change.

## Printables: draw once, color in (queued 2026-11-17, Haylee approved): DONE 2026-11-17 (decisions/2026-11-17-round-plans-printables-page.md; relay redeploy + live check pending)
- Spec: decisions/2026-11-17-printables-draw-once-color-in.md. Test code/prompts: design/printables-match-test/ (scripts/, notes.md, prompts.json; the tuned v2 color prompt). The model rejects `input_fidelity`.
- Relay must allow POST /v1/images/edits (multipart, image input); Haylee redeploys. Keep the badge/ticket draw-6-then-crop flow; the crop works on both versions since they match.
- Guardrails: dark/saturated letter fills only (no cream/white/pale yellow letters, no yellow-on-white), white paper; Vision contrast check per text box + one redraw; word check on the color page; the outline page's word check follows the round 46 rule.

## Plans 5/20 in the app + relay (queued 2026-11-17, Haylee locked): DONE 2026-11-17 (decisions/2026-11-17-round-plans-printables-page.md; relay redeploy + App Store Connect pending)
- decisions/2026-11-17-plans-5-and-20.md. Subscriptions.swift, ParentOnboarding.swift, GrownUps.swift, the StoreKit test config, paywall/plans copy, onboarding pages: Show 5 / Season 20, $9.99 / $99.99 and $24.99 / $249.99, remove intro offers and intro copy. Free Preview copy must say 2 games to try, ONCE ("2 free games to try", never "a month"); check every place the free games are mentioned (onboarding, paywall, Grown-ups, Nutmeg's lines/clips if any say it).
- relay/src/shows.ts plan limits 10/30 → 5/20 (Haylee redeploys with the image-edit change).

## Saved game page + replays need a pass + no bar in Play/The End (queued 2026-11-17, Haylee): DONE 2026-11-17 (decisions/2026-11-17-round-plans-printables-page.md)
- Spec: decisions/2026-11-17-saved-game-page-and-play-bar.md; mockup design/mockups/after-cancel/ (main version A, no player picker).

## Copy: new tagline + no "off the screen" (queued 2026-11-18, Haylee)
- decisions/2026-11-18-tagline-and-play-wording.md: onboarding page 1 tagline → "Plan it, print it, play it"; grep app strings and Nutmeg's scripted lines for "off the screen", "steps back", the old flow sentence; use the new wording. Re-record any bundled clip whose words change (one short live recording allowed, voice work).

## App Store slides v3 to compare (queued 2026-11-18, Haylee) — after the current site/slides agent finishes
- Haylee's reference: the "Rays" set (vitamin D app). Make design/appstore-screens/slides-v3/ alongside v2 (don't replace v2): enlarged real UI cards floating off the phone edges (wider than the phone), a small outlined label chip at the top of each slide, medium-weight headline, a soft colored shape behind the phone (stage arc / warm spotlight), a bottom caption line with one more detail, logo on some slides, full-bleed hero slide 1 with image 49 (Nutmeg on stage). Same screens/copy as v2 (new tagline "Plan it, print it, play it", sparkly talking screen, "Play it out, scene by scene"). iPhone + iPad + 6.3" sets, strips for comparison.
