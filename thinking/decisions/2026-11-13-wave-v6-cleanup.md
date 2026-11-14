# Wave body v6: cleanup, transform, clipboard layer split

**Date:** 2026-11-13 · **Decided by:** Claude's call (following Haylee's cleanup-only rule: fill swaps, no reshaping)

- New headless wave (Figma 35:72, clipboard on viewer's left like idle, waving with her left arm on viewer's right) replaces `nutmeg-body-wave.svg`; the old one is kept as `nutmeg-body-wave.v5bak.svg`.
- Green screen removed; fills swapped to the palette (fur #AD5E36, shade #9C4727, vest #55157C, vest shade #470D62, belly #FFE9CF, clipboard #FEB80B/#FD9502/#FBA304/#FED964 like idle).
- Neck top is at y 589, x 502–719 (idle: 766, 544–734), so the pose needs a body transform: scale 0.876 anchored at the neck top (610.5, 589), then offset (+28.5, +177). Matrix [0.876, 0, 0, 0.876, 104.2, 250.0].
- Clipboard + the forearm/paw in front of it go in `nutmeg-wave-clipboard.svg` (same viewBox, same transform) to draw above the head; it uses a single-path clipPath (1px-rect clips showed seams under the 0.876 scale).

**Why:** matches the writing body's approach; lets the clipboard sit in front of the head.

**Update (Haylee):** the waving arm goes in front of the head. It is split out whole (arm path + paw lines + pad, 7 paths, no clip needed since nothing in the body was drawn over it) into `nutmeg-wave-arm.svg`, same viewBox and transform as the body. Stack: body → head → face → headset → wave-arm → wave-clipboard.
