# Round 25: no Draw it!, Print is back, the "x" checklist fix, The End's Play step, fewer replay buttons, voice rate

**Date:** 2026-11-15. **Who decided:** Haylee asked for every item (after testing a replay) and for this record. The
implementation details are Claude's calls, noted below.

## 1. The no-printer "Draw it!" path is gone (Haylee)
- **Haylee's call: add it back only if there's lots of feedback about not having a printer.**
- Removed: the "Do you have a printer?" step and its Yes / No buttons, the Draw it! card and step, "Save printables for
  later" (and its share sheet), "Draw it instead" on a replay's Paper step, the DrawGuide generation (`DrawIt`,
  `PhaseService.drawGuide`, the hunt-time draw draft), the voice tools `set_printer` and `draw_step`, their realtime
  instructions (step 3c PRINTER; the color question is step 3c again), coaching lines, tests and driver commands.
  No bundled clip belonged only to Draw it! (the 9 common lines are all generic), so none were removed.
- Every game makes the printable kit again: the confirm yes → the color question → the kit is made during the hunt
  (the round 20 flow).
- **Saved games (Haylee: the app isn't live, every save is test data, no backward compatibility):** `SavedGame` lost
  `hasPrinter`, `drawGuide`, `printablesMade` and `printables` (the allowed-keys privacy list too). An old save's extra
  keys are simply ignored when decoding, so it still loads, but nothing special is done for it. The old test saves on
  PT-R15-iPad were deleted for the screenshots.

## 2. The step is "Print" again, with a printer icon (Haylee, changed mid-round)
- First ask: a clean sheet-of-paper icon without the crayon. Then, since drawing is gone: rename **Paper → Print**
  everywhere it's shown or spoken (rail label, accessibility, "Back to Print! Tap Print to print it again.", the
  go_to_step enum and descriptions, README, design spec, tests) and use a **printer** icon (`printer.fill`, filled
  like the other rail icons). The crayon overlay is gone. The steps are **Pick · Props · Print · Play**.
- Claude's call: "paper" still maps to Print in `BackNav.toolSteps` (and the driver's `#rail paper`), so older voice
  phrasing keeps working; the tool's enum now says `print`.

## 3. The checklist bug: a title of "x", generic steps, no props (Haylee's magic bakery)
**Root cause (from her saved game's JSON on her simulator, read only):** the game was made on the no-printer path. That
path wrote its play guide AFTER the hunt with the old array-form schema at low effort, which came back cut short (the
guide-prefetch finding: about 1 call in 3). Her guide had **ONE scene, titled "x"**, and its role steps used none of the
props (the tray was only in the Decorator's step, R4, who wasn't playing). `Validate.scenes` flagged it (fewer than 4
scenes; a title under 3 letters), but both problems were non-fatal, so after its one retry the short answer was kept.
The draw path also never ran the guide-prefetch prop weave. The scene titled "x" with the Head Baker's badge step and
two "Everyone" cheers is exactly what a 1-player checklist shows for that scene.

**3b, same root cause (Haylee: replay 1 → 2, the second player got no checklist):** the replay's `PlayCast` and the
hand-off rotation were rebuilt correctly for 2 (scene i belongs to role i mod N, a step per playing role), but with
ONE scene there is only scene 1, which belongs to R1, so the game ended before R2's turn. The "both players' steps on
the Head Baker's checklist" part is the round C1 design (every playing role gets its own step in every scene; the
holder is who has the iPad).

**Fix (Claude's calls):**
- `GuideRepair` (NutmegCore, no AI call, idempotent) runs on every guide that lands (`AdventureStore.fullKit`'s
  didSet) and on a replay's saved guide at load: placeholder titles ("x", "Title", "Scene 3", "...") get a real title;
  a guide with fewer than 4 scenes gets template scenes (a step for each of the 6 roles from the role's job, two group
  steps, a "Pretend that" intro); every prop no step uses is worked into R1's step in one scene (R1 always plays, so
  every count sees it) and an everyone step in the next ("Head Baker, grab the mixing bowl!", "Everyone, take a turn
  with the mixing bowl!"), as "pretend …" with no prop picture when the prop was skipped. A guide that already uses its
  props and has real titles comes back unchanged.
- The after-hunt guide call (now only used when the early guide failed) asks once more when the answer still has fewer
  than 4 scenes, and its prompt asks for every household prop in a role step and a real 2–5 word title per scene.
  `Validate.scenes` uses the same placeholder test.
- Tests (`Round25Tests`): placeholder / real title tables; `Validate` flags "x"; the bakery guide repaired (≥4 scenes,
  unique real titles, "Pretend that" intros, a step per role, every prop visible for N = 1…6, idempotent); a good guide
  untouched; a skipped prop woven as "pretend"; a NEW game whose AI guide is one scene titled "x" comes out repaired;
  a replay at 1 → 2 → 3 (hand-offs rotate R1…RN and reach every playing role, each checklist has exactly one step per
  playing role and none for others) and 1 → 2 inside one replay; the replay checklist has real titles and the props.

## 4. The End: no "Back to the checklist"; the Play step goes back (Haylee)
- The End's Back to the checklist button is gone. At The End the rail shows every step finished: **Play is lime with
  the ↺ mark and tappable**, and tapping it reopens the last scene's checklist (the checkmarks from before Done! when
  there are some, else all checked) with her line "Here's your checklist again! Tap Done when you're finished."
