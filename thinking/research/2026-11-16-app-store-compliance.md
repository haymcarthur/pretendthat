# App Store compliance: gap list for PretendThat

**Date:** 2026-11-16 · **Asked by:** Haylee ("background research on what we are missing to get the app compliant with the app store") · **Written by:** Claude (research only: no app code changed, nothing committed)
**Status:** research. Nothing here is decided. The questions for Haylee are in §3.
**Not legal advice.** COPPA, the state app-store laws and GDPR are legal questions. Before launch, get a short review from a children's-privacy lawyer or a COPPA Safe Harbor program (for example kidSAFE or PRIVO).

**What I checked in the code (2026-11-16):** `PretendThat/Resources/Info.plist`, `project.yml`, `Relay.xcconfig`, `Secrets.xcconfig` (I only checked whether each key is set; no values were read out), `relay/src/index.ts`, `GrownUpsView.swift`, `GrownUps.swift`, `Listener.swift`, `RealtimeProtocol.swift`, `ClaudeClient.swift`, `ImageClient.swift`, `Suggestions.swift` and the app icon set. I also read the live pretendthat.app/privacy and /support pages.

---

## 0. The six things that matter most

1. **A release build from this Mac would ship your personal API keys.** `Relay.xcconfig` does `#include? "Secrets.xcconfig"`, and both configurations (Debug and Release) use `Relay.xcconfig`. The local `Secrets.xcconfig` has `ANTHROPIC_API_KEY` and `OPENAI_API_KEY` **set**. `Info.plist` copies both into the bundle (`$(OPENAI_API_KEY)`), and "personal keys win over the relay". So an Archive made here would:
   - put live keys in plain text inside the IPA
   - skip the relay's rate limits and spend cap
   This is not an Apple rule, but it's the most urgent fix.
2. **Third-party AI consent (Guideline 5.1.2(i), November 2025).** The current text says: "You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so." The child's voice and words go to OpenAI, and their words also go to Anthropic. Today nothing in the app asks for or records that permission. The onboarding (research of 2026-11-16) isn't built yet.
3. **COPPA plus OpenAI's own rule.** OpenAI's under-18 guidance says not to "process any personal data of children under 13" without first setting up **Zero Data Retention (ZDR)**. By default, `/v1/realtime` keeps abuse-monitoring logs for 30 days. COPPA's audio exception (§312.5(c)(9)) needs the audio "deletes[d] immediately after responding". Without ZDR, both the COPPA voice story and the "Data Not Collected" privacy label fall apart.
4. **No privacy manifest.** The app uses `UserDefaults`, a required-reason API (`Suggestions.swift` and `AppModel.swift`), and there's no `PrivacyInfo.xcprivacy`.
5. **Subscriptions aren't built.** There's no StoreKit, Restore, Terms of Use or EULA. The Grown-ups rows are placeholders behind a flag, and the website has no /terms page.
6. **The AI content-reporting rule (1.2).** It covers "AI content creation apps": filtering, "a mechanism to report offensive content", and published contact info. The filtering exists (round 19). There's no in-app report.

---

## 1. Requirement → status → gap → fix

Priority: **BLOCKER** = rejection or a legal or security problem that's likely · **important** = may be rejected or is a real legal risk · **nice** = polish. Effort: S under half a day · M 1–3 days · L more than 3 days, or needs outside parties.

