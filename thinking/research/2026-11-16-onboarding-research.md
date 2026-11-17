# Parent onboarding and plans: research and a proposed flow

**Date:** 2026-11-16 · **Plan names (Haylee):** Free Preview (~2 new shows), Show Pass ($9.99/mo or $79.99/yr, 10 new shows a month), Season Pass ($14.99/mo or $119.99/yr, up to 30 new shows a month); both paid plans include unlimited replays. Never call a plan "Unlimited". · **Asked by:** Haylee ("something really simple that walks parents through how the app works and privacy things", plus the plan options) · **Written by:** Claude (research and proposal only, no app code)

**Status:** a proposal. Nothing here is decided until Haylee picks; her decisions are at the end.

---

## 1. What strong kids' apps do

Caveat: most screen orders below come from third-party screen recordings (ScreensDesign) and reviews, not from a fresh install today. Flows change often. Treat them as patterns, not exact current screens.

| App | Account? | What the parent sees on first launch | Plans and paywall |
|---|---|---|---|
| **Khan Academy Kids** | Yes, parent email required before anything else, then verify by email | Email → verify → add child (name, age) | Free, no paywall. The contrast case: everything's free, so onboarding is only setup ([Khan support](https://support.khanacademy.org/hc/articles/360040168512-Parent-Quick-Start-Guide), [gHacks review](https://www.ghacks.net/?p=146284)) |
| **Duolingo ABC** | Optional ("Not now" on account) | About 13 steps in ~1:45: welcome → class code → "how did you hear" → who's it for → child's name and age → avatar → starting level → **mascot-led mic explainer → system mic prompt** → account (skippable) → parent's age → notifications → "building your experience" | A keypad parental gate guards level unlocks, not onboarding ([ScreensDesign: Duolingo ABC](https://screensdesign.com/apps/learn-to-read-duolingo-abc/)). Only the parent's email is stored ([iMore](https://imore.com/duolingo-releases-iphone-and-ipad-app-help-kids-learn-read)) |
| **Epic!** | Yes, adult email + password | ~20 screens: role (family/educator) → sign up → password + terms → birth-year age check → privacy disclosure "I Agree" → **paywall** (7-day trial, feature rows, then an annual vs monthly comparison) → App Store confirm → notification pre-prompt ("we'll remind you before the trial ends") → child profile | **Hard paywall** inside onboarding. Reviewers complain there was "no way out" of the trial, and of surprise annual charges ([ScreensDesign: Epic](https://screensdesign.com/apps/epic-kids-books-reading/), [Trustpilot](https://www.trustpilot.com/review/getepic.com?page=3), [Screenwise](https://screenwiseapp.com/guides/is-epic-safe-for-preschoolers-privacy-concerns)) |
| **Lingokids** | Yes: email, plan, child's name and age | Short setup, personalised by age | 7-day trial plus a limited free version (about 3 activities a day). Monthly ~$15, yearly ~$72–90. Common complaint: charged after cancelling the trial ([edtechimpact](https://edtechimpact.com/products/lingokids), [Common Sense](https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn), [Adapty paywall library](https://adapty.io/paywall-library/lingokids/), [unitQ](https://www.unitQ.com/unitq-scorecards/lingokids/)) |
| **Homer** | Yes | A short quiz (child's age, level, interests) builds a "personalised plan" before the offer | 30-day trial; ~$9.99/mo or ~$59.99/yr ([Homer](https://www.beginlearning.com/homer/), [Romper](https://www.romper.com/parenting/homer-learn-grow-app)) |
| **Sago Mini World** | No account needed to start | Straight into play | Trial starts on download with no commitment, then **a free tier of ~3 games**; monthly or annual after. Kids get upset when the trial ends and games lock ([App Store listing](https://apps.apple.com/us/app/id874425722), [unitQ](https://unitq.com/unitq-scorecards/sagominiworld)) |
| **PBS KIDS Games** | No accounts at all | Straight into play | Free. The privacy policy says neither parent nor child needs an account ([PBS Kids privacy](https://api.pbskids.org/privacy), [Pixalate](https://pixalate.com/blog/app-review-series-pbs-kids-games)) |
| **Toca Boca World** | A parent-made Toca ID only for online features | Free to download, purchases inside | Freemium, no subscription wall ([Toca help](https://tocaboca.helpshift.com/hc/en/18-toca-boca-days/faq/144-toca-id-account-creation)) |
| **Voice/AI kids' apps** (Lumo, Avo, GentleGate) | Varies | The privacy story leads: "audio is streamed to answer and never stored", voice off until a parent turns it on | No detailed onboarding teardown found for WimziPal, Moshi or Kinzoo ([Avo](https://avo-website.pages.dev/), [Lumo](https://lumo-product-page.pages.dev/), [GentleGate privacy](https://gentlegate.pages.dev/privacy.html)) |

### Patterns worth copying
- **The mascot explains the microphone before the system prompt** (Duolingo ABC). It works because the reason ("so she can hear you") is shown before iOS asks.
- **No-account apps go straight to play** (PBS KIDS, Sago Mini). PretendThat has no accounts, so it can be much shorter than Khan, Epic or Duolingo: no email, no child profile, no age.
- **A "we'll remind you before the trial ends" step** (Epic) builds trust after a trial starts.
- **Free tiers soften the cliff**: Sago Mini and Lingokids keep a few games free after the trial.

### Patterns to avoid
- **Hard paywalls with no way out** (Epic): the top complaint in reviews.
- **Trial-then-surprise-charge** (Lingokids, Epic): the most common billing complaint in this category.
- **Asking for the child's name, age or interests** (Khan, Duolingo, Homer, Lingokids): PretendThat doesn't need them, and not asking is a selling point.
- **Marketing surveys** ("How did you hear about us?") and notification prompts. PretendThat has neither analytics nor anything to notify about.

---

## 2. Apple's rules that shape onboarding

**Kids Category (Guideline 1.3).** Kids Category apps "must not include links out of the app, purchasing opportunities, or other distractions to kids unless reserved for a designated area behind a parental gate." No third-party analytics or ads, and no personal or device info sent to third parties. Once you're in the category you must keep following these rules ([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple: Parental gates](https://developer.apple.com/app-store/parental-gates/), [2019 Kids update](https://developer.apple.com/news/?id=06032019j)).
→ **The plan screen and the privacy-policy link must both sit behind the gate.** Simplest answer: put the gate at the start of the onboarding, so the whole flow is a grown-up area.

**Parental gates.** "Adult-level tasks that must be completed in order to continue." For pre-literate kids, Apple suggests a **voice prompt telling kids to get a parent** ([Apple: Parental gates](https://developer.apple.com/app-store/parental-gates/)). PretendThat's existing gate (hold 2 s, then tap the spelled-out number) fits.

**Asking for the microphone (HIG Privacy).** Ask only when needed. Asking at launch is fine "if the data or resource is required for your app to function", and the mic is Nutmeg's core. A custom screen before the system prompt is allowed if it has:
- **exactly one button** that opens the system alert, labelled "Continue" or "Next", **never "Allow"**
- **no cancel and no close** option

([HIG: Privacy](https://developer.apple.com/design/human-interface-guidelines/privacy), [HIG: Onboarding](https://developer.apple.com/design/human-interface-guidelines/onboarding) says asking inside onboarding lets you "show people why your app or game needs their permission.")

The purpose string should be a brief active sentence that says how and why. Guideline 5.1.1(ii) says purpose strings must "clearly and completely describe" the use, and paid features must not depend on granting data access.

**Onboarding in general (HIG: Onboarding).**
- "Fast, fun, and optional."
- "If you let people skip the tutorial ... don't present it again on subsequent launches, but make sure it's easy for people to find" later, for example in settings. For PretendThat that's the Grown-ups corner.
- "Prefer letting people experience your app or game before prompting them for ratings or purchases."
- Keep licensing text out of the onboarding.

**Privacy policy (5.1.1(i), 5.1.4).** A privacy policy link is required in App Store Connect and must be "easily accessible" in the app. Kids Category apps need a policy and COPPA compliance.

**Subscriptions (3.1.2, plus Apple's subscription page).**
- 3.1.2(c): "clearly describe what the user will get for the price. How many issues per month?" "10 new shows a month" fits this exactly.
- The sign-up screen needs:
  - the subscription name, duration and what you get
  - the **full renewal price, shown clearly and prominently**
  - **a way to restore purchases**
  - links to **Terms of Use and the Privacy Policy**
- The **billed amount must be the most prominent price**. A per-month breakdown of an annual plan must be "subordinate" in position and size.
- Free trials must state **how long the trial lasts and the price after it ends**.
- Apps that "trick users into purchasing a subscription under false pretenses or engage in bait-and-switch" get removed (3.1.2, 5.6).
- Offer an easy way to manage or cancel (`showManageSubscriptions`).

([App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple: Auto-renewable subscriptions](https://developer.apple.com/app-store/subscriptions/))

**Important for our tiers:** an App Store free trial (an introductory offer) is **time-based** (days, weeks or months). It can't be "2 games". the **Free Preview** ("2 free new shows") is an **in-app free allowance (a free tier)** that PretendThat counts itself. It needs no Apple trial, no card and no auto-renew. That's simpler to explain and avoids the trial-charge complaints above. We could still add an Apple 1-week free trial on Show Pass later.

**COPPA and voice.** The FTC's voice policy, now in the amended rule, allows collecting a child's voice without parental consent only if:
- no other personal info is collected
- the audio is used only to answer the child's request
- the audio is **deleted immediately after**
- the privacy policy explains this

([FTC 2017 policy via Fenwick](https://fenwick.com/insights/publications/ftcs-new-coppa-guidance-on-recording-childrens-voices-five-tips-for-app-developers-and-toymakers-to-comply), [MoFo on the 2025 rule](https://www.mofo.com/resources/insights/250204-coppa-rule-updates-are-here-for-now-what-businesses)). PretendThat's design (no names, push-to-talk, nothing saved) matches the spirit. See the check in §5.

---

## 3. Best practices

1. **Once, short, re-openable.** First launch only, about a minute; "How PretendThat works" in Grown-ups replays it.
2. **One grown-up gate up front.** A gate at the start turns the whole flow into a grown-up area, so the privacy link and the plans are allowed (1.3) without stacking gates.
3. **Show, don't ask.** No names, ages, emails or surveys. The only real asks are the microphone and, optionally, a plan.
4. **Set real-world expectations.** A printer is optional, plus crayons, scissors (a grown-up helps cutting), space to move around, and about 20–40 minutes.
5. **A pre-permission screen with one "Continue" button** right before the iOS mic alert, and a clear fallback if it's denied (tap choices still work).
6. **Free first, plans visible but not pushy.** Lead with the Free Preview. Put "Restore purchases" on the same screen. Don't auto-start anything that charges.
7. **End with a hand-off.** The parent's last tap gives the iPad to the child, and Nutmeg greets the kid by voice.
8. **What not to do:**
   - make onboarding mandatory every launch
   - add a close button on the mic explainer
   - label any custom button "Allow"
   - put a card-required trial in the onboarding
   - show monthly-equivalent prices bigger than the billed price
   - put links or purchases outside the gate

---

## 4. Proposed flow (6 screens, about 60–75 seconds)

**When:** the first launch only, right after the curtain intro and before the start screen. If it's closed partway, it starts again at screen 1 next launch until it's finished once. **Re-open:** Grown-ups → "How PretendThat works" (replays screens 2–4; the plans have their own Grown-ups rows, "Plans" and "Restore purchases"). **Look:** the backstage stage with Nutmeg on the right and a big card on the left, plus a dot progress row. **Voice:** Nutmeg speaks only on screens 1 and 6 (the kid-facing ends). The middle screens are quiet text for the grown-up, with an optional "read it to me" pill.

### Screen 1: "Grown-ups first!" (parental gate)
- **Purpose:** get a grown-up, and gate the whole flow (1.3: the plans and the privacy link live inside).
- **Nutmeg says** (her real recorded voice, since a child may be holding the iPad): "Hi! I'm Nutmeg. Can you get a grown-up? This part is just for them."
- **Headline:** Hi, grown-up! 👋
- **Copy:** A quick minute on how PretendThat works and how we keep your child's info private.
- **Visual:** Nutmeg waving from behind the curtain, holding her clipboard.
- **Action:** the existing `PTGrownUpGate` (hold 2 s → tap the spelled-out number). There's no skip before the gate.

### Screen 2: "How it works" + what you'll need
- **Purpose:** the 4-step model and real-world expectations, including the printer note.
- **Headline:** Pretend play that happens off the screen
- **Copy, four picture cards in a row:**
  1. **Pick:** your child tells Nutmeg what to play: "a pancake restaurant on the moon."
  2. **Props:** she sends them hunting for things around the house.
  3. **Print:** a custom kit of badges, signs and play money, in color or as coloring pages.
  4. **Play:** Nutmeg guides each scene, then naps while the kids play. Pass the iPad between roles.
- **"You'll want" strip:** 🖨 a printer (AirPrint), or play without one: Nutmeg will have kids draw it instead · ✂️ crayons and safety scissors (little ones may need help cutting) · 🏠 room to move · ⏱ about 20–40 minutes · 👧👦 1–6 players
- **Visual:** the existing pitch art (prop hunt, kit reveal, checklist) as thumbnails.
- **Action:** **Next.** A small "Skip intro" link jumps to screen 4 (the mic), because the mic still needs a choice.

### Screen 3: "Your family's privacy"
- **Purpose:** the privacy summary in plain words, with the policy link (allowed because we're behind the gate).
- **Headline:** Private by design
- **Copy (four short lines, each with an icon):**
  - **No accounts, no sign-in.** We never ask for your email.
  - **Nutmeg never asks your child's name.** Kids are "the chef" or "the captain."
  - **She listens only while the mic button is held.** We never save your child's voice or words.
  - **Saved games stay on this iPad** (and your family's iCloud). We can't see them. Delete any game in Grown-ups.
- **Small print:** No ads. No tracking. Read our full privacy policy → **pretendthat.app/privacy** (opens in Safari).
- **Visual:** Nutmeg with a finger to her lips and a little padlock on her clipboard.
- **Action:** **Next.**

### Screen 4: Microphone (pre-permission)
- **Purpose:** explain the mic, then hand over to the iOS alert (HIG pre-alert rules).
- **Headline:** Nutmeg needs to hear your child
- **Copy:** Kids talk to Nutmeg by holding the big mic button, like a walkie-talkie. She only listens while it's held. Next, your iPad will ask to use the microphone.
- **Visual:** a kid's hand holding the purple mic button, with Nutmeg's ear perked up.
- **Action:** **one button, "Continue"**, which shows the system microphone alert. No close, no "not now", no "Allow" wording.
- **After the alert:**
  - **Allowed:** go on.
  - **Denied:** a gentle note on the next screen: "No problem: kids can tap Nutmeg's picture choices instead. You can turn the mic on later in Settings → PretendThat." Never block, never nag.
- **Purpose string (Info.plist), suggested:** "Nutmeg listens while your child holds the microphone button so she can answer. PretendThat never saves what your child says." (See §5: today's string says "Your voice stays on this iPad," which isn't accurate because speech goes to the voice service to be answered.)

### Screen 5: Plans (soft, start with the Free Preview)
- **Purpose:** show the options honestly. The default path is free.
- **Headline:** Start with your Free Preview
- **Copy:** Your first two brand-new shows are on us, with no card and nothing to cancel. Want more? Pick a pass anytime in Grown-ups.
- **Plan cards** (Monthly | Yearly toggle, Yearly preselected; prices tentative):

  | | **Show Pass** | **Season Pass** |
  |---|---|---|
  | New shows | **10 a month** | **Up to 30 a month** (about one a day) |
  | Replays of saved games | Unlimited replays | Unlimited replays |
  | Yearly | **$79.99/year** · *about $6.67/mo · save 33%* | **$119.99/year** · *about $10/mo · save 33%* |
  | Monthly | **$9.99/month** | **$14.99/month** |

  The billed price is the big number; the per-month breakdown is smaller and grey (Apple's prominence rule). Season Pass says "up to 30" plainly; never call a plan "Unlimited" (only the replays are unlimited).
- **Buttons:**
  - **Primary: "Start my Free Preview"**: no purchase, goes to screen 6.
  - **Secondary: "Choose Show Pass"** or **"Choose Season Pass"** (whichever is selected) opens the StoreKit purchase sheet. Apple's sheet confirms the price with Face ID or a password, so the parent stays in control.
- **Footer (required):** Restore purchases · Terms of Use · Privacy Policy · "Subscriptions renew automatically until cancelled in Settings. Cancel anytime, at least 24 hours before renewal."
- **Visual:** Nutmeg holding two golden theater tickets ("Free Preview: 2 shows!"), a nice fit with the pass names.
- **Parental gate:** already passed on screen 1 (same session). If this screen is ever reached on its own (from Grown-ups or the "Free Preview used up" moment), it shows the gate first.
- **Build tip:** StoreKit 2's `SubscriptionStoreView` draws Apple-compliant terms, restore and manage controls for us. Style it with our fonts and colors.
- **The trial and free-games flow later:**
  - The start screen shows a quiet "Free Preview: 2 new shows left" chip (grown-up-facing, small).
  - Replays of saved games never count.
  - When the Free Preview is used up and a kid taps **New game**, Nutmeg says (no price, no pressure): "That's all my new shows for now! Ask a grown-up to get more. You can still play your saved games!"
  - A **Grown-ups** button opens the gate, then screen 5 again.
  - Kids never see prices or buy buttons.

### Screen 6: Hand-off
- **Purpose:** the moment the parent passes the iPad to the child.
- **Headline:** You're all set!
- **Copy:** Now hand the iPad to your child and tap **New game**. Nutmeg takes it from here. You'll find saved games, plans and this tour again in **Grown-ups** (top corner).
- **Visual:** Nutmeg bouncing on her toes, curtains starting to open.
- **Action:** **"Hand it over! 🎭"** goes to the start screen with **New game** gently pulsing.
- **Nutmeg says**, once the start screen appears (to the kid): "Hi! I'm Nutmeg, the stage manager. Want to make up a game? Tap New game!"

**Total:** 6 screens. The grown-up reads 3 short cards, makes one mic choice and one plan choice (free by default): about a minute.

---

## 5. Checks to do before shipping (not decisions, just facts to confirm)

- **The microphone purpose string is wrong today.** `PretendThat/Resources/Info.plist` says "Your voice stays on this iPad," but push-to-talk audio goes to OpenAI's Realtime API to be answered. Apple requires purpose strings to "clearly and completely describe" the use (5.1.1(ii)). Use the suggested string in screen 4.
- **"Never saved" needs to hold at the AI provider.** The COPPA voice exception expects the audio to be deleted right after answering, and Kids Category apps can't send personal info to third parties. Confirm OpenAI's data retention for the Realtime API on our account. By default, API data can be kept up to 30 days for abuse monitoring unless zero-data-retention is approved. Set the onboarding and privacy-policy wording to match ("PretendThat never saves..." is accurate either way; "deleted immediately" is only accurate with zero retention).
- **The App Privacy label** ("Data Not Collected") follows from the same retention answer.
- **Counting Free Preview shows without accounts:** keep the count in the Keychain (it survives a reinstall) or iCloud key-value storage. Reinstall abuse costs about $0.40–$1.60 per game (see [cost per game](2026-11-15-cost-per-game.md)), which is acceptable at launch.
- **Grown-ups rows to add:** "How PretendThat works", "Plans", "Restore purchases", "Manage subscription" (`showManageSubscriptions`), "Privacy policy". The `GrownUpsSection` slots already exist.

---

## 6. Decisions for Haylee (with recommendations)

1. **Free tier, Apple trial, or hard paywall?**
   **Recommend: the Free Preview as 2 free new shows with no card (a free allowance), and no hard paywall.** It matches the "about 2 games" idea, avoids the trial-charge complaints that hurt Epic and Lingokids, and fits the HIG ("experience before purchases"). An Apple 1-week free trial on Show Pass Yearly can be added later as a test.
2. **Is the plan screen part of first-launch onboarding, or only shown when the Free Preview runs out?**
   **Recommend: in onboarding as screen 5, with "Start my Free Preview" as the primary button**, and shown again (behind the gate) when the Free Preview runs out. The parent sees the prices once, calmly, with no surprises later.
3. **Where does the parental gate go?**
   **Recommend: once, on screen 1, covering the whole flow.** It satisfies 1.3 for the plan screen and the privacy link in one go. The plan screen re-gates whenever it's opened outside onboarding.
4. **Yearly or monthly preselected, and show both passes?**
   **Recommend: show both Show Pass and Season Pass, Yearly preselected with "save 33%", and Monthly one tap away.** If Season Pass's 30-show cap isn't confirmed by launch (cost per game), show Show Pass only and add Season Pass later.
5. **Does Nutmeg speak during onboarding?**
   **Recommend: only on screen 1 ("Can you get a grown-up?", which Apple suggests for pre-literate kids) and at the hand-off.** The parent screens stay quiet so a grown-up can read at their own pace.

---

## Sources

- Apple, App Review Guidelines (1.3, 3.1.1, 3.1.2, 5.1.1, 5.1.4, 5.6): https://developer.apple.com/app-store/review/guidelines/
- Apple, Parental gates: https://developer.apple.com/app-store/parental-gates/
- Apple, Kids Category update (2019): https://developer.apple.com/news/?id=06032019j
- Apple HIG, Onboarding: https://developer.apple.com/design/human-interface-guidelines/onboarding
- Apple HIG, Privacy (requesting permission, pre-alert screens): https://developer.apple.com/design/human-interface-guidelines/privacy
- Apple, Auto-renewable subscriptions: https://developer.apple.com/app-store/subscriptions/
- ScreensDesign, Duolingo ABC onboarding: https://screensdesign.com/apps/learn-to-read-duolingo-abc/
- ScreensDesign, Epic onboarding: https://screensdesign.com/apps/epic-kids-books-reading/
- Khan Academy Kids, Parent Quick Start: https://support.khanacademy.org/hc/articles/360040168512-Parent-Quick-Start-Guide
- gHacks, Khan Academy Kids: https://www.ghacks.net/?p=146284
- iMore, Duolingo ABC: https://imore.com/duolingo-releases-iphone-and-ipad-app-help-kids-learn-read
- edtechimpact, Lingokids: https://edtechimpact.com/products/lingokids
- Common Sense Media, Lingokids: https://www.commonsensemedia.org/app-reviews/lingokids-play-and-learn
- Adapty, Lingokids paywall: https://adapty.io/paywall-library/lingokids/
- unitQ, Lingokids: https://www.unitQ.com/unitq-scorecards/lingokids/
- Homer: https://www.beginlearning.com/homer/ · Romper: https://www.romper.com/parenting/homer-learn-grow-app
- Sago Mini World, App Store: https://apps.apple.com/us/app/id874425722 · unitQ: https://unitq.com/unitq-scorecards/sagominiworld
- PBS KIDS privacy: https://api.pbskids.org/privacy · Pixalate: https://pixalate.com/blog/app-review-series-pbs-kids-games
- Toca Boca, Toca ID: https://tocaboca.helpshift.com/hc/en/18-toca-boca-days/faq/144-toca-id-account-creation
- Epic reviews: https://www.trustpilot.com/review/getepic.com?page=3 · Screenwise: https://screenwiseapp.com/guides/is-epic-safe-for-preschoolers-privacy-concerns
- Voice AI kids' apps: https://avo-website.pages.dev/ · https://lumo-product-page.pages.dev/ · https://gentlegate.pages.dev/privacy.html
- FTC voice recordings (Fenwick): https://fenwick.com/insights/publications/ftcs-new-coppa-guidance-on-recording-childrens-voices-five-tips-for-app-developers-and-toymakers-to-comply
- COPPA rule updates (MoFo): https://www.mofo.com/resources/insights/250204-coppa-rule-updates-are-here-for-now-what-businesses
