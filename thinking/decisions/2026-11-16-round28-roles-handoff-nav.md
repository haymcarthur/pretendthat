# Round 28: customer roles, one role per checklist, real props only, hand-off badge, back-nav fixes, cover on Pick

**Date:** 2026-11-16. **Who decided:** Haylee asked for all 7 items (and for this record). The implementation details
are Claude's calls, noted below. The microphone text fix was asked by the coordinator (Haylee's session) mid-round.

## 1. Customers are roles too (Haylee)
- Prompts (Claude system + roles prompt, Realtime instructions, `set_roles` tool, the confirm output) say customers,
  visitors, guests, passengers, patients and pet owners are roles too: R2 is the customer counterpart of R1
  (Shopkeeper + Customer, Pilot + Passenger, Vet + Pet Owner), R3–R6 mix workers and customers. The play-guide rules
  ask that customers get real things to do (order, pay, show a ticket).
- **App check, no AI call (`CustomerRoles`, Claude's call):** a game-keyword table finds the customer kind (shop /
  stand / bakery → Customer, airplane / train → Passenger, vet → Pet Owner, doctor → Patient, hotel → Guest, zoo /
  museum → Visitor, theater / circus → Audience Member, library → Reader, school → Student). A customer the model ranked
  low moves up to R2; with none, the counterpart becomes R2 (the lowest extra drops off); a customer game gets at least
  2 customer-type roles (a "VIP Customer"-style extra replaces the lowest worker extra). Games with no customers
  (pirates, knights) are left alone. Runs inside `Sanitizer.clean(plan)`, so the set_roles result names them.
- The bundled airplane game is now Captain, Passenger, Flight Attendant, Co-Pilot, Snack Chef, VIP Passenger.

