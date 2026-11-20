# Open questions

- ~~**App name**~~: decided, **PretendThat**. See [decision](decisions/app-name-pretendthat.md).
- ~~**Mascot name**~~: decided, **Nutmeg** (she/her). See [decision](decisions/mascot-nutmeg.md).
- ~~**Names in image prompts?** Sending kids' first names to OpenAI so the art includes them is simpler, but weakens the "names never leave the iPad" pitch. **Built default:** art is generated with a blank name banner and the app overlays the names, so names are never sent to OpenAI. Haylee can still overrule.~~ Resolved by [roles-not-names](decisions/roles-not-names.md): we never ask for names.
- **OpenAI API key and cost:** Haylee will paste keys into the git-ignored `Secrets.xcconfig`. gpt-image costs per image; a kit of ≤ 6 pages is ≤ 6 images per game.
- **Relay ready?** Built and tested 2026-11-15 ([relay-for-shared-builds](decisions/2026-11-15-relay-for-shared-builds.md)); waiting on Haylee's Cloudflare account, deploy and spend caps (relay/README.md).
- ~~**GitHub repo name**~~: `haymcarthur/pretendthat` (private).
- **Domain:** `pretendthat.app` looked free; the `.com` is parked. Register?
- **Font:** SF Rounded until a heavy rounded brand font is chosen.
- ~~**Names without a mic:** if speech is unavailable (denied, or the simulator), players stay "Player 1…". Add a grown-up keyboard entry behind the parent gate?~~ Resolved by [roles-not-names](decisions/roles-not-names.md): we never ask for names.
- ~~**Keys rejected**~~: fixed by Haylee (2026-11-13 PM).
- **OpenAI has no credits (2026-11-13 PM):** image calls return 429 `credit_balance_exhausted` (not an org-verification error). Haylee: add credits at platform.openai.com → Settings → Billing. Until then the kit uses app-drawn pages automatically, and Grown-ups → Connections shows "Off (no OpenAI credits)". Model IDs listed for the key: gpt-image-2.6-flare, 2.5-flare, 2 (the app tries them in that order and remembers the first that works).
- ~~**Names said before the players screen** (e.g. on pick-game) go to Claude untokenized, since names aren't known yet. Acceptable, or strip capitalized words there?~~ Resolved by [roles-not-names](decisions/roles-not-names.md): we never ask for names.

## Added late 2026-11-13
- **Agents' live tests share Haylee's simulator:** build agents test push-to-talk by speaking lines with macOS `say` into the Mac mic, while holding the mic in the same simulator Haylee uses. Their lines ("Three friends", "We found it!") can land in her game. Option: agents use a second simulator, or announce runs. Undecided.
- **Wave art leftovers:** (a) the feet run ~4 px past the canvas bottom after the body transform; (b) where the waving arm crosses the brown cheek there's no outline, so the fur blends (accepted for now; would need regenerated art to improve).
- **Both-hands paws layer:** tiny orange slivers under each paw (old clipboard edge). Probably invisible at app size; check after the round 8 import.
- **Repeat-reply guard vs. step tools:** round 6's "one reply per turn" guard suppressed needed follow-ups after step tools (roles, props). Round 7 is fixing it; re-test the whole flow end to end after every conversation change.

- **2026-11-14: focus (coloring) face eyes.** Haylee is regenerating these with the eyes-on-green method (see decisions/2026-11-14-face-art-method.md). They get swapped in after round 15.

- **2026-11-16: App Store compliance questions** (from research/2026-11-16-app-store-compliance.md §3): apply for OpenAI + Anthropic zero data retention now? Kids Category or a general Family category? Age band 6–8 or 5 and under? Launch countries (US only)? Individual seller or an LLC? Nutmeg's "I'm a computer helper" disclosure wording? What happens if a parent declines AI consent? Raise the relay cap and per-IP limits for the review window?

- **2026-11-16: cost v3 (research/2026-11-16-cost-per-game-v3.md §8).** Does the mini voice (design/voice-ab/, 8 pairs) sound like the same Nutmeg? OK to move the play guide + weave to Sonnet 5.5 (relay allow-list)? Plan limits: 8 / 12 now, or 10 / 15 after both changes?

- **2026-11-17 (round 38): yearly intro offers?** The decisions give yearly prices ($149.99 / $299.99) but no yearly intro offer, so during the first 12 months monthly is cheaper than yearly ($119.88 vs $149.99; $239.88 vs $299.99). Options: no yearly intro (built), a pay-up-front yearly intro (e.g. $99.99 / $199.99 for the first year), or launch monthly only. Also: Family Sharing on or off (built as off)?

- **2026-11-17 (analytics): default OFF ok?** Built with the "Share anonymous usage counts" switch OFF until a grown-up turns it on (onboarding privacy page, Grown-ups → About what we save); fewer counts, safer under COPPA. Turn it ON by default only after the lawyer / Safe Harbor review says anonymous analytics fits "support for internal operations". Also confirm TelemetryDeck's retention period and DPA for the privacy policy brackets.

- **Nutmeg speed (2026-11-17):** which row in design/voice-speed-check/ sounds like "1.2" to Haylee (line 1 and line 2, ideally on the iPad too)? 1.20 = the app today. See research/2026-11-17-voice-speed-check.md.