| # | Requirement (source) | Status in the app (checked) | Gap | Fix | Priority | Effort |
|---|---|---|---|---|---|---|
| 1 | **No secrets in the binary** (security; it also keeps 1.3 and 5.1.2 promises true, since direct calls skip the relay's moderation route and caps) | `Secrets.xcconfig` has both personal keys set. It's included in Release, and `Info.plist` embeds `OPENAI_API_KEY` and `ANTHROPIC_API_KEY` | A release archive ships live keys and calls the providers directly | Release reads only `RELAY_HOST`/`RELAY_TOKEN`: include `Secrets.xcconfig` in Debug only, or blank the key lines in a Release xcconfig. Add a build-phase check that fails a Release build if a key is non-empty. Rotate both keys if any build with them ever left this Mac (TestFlight, a shared IPA) | **BLOCKER** | S |
| 2 | **5.1.2(i): disclose and get explicit permission before sharing personal data with third-party AI** ([Guidelines](https://developer.apple.com/app-store/review/guidelines/#data-use-and-sharing); [Apple news, Nov 2025](https://developer.apple.com/news?id=ey6d8onl)) | No consent screen. Only the mic purpose string mentions "our AI partner" | No explicit permission; OpenAI and Anthropic aren't named in the app | Onboarding screen 3 (behind the gate) names OpenAI (voice, pictures) and Anthropic (stories), says what's sent and that it's not kept. Add an explicit **"I agree"** button plus a Privacy Policy link. Store the yes as a local flag only. No yes means no AI: show a "Grown-ups: please finish setup" state. Re-ask if the providers change | **BLOCKER** | M |
| 3 | **COPPA verifiable parental consent / voice exception** ([16 CFR 312.5(c)(9)](https://www.law.cornell.edu/cfr/text/16/312.5); compliance date **Apr 22, 2026**, [BBB Programs](https://bbbprograms.org/media/insights/blog/coppa-amended)) | Push-to-talk audio streams to OpenAI Realtime. Realtime transcription (`gpt-4o-mini-transcribe`) makes text, and the kid's text goes to Claude (`kidSaid`). A local PII filter and moderation exist | The audio exception needs "no other personal information", "does not disclose it" and deletion "immediately". OpenAI's default is 30-day retention. There's no verifiable-consent path, so the app has to fit the exception | (a) Get **OpenAI ZDR** for the org/project (`/v1/realtime`, `/v1/audio/speech` and the image endpoints are listed as ZDR-eligible; approval goes through sales). (b) Get **Anthropic ZDR**, or at least confirm its retention. (c) Sign or accept both **DPAs** so the providers count as "support for internal operations" service providers, not third parties. (d) Keep the PII filter. (e) Have a lawyer or Safe Harbor confirm the approach | **BLOCKER** | L (outside parties) |
| 4 | **OpenAI terms for under-13 users** ([Under-18 API guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance)) | No ZDR | Using the API with under-13 data without ZDR breaks OpenAI's terms, which risks the account (and the app) | ZDR approval (same as #3). Also check the image model: ZDR lists `gpt-image-2`, `-1.5` and `-1-mini`, but the app defaults to `gpt-image-2.6-flare` ([OpenAI: your data](https://developers.openai.com/api/docs/guides/your-data)) | **BLOCKER** | L |
| 5 | **Anthropic: organizations serving minors** ([guidelines](https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-minors)) | Claude gets the kid's words through the relay. Nutmeg never says she's an AI. Model `claude-opus-5-5` | You must disclose to users that they're talking to an AI. You must also state COPPA compliance publicly, use Anthropic's child-safety system prompt and add moderation, and Anthropic may audit | Add an AI disclosure in onboarding and on Nutmeg's first-ever line (for example "I'm Nutmeg, a computer helper, not a real mouse!"). Add a COPPA statement to /privacy. Ask Anthropic for the child-safety prompt. Check ZDR eligibility for the model you use | **BLOCKER** (disclosure) / important (the rest) | S–M |
| 6 | **1.3 Kids Category: no personal or device info to third parties** ([Guidelines 1.3](https://developer.apple.com/app-store/review/guidelines/#kids)) | Claude, images and moderation go through your relay. **The Realtime WebSocket connects straight from the iPad to `wss://api.openai.com`** with an ephemeral key (`RealtimeProtocol.swift:44`) | OpenAI sees the device's IP address (network info) plus voice | Option A: proxy the Realtime WebSocket through the Cloudflare relay (Workers support WebSocket passthrough), so OpenAI only sees Cloudflare. Option B: keep it, rely on ZDR and the DPA, and describe it in the review notes. A is safer | important (likely a rejection reason if a reviewer digs in) | M |
| 7 | **Privacy manifest / required-reason APIs** ([Apple docs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api); required since May 1, 2024, [upcoming requirements](https://developer.apple.com/news/upcoming-requirements/)) | No `PrivacyInfo.xcprivacy`. Uses `UserDefaults` (CA92.1). No file-timestamp, boot-time, disk-space or keyboard APIs found in a search of `PretendThat/` and `NutmegCore/Sources` | Missing manifest, so App Store Connect flags it at upload (ITMS-91053) | Add `PretendThat/Resources/PrivacyInfo.xcprivacy`: `NSPrivacyTracking` false, no tracking domains, `NSPrivacyCollectedDataTypes` matching #8, and the UserDefaults reason CA92.1. Re-grep before each release (iCloud/CloudKit in D4 may add file timestamps → C617.1) | **BLOCKER** | S |
| 8 | **App Privacy "nutrition label"** ([App privacy details](https://developer.apple.com/app-store/app-privacy-details/)) | Not filled in | Apple's "collect" means kept "longer than what is necessary to service the transmitted request in real time", **including by third-party partners** | **With ZDR at both providers:** "Data Not Collected" is defensible. **Without ZDR:** declare **Audio Data** and **Other User Content** (the kid's text), purpose App Functionality, not linked to identity, no tracking. Purchases go through Apple, so you don't declare them. The CloudKit private database isn't collection. The label must match the privacy policy and the 5.1.2(i) screen word for word | **BLOCKER** (required to submit) | S once #3 is settled |
| 9 | **5.1.1(i) privacy policy: link in App Store Connect and in the app; retention, deletion, how to revoke consent** ([Guidelines](https://developer.apple.com/app-store/review/guidelines/#privacy)); **COPPA §312.10 written data retention policy** ([eCFR](https://www.law.cornell.edu/cfr/text/16/312.10)); §312.4 notice | pretendthat.app/privacy is live and good. **Missing:** retention periods at OpenAI, Anthropic and Cloudflare; a written retention policy (purpose, business need, deletion timeframe); how a parent revokes consent; an effective date; the COPPA operator contact details (name, address, email). No in-app link yet (`privacyPolicy` is a placeholder row) | Policy gaps, and no in-app link | Add a "Data retention" section (voice: 0 days with ZDR or "up to 30 days at OpenAI" without; saved games: on device until deleted; support email: say 12 months). Add "Revoke consent: Grown-ups → Turn off Nutmeg's voice, or delete the app". Add operator contact details and the providers' named roles. Add the in-app Privacy Policy row behind the gate | **BLOCKER** (link) / important (content) | S |
| 10 | **3.1.2 auto-renewable subscriptions** ([Guidelines 3.1.2](https://developer.apple.com/app-store/review/guidelines/#subscriptions); [Apple: subscriptions](https://developer.apple.com/app-store/subscriptions/)) | Not built: no StoreKit code, Restore, Manage or Terms of Use. Plans are designed (Free Preview of 2, Show Pass, Season Pass) | The purchase screen needs: the plan name, length and what you get ("10 new shows a month", "up to 30"); the **billed price as the most prominent price**; Restore; functional links to the **Terms of Use (EULA)** and the Privacy Policy; and auto-renew wording | StoreKit 2 `SubscriptionStoreView` (or a custom view) behind the gate. Add Grown-ups rows: Restore (`AppStore.sync()`), Manage (`showManageSubscriptions`), Privacy, Terms. Put a Terms of Use link in the App Store Connect description, or use Apple's standard EULA. Test with a StoreKit configuration file and the sandbox | **BLOCKER** (if you launch paid) | L |
| 11 | **The Free Preview isn't an Apple "trial"** (3.1.1/3.1.2) | Planned as 2 free new shows counted in the app | Never call it a "free trial", and don't present it as an introductory offer. When it runs out, say clearly what happens; kids never see prices | Keep the count in the Keychain (it survives a reinstall). Copy: "2 free new shows, no card". Replays stay free. The paywall only appears behind the gate | important | S |
| 12 | **Terms of Use / EULA** (3.1.2; App Store Connect metadata) | No /terms on the site. The support page links only Pricing, Support and Privacy | Required for subscriptions | Either point to Apple's standard EULA (`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`) in the description, or publish pretendthat.app/terms (subscription terms, the fair-use cap of 30, AI-content disclaimer, governing law) and add it as a custom EULA | **BLOCKER** (with subscriptions) | S |
| 13 | **1.3 parental gate for links, purchases and "distractions"** ([Apple: parental gates](https://developer.apple.com/app-store/parental-gates/)) | `PTGrownUpGate`: hold 2 s, then tap the spelled-out number. It covers Grown-ups | The rows behind it (privacy, help, purchase) don't exist yet. The risk: a 7–8-year-old can read "seven", and reviewers have rejected easy gates | Keep the hold step, but make the question harder for a kid (for example "tap the number that's three more than *five*", or a two-digit number spelled out). Every link out, `mailto:`, the paywall and the Terms go through it | important | S |
| 14 | **1.2 / 4.7: AI content creation, filtering, reporting, contact** ([Guidelines 1.2](https://developer.apple.com/app-store/review/guidelines/#user-generated-content)) | Filtering: local filter + `omni-moderation-latest` + OpenAI image moderation (round 19). Contact: support@ on the site. Reporting: none in the app | No "report offensive content" in the app | Add Grown-ups → "Report a problem with a game". It opens a gated `mailto:` with the game title and kit text (not voice, nothing about the kid). Also add a long-press "Report" on a saved game in Grown-ups. Commit to answering within 48 h on /support. "Block users" isn't applicable (no users talk to each other); say so in the review notes | **BLOCKER**-ish (often cited for AI apps) | S–M |
| 15 | **5.1.1(ii) purpose strings** | Mic: accurate since round 28 ("sent securely to our AI partner... isn't saved by PretendThat"). Speech: honest about Apple | Reasonable. The "isn't saved" claim depends on ZDR. Name OpenAI if the consent screen does | After ZDR: "...sent to OpenAI to understand it and isn't kept." The speech fallback can use server recognition (`requiresOnDeviceRecognition = !usesServerRecognition`); prefer on-device so nothing leaves the iPad | important | S |
| 16 | **Pre-permission screen (HIG)** ([HIG: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy)) | Onboarding not built | The mic alert may appear with no explanation | One "Continue" button, no close, then the system alert. If denied: the typed chat and choices still work | important | M (part of onboarding) |
| 17 | **Age rating questionnaire (the new 2025 system: 4+, 9+, 13+, 16+, 18+)** ([upcoming requirements](https://developer.apple.com/news/upcoming-requirements/); [9to5Mac](https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/)) | Not filled in | New items cover in-app controls and capabilities (AI features, user-generated content, web access) | Answer honestly: no web access, no user-to-user chat, AI-generated content with filtering, in-app controls = the parental gate. You need **4+** for the Kids Category | **BLOCKER** (required) | S |
| 18 | **Kids Category age band** (App Store Connect) | The audience is 4–8 | Bands are 5 and under, 6–8 and 9–11, and you can choose only one | Choose **6–8** (it fits the reading-level gate and printing with scissors) and keep the copy "ages 4–8" out of the metadata, or choose 5 and under. Decide (§3) | important | S |
| 19 | **2.1 completeness / review access** ([Guidelines 2.1](https://developer.apple.com/app-store/review/guidelines/#app-completeness)) | No login (good). Relay: per-IP rate limits and a $20/month cap. Placeholder Grown-ups rows behind a flag. `DemoDriver` is `#if DEBUG` (good) | Reviewers share Apple network IPs and may trip the per-IP limit. The spend cap could run out during review. No printer at Apple | Raise the limits or the cap during review (or allow-list a review token). Review notes: push-to-talk, the typed-chat fallback, the gate answer, "printing is optional; the print preview shows the kit", and a 60 s demo video. Remove the placeholder rows. Keep the relay up and watched while the app is in review | **BLOCKER** (if review fails it's 2.1) | S |
| 20 | **Export compliance** | `ITSAppUsesNonExemptEncryption` is missing from `Info.plist` | App Store Connect asks on every build | Add `ITSAppUsesNonExemptEncryption = NO` (HTTPS/TLS only, which is exempt). No French declaration needed | important | S |
| 21 | **Minimum SDK** (Xcode 26 / iOS 26 SDK since Apr 28, 2026) | Target iOS 17; build with the current Xcode | Check the archive's Xcode version | Build the archive with Xcode 26+ | important | S |
| 22 | **4.0 design / iPad** | iPad only (`TARGETED_DEVICE_FAMILY 2`), landscape only, `UIRequiresFullScreen` | Fine. Landscape only is allowed for a full-screen app | Test on the smallest supported iPad (iPad mini) and the 13" | nice | S |
| 23 | **Sign in with Apple (4.8) / account deletion (5.1.1(v))** | No accounts | **N/A, confirmed.** 4.8 only applies with third-party login. 5.1.1(v) only applies if accounts can be created | Say "no accounts" in the review notes. Saved-game delete already exists in Grown-ups | — | — |
| 24 | **2.3 metadata: screenshots, support URL, privacy URL** ([screenshot specs](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)) | Support and privacy URLs exist. No screenshots yet | iPad 13" screenshots (2064×2752 or 2752×2064; 2048×2732 also accepted) showing the app in use (2.3.3), not the title art. "For Kids" wording only in the Kids Category (2.3.8) | Use the existing pitch shots taken on a 13" simulator. Add restore info to /support | **BLOCKER** (required fields) | S |
| 25 | **Accessibility Nutrition Labels** ([App Store Connect Help](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels)) | 40 `accessibilityLabel` uses | **Optional for now**; Apple says it'll become required "over time" | Fill in only what you can honestly claim (for example Larger Text no; VoiceOver partial = don't claim it). Revisit | nice | S–M |
| 26 | **State app-store age laws** (Utah, Texas; Louisiana later) ([Apple: Texas update](https://developer.apple.com/news/?id=8jzbigf4); [Mondaq overview](https://www.mondaq.com/unitedstates/telecoms-mobile-cable-communications/1720916/countdown-to-jan-1-2026-mobile-developers-must-adopt-apple-google-apis-to-comply-with-app-store-accountability-acts)) | Not considered | Developers may need to read Apple's age signal (Declared Age Range API, iOS 26+) and respect the parental consent the store gets. Dates and injunction status are unsettled (sources conflict). You're in **Utah** | Lawyer check. Likely fix: call the Declared Age Range API on iOS 26+, and on a "significant change" (for example new subscription terms), use the PermissionKit Significant Change API | important | M |
| 27 | **EU / UK** (GDPR Art. 8, UK Age Appropriate Design Code; EU DSA trader status) | Not considered | EU distribution needs **DSA trader status** (an address and phone shown publicly) and GDPR-K parental consent at 13–16 depending on the country; the UK needs the Children's Code (high privacy by default, a DPIA) | **Launch in the US only** at first (the app is en-US anyway). Add the UK, Canada and Australia after the lawyer review. EU later | important (as a scope decision) | S (to exclude) / L (to include) |
| 28 | **Moderation must survive a direct-key build** | Moderation calls go through the relay `/v1/moderations` | If #1 isn't fixed, they go direct with a personal key | Covered by #1 | — | — |
| 29 | **Truthful claims (FTC Act §5, 2.3.1)** | The app and site say "never saved", "nobody sees" | Untrue if OpenAI keeps abuse logs for 30 days | Get ZDR, or reword to "PretendThat never saves it; OpenAI may keep it up to 30 days for safety, then deletes it" | important | S |

---

## 2. Launch checklist, in order

1. **Now (S):** fix #1. Release builds use the relay only, plus a build check. Rotate the keys if any key-bearing build ever left this Mac.
2. **Decisions (§3):** countries, Kids Category or not, age band, ZDR yes or no.
3. **Outside parties (start now; they take the longest):**
   - Apply for **OpenAI ZDR** through sales. Mention a COPPA-covered kids product, and list `/v1/realtime`, `/v1/audio/speech`, `/v1/images/*` and `/v1/moderations`.
   - Apply for **Anthropic ZDR** and confirm the model's eligibility, then ask for the child-safety system prompt.
   - Accept both DPAs.
   - Optional: a COPPA Safe Harbor program or a one-hour lawyer review (COPPA, Utah).
4. **Privacy package (S):** update /privacy (retention, how to revoke, operator details, AI providers by role, COPPA statement). Add /terms. Add Restore to /support.
5. **App build round (M–L):**
   - onboarding: the gate → how it works → privacy + **explicit AI consent** + AI disclosure → mic pre-permission → plans → hand-off
   - StoreKit 2 with Restore, Manage, Terms and Privacy
   - Grown-ups rows: Report a problem, Privacy, Terms, Help (all gated)
   - a harder gate question
   - `PrivacyInfo.xcprivacy`
   - `ITSAppUsesNonExemptEncryption = NO`
   - proxy Realtime through the relay (#6)
   - prefer on-device speech recognition for the fallback
   - remove the placeholders
6. **App Store Connect:**
   - the app record (bundle `app.pretendthat.ios`)
   - the Kids Category and age band
   - the age rating questionnaire
   - the App Privacy label (matching the ZDR outcome)
   - privacy and support URLs
   - the subscription group (Show Pass and Season Pass, monthly and yearly) with localized names and descriptions
   - the EULA
   - 13" iPad screenshots
   - export compliance
   - optional: the accessibility labels
7. **TestFlight:** a sandbox purchase, restore, and a new-iPad flow (mic denied, offline, gate wrong answer). Check the relay's limits from a single IP running many sessions.
8. **Before submitting:** raise the relay cap or limits. Write the review notes (the gate answer, push-to-talk, the typed fallback, no printer needed, no accounts, how AI content is filtered and reported, links to the demo video). Keep the relay watched during review.
9. **After approval:** watch for the accessibility-label requirement and changes to the state laws. Re-check the privacy manifest after D4 (iCloud).

---

## 3. Decisions and questions for Haylee

1. **OpenAI and Anthropic ZDR: apply now?** My recommendation is yes. It's the cleanest way to meet COPPA's audio exception, OpenAI's under-13 rule, a "Data Not Collected" label and the "never saved" copy. The risk is that approval isn't guaranteed and may need a sales contract or a minimum spend. **Fallback if refused:** declare Audio Data and Other User Content, and get real verifiable parental consent (for example a small card check or a signed form). That's heavier, and it changes the "no accounts" story.
2. **Kids Category, or a general category ("Family" under Entertainment)?** The Kids Category gets you discovery and trust, but 1.3 adds "no device info to third parties" (the direct Realtime socket, #6), a stricter review, and it's permanent. Leaving it means no "for kids" wording in the metadata (2.3.8), while COPPA still applies because the app is aimed at children. **My lean:** stay in the Kids Category and proxy Realtime through the relay.
3. **Which age band:** 6–8 or 5 and under?
4. **Countries at launch:** US only (my recommendation), or also the UK, Canada and Australia? The EU needs DSA trader status (your address and phone become public) plus GDPR-K.
5. **Individual seller or an LLC?** For a kids' AI app that takes subscriptions, an LLC limits personal liability and keeps your home address off the EU trader listing. It isn't required by Apple.
6. **The AI disclosure wording:** how should Nutmeg say she's a computer helper without breaking the magic? Anthropic requires the disclosure; Apple 5.1.2(i) needs the parent to know.
7. **What happens if a parent says no to the AI consent:** block new games (my recommendation), or allow replays only, since replays use recorded clips and few AI calls?
8. **Relay cost during review:** OK to raise the $20/month cap and the per-IP limits for the review window?

---

## 4. Risks that could get it rejected (or worse)

- **2.1, the AI doesn't work in review:** the relay rate-limits Apple's shared IPs, the spend cap runs out, or the reviewer has no printer, or denies the mic and doesn't find the typed fallback.
- **5.1.2(i), no explicit consent** before the voice goes to OpenAI. New since November 2025 and actively cited.
- **1.3, a weak parental gate** (a spelled number a 7-year-old can read) or any link, `mailto:` or price outside it.
- **1.3 / 5.1.4, device info to a third party** (the direct WebSocket to OpenAI) or an app privacy label that doesn't match how it behaves.
- **1.2, no report mechanism** for AI-generated content.
- **3.1.2, the subscription screen:** the billed price isn't the most prominent, no Restore, missing Terms or Privacy links, unclear caps ("up to 30"), or "Free Preview" read as a trial.
- **ITMS-91053:** missing privacy manifest reasons (UserDefaults).
- **Metadata:** title-art screenshots, "ages 4–8" against the chosen band, a missing EULA.
- **Not a rejection, still serious:** shipping live API keys (#1); an FTC COPPA problem if voice is kept 30 days at OpenAI while the app says "never saved"; OpenAI or Anthropic suspending the account for serving under-13s without ZDR or the minors safeguards.

---

## Sources

- Apple App Review Guidelines (1.2, 1.3, 2.1, 2.3, 3.1.1, 3.1.2, 4.7, 5.1.1, 5.1.2(i), 5.1.4): https://developer.apple.com/app-store/review/guidelines/
- Apple news, guidelines update of Nov 2025 (third-party AI): https://developer.apple.com/news?id=ey6d8onl · coverage: https://9to5mac.com/2025/11/13/apple-tightens-app-review-guidelines-to-crack-down-on-copycat-apps/
- Apple: parental gates: https://developer.apple.com/app-store/parental-gates/
- Apple: App privacy details (the "collect" definition, data types): https://developer.apple.com/app-store/app-privacy-details/
- Apple: required-reason APIs: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- Apple: upcoming requirements (Xcode 26 SDK, age ratings, privacy manifests): https://developer.apple.com/news/upcoming-requirements/
- Apple: auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
- Apple: screenshot specifications: https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications
- Apple: Accessibility Nutrition Labels: https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels
- Apple: Texas age requirements update: https://developer.apple.com/news/?id=8jzbigf4
- New age ratings (2025): https://9to5mac.com/2025/07/24/apple-notifies-developers-of-new-app-store-age-rating-system/
- HIG Privacy: https://developer.apple.com/design/human-interface-guidelines/privacy
- COPPA §312.5 (consent and the audio exception): https://www.law.cornell.edu/cfr/text/16/312.5 · §312.10 (retention): https://www.law.cornell.edu/cfr/text/16/312.10
- The amended COPPA compliance date (Apr 22, 2026): https://bbbprograms.org/media/insights/blog/coppa-amended · https://www.davispolk.com/insights/client-update/ftc-prioritizes-coppa-enforcement-new-compliance-obligations-take-effect
- OpenAI under-18 API guidance (ZDR for under-13): https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance
- OpenAI data controls (ZDR eligibility, 30-day abuse logs): https://developers.openai.com/api/docs/guides/your-data
- Anthropic guidelines for organizations serving minors: https://support.claude.com/en/articles/9307344-responsible-use-of-anthropic-s-models-guidelines-for-minors
- Anthropic API data retention and ZDR: https://platform.claude.com/docs/en/manage-claude/api-and-data-retention · https://privacy.claude.com/en/articles/8956058-i-have-a-zero-data-retention-agreement-with-anthropic-what-products-does-it-apply-to
- State app-store laws: https://www.mondaq.com/unitedstates/telecoms-mobile-cable-communications/1720916/countdown-to-jan-1-2026-mobile-developers-must-adopt-apple-google-apis-to-comply-with-app-store-accountability-acts · https://www.macrumors.com/2025/11/04/ios-26-2-texas-age-verification-law/
- PretendThat site: https://pretendthat.app/privacy · https://pretendthat.app/support

**Verification notes:**
- These were confirmed on Apple's live guidelines page on 2026-11-16: the 5.1.2(i) AI text, 1.3, 5.1.4 and 1.2.
- These came from secondary sources and need checking in App Store Connect: the exact wording of the age rating questionnaire and the dates for the state laws.
- Anthropic's standard API retention: sources conflict (30 days vs 7 days). Confirm it on the platform page.