## 4. One role per checklist + props must be real (Haylee)
**Turn structure (Claude's call):** the play guide is now **4 scenes × 2 steps for each of the 6 roles (48 steps, the
same size and cost as round C1's 6 × 8)**, and **no "Everyone" steps** (dropped: a role's checklist is only theirs; an
"Everyone!" moment didn't fit cleanly with one iPad holder). In play, **each scene is N turns**: R1, R2, … RN each get a
hand-off and then a checklist of only their own 2 steps (`PlayCast.turns`; the N-player `kit.scenes` is the turn list,
so all play code, auto-advance, Repeat, resume and the rail work unchanged). The scene's "Pretend that" intro plays on
its first turn; later turns start at "First, <Role>, …". With 1 kid there are no hand-offs (4 checklists). Every playing
role gets a turn in every scene (C1's "every role called out"). 4 scenes rather than 6 keeps a 4–6 kid game to 16–24
short turns. Older guides (6 × 8) still play: each role's one step, "Everyone" steps hidden.
- **Real props only (`GuideRepair.realProps`, no AI call):** a step may name only the found props (and the pretend
  stand-ins for ✗ props, by what they become), words printed on the kit pages, the kit item types (badge, sign, money,
  ticket, menu, cut-out) and body actions. Any other object from a ~180-word list of hand-held things (bell, wand,
  phone, basket, cash register…) gets "pretend" in front ("ring the pretend bell"); the ring-bell picture or a prop
  picture of a thing they don't have becomes the plain point. Skipped: role titles ("Bell Ringer"), anything after
  "pretend", a modifier of a real thing ("the cake menu"), and ambiguous verbs (stamp your feet). Runs on every guide
  that lands and on a replay's saved guide at load; idempotent. The guide and system prompts say "ONLY REAL PROPS" too.
- Also (found live): a step's role title keeps its capitals when she reads it ("First, Stand Manager, …").

## 2. The scribble waits for the writing pose (Haylee)
The scribble sound starts only after the writing shot has settled (1.1 s camera + pose swap; 0.4 s with Reduce Motion)
and only if she's still writing; it stops the moment she leaves the pose (`AppModel.writingChanged`).

## 3. The hand-off card shows the colored badge (Haylee)
The text is gone: the role's slice of the COLOR badge sheet, big (250 pt, 150 pinned), framed in the role color, with
a tiny role name under it, plus the green ✓. Until the slice is drawn: the role's color chip (`PTRoleBadge`). She still
says "Pass the iPad to the …!".

## 5. Back to Print shows the pages at once (Haylee)
`papersShown` remembers that this kit's papers came out; leaving Print for Play no longer resets the beat to coloring,
so the rail back to Print shows the pages immediately (no writing, no ready line). Cleared on a new game or remake.

## 6. After the yes the game stays; back to Pick asks the count (Haylee)
- After the confirm "yes", `set_game` / `set_theme` are refused (`gameLocked`): "Our game stays Post Office in a Fairy
  Forest! But you can change how many friends are playing." Before the yes, corrections work as in round 19. The
  round 19 print-step remake path is gone (no way to reach it).
- Back to Pick (rail or voice): "We're playing Post Office in a Fairy Forest! How many friends are playing now?". A kid
  turn there is tool-first over the count (`Realtime.pickBackTools`; found live: without it she narrated and never said
  the count line). The count changes with no AI call (C1).

## 7. Opening a saved game: the cover on Pick (Haylee)
The replay's Pick shows the game's wide cover in a white mat where the title text was (`PTReplayCover`), falling back
to the color sign page, then the title text. She still says the name.

## Microphone permission text (coordinator, Guideline 5.1.1(ii))
`NSMicrophoneUsageDescription` said "Your voice stays on this iPad" (wrong: speech goes to OpenAI via the relay). Now:
"Nutmeg listens only while you hold the microphone button, so she can understand and answer. Your voice is sent
securely to our AI partner to understand it, and isn't saved by PretendThat." The site's privacy page already says
this (no change). **Open:** `NSSpeechRecognitionUsageDescription` still says "Nothing is sent anywhere", which is wrong
when the backup recognizer uses Apple's server recognition (`usesServerRecognition`); not changed this round.

## Tests
NutmegCore 399 green (new `Round28Tests`: customer titles and game kinds, R2 counterpart, extras mix, store
announcement, prompts; turns per role at N = 1–6, store hand-off before every turn, only the holder's steps; missing
object → pretend, real things untouched, prop pictures, repair on landing and on replay load; refusal after the yes,
corrections before it, back-to-Pick line and count change with no AI call). Older tests updated for the new shape.

## Live checks (typed turns as voice, PT-R15-iPad, clean rebuild; `/tmp/pt-round28/`)
- **Lemonade Stand on the Moon, 3 players:** roles Stand Manager, **Customer**, Mixer (+ Sign Artist, Cup Organizer,
  VIP Customer). Tray ✗ → "carry the drink on the pretend serving tray"; the model wrote "pretend to ring a party bell".
  12 turns (4 scenes × 3), each checklist only the holder's 2 steps. Hand-off card: the color badge (02, 04).
  Rail → Print: pages at once, no scribble (06). Rail → Pick: "We're playing Lemonade Stand on the Moon! How many
  friends are playing now?" (07). Found here: "we have four now" changed the count but she narrated first and never
  said the count line → fixed with the tool-first Pick pass; "First, stand Manager" → fixed capitals.
- **After the fix, Post Office in a Fairy Forest, 2 → 3 players:** Postmaster + **Forest Customer** (+ VIP Customer in
  the extras). Back to Pick: "we have three now" → "Three friends! Our crew is a Postmaster, a Forest Customer and a
  Stamp Artist!"; "make it a pirate ship" → "Our game stays Post Office in a Fairy Forest! But you can change how many
  friends are playing." Played through (auto-advance) to The End, saved (generated cover), opened from the shelf: Pick
  shows the cover (14) and she says "Post Office in a Fairy Forest! How many friends…".
- Scribble: "scribble: on (the writing shot settled)" logged after the camera move both times.

## Not verified
By ear / real iPad / spoken (mic) turns; the 1.1 s scribble delay by eye against the pose swap; the color-chip
fallback on the hand-off card (the badge sheet was always drawn first); a 5–6 player game's length in practice.
