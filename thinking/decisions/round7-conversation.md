# Round 7: fresh suggestions, open player count, no permission checks, spoken-only reminder, no narration, prop cards

**Date:** 2026-11-13 · **Decided by:** Haylee (the features and the bugs from her live test). The implementation details below are Claude's calls.

## Fresh suggestions every session (Haylee)
- New `NutmegCore/Suggestions.swift`: 42 kid-friendly pretend games that work with household props, and 32 general theme twists. Every item has a stable ID.
- `Suggestions.sample` picks 3 distinct items and avoids the previous picks. It only reuses an avoided item if the pool is too small, which never happens with these lists.
- `SuggestionMemory` stores ONLY the last pick IDs in UserDefaults (`pt.lastGamePicks`, `pt.lastTwistPicks`). Nothing about kids.
- Games: picked in `AppModel.startConversation` and injected with `Realtime.instructions(todayGames:)`, which adds a "TODAY'S GAME IDEAS … suggest ONLY these … if a kid says ANY other idea, happily take it" block. *Claude's call:* the kick-off message also names the 3 ideas, so the greeting is ONE response with the suggestions in it. Haylee saw a first build where the intro bubble had no suggestions.
- Themes: picked when `set_game` arrives (`store.themeIdeas`) and delivered in the set_game function output ("suggesting ONLY today's theme ideas: …; if the kids say their own theme, take it").
- Picking by position ("the first one!") is supported in the instructions (Haylee liked it).

## Player count wording (Haylee)
- Asked open: "How many friends are playing today?" Never a list of numbers. Updated in the instructions, the set_theme output, the step goal and the set_player_count description. TurnCheck flags a closed count list (`offersCountList`).

## No permission checks (Haylee)
- Her only questions are game, theme, how many friends, and the per-prop found-it question. The instructions, tool descriptions and set_roles output forbid "Sound good?", "Okay?" and "Ready?".
- Flow: count answer → writing beat (start_planning, KEPT: Haylee confirmed the pause after the count is the intended writing moment) → set_roles → show_next_prop → ONE spoken turn with the roles and the first prop.
- *Claude's call:* the one writing beat now plans the roles AND the prop list, so there's no second beat before prop 1 (`propsPlanned` is set when the roles beat starts). Two back-to-back silent beats would read as a stall.
- TurnCheck: `isPermissionCheck` flags a short check-in question on any step. `TurnCheck.review` returns a continuation if the roles are set but no prop card is out yet, so she goes straight into prop 1 without waiting for a kid reply.

## Silence reminder (Haylee: first spoken-only, then reverted to "everything she says is in the chat")
- Still ONE "Hold the red button whenever you're ready!" per question (after 20 s, or 45 s in the hunt).
- It is a fixed out-of-band `sayExactly` line, shown in the chat as its OWN bubble. Haylee first asked for spoken-only, then reverted: everything she says out loud is in the chat, no exceptions.
- Bug found live: an out-of-band response still sees the conversation by default, so the "reminder" improvised game ideas. That is the "suggestions spoken but missing from the chat" Haylee saw. Fix: `sayExactly` sends `input: []` (no context), so it says exactly the line.

