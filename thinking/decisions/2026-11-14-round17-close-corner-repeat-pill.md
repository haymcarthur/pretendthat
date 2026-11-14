# Round 17: the close (X) moves to the top-left corner; Repeat takes its slot in the control pill

**Date:** 2026-11-14 (before the 7:59 AM code freeze) · **Decided by:** Haylee asked ("move the back/close button up to
the left hand corner and add a repeat button where the close was"; "Yes, move the X"). Implementation details are
Claude's calls, noted.

## What changed
- **X in the top-left corner (Haylee).** `PTCornerClose`: a 56 pt white round icon button with a soft shadow, below the
  valance (`PTCurtain.metrics(...).valance` + 8 pt), centered over the step rail's column, above the rail. Shows in every
  step with the chat open or closed (same visibility as the rail and pill). Same behavior: it opens `PTLeaveDialog`
  (the game can't be resumed). Claude's call: white fill (not the pill's gray) so it reads on the coral curtain;
  `PTIconButton` now uses ink for a white fill.
- **Repeat in the pill (Haylee).** Pill is now Repeat | big red mic | chat, same 64 pt size and style as chat, the
  swell around the mic unchanged. Icon `speaker.wave.2.fill`, accessibility label "Hear it again".
  - What it does is chosen by `RepeatTarget.choose` (NutmegCore, unit-tested): during the play step's checklist it runs
    round 16's `repeatChecklist` (title + unchecked steps, cancels a stale cheer, debounced); in every other step
    Nutmeg says her last spoken line again (her latest chat bubble; the last app line when there's no chat, e.g. the
    device voice) through the same `sayExactly` app-line path and voice.
  - **Claude's call: no duplicate bubble.** A repeat is sent as an "echo" app line (`RealtimeSession.say(_, echo:)`):
    its transcript is kept out of the chat, and it's out of band (`conversation: none`), so the model never sees it.
  - Dimmed and disabled when there's nothing to repeat yet, or while she's speaking / a reply is on the way /
    the kid holds the mic / a checklist read is queued. Taps within 2.5 s are ignored (no spam).
- **Round 16's checklist "Hear it again" pills removed** (stage card and the chat panel's Checklist tab). Done! is back
  to its round 15 layout (PlayScreens.swift matches round 15 exactly).
- The live harness's `#repeat` now taps the pill's Repeat (`repeatTapped`).

## Tests and checks
- NutmegCore: 199 green (was 196): + Round17RepeatTests (checklist during play, last line elsewhere with the app-line
  fallback, dimmed when empty or busy, debounce).
- Built for the second simulator (PT-R15-iPad). Screenshots in /tmp/pt-round17/ (props-*-rot.png = conversation step,
  scene-*-rot.png = play checklist; chat closed and open).
- Not verified: a live (voice) run of Repeat; whether the echo line's audio plays cleanly in every phase.
