# iPhone checklist in the chat's bottom sheet; rows wrap instead of "…"

**Date:** 2026-11-20 · **Who decided:** Haylee (the sheet, and fixing the "…" rows); the details are Claude's calls

**Decision:** On the iPhone, the checklist (the one scene's setup and clean-up, and the older checklist scenes) uses the same sheet as the chat: edge to edge, attached to the bottom of the screen, only its top corners rounded, starting under the ✕ + step rail (`PTChatPanelShape(shelf: true)`). The one big button (▶ Let's play! / ▶ The End, or the ◀ / ▶ pair) sits on the sheet's white footer above the home indicator; the cards scroll above it. Checklist rows wrap to up to 3 lines (iPad too) so a row never ends in "…".

**How:** RootView draws `phoneChecklistSheet` in the sheet layer beside `phoneChatSheet` (ChecklistSceneView draws nothing on the iPhone now); `PTChecklistShelf` takes a `bottomClearance` (the button's room + the safe area's bottom inset from `safeInsets`).

**Why:** Haylee: the checklist "should be using the same slide up panel like the chat that goes from edge to edge and the bottom of the screen". The old shelf sat in the stage zone with side margins, and its rows were cut to 2 lines.

**Checked:** iPhone 17 Pro simulator (demo, no keys): setup at 3 and 6 kids, clean-up; iPad setup unchanged. Debug and Release build. Shots in design/sim-checks-2026-11-20/.
