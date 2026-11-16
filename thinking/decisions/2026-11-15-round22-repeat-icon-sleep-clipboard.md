# Round 22: Repeat icon, sleeping clipboard

**Date:** 2026-11-15 · **Decided by:** Haylee (both items, and "speaker AND replay arrow" for the icon); details are
Claude's calls, noted.

## 1. Repeat ("Hear it again") icon shows a speaker and a replay arrow (Haylee)
- The old `speaker.wave.2.fill` alone didn't read as "repeat". Haylee asked for an icon with both a speaker and a
  replay arrow.
- SF Symbols has no combined speaker + replay symbol on iPadOS 17 (checked the system symbol list: the nearest,
  `hifispeaker.arrow.forward`, is iOS 18 and means "send to speaker"; `arrow.trianglehead.counterclockwise` is iOS 18 too).
- So it's composed (Claude's call, after trying a small corner badge, which was too small and crowded the waves):
  `arrow.counterclockwise` as a ring (0.5 × button, regular weight, same ink as the chat icon) with a small
  `speaker.wave.2.fill` (0.19 ×, semibold) inside. `PTIconButton` gained an optional `ring:` symbol. Vector symbols, so
  crisp at every scale. Label "Hear it again", hint, and the 0.4 dim / disabled state are unchanged.

## 2. Sleeping Nutmeg no longer sits on her clipboard (Haylee)
- Round 14 split the clipboard out of the sit art and shifted it +125 canvas px, which put it at x ~298–603, right
  under her seat (~383–875).
- `NutmegPose.sitClipboardShift` 125 → 678: it now lies flat on the floor beside her feet on her right (x ~850–1156),
  tucked just behind her toes, still drawn behind her. Transform only, no art change. She stays grounded (round 14's
  `sitDrop` untouched). Checked chat closed and open: /tmp/pt-round22/sleep-chat-closed.png, sleep-chat-open.png,
  pill-zoom.png.

## 3. Zzz when she's asleep (Haylee)
- The floating Zzz only drew in the old `.napping` state; the real doze flow (round 9, Doze.swift: sitting → drowsy →
  asleep) never showed it (round 9 had said "no z's"; Haylee now wants them). `NutmegState.showsZzz` = napping or
  asleep; never drowsy or sitting.
- The Zzz is always in the view tree and its opacity eases 0.8 s with `showsZzz` (fades in as she falls asleep, out when
  she wakes), so the pose-swap animations aren't touched.
- Claude's call: a tighter, lower drift by her head (1024-space x 710→760, y 280→110; was 720→840, 240→40) so it clears
  the big stage star up and to her right with the chat open, and stays low, away from the choice buttons at the top.
- Reduce Motion: the three z's hold still at staggered spots (no drift) and still fade with sleep.
- Screenshots: /tmp/pt-round22/asleep-zzz.png, asleep-zzz-chat-open.png, drowsy-no-zzz.png (none).