- Voice "go back to the checklist" keeps working: at The End `go_to_step play` does the same (the tool description
  and instructions now name "back to the checklist").
- The End's spoken line now says "Tap Play at the top to see your checklist again." instead of naming the button.
- Claude's call: the hand-off card's "Back to the checklist" stays for now (Haylee asked only about The End; the button
  audit is next).

## 5. Fewer buttons, the obvious ones only (Haylee; the full audit comes next)
- Replay Print: "Draw it instead" removed; "Skip, we have them" merged into **Let's play!**, which is always there (both
  went straight to Play). Now: Print everything · Just the badges · Let's play!.
- Replay Props: each card's Got it / Don't have it pair is ONE toggle (cards start as Got it, green; the button offers
  "Don't have it", and a missing card offers "Found it!"). "Use a … instead?" and All set! stay.
- Nothing else redesigned.

## 6. The button audit screenshots
`/tmp/pt-buttons/` (NN-name.png per screen), `/tmp/pt-buttons/sheet.png` (labeled contact sheet), and
`/tmp/pt-buttons/inventory.md` (screen → button → what it does → voice can do it?). DEBUG driver additions for it:
`#leavedialog` / `#stay`.

## 7. Nutmeg's voice wasn't as high (Haylee, mid-round)
**Root cause:** not a D3a/D3b code change. The audio graph is identical in the pre-D3a build (686c223) and HEAD:
player → Varispeed 1.20 → mixer, and every source (live, app lines, clips, bundled clips) goes through it. But the
engine's IMPLICIT mixer → output link was **44.1 kHz while the audio session and hardware ran at 48 kHz** (logged on
PT-R15-iPad: session 48000, output hardware 48000, output input 44100, mixer out 44100). Measured with DEBUG mixer taps
(`-PTTapOut`: what goes into the pitch unit vs what the mixer sends out), the effective rate was **1.10 on both
builds** (686c223: 51.7 s of 24 kHz input per 46.9 s of output; HEAD: 52.1 s per 47.2 s; = 1.20 × 44.1/48 = 1.1025),
about 1.5 semitones lower and slower than her approved 1.20. Likely why it "changed again": the simulator's/Mac's audio
setup decides that default, so it can change without a code change.
**Fix (Claude's call):** `SpeakerGraph` (NutmegCore) builds the graph in one place and connects mixer → output at the
output's hardware format. After: mixer out 48000, **effective rate 1.2015** (51.88 s in / 43.18 s out), median F0
247 → 293 Hz. Lock: `SpeakerGraphTests` renders each source path offline (PCM16 live deltas, float clip chunks) at 48
and 44.1 kHz outputs and checks the 2 s tone lasts 1/1.20 and is 1.20× higher.
**Clips:** they're recorded from the raw Realtime audio before Varispeed (the recorder never sees the output graph),
so saved and bundled clips were never affected and need no re-recording; they now play at the right rate too.

## Live checks (typed, PT-R15-iPad; old test saves deleted first)
- **New "Magic Bakery" game, 2 players:** confirm → the color question (no printer question) → hunt (bowl → mixing bowl,
  tray → bakery counter, a missing hat swapped to a bowl → chef hat) → Print (printer icon on the rail). The guide had
  **6 scenes with real titles** (The Bakery Opens, First Order, Mixing Magic, Into the Oven, Sprinkle Time, Special
  Delivery), a Head Baker and an Oven Watcher step in every scene, props in the steps ("hold the mixing bowl", "line up
  treats on the bakery counter", "tip your chef hat"), hand-offs alternating. The End: the rail's Play showed lime with
  ↺; tapping it reopened Special Delivery's checklist; Done! → The End again; Save.
- **Replay at 1, then at 2 (3b):** 6 scenes both times; at 1 every checklist is the Head Baker's step + 2 group steps
  (a missing bowl read "the pretend mixing bowl"); at 2 hand-offs went R1, R2, R1, R2, R1, R2 and every checklist had
  both roles' steps. **0 Claude / image calls** on the replays. The End → rail Play → the checklist again.
- Screenshots: `/tmp/pt-buttons/` (28 screens, `sheet.png`, `inventory.md`).

## Also found and fixed (Claude's calls)
- The N-player kit view (`AdventureStore.kit`) is memoized: `PlayCast` compiled regexes on every read, SwiftUI and
  the test driver read it many times a frame (a driver wait spun for minutes; NutmegCore tests 19 s → 4 s).

## Found live and fixed (Claude's call)
- A stray Found it! after the hunt had ended (the driver tapped one too many) ran the hunt reply again, the model called
  finish_planning a second time, and the whole kit was remade (Print waited ~2 more minutes). Now the hunt buttons do
  nothing outside the hunt, and a second finish_planning once the kit is being made or made changes nothing (test).

## Not verified
- By ear (Haylee's listening test) and on a real iPad (its hardware is usually 48 kHz throughout; the explicit link is
  harmless there). Spoken (mic) runs. The repair's template scenes read fine but are generic by design: they only
  appear when Claude's guide came back short.
