# Round 37: setup / clean-up rows + App Store compliance (code and config)

**Date:** 2026-11-17 · **Decided by:** Haylee (the rules: every prop and printout used on purpose, tasks short and broad,
kids can't read; not Kids Category, Education 4+, US only, AI required with consent). How it was built is Claude's call.

## Part A: setup and clean-up rows
- **Problem (round 36):** a solo kid got one ~45-word row with every item, labeled "Hang up the sign and more".
- **Now:** a role may have **several rows** in the setup and clean-up scenes, **at most 2 items a row**
  (`Bookends.rows`). Rows per role before items pair up: solo 4, else `6 / players` (≥1), so the scene stays ~6 rows.
  Solo setup target is 4 items (was 3); items no play task names are still always set up (worst case solo: 5 rows of 2).
- **Labels:** every row has a real short of **2–7 words that names its item(s)** (`Bookends.rowShort`,
  `isValidRowShort`): the AI's own short when it names its item and fits; two items → both shorts if ≤7 words, else
  "Set up the sign and the money" / "Put away the bowl and the hat" (tighter wording until it fits). Never "and more".
  The "After that, …" second sentence is gone. Each row's say line is "Role, A!" or "Role, A, then B!".
- **Prompts:** page/prop jobs ask for 5–12 word says and 2–5 word shorts that name the item (validation unchanged:
  ≤22 words, so older kits still pass).
- **Voice "what do I do?" (`read_job`)** reads all of that role's rows as one line (`SceneRowTap.roleLine`); a tap
  still reads its own row.
- **Replay parity:** rows are composed by the app from the saved jobs, so the same count says the same words
  (tested). Round-36 saved games compose the new rows: their row-read clips miss once (live once, then saved); the
  story, scene openings and play rows still hit.
- **Verified (iPad Pro 13" sim, `-PTDemo scene2`):** solo = 4 rows ("Set up the sign and the money", "Set out the
  snack menu", "Load the cut-outs", "Pack the suitcase"); 3 players = 6 rows, 2 per role. Screenshots:
  /tmp/pt-round37/setup-solo.png, setup-3players.png, report.png.

## Part B: compliance (from research/2026-11-16-app-store-compliance.md)
1. **`PrivacyInfo.xcprivacy`** (PretendThat/Resources; xcodegen puts it in Resources, confirmed in the bundle):
   no tracking, no tracking domains; UserDefaults **CA92.1**; system boot time **35F9.1** (CACurrentMediaTime/UITouch
   timestamps measure in-app timing; declared to be safe). No file-timestamp/disk/keyboard APIs found. Collected:
   **Other User Content**, not linked, no tracking, App Functionality (the kid's words as text to OpenAI/Anthropic,
   which may keep API data ≤30 days until ZDR). Claude's call: declare it until ZDR is confirmed at both, then remove.
2. **`ITSAppUsesNonExemptEncryption = NO`** in Info.plist (HTTPS/TLS only; research #20 agrees).
3. **Report a problem** (Guideline 1.2): Grown-ups (behind the gate) → **Report a problem** → the game just played
   (memory only, until the app quits) or a saved game → a part (each printed page, the story, setup, scenes 1–3,
   clean-up) → the mail sheet to support@pretendthat.app (mailto fallback; no mail account → "Copy the report").
   The email has only the game title, the part id, that part's AI-made text (≤1,500 chars) and the app version.
   Claude's call: **no flag on the kids' screens** (button audit: kids tap only to print and play; the gate would
   be needed anyway).
4. **AI disclosure:** the first-game intro already says "Hi! I'm Nutmeg, a pretend helper made by a computer!" (a
   bundled clip in her voice; kept as is). Added to Grown-ups → About what we save: "Nutmeg is an AI helper" (a
   computer character, AI-made words/story/pages, checked for safety, can be wrong, how to report). The consent
   screen already names OpenAI and Anthropic.
5. **Already in the app (checked):** no sign-in (4.8 / 5.1.1(v) N/A), Restore purchases + Manage subscription rows,
   Privacy policy + Terms in-app (Safari view, behind the gate), gate uses two-word numbers 21–99, explicit AI
   consent in onboarding, mic purpose strings honest about on-device speech.
6. **Privacy policy draft:** /Users/haymcarthur/pretendthat-site branch `privacy-additions` (commit a9b8f0d, not
   pushed/merged/published): operator, AI partners' roles, retention (pick ZDR option A or B), revoking consent,
   Nutmeg-is-AI + report, COPPA statement, US only. Bracketed items to fill.

## Haylee's to-do (account / store tasks), with the answers to give
- **Fill the privacy draft:** LLC legal name + mailing address, response time for reports, pick retention option A/B, legal review, then merge + publish.
- **ZDR:** NOT applying (Haylee, 2026-11-17: no audio is sent to AI; only text). The policy keeps "AI partners may keep requests up to 30 days", and the App Privacy label keeps User Content → Other User Content.
- **App Store Connect → App Privacy** (updated 2026-11-17 for analytics, see [analytics build](2026-11-17-analytics-build.md)):
  Tracking: **No**. Data collected:
  - **User Content → Other User Content** (until ZDR): **App Functionality**; linked **No**; tracking **No**.
  - **Usage Data → Product Interaction** (TelemetryDeck; always on since 2026-11-17, no switch): **Analytics**; linked **No**; tracking **No**.
  - **Identifiers → Device ID** (the random per-install id TelemetryDeck hashes; declared because the TelemetryDeck SDK's
    own privacy manifest declares it and the label must match the app's privacy report): **Analytics**; linked **No**; tracking **No**.
  - Everything else (contact info, user ID, diagnostics, audio, purchases, location) **Not collected**.
  After ZDR at both: drop Other User Content (Usage Data + Device ID stay while analytics ships).
- **Age rating questionnaire (→ 4+):** violence, sexual content, profanity, horror, drugs, gambling, contests: **None**. Unrestricted web access: **No**. User-generated content / user-to-user messaging: **No**. Medical/wellness: **No**. AI / generated content: **Yes**, filtered (local filter + OpenAI moderation) with in-app reporting. Parental controls: **Yes** (grown-up gate on settings, links and purchases). Age assurance: **No**. Advertising: **No**.
- **Category:** Primary **Education** (secondary Entertainment); **not** Made for Kids / Kids Category; no age band.
- **Availability:** **United States only**.
- **Export compliance:** "Uses encryption?" **Yes → only exempt (standard HTTPS)**; the Info.plist key answers it per build.
- **URLs:** Privacy https://pretendthat.app/privacy · Support https://pretendthat.app/support · EULA: custom https://pretendthat.app/terms (or Apple's standard EULA).
- **Review notes:** no accounts; gate = hold 2 s then tap the spelled number; push-to-talk + typed fallback; printing optional; AI content filtered and reportable (Grown-ups → Report a problem); no user-to-user chat, so blocking N/A; raise the relay cap/per-IP limits during review.
- **Support page:** add Restore instructions and the report response time.
- **Sim:** PT-R15's mic permission is still off (round 36 note).
