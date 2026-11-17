# Round 33: first-launch parent onboarding, AI consent, Free Preview, shorter game greeting, voice-rate guard

**Date:** 2026-11-16 · **Decided by:** Haylee (the flow, consent rules, plan names and prices, the greeting change, the
voice-rate report), from [paid-app direction](2026-11-15-paid-app-direction.md),
[onboarding research](../research/2026-11-16-onboarding-research.md), [round 31](2026-11-16-round31-on-device-speech-build.md),
[round 32](2026-11-16-round32-grownups-menu.md) and the [compliance list](../research/2026-11-16-app-store-compliance.md).
Details are Claude's calls, noted.

## The flow (shown once; Grown-ups → Replay the intro opens it again from screen 2)
1. **Hi, grown-up!** Nutmeg's bundled clip (her real recorded voice, never TTS): "Hi! I'm Nutmeg. Can you get a
   grown-up? This part is just for them." Then the D2 gate (hold 2 s + the spelled number). A "Hear Nutmeg again" link.
2. **How it works:** the tagline, Pick · Props · Print · Play with the rail icons, and what you'll need (a printer,
   crayons and scissors, room to move, about 15–25 minutes). Next.
3. **Private by design + REQUIRED AI consent:** no accounts; nothing about your kids is saved; the voice becomes words
   on this iPad and is never sent; only those words, names removed, go to OpenAI and Anthropic; saved games stay on this
   iPad. Privacy policy link (in-app Safari). **I agree, let's play** / **Not now**.
   - Not now → "PretendThat needs this to work … turn it on any time in Grown-ups" with Go back / Close for now.
4. **Microphone pre-permission** (HIG: one Continue, no "Allow", no cancel) → the system mic prompt, then speech
   recognition. Denied → "No problem. Kids can type instead." + how to turn it on in Settings + Open Settings + Next.
5. **Plans:** "Start my Free Preview" (2 free new shows, no card) as the main button; Monthly/Yearly (monthly
   preselected); prices per Haylee's later update, in ONE config place (`PlanCatalog`, for StoreKit to replace):
   Show Pass $9.99/month for the first 12 months, then $14.99/month (yearly $149.99); Season Pass $19.99/month for the
   first 12 months, then $29.99/month (yearly $299.99). Shown Apple's way: the billed price big, "for your first 12
   months, then $14.99/month" in body text right under it (the regular price visible), the yearly per-month line smaller; "10 / 30 new shows a month (planned)" from config (`PlanCatalog`); a disabled
   "Coming soon" buy button with a note; Restore purchases (StoreKit `AppStore.sync`), Terms, Privacy, renewal text.
6. **Hand-off:** "Now hand the iPad to your child and tap New game!" → the start screen, and Nutmeg greets the kid
   (bundled clip).
Back moves one screen at a time after the gate (never back to the gate). Dots show progress.

## Gating and counting (device flags only)
- `pt.onboarding.done` (bool), `pt.aiConsent` (bool), `pt.freePreview.newGames` (int: NEW games started),
  `pt.hasPlayedBefore` (bool), `pt.greeting.lastShort` (int). Nothing about kids.
- **New game:** no consent → a kid card ("Ask a grown-up to finish setting up.") with the calm explanation and a
  Grown-ups button (gate → AI partners row); Free Preview used up and no plan → "That's all the new shows for now! Ask
  a grown-up." → the gate → the plans sheet. Kids never see prices.
- **No AI connection before consent:** the start-screen pre-connect waits for consent and the end of the onboarding.
- **Grown-ups → AI partners:** a toggle to grant or revoke (revoking hangs up the voice session).
- Debug: `-PTResetOnboarding`, `-PTResetFreePreview`, `-PTResetGreeting`, `-PTFreeUsed N`, `-PTConsent`,
  `-PTNoConsent`, `-PTOnboarding <screen>[Denied]`, `-PTOldGreeting`.

## Shorter game greeting (Haylee, mid-round)
- First game ever: bundled clip "Hi! I'm Nutmeg, a pretend helper made by a computer!" (the AI disclosure lives only
  here). Later games: one of 4 short clips ("Hi again, friends!", "Welcome back to the stage!", "Ooh, time for a new
  show!", "Hooray, you're back!"), never the last one again. Then her live turn asks only the game question with two of
  today's ideas ("do NOT greet or introduce yourself").
- **Measured (heard seconds, live, PT-R15):** old opening 13.9 / 14.6 / 14.5 s → first game 8.2 s (clip 3.6 + live
  4.6) → later games 9.1 / 9.1 / 8.8 s (clip 1.2–1.9 + live 7.2–7.8). The model still sometimes lists three ideas
  (today's-ideas note has three); trimming that note would save ~1–2 s more.

## Voice rate ("her voice sounds changed again", Haylee, urgent; own commit fcfc9b7)
- **Measured on PT-R15 with `-PTTapOut`** (player input vs mixer output, input pre-warmed): HEAD before the fix
  86.87 s in / 72.36 s out = **1.2005**; after, including a real mic press (recognition started) and typed turns,
  108.71 / 90.54 = **1.2008**. A new per-line `VOICEFMT` log showed session = output hardware = mixer→output link =
  48 kHz with voice processing off at every line; no re-link ever fired. **Root cause not reproduced on the
  simulator.** Round 31's input tap isn't new (the old MicPump tapped the same input); the graph is unchanged.
- **Guard added:** before each line (nothing queued) and on route changes, if the hardware rate no longer matches the
  mixer→output link, re-link it (logged with the rate she would have been heard at); the session prefers 48 kHz before
  activating. Test: a stale link at 44.1/48/24 kHz is detected and re-linked and every path renders at 1.20.
- **Other suspects for a real iPad** (unverified): the hardware rate moving when the input starts on device; and round
  31's switch to text-only kid turns, which can change gpt-realtime's prosody (not the playback rate). Check on the
  iPad with the VOICEFMT log.

## Claude's calls
- A replay also needs the AI consent (Nutmeg's live voice runs on replays), but is never counted.
- "Not now" ends the onboarding without the mic or plans screens; after consent in Grown-ups, the first New game asks
  for the mic with the system prompt.
- The onboarding clips play on their own playback-only engine, so no mic prompt can appear before screen 4.
- The kid greeting avoids naming "New game" (round 26 rule: lines don't name buttons by word): "Tap the big play button".
- The first-game intro is shorter than the brief's example ("your pretend-play stage manager" is said at the hand-off).
- The Free Preview count lives in UserDefaults per the brief (the research suggested the Keychain to survive reinstalls).

## Checks
- NutmegCore green (436 tests): `Round33OnboardingTests` (flow, back, replay, flags, consent gating, Free Preview new
  vs replay, reset, plans config/prices, copy, greeting pick/rotation/flag) and `SpeakerGraphTests` stale-link render.
- Clean build `-derivedDataPath build/DD-r33`, debug dylib confirmed. 8 clips recorded live from her real voice
  (`-PTRecordCommon`, transcript-gated, all first try).
- Screenshots in `/tmp/pt-round33/` (01–19): every screen, the system mic and speech prompts, the denied note, the
  hand-off back on the start screen, New game without consent, the Free Preview used up (kid card; the gate → plans
  sheet was walked live, its shot removed after the price change: same `PlansContent` as 08/19), the plans at the new
  prices (08 monthly, 19 yearly), Grown-ups with AI partners off/on and Replay the intro.
- **Not verified:** VoiceOver and the largest Dynamic Type sizes by hand; purchases (StoreKit not wired); the real iPad
  voice rate; a replay's "not counted" live (unit-tested); 02's screenshot is from before the layout pass.
