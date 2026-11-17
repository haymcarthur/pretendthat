# Onboarding v3: Haylee's revisions

- **Date:** 2026-11-17
- **Decisions (Haylee):**
  - **Page 1:** the home-screen art of Nutmeg on her stage, titled "Welcome to PretendThat".
  - **Privacy page:** green shield, no chips, and only "I agree, let's play". No "Not now": the app can't be used without AI.
  - **Usage counts:** ON by default, removed from onboarding, disclosed in the privacy policy, and changeable in Grown-ups. This reverses Claude's earlier off-by-default call. Claude's caveat: on by default is commonly allowed for anonymous, app-improvement-only counts (COPPA's "support for internal operations"), as long as it's disclosed and never used for ads. If the app is in Apple's Kids Category, the analytics must not send identifiable device information. Not legal advice; worth a check before launch.
  - **Mic page:** the button says it turns on the microphone, so the system prompt isn't a surprise.
  - **Plans page:** parents don't know what a "show" or a "replay" is. Proposed: say "new game" instead of "show", and "playing a saved game again is free". The renewal price is shown plainly, and there's no monthly/yearly switch in onboarding. The same wording needs to go on the site and in the app's plan screens.
  - **Last page:** the PretendThat logo, "You're all set", and "Hand your device to your child. Nutmeg will take it from here."
- **Who decided:** Haylee. The "new game" wording is Claude's proposal, pending her OK.

## Follow-up (same day)
- "Show" → "game" is approved EVERYWHERE: onboarding, the app's plan screens and kid-facing lines, StoreKit display names and descriptions where possible, and the site.
- Onboarding goes to 6 pages:
  1. Welcome
  2. How it works (the 4 steps)
  3. What you'll need (supplies)
  4. Privacy + mic combined (one button: "I agree, turn on the mic")
  5. Start with 2 free games
  6. You're all set
- Combining privacy and mic is Claude's proposal, to make room for the steps and supplies pages Haylee wanted back.

## Follow-up 2 (same day, Haylee)
- **Usage counts:** no switch anywhere. They're on for everyone, removed from onboarding AND from Grown-ups → About, and disclosed in the privacy policy. Claude noted that COPPA's internal-operations allowance and a US-only, non-Kids-Category launch make an opt-out not legally required (not legal advice).
- **No game length anywhere:** no "15–25 min" in the app's onboarding or on the site.