- **2026-11-17 (round 39): auto-save follow-ups.** (a) Writing-hand shadow: the shirt shadow is in the body art, not the fingers layer, so the "move the paths" fix doesn't exist; regenerate a writing body with the paw cut out under the fingers, or shrink the rock (±3.2° → ±1.5°)? (b) Bundle "I put it on your bookshelf!" and the new End line as clips (a short `-PTRecordCommon` run, ~2–6 responses), or leave them live-then-kept per game? (c) When the relay's show count is deployed it still counts at Let's play! (it must issue the ticket before the kit's AI calls); add a "commit at the kit" step so early closes are free there too? (d) The bookshelf order is most recently played first (Claude's suggestion): keep it?

- **2026-11-17 (round 40): checklist rows and goal rows.** (a) Rows: keep the shipped soft tinted pill (no rings), or switch to the thin-outline alternative (rows/sheet-rows-*.png in /tmp/pt-round40; one-line change, `PTRowLook.current`)? (b) The rows have no checked / done state since round 29 (no checkboxes); want one back (e.g. the row fills with its color and a white ✓ replaces the 🔊)? (c) Goal rows: a 2-player game can now show up to 4 rows (2 per kid, at most 3 items a row); is that "a few", or should 2 players stay at exactly one row each (longer spoken lines)?

- **2026-11-17 (rounds 41–42).** (a) iPad with the chat CLOSED during Props, Print and the scenes: she keeps the medium shot beside the card (a close-up next to the card would make her head smaller); should the card sit over her lower body instead so she stays in the talking close-up? (b) The leave dialog after the kit still shows the little card-onto-shelf picture (no words, nothing said): keep it, or remove it with the bookshelf moment? (c) Odd but allowed prop uses like "stuffed animal → the pet drying cloth" (seen live): add a "cloth" rule (soft or sheet things only)? (d) Round 40's (a)/(b) were answered (soft rows, no done state); round 39's (a) and (b) are done (round 41 shadow layer, round 42 End clip; the shelf line is gone).

## Status check (2026-11-17 evening, Claude): what's resolved vs still open
**Resolved today:**
- **App Store compliance:** not the Kids Category; Education 4+; US only. **No ZDR** (Haylee: only text, never audio, goes to AI; the policy keeps "may keep up to 30 days").
- **Cost v3:** mini voice approved for scripted lines (default in round 44); Sonnet 5.5 for the play guide + weave approved (default in round 44).
- **Yearly intro:** $99.99 / $199.99 for the first year (decisions/2026-11-17-yearly-intro-sonnet.md).
- **Analytics:** always on, no switch anywhere (decisions/2026-11-17-onboarding-v3-feedback.md).
- **Nutmeg's speed/pitch:** 1.20 + Signalsmith plain +2; clips get the same processing (voice-clips-match).
- **Round 39–42 questions:**
  - writing hand fixed (crayon shadow layer);
  - no done state on rows; tinted rows kept;
  - no bookshelf moment;
  - leave-dialog picture removed (round 44);
  - chat open = no card on stage (round 44);
  - prop audit → round 43.
- **The TelemetryDeck app ID** is set in Analytics.xcconfig. The relay was redeployed (version 8ed4aa7c, SHOW_LIMITS off).

**Still open (Haylee):**
- **Round 44: the "Hooray, a new show! What should we play?" greeting** (a bundled clip kids hear) still says "show".
  Re-record it as "a new game" (one clip), or drop it from the four greetings? (decisions/2026-11-17-round44.md)
- **Round 44: the live check of the mini voice on by default** is still to do (the one live run used a stale build).
- **Privacy policy facts:** legal business name + mailing address; how long support emails/reports are kept; iCloud syncing is built (round D4): make the policy line present tense; a legal (COPPA) look before launch.
- **App Store Connect setup:** agreements/bank/tax, 4 subscriptions + intro offers, App Privacy label, age rating, review notes, sandbox tester (decisions/2026-11-17-storekit-subscriptions.md, 2026-11-17-setup-rows-and-compliance.md).
- **Plan sizes:** re-measure the cost per game after rounds 43–45 (mini voice + Sonnet + printables), then confirm 10 / 30 a month. At ~$1.10 a game, 30 a month loses money; after the cuts it may not.

**Still to build (app):**
- Round 43, building: prop audit fixes, hard no-repeat rule, prop shortlist for variety.
- Round 44: onboarding v3, show→game, no usage switch, chat/leave-dialog fixes, yearly intro, mini voice + Sonnet defaults.
- Round 45: the printables overhaul, then refresh the site's print fan.

**Ideas parked:** mini voice for the whole conversation; voice-light replays for families without a plan; iCloud sync; Season Pass extras.

- (2026-11-17, round plans/printables/page) The End's bundled clip still says "This game is saved, so you can play it again later." Without a pass, playing it again needs a grown-up. Re-record with new words (suggestion: "This game is saved, so you can print it again later.")? Needs one live recording run.

- (2026-11-18) **Peek right paw rim:** in the v4 art the right paw's dark top rim is hidden under the taller redrawn right paw. Fix in Figma and re-export, or leave it? (decisions/2026-11-18-peek-hands-regenerate.md)
- (2026-11-18) **Not-ready printable:** should Nutmeg say something when a page shows "Try again"? (needs a recorded clip; decisions/2026-11-18-printables-after-lock.md)
- (2026-11-18) **Build 4 device checks** (Haylee): idle/lock mic + taps; printables after a lock match with no built-in art.

- (2026-11-20) ~~Where does Nutmeg go with many checklists?~~ Answered: on a card (iPad), over a checklist shelf (iPhone).
