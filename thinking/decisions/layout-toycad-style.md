# Layout (ToyCAD) and component style (Emote, revised)

- **Date:** 2026-11-13
- **Decided by:** Haylee. Supersedes the "neutral placeholder components" note in [motion and surface](motion-and-surface.md).

## Layout (from Dribbble "3D Kids App UI Design for Creative Learning" by Nixtio/ToyCAD; Nutmeg stays FLAT)
- iPad landscape. **Nutmeg is the hero, big and centered.** Items she presents (game ideas, roles, props) are cards **fanned in an arc** around her (half on each side, slight tilt per card, small overlap), springing in and out (`PTFan`).
- **Left step rail** (`PTStepRail`): 4 round steps with labels "Game", "Get Ready", "Print", "Play". Done = check, current = highlighted, upcoming = dimmed. A connector fills as progress. Tapping a reached step jumps back without losing state (`AdventureStore.goTo`, `reachedStep`).
- **Bottom control pill** (`PTControlBar`): mute/unmute (with a listening dot), chat panel toggle, leave.
- **Chat panel** (`PTChatPanel`): slides in from the right with the live transcript (Nutmeg's and the kids' turns) and a native TextField. Voice and typing work together; the stage shifts left when it opens. Transcripts live in memory only and are cleared on leave (PretendThat stores nothing). Kid turns come from Realtime input transcription (`gpt-4o-mini-transcribe`).

## Style revised (from Dribbble "Kids Character Animation" by Emote Agency): clean, light, minimal
- **Canvas** `Theme.canvas` (#F5F4F2). The angular shard background was dropped. A flat light-gray **ground oval** under Nutmeg (`PTGround`, crisp).
- **Panels** (rail, chat, cards, speech bubble): white, radius 24–28, one small low-opacity shadow (`ptPanel`). No dark panels.
- **Round icon buttons** (`PTIconButton`): light gray (#EDEDED) circles, thin regular-weight SF Symbols; selected = thin dark ring and/or brand fill; mute uses coral.
- **Primary CTA**: black pill (#111) with white text (`.ptPrimary`, the print gate). **Secondary**: white pill with a hairline border. Quiet: gray pill. Success: lime.
- **Cards** (`PTItemCard`): white, rounded, illustration as hero, small semibold label, small gray tag pill (with a role-color dot) and state chip (found ✓, swapped, pretend).
- **Type**: calmer medium/semibold rounded (`Theme.uiFont`); heavy display only for big moments (the hand-off). Brand colors used sparingly as accents (selection, progress, checks, role colors). Lots of white space; Nutmeg and her stage props carry the color.
- Touch targets ≥ 64 pt.
