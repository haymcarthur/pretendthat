# Round 15: skipped-prop reassurance, varied kit lines, checklist cheers, floor behind the curtains

**Date:** 2026-11-14 (morning, before the 7:59 AM code freeze) · **Decided by:** Haylee asked for all 4 items after
testing round 14 (f7644fc). Implementation details are Claude's calls, noted.

## 1. "Don't have" twice on the same prop card: she reassures out loud (Haylee asked)
- **Root cause (found):** the second tap usually lands while her swap reply ("a towel works too...") is still being
  generated. `tapTurn` interrupts her (`dropAudio = true`, `response.cancel`) and asks for the new turn's response, but
  one is still active, so the request is parked as "pending". When the cancelled response ended, `ResponseGate.done`
  was called with `allowFollowUp: false` (the interrupt flag), so the parked request was dropped for good: the card
  moved aside and she said nothing. The same hole existed for a typed line or a quick second tap of any kind.
- **Fix:** `ResponseGate` records a request from a NEW turn that arrives while the OLD turn's response is active
  (`deferredTurn`). When that response ends, `RealtimeSession` closes it out (tool outputs sent, silent items deleted)
  and asks for the new turn's reply with its normal tool-first rule (`takeDeferredTurn` → `requestResponse`). Exactly
  one spoken reply, and it is an in-conversation response, so it shows in the chat. Unit-tested
  (`tapWhileHerReplyIsRunningStillGetsExactlyOneReply`).
- **What she says:** the skip note (`PropSkip.note`) tells her to call show_next_prop first, then speak once, starting
  with "That's okay, we'll just pretend that" plus a quick pretend substitute, then the new prop.
- **Claude's call:** if the silent pass ends the hunt there (finish_planning, allowed after 3 props), no model reply
  follows, so the app's "making your kit" line starts with a random app-written reassurance (`PropSkip.reassurance`,
  `AdventureStore.kitLeadIn`, only within 20 s of the skip). Still one line, in the chat.
- The first "don't have" (swap) is unchanged: one spoken, tool-free reply about the alternate.

## 2. Kit commentary is varied (Haylee asked)
- `KitProgress.lines`: 42 short lines, 6 to 7 wordings each for badges, sign, money, tickets, menu (works for a price
  list too), cut-outs, and the play guide's checklists. Picked at random (`LineDeck`), never repeated in an app session
  until a pool is used up, and a different page kind than the last line when possible.
- Only true lines (the round 7 rule): while the kit's content is being written, every page and the checklists are in
  progress; once it's back, only pages whose art is still drawing (`KitProgress.inProgress`). Still at most 4 lines,
  ~13 s apart, and a line waits if anything else is being said. No "ready", "all set", "go play" or stage directions
  (tested). No maps: the kit never makes one.

## 3. Checklist check-offs during play (Haylee asked)
- Checking a step: one short varied praise (`ChecklistCheers.praise`, 14) + the next unchecked step ("Next, hand out
  the snacks!"). Checking the last step: one overall congratulations + "Tap Done...". Unchecking says nothing.
- Done! before everything is checked: no per-step cheers; ONE overall congratulations, said as the start of the next
  line (hand-off, next scene or The End: `AdventureStore.sceneLeadIn`), so the tap gets one spoken reply.
- No overlap (Claude's call on the mechanism): a cheer waits 0.6 s (a quicker second tap replaces it, the stale one
  is never sent) and then waits for anything she is saying to finish (`RealtimeSession.voiceBusy`). App lines are
  out-of-band responses whose transcript streams into the chat, so every cheer shows there.

## 4. Stage floor always behind the curtains (Haylee asked)
- **Root cause:** the curtains, tie-backs and valance were drawn by the full-screen backdrop UNDER the shared stage, so
  whenever the camera pulled back the floor ellipse (part of the stage) was drawn over the bottom of both curtains.
- **Fix:** `PTStageView` draws the same `PTCurtain` right above the floor (below the stars, Nutmeg and the cards),
  placed at the backdrop's full-screen frame (`screenSize` + the stage's global origin), so it lines up exactly. This
  holds for every preset and phase, chat open or closed, and doesn't touch the camera: round 14's framing (floor under
  Nutmeg, chat-open fitClosed, keyboard covering the stage) is unchanged. The start screen already drew its curtains on
  top. Claude's call: stars stay above the curtains as before (only the floor moved behind).
- Verified on a second simulator: props, kit, checklist, hand-off and The End, chat open and closed
  (/tmp/pt-round15/grid.png, before/after crop /tmp/pt-round15/zoom-end-bottomleft-before-after.png).

## Tests
- NutmegCore: 189 green (was 178): + Round15LinesTests (kit pool size and rules, only-in-progress topics, random with
  no repeats, no same topic twice, deck cycling, skip reassurance and note, kit lead-in freshness, deferred tap turn,
  checklist cheer wording and variety, early-Done congratulations).
- Live check: see "Live run" below (189 still green after its two fixes).

## Live run (typed harness on a second simulator, /tmp/pt-round15/live1/console.log)
- Turns: airplane, moon, "just me", Found, Don't have (swap), Don't have again 0.7 s later (while the swap reply was
  still running), Found, kit, Let's play, check step 0, check step 1 quickly, early Done!.
- Swap: one reply ("A bag works too as the pilot cap."). Quick second tap: `deferred turn` fired, then one reply:
  "That's okay, we'll just pretend that your hands are the pilot cap! Can you find a blanket?..." In the chat.
- Kit lines: two different random lines (sign, badges), each in the chat.
- Checklist: "Good job! Next up: hang up the Moon Airlines sign!", then "Look at you go! Now, set the box by your
  seat!" (no overlap); early Done!: "Hooray, you did the whole scene! Pretend that teddy passengers..." (one line).
- Two bugs found and fixed after the run: the kit lead-in repeated the reassurance after the skip reply had already
  said it (now cleared whenever the next prop card comes out), and "the the pilot cap" (articles stripped).
