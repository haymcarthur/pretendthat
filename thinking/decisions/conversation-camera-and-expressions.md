# Conversation camera and expressions

- **Date:** 2026-11-13
- **Decided by:** Haylee (behavior); implementation details Claude's call

1. **Camera:** stays close on her face for the whole planning chat (while she talks AND while the kid talks). It zooms
   out only when cards need room (prop cards); back in when they're gone. At least 2 s between camera changes, except
   zooming out for cards (they must never cover her face). Arriving from the start screen she lands at the medium shot,
   then the camera eases in after ~0.9 s.
2. **True camera move:** the floor (with its rim), her contact shadow and the stage stars zoom with her as one stage
   world (stars with ~70% parallax); the curtains and valance are a fixed proscenium; the UI chrome never zooms; cards
   are laid out in screen space. At close-up the floor mostly leaves the bottom of the screen.
3. **Expressions:** Realtime tool `set_expression(expression, seconds)` (happy, excited, ooh, thinking, listening,
   oops); the instructions ask for it at the start of most turns; it's silent, returns "ok" at once and never blocks
   audio (a response that only set a face gets a follow-up so she still answers). While she talks, the chosen face's
   eyes/brows stay and only the mouth (lip sync) and a talking bob follow the audio. Local layer: listening while the
   kid talks; thinking in the gap after the kid stops (after 250 ms, so a fast reply doesn't flash it); happy by
   default; a blip (ooh / excited) when her reply opens with "Ooh!", "Wow!", "Yes!". A face holds at least 1 s and ends
   with her turn.
4. **Lip sync:** each audio delta is analyzed as it's scheduled (10 ms windows: loudness plus a low/high band split),
   stamped with when it will leave the speaker (player sample position, Varispeed rate divided out, plus output
   latency and IO buffer), and fed to `MouthShaper` (30 ms attack, 80 ms release, hysteresis, 60 ms hold): silence →
   closed, soft → small, bright → wide, rounded → ooh, loud mid → open. Replaces the mixer tap, which iOS delivers in
   ~100 ms chunks after the fact. No new mouth art.
5. **Shadow:** a small low-contrast ellipse in the floor's edge tone (60%), ~1.1x her stance, under her feet; it stays
   on the floor when she hops and shrinks a little in the air.
