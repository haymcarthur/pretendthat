# Printables after a lock: retry on return, matching sets, no fallback art

**Date:** 2026-11-18 · **Decided by:** Haylee ("no fallback art, show an error"); the root cause, the retry design and
the Try again tile are Claude's call.

## The bug (Haylee's phone)
She started a game at home, locked the phone, opened it at dinner (about an hour later, on cellular) and finished the
props. On the Print screen a couple of printables had the app-drawn ("computer generated") color page while their
coloring page was the AI picture.

## Root cause (PretendThat/Print/KitArtService.swift, before this fix)
1. **The color edit had no wait-for-the-app retry.** The color page is the outline colored in with the edit endpoint
   (`colorIn` → `ColorInFlow.color`, which only had `RetryOnce`: one retry after 1 s). An edit cut off by the lock
   failed on return, its one quick retry failed too while the network was still switching from Wi-Fi to cellular,
   and the page was marked failed: app-drawn color page next to an AI coloring page. Only the outline path had
   round 9's "retry once the app is active" (line ~433).
2. **The color set stopped waiting for its outline after 6 wall-clock minutes** (`waitForOutline`, `> 360`). A locked
   hour counted, so on return the color set gave up and drew its own page from the prompt: a different picture from
   the coloring page.
3. **An outline that failed made the color set draw its own page**, so the two sets never had to match.
4. **No background time during the hunt.** The background task only started in `makingKit` / `kitReady`, but the
   kit art is drawn during the prop hunt, so a lock then gave in-flight calls no time at all.

## Decision
- **Retry after a lock (`AwayRetry`, NutmegCore/PrintablesAfterLock.swift).** Every kit image call (outline pages,
  the character sheet, color edits) runs through it. A call that failed while the app was away (it went to the
  background during the call, or isn't back yet) waits for the foreground, pauses for the network, and tries again;
  these don't count as real retries (cap 6). In the foreground: network errors get 2 real retries, other errors 1
  (as before). An unusable account (no credits, bad key) stops at once. `AppPresence.shared` is set from
  `AppModel.scenePhaseChanged`.
- **Background time** also starts on background while either set is drawing (the hunt).
- **The sets always match (`PrintablePairs`).** The color page always waits for its outline (no time limit; the
  outline always ends landed or failed) and never draws a picture of its own. A page either set gave up on is
  "not ready" in BOTH sets.
- **No fallback art in a live game (Haylee).** A page whose picture still fails after the retries shows a blank page
  with a soft veil, a paintbrush and a **Try again** button (`PTPageNotReady`), on the fan tiles and in the chat
  panel's Print tab. Try again asks for only that picture: the outline failed → both sets redraw it; only the color
  failed → the kept outline is colored in again (one edit). The printer waits (dimmed, no spinner) while any page of
  the chosen set is not ready or drawing again, and `KitPrinter` never prints a live page without its picture. A page
  that is still drawing shows a blank page under the spinner (no fallback underneath). A page one set gave up on
  isn't saved with the game.
- **Demo mode and replays keep the built-in pages** (no image service, or saved art): `PictureState.builtIn`.

## Why
- Haylee's report: the two versions disagreed and some were fallback art after a lock, not after a real failure.
- Haylee (2026-11-18): she'd rather show an error than the computer-generated art in a live game.
- Simplest fit with the code: one retry helper for every image call, one small state table for both sets on the
  existing `OutlineBoard`, no new services.

## Not done / not verified
- No real-device lock test (no keys or live calls in agent tests). Unit tests simulate it: calls throw network errors
  while `AppPresence` is away, then succeed once it's back (NutmegCore/Tests/.../PrintablesAfterLockTests.swift).
- Nutmeg says nothing about a not-ready page (no new voice line, so no clip cost); the tile is silent.
