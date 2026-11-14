# Prop gathering: one prop at a time, answer only when talked to

- **Date:** 2026-11-13
- **Decided by:** Haylee (flow, layout); implementation details Claude's call

1. **Timing:** a prop card never appears while she's still talking about the roles: a new card waits until the turn
   that was playing when it was requested has finished (it appears with her prop line, or once playback drains).
2. **One at a time:** tool `show_next_prop(item_id, becomes, for_role, alternates)` replaces the all-at-once list;
   `mark_found(id)` checks a card off; `swap_prop` / `skip_prop` stay. The store tracks the current prop
   (`currentPropID`). She says what to find and what it becomes and ends with "say 'found it' or tell me if you
   don't have it". 3–5 props, then `finish_planning`. She points toward each new card.
3. **Only when talked to:** while the hunt runs, automatic replies are off (`turn_detection.create_response: false`,
   input transcription stays on). The app answers only lines meant for her (`HuntGate`: her name, or a found /
   not-found / back phrase, whole words) or the card's backup buttons; chatter like "Mom, where's the big plate?" gets
   no reply. After ~45 s of quiet she checks in once. Auto replies come back after the hunt.
4. **Layout (`PTPropActiveCard`, `PTPropDoneChip`, hunt camera shot):** a medium shot with Nutmeg left of center; the
   ACTIVE card big on the right where she points (≥ 32 pt inside the curtain, centered on her chest) with "Found it!"
   / "Don't have it" pills inside it (side by side or stacked, never truncated, ≥ 56 pt); done props shrink and fly
   into a stack on the left between the rail and Nutmeg (check, swap, or faded "pretend"). Cards are screen space; the
   floor stays under her.
