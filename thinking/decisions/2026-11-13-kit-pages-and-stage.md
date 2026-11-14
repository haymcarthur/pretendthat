# Kit pages fit; pages step uses the prop-card camera; confetti on top

**Date:** 2026-11-13 · **Decided by:** Haylee (bugs and wants); fixes built in rounds 5–6.

- **Page preview:** the large preview looks exactly like the pages in the stack: one white sheet, rounded corners, a single soft shadow, no per-item cards or shadows, and near-white AI backgrounds blended to white.
- **AI art is always aspect-FIT, never cropped,** in the stack, the preview and the printed PDF. ("Fill edge to edge" briefly caused cropping, which was a regression.) Verified with BOTTOM-marker test art on all 6 page types.
- **Print / Let's play buttons sit above the pages.**
- **The pages (Print) step uses exactly the prop-card step's camera:** same Nutmeg scale and position, same floor; only the right-hand content differs.
- **Confetti is the topmost layer** (above the chat panel, step rail and control pill) and ignores taps.
- **Prop card text is never truncated** (the card grows), and Nutmeg keeps prop descriptions to about 6 words.