## No narration, and prop cards driven by show_next_prop (Haylee's live test)
- Seen live: "let me think about the theme choices next", "let me set that up", "let me grab the next prop." followed by a stop, and a prop named out loud with no card.
- The instructions now say NEVER NARRATE, and that a prop is never named unless show_next_prop was called first in that turn. After mark_found/swap/skip, she calls show_next_prop before speaking.
- TurnCheck: `isNarration` ("let me", "coming up", …) is never a valid ending, even with an instruction word in it ("grab the next prop" used to count as an instruction). `review` also continues when the current prop is found or skipped and no next card is out.
- ResponseGate (*Claude's call*): a response that called a real step tool AFTER speaking gets ONE follow-up when what she said didn't finish the step (`spokenTurnIncomplete`). A spoken turn that already ended with its question gets none, so round 6's repeated questions don't come back. Expression-only responses never get one.
- The turn check reads her latest line, not simply the last chat line (a late kid transcript can land after hers).

## Roles → prop 1 choreography (Haylee)
- Order: she says ONLY the roles → that audio finishes playing → 1 s → the card appears and she switches to the point pose → a separate response for the prop line → the point holds until that line finishes playing, plus 3 s.
- How (Claude's call): the first show_next_prop's output tells her to speak only the roles. `RealtimeSession.holdFirstPropLine()` holds the card. When the roles response ends, a watcher waits for local playback to end + 1 s, then `onPropLine` reveals the card, calls `pointAtCard()` and returns the note (`AdventureStore.firstPropLine`). After that comes `forceFollowUp` + `response.create`. If she narrated in the same response as the tools, she gets one "roles only" continuation first. Later props: the card appears and the point starts when her prop line starts playing, and holds through it.
- Root cause of "roles + prop 1 never spoken" (live trace): a lead-in line closed the turn (`inTurn = false`) in the start_planning response, so after the beat the silent set_roles → show_next_prop chain never got its spoken reply. Fix: `forceFollowUp()` / `continueTurn()` reopen the turn. `maxFollowUps` went from 3 to 5.
- `NutmegCue.hold`: a gesture can be held for a set time, and a 0 hold releases it. The point is no longer fired on `currentPropID` / `presenting` changes (those happen when the tool arrives, not when she speaks).

## Kit time (Haylee)
- finish_planning ends her turn (`gate.endTurn()`), so no follow-up response. Before this, a silent finish got a follow-up: "All set … go play!".
- During generation: the app's one "Ooh, let me make your kit! Wait for it..." line (plus the earlier approved reassurance lines on a long wait). The ready line `AdventureStore.kitReadyLine` ("Ooh, your kit is ready! Let's print it!") is spoken only when the whole kit is final (pages + art, at the paper reveal). It's no longer spoken when the kit JSON lands.
- Kid input after planning: the mic is off (D3), and `sendText` ignores it once planning ends. A typed line during generation gets "Almost ready!" at most.
- "Go play" phrases only in the play step: the instructions forbid them in every planning step, and `TurnCheck.mentionsGoPlay` flags them.

## Voice and narration refinements (Haylee, later in the round)
- **Suggestions sound open**, not a menu: "You can pick anything! Maybe a hotel, a pirate ship, or a pet groomer?" and "Any twist you like! Maybe …?" (in the instructions, today's-ideas block, kick-off and set_game output).
- **One planning line**: right before the writing moment she says ONE short sentence like "Great, let me put some plans together!" (the set_player_count output asks for it). This is the only allowed process line. `TurnCheck.isNarration` exempts it. Every other narration is flagged ("coming up next", "get ready to hunt", "start the hunt", "let me think about the next…", the exact phrases seen live).
- **No pre-announcing the card**: the roles-only note forbids mentioning props, cards or the hunt. The prop line starts right away with "First, can you find…". The prop line gets its own chat bubble (it comes after a pause).
- **No sound words**: "giggle", "squeak", "eee", "eep", "heehee", "teehee", "hehe", "*laughs*" are banned in the instructions, and `TurnCheck.hasSoundEffect` flags them. The instructions no longer say "giggly", "playful giggles" or "giggle and bring them back", the sayExactly prompt dropped "a little giggle", and the audition line dropped "wheee". "Ooh!" and "Yay!" are fine.
- **Every kid answer on a step is tool-first and SILENT** (*Claude's call*, after live runs showed `tool_choice: required` alone still let her talk before the tool): the FIRST response to a kid turn may only call that step's tools (`Realtime.kidTurnTools`: game → set_game/show_game_ideas/just_talk; theme → set_theme/set_game/just_talk; count → set_player_count/just_talk; hunt → mark_found/swap/skip/show_next_prop/finish_planning/just_talk). That response's audio is never played and its words never reach the chat. Its items are truncated to 0 ms so the model knows nobody heard them. Her one spoken reply comes in the follow-up, after the tool result. So no "let me set that up / check it off / grab the next prop" is ever heard, and a stall after mark_found can't happen: the follow-up is always owed. New `just_talk` tool: an off-topic or unclear kid line changes nothing, and she replies in one line and re-asks.
- Cost: one extra short round trip per kid turn (the silent tool call), about 0.5–1 s.
- **Kit progress commentary** (`NutmegCore/KitProgress.swift`): after the one "making your kit" line, a line about every 13 s, ONLY about a page that is still being drawn ("I'm making your name badges!", "I'm putting together some tickets!", "Ooh, the menu's looking yummy!"). There are no generic lines: Haylee heard "I'm writing down all your roles!" after the roles were done. At most 4, never repeated, and it stops as soon as the whole kit is final. These replace the two older 20 s reassurance lines. The art jobs run in parallel, so "being drawn" means "not landed yet". Each app line (progress, ready) is its own chat bubble.
- **Continuous writing moment**: the auto-beat on set_roles fired a SECOND beat when the first one ran over 8 s (the flicker Haylee saw). Now only one beat per adventure. The beat's result goes back after the minimum time, but she keeps writing until her roles line starts playing, and only then looks up.
- **Mic in the print step and play** (Haylee): the mic only looks disabled while connecting. Kit making: pressable, but a hold is cleared and she says "Almost ready!" at most. Print step: new tools `start_play` (same as tapping Let's play!, refused before the kit exists) and `print_kit` (opens the iOS print screen). The kit-ready line is "Your kit is ready! Tap Print, or tell me when you're ready to play!". Play: a silent note asks for one short helpful line and no tools.
- "Pretend that": the instructions ask for it on about 1 prop in 3, never on two in a row. The Claude play prompt asks for it in scene and hand-off lines.

## Roles wording, prop variety, bubbles (Haylee)
- Roles are parts to share: "Our crew is a Train Driver, a Conductor, and a Passenger! Pick who's who!" and never "You're the X, the Y, and the Z" (that sounds like one kid gets them all). For one kid: "You'll be the Train Driver!". `TurnCheck.assignsAllRolesToOne` flags it. "All set!" counts as narration.
- Props come from THIS game and theme, and the first prop is the game's most iconic thing. The instructions' repeated "plate → steering wheel" example was the reason every game started with a plate; it's gone, replaced by varied examples.
- Speech after the writing moment always starts a new chat bubble (`breakTurn` when the beat ends).
- Kit progress bug: the loop returned the first time no line was due (before the kit JSON existed), so no progress line ever played. Now it keeps waiting. While the pages are still being written, every page counts as in progress, so the first line is about the first page type.

## Tests (148 total, all green)
- New `SuggestionsTests` (about 30 tests, including the ones listed below): list sizes and unique IDs, 3 distinct picks that avoid the previous picks (200 seeds), variety, the memory stores only the two ID lists, the instructions contain the injected picks, the set_game output contains the themes, open count wording, roles → first prop, permission checks, the spoken-only reminder, the gate tool flow (count → set_roles + show_next_prop → one follow-up), found-it → next card, narration, `input: []`.
- `turnEndings` updated: the closed count list and "Sound good?" are now flagged.

## Debug-only helpers
- `-PTSay "#wait N"` stays quiet N seconds (to check the reminder). At the end of a live run the chat panel's lines are logged as `CHAT[i]`. The live driver waits until she is fully settled (no response, beat or reply pending) before the next typed turn.

## Live verification
- Typed live sessions (`tools/live-voice.sh`, `-PTLive -PTSay`), transcripts in /tmp/pt-round7/*-transcript.txt. The final end-to-end run is /tmp/pt-round7/s1 (intro → kit ready → Let's play). Screenshots: /tmp/pt-round7/prop1-card-and-point.png and /tmp/pt-round7/kit-ready.png.
- Five sessions each picked different games: camping/grocery/ice-cream truck; knights/post office/rocket; hotel/pirate ship/pet groomer; train/grocery/circus; knights/restaurant/bakery.
- Not verified: real push-to-talk with `say` (all runs were typed turns), the print_kit voice tool, the off-topic `just_talk` path, and the play-step voice note.
