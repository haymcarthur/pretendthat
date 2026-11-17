# Paid-app direction (talked through, not built yet)

**Date:** 2026-11-15 · **Who decided:** Haylee (Claude's suggestions noted)

- **Platform:** iPad only to start. Consider Android later only if it would clearly make a difference.
- **Saved games:** on the device, synced through the family's own iCloud (CloudKit private database). No accounts and no backend database. What's stored is game content, never anything about kids.
- **Replays keep Nutmeg's real voice:** NEVER the free system voices, and her voice never changes between plays. Claude's suggestion: record her scripted lines on the first play and replay those recordings, using the live voice only for new interaction.
- **Players capped at 6** (replaces "any number, one holds the iPad"). The badges page has exactly one badge per player/role, not always 6. (Known bug to fix: 2–3 players still get 6 badges.)
- **Money is a single $1 bill page.** Kids print more copies for more money. Menu prices should be small whole dollars to match.
- **Open:** the replay flow and UI, changing the player count on replay, and clearer navigation back to earlier steps (for example reprinting). See the conversation recap in the next round brief.

## Replay decisions (Haylee, 2026-11-15)
- **Generate for 6 every time, with ranked roles:** roles 1–2 are the core and 3–6 are extras. Badges are drawn as one 6-up sheet and sliced; checklist steps for extra roles are optional and only show when that role is playing. A replay with a different count (1–6) needs no AI calls. The only exception is a voice line for a role that wasn't present the first time; it's said live once in the same voice and then saved.
- **Save at The End instead of "Play again":** a "Save it to play again ⭐" button. Unsaved games are discarded when they leave.
- **No shelf cap.**
- **Grown-up delete:** a grown-up-gated delete on the saved-game shelf (for example a long press plus a confirm).

## Pricing (Haylee, 2026-11-15)
- **Pro:** $9.99/mo or $79.99/yr, **10 new games a month**, unlimited replays.
- **Unlimited:** $14.99/mo or $119.99/yr, with a large fair-use cap on new games (Claude suggests 30/mo, about one a day; to be confirmed after re-measuring the cost per game).
- Margins depend on getting the cost per new game to about $0.40 (see the conversation and research/2026-11-15-cost-per-game.md). No-printer games skip images, so they cost less.

## Design answers (Haylee, 2026-11-15)
- Offline replay needing an unrecorded line: ask to go online and pause; never silent text, never a different voice.
- Every playing role gets its own called-out checklist steps in every scene, and hand-offs rotate (changed from "extras optional").
- Parental gate: hold 2 s plus tap the spelled-out number.

## Plan names (Haylee, 2026-11-16)
- **Free Preview** (trial), **Show Pass** (10 new shows a month), **Season Pass** (up to 30 a month). "Unlimited" is never a plan name, since both paid plans include unlimited replays. Theater framing: "new shows", "replay your favorites as often as you like".

## Onboarding decisions (Haylee, 2026-11-16); see research/2026-11-16-onboarding-research.md
- **Free Preview with no card:** 2 free new shows counted by the app; not an Apple trial.
- **The plan screen appears in onboarding** ("Start my Free Preview" is the main button) **and when the free shows run out.**
- **Nutmeg speaks only on the first screen** (asking a kid to get a grown-up) **and at the hand-off.**
- The gate goes once, on screen 1 (the research recommendation; Claude's default unless Haylee objects).
- **Open:** the default billing period. Haylee asked whether yearly loses money; it can if heavy users max out their monthly game cap at today's cost per game. To be settled after re-measuring the cost per game.
- **Fixed in round 28:** the mic permission text wrongly said "Your voice stays on this iPad".

## Tagline (Haylee, 2026-11-16)
- Tagline: **"Turn your living room into a pretend-play adventure."** Nutmeg intro: **"Meet Nutmeg, your pretend-play stage manager."** This replaces "The game master for real-world pretend play"; avoid "I'm bored" in copy.

## Compliance answers (Haylee, 2026-11-16; Claude recommendations where she asked)
- **ZDR:** yes, apply for zero data retention with OpenAI and Anthropic now (Haylee does the applications).
- **Category (Claude's recommendation, Haylee: "whatever you suggest"):** launch OUTSIDE the Kids Category, as Education (or Entertainment), marketed to parents of kids 4–8. Why: Kids Category apps may not send personal or device data to third parties, and the core of the app is voice to a third-party AI. We still treat it as child-directed: COPPA, the parental gate, no ads or tracking, and the guardrails.
- **Age band:** N/A outside the Kids Category; the marketing says ages 4–8 and the age rating is 4+.
- **US only at first:** yes.
- **Publisher (Claude's recommendation):** an LLC rather than an individual (liability with kids' data; the store shows the LLC name instead of her personal name). Needs a D-U-N-S number for the Apple organization enrollment. Not legal advice; confirm with an accountant/lawyer.
- **AI disclosure and consent (Claude's recommendation):** the onboarding consent screen for parents names OpenAI/Anthropic, says what's sent (voice, game choices; no names) and that nothing is kept. Nutmeg introduces herself to kids as "a pretend helper made by a computer" in her first greeting. If the parent declines: the app offers only the bundled built-in sample adventure with tap choices (no AI), and they can turn AI on later in Grown-ups.
- **Relay cap:** $50 (Haylee's current setting) is enough for App Review; keep the per-IP limits.

- **Update (Haylee, 2026-11-16):** AI is REQUIRED; there's no AI-off sample-adventure mode. Onboarding asks the parent for clear AI consent; if they decline, the app explains PretendThat needs it to work and shows how to turn it on later in Grown-ups (no nagging). Publisher: Haylee will use an LLC and is considering an umbrella studio LLC for her apps (Tittl stays in its own LLC for now).

## Cost cuts and pricing direction (Haylee, 2026-11-16); see research/2026-11-16-cost-per-game-v3.md
- **Use the mini realtime voice for scripted (app-written) lines;** the conversation stays on gpt-realtime-2.1. **Sonnet 5.5 for the play guide and per-prop weave;** Opus stays for the kit pages.
- **Keep the game counts Haylee likes:** Show Pass 10 a month, Season Pass 30 a month ("one a day"). Set LIST prices that cover heavy use, launch at a discounted "launch price", watch real usage, and make the discount permanent if usage allows.
- **Yearly ~15% off** (comparable to other apps).
- Usage visibility needs anonymous counts at the relay (new games per subscription per month, no kid data); this ties into the cap enforcement planned with StoreKit.
- **Pricing (Haylee, 2026-11-16), tentative:** Show Pass list $14.99/mo with an introductory price of $9.99; Season Pass list $24.99/mo with an introductory price of $19.99. Use Apple introductory offers rather than "changing" the price. Yearly about 15% off. 10 and 30 new shows a month. To confirm: the intro offer duration (Apple caps pay-as-you-go intros at 12 billing periods per new subscriber) and the re-measured cost after rounds 34/35.
- **Mini voice:** Haylee heard the WRONG voice in the A/B samples. Mini must match coral at 1.20 exactly before shipping (round 35).
- **Intro offer length (Haylee, 2026-11-16):** 12 months (Apple's maximum for pay-as-you-go). Show Pass $9.99 for 12 months, then $14.99; Season Pass $19.99 for 12 months, then $24.99. Yearly: $149.99 / $249.99 (about 15% off). Pricing page updated.
- **Season Pass regular price (Haylee, 2026-11-16):** $29.99/mo (intro $19.99 for 12 months), yearly $299.99. Reason: the bigger plan should earn more; $1/game vs Show Pass $1.50/game. Idea for later: Season Pass extras (iCloud sync across devices, early themes/outfits, more saved games). Decide with real usage counts from the relay.
