# Analytics: TelemetryDeck + Apple App Store analytics (2026-11-16)

**Decision:** Use Apple's App Store Connect analytics (no code) plus TelemetryDeck for anonymous in-app event counts (show started, step reached, print tapped, plan bought). No user IDs, no names, nothing about kids, no ad tracking. Firebase/Mixpanel were ruled out because they track devices and complicate the privacy label.

**Why:** Fits the "never store anything about kids" rule and keeps the App Store privacy answers simple, while still telling us where families drop off and which plans sell.

**Who decided:** Haylee (picked Claude's recommendation).
