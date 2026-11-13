# Components first, native controls first

- **Date:** 2026-11-13
- **Decided by:** Haylee

**Decision:** Build every screen from a small component library in `PretendThat/DesignSystem/`. Use native SwiftUI/UIKit controls (Button, Toggle, ProgressView, sheets, NavigationStack, Label, Grid, UIPrintInteractionController, …) wherever one exists, styled through `ButtonStyle`, `LabelStyle`, `ProgressViewStyle` and `ViewModifier`s that read `Theme` tokens. Reusable views (`PTChoiceTile`, `PTCard`, `PTRoleBadge`, `PTChecklistRow`, `PTPropCard`, `PTHandoffCard`, `PTMicButton`, `PTPageThumbnail`, …) cover the rest. Screens compose only these; no one-off styling, colors, fonts or paddings in screen files. A DEBUG-only component gallery (opened from parent settings) shows every component in every state.

**Why:** Custom one-off elements break consistency. A gallery gives Haylee one place to review and design against.
