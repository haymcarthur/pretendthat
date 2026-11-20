# Where things stand (handoff, end of 2026-11-18 session)

Start here in a new session, after CLAUDE.md. The decision files have the details; this is the map of what's done, what's live, and what's next.

## First: set up the MacBook Air (2026-11-20)
The repos moved to mcartha ([repos-moved-to-mcartha](decisions/2026-11-20-repos-moved-to-mcartha.md)) and this Mac has no copies yet.
1. Clone if missing: `git clone https://github.com/mcartha/pretendthat ~/PretendThat` and `git clone https://github.com/mcartha/pretendthat-site ~/pretendthat-site` (same paths the notes and scripts use).
2. Not in git: `Secrets.xcconfig` (ask Haylee to copy it from the old Mac, or fill in from Secrets.example.xcconfig), design/appstore-screens/ (only needed for App Store screenshot work).
3. Tools: `brew install xcodegen`, then `xcodegen` in ~/PretendThat; `npm install` in ~/pretendthat-site. Check Xcode 16+ is installed and signed in.
4. Check `swift test` in NutmegCore (751 tests passed last time) and a simulator build in demo mode, then do the next small task below.
5. Pages for pretendthat-site was checked 2026-11-20: main / root, pretendthat.app, HTTPS enforced (DNS check was still running).

## Shipped
- **TestFlight build 1.0 (4)** uploaded 2026-11-18 (commit 933c6c6, pushed to origin/main). Internal testers get it without beta review. Contents: [decisions/2026-11-18-build-4.md](decisions/2026-11-18-build-4.md).
  - Peek v4: Haylee's redrawn body + paws; the body sits behind the scene card, the paws in front ([peek-hands-regenerate](decisions/2026-11-18-peek-hands-regenerate.md)).
  - Saved-game offer is just the picture. On iPad it sits beside Nutmeg, on iPhone above the bar, and in the chat (both devices) when the chat is open. Tapping the picture plays the game. ([saved-offer-picture-only](decisions/2026-11-18-saved-offer-picture-only.md)).
  - Nutmeg looks up at the kids while she talks during Play. The idle/lock fix: the voice reconnects with retries, a keepalive ping, and the speaker restarts. ([device-testing-fixes](decisions/2026-11-18-device-testing-fixes.md)).
  - Printables after a lock: art requests cut off by the lock are retried on return, and the color and coloring pages always come from the same AI picture. Live games show **no fallback art** (Haylee): a page that still fails shows a "Try again" tile and won't print until it loads. ([printables-after-lock](decisions/2026-11-18-printables-after-lock.md)).
- **Repos moved (2026-11-20):** now github.com/mcartha/pretendthat and github.com/mcartha/pretendthat-site ([repos-moved-to-mcartha](decisions/2026-11-20-repos-moved-to-mcartha.md)). Update the Mac remotes and check Pages.
- Build 3 was submitted for beta review earlier (may be moot now that internal testers have 4).
- NutmegCore: 751 tests pass.

## Waiting on Haylee (device checks of build 4)
- **Idle/lock:** lock the phone mid-game for a few minutes, unlock, then press the mic and tap a prop card. Both should work.
- **Printables after lock:** lock the phone during the prop hunt (ideally switch Wi-Fi → cellular), come back, and check that the color and coloring pages match and none show built-in art.
- **Try again tile:** never seen on screen yet. Demo mode can't show it because it has no AI images.

## Next small task
- **Retake the saved-offer screenshots from current main.** Demo games now seed "Moon Crumbs Bakery" with its real cover, so the offer shows the same picture as its bookshelf book ([demo-seed-real-cover](decisions/2026-11-18-demo-seed-real-cover.md), merged). The agent's shots in /tmp/pt-saved-offer-v2/ were built from an old base and show the OLD card with buttons. Ignore them. Retake 4 shots (iPhone/iPad, chat closed/open: `-PTDemo soundsLike`, `-PTChat`, plus `-PTNoAI -PTAnalyticsOff -PTSkipAuth`) and show Haylee. **Real-game behavior was never wrong:** the offer and the shelf both use `AppModel.cover(for:)`.

## Open / later
- **Peek right paw rim:** the right paw's dark top rim (path 5) is hidden under the taller redrawn right paw, so the two paws don't quite match. This is Haylee's call: either fix the art in Figma (move the arc above the paw, re-export) and rerun `tools/peek_v3_imagesets.py`, or leave it. Tiny finger-line nicks only show at 8×.
- **Not-ready page voice line:** Nutmeg says nothing when a printable isn't ready (a clip would cost money). Maybe add one later.
- Carried over: the iCloud schema deploy to production (needs Haylee's iPad signed into iCloud), the D&B name change, and the rest of [business-setup-todo.md](business-setup-todo.md). The App Store listing draft is in docs/app-store-listing.md. Plus the other items in [open-questions.md](open-questions.md).

## How we work (standing rules from this stretch)
- Art: regenerate Nutmeg art in ChatGPT and vectorize it in Figma (Haylee), never patch shapes in code or Figma. She exports SVGs to ~/Downloads, and they're copied into design/nutmeg/peek/regen/. Prompts are in design/nutmeg/peek/regen/prompts.md.
- Queue app changes into rounds of 3–5 items, with one build agent at a time on the same files.
- No API keys in agent tests by default (demo mode), and at most one live game per round.
- No new TestFlight build until Haylee says. Builds use team 66898X3HH3, Release config, and the key check must pass. Upload with `xcodebuild -exportArchive` (method app-store-connect, destination upload) through her signed-in Xcode account.
- Don't touch simulators AF512F6A / 1820E3FA or her devices; agents make throwaway simulators.
- Local only (not in git, too big): design/appstore-screens/ (298 MB of App Store screenshot work).
