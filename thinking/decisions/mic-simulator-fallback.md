# Mic: why it was off in the simulator, and the demo path

- **Date:** 2026-11-13
- **Decided by:** Claude's call (polish pass)

**Finding:** The mic button was disabled because the simulator had the app's **Speech Recognition permission stored as denied** from an earlier run (the prompt never showed again, and the app silently turned the mic off). It was not a missing on-device model: after resetting the simulator's privacy state (`xcrun simctl privacy booted reset all co.crimsonfoundry.pretendthat`) and allowing both prompts, the iPad Pro 11" (M5) simulator on iOS 27.2 reports `supportsOnDeviceRecognition == true` and the mic turns on ("On-device ✓" in Grown-ups). On a real iPad (A12 or newer), on-device en-US recognition is supported, so the mic works as designed.

**Decision:**
1. `Listener` now reports *why* it is off (`status`), shown in Grown-ups > Connections > Speech (permission denied, restricted, no recognizer, no on-device support). Grown-ups gets an "Open Settings" button when permission was denied.
2. When the mic is off for any reason, the mic button becomes a **keyboard button** that opens `PTTypeSheet` (a native TextField sheet). Typed text goes through the same path as speech. This is the graceful demo path everywhere, including a simulator with no mic.
3. Only in **DEBUG simulator builds**, if on-device recognition is unavailable, `Listener` falls back to Apple's server recognizer so the demo mic still works; Grown-ups says so ("Simulator demo: Apple server speech"). Release builds and real iPads stay on-device only, so kids' audio never leaves the iPad ([On-device speech-to-text](on-device-stt.md) still holds).

**Before the demo:** if the mic shows as a keyboard, open Grown-ups and read the Speech line; for a denied permission run `xcrun simctl privacy booted reset all co.crimsonfoundry.pretendthat` (or tap Open Settings) and relaunch.

**Why:** A silent disabled mic looked broken. Telling the grown-up why, plus a typing fallback, keeps the demo moving without weakening the on-device privacy promise for real use.
