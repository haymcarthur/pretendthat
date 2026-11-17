# Onboarding v2 build: full-screen pages, no gate, straight into the first game or a silent home

**Date:** 2026-11-16 · **Decided by:** Haylee (the design: [mockup approved](2026-11-16-onboarding-v2-approved.md),
[no gate](2026-11-16-no-gate-in-onboarding.md), queue "Onboarding v2"). How it was built is Claude's call, noted.

## What changed
- **Seven full-screen pages** matching design/mockups/onboarding-v2/ pages 1–7 (option A, one-page How it works):
  Hi, grown-up! · How it works (4 cards) · What you'll need · Private by design + REQUIRED AI consent · Hold to talk ·
  Start free, upgrade anytime · Hand the iPad to your child. Left art card on a stage (sky, valance, curtains, floor
  disc, glow), right column with back arrow, 7 dots, big title, one line, one big coral button. Every size is the
  mockup's (1194 × 834 pt) times one scale; the 13" gets the same page a little bigger and the art card stretches.
- **No grown-up gate anywhere in onboarding.** The gate stays on the Grown-ups menu and the plans sheet (unchanged).
- **Not a dialog over home:** the onboarding is now a full-screen layer in RootView (was a `fullScreenCover` with a
  card). `OnboardingPages.swift` holds the pages; `OnboardingView.swift` keeps the round 33 plans sheet and kid card.
- **Page 7:** "Start our first game" → `onboardingStartFirstGame()` saves the flags, checks the New game gate, and
  starts the conversation; the onboarding stays up until `store.beginConversation()` and is removed in the same update,
  so the stage replaces it with no home page in between (measured: 0 s after the tap the stage is already under the
  fading page; she greets with the first-game intro clip + live line, 9.2 s heard). "Go to the home page" → the start
  screen with NO voice (log: no clip, no greeting; only the silent socket pre-connect). The start screen's intro
  replays once the onboarding goes (it ran unseen underneath).
- **Consent (page 4):** unchanged rules: "I agree, let's play" / "Not now" → the calm "PretendThat needs this to work"
  page (on the same dot; "I agree, let's play" or "Close for now" → home, silent). Privacy link in the in-app browser.
- **Mic (page 5):** one Continue → the system mic + speech prompts; denied → the round 33 note + Open Settings + Next.
  The speech-model pre-download still starts here (round 34 code, untouched).
- **Plans (page 6):** Free Preview primary; Show Pass / Season Pass cards read `PlanCatalog` (new `introThenText`,
  `OnboardingCopy.cardShows`, `PlanCatalog.dollarsText`); Restore (StoreKit `AppStore.sync`, round 33) / Terms / Privacy.
  A replay with the Free Preview used up says "Continue". No purchase button (StoreKit comes later).
- **Back works on every page but page 1** (nothing before it). **State survives backgrounding and even the app being
  closed:** a first-launch flow saves its page and mic answer (`pt.onboarding.page`, `.micAsked`, `.micDenied`: a page
  name and booleans, nothing about kids) and resumes there (verified: killed on page 3, relaunched on page 3).
- **Replay the intro** (Grown-ups) opens the same new pages from page 1 (no clip on a replay; never counted).

## Voice
- Only page 1 keeps a clip: round 33's "Hi! I'm Nutmeg. Can you get a grown-up? This part is just for them." It plays
  through NutmegSpeaker (round 35 prep path) only while page 1 is showing, stops when the page changes or the app goes
  to the background, never on a replay. Her mouth follows it (the page uses her real rig, not a still).
  Log: `PlayAndRecord 48000 Hz … input off (output only)`, `heard ×1.200`, mic permission still not asked.
- **Dropped:** the round 33 hand-off line ("…Tap the big play button…"): it played on the start screen after the cover
  closed, which breaks "never a voice without Nutmeg on screen talking to them", and "Start our first game" now opens the
  game whose own greeting comes first. The clip stays bundled (DemoDriver uses it), just not in onboarding. No TTS.

## Claude's calls
- Nutmeg on pages 1, 3, 4, 5, 7 and the Play card is the game's layered rig (`NutmegCharacter` with a forced pose and
  face: wave/happy, point/talking, idle/happy, idle/ooh, celebrate/yay), so she breathes, blinks and lip-syncs. Page 6's
  perky sit (clipboard on her lap) isn't a rig pose (the rig only sits for the nap), so it's the mockup's still
  `nutmeg-sit-perky.png` imported as `onboarding-nutmeg-sit-perky` (made from her real art; no new character art).
- The printer, shield, clock and mic badge are drawn in SwiftUI from the mockup's inline SVGs; the props, stars,
  ticket, valance and curtains are the repo's existing assets (byte-identical to the mockup's img/).
- Fixed point sizes × scale instead of Dynamic Type (the page is a fixed composition); titles may shrink to fit.
- Privacy copy follows the mockup's four lines ("Saved games stay on this iPad" is no longer on this page; it's still
  in Grown-ups → About what we save). The consent question line is gone (the button says it).

## Deviations from the mockup
- Type is SF Rounded (the app's face), not Nunito, so a few lines wrap differently (page 6 title "Start free, /
  upgrade anytime"; page 1 and 5 leads).
- The How it works cards get extra white space at the bottom on the 13" (the row fills the taller screen).

## Checks
- NutmegCore `swift test`: 467 passed (flow v2: no gate, 7 pages, back on every page, two exits, resume; copy/prices).
- Clean simulator Debug build (`build/DD-onb2`) and a Release build: "Release key check: no personal keys".
- PT-R15 (11"), fresh install, mic reset: run A all 7 pages → Allow → Start our first game (stage, talking);
  run B → Don't Allow (denied note) → Go to the home page (silent). iPad Pro 13": every page via `-PTOnboarding`.
- Screenshots: /tmp/pt-onb2/ (01–07 + compare-01…07 mockup-over-app, 05b system prompt, 05c denied, 08a/08b first
  game, 09 silent home, relaunch-on-needs, 13in-*).
- **Needs the real iPad:** hearing page 1's clip (and that it stops on Next), no mic prompt before page 5, the system
  prompts and the speech-model download, VoiceOver order and the largest text sizes, the first game's greeting
  timing on device.
