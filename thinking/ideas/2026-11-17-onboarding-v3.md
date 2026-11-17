# Onboarding v3: six calm pages (mockup, for Haylee's review)

- **Date:** 2026-11-17 · **Status:** mockup only, not built. Nothing in the app changed. This is round 3 with Haylee's changes.
- **Why:** Haylee's feedback on the v2 iPhone onboarding: still way too fancy and complicated. She wants much less Nutmeg, much shorter copy, no scrolling, and the calm, white-space look of the new site. Her reference pattern is a light page, a thin segmented progress bar with a small round back button, one simple visual, a short title, one gray line and one full-width pill button.
- **Mockup:** [design/mockups/onboarding-v3/index.html](../../design/mockups/onboarding-v3/index.html) shows every page at iPhone 17e size (375 × 812) and iPhone 18 Pro size (402 × 874), the mic-denied state, and iPad landscape frames for pages 1, 2 and 4. There's a full screenshot in `mockup.png`, plus `page-01.png` … `page-06.png`, `page-07-state-04b-mic-denied.png` and `page-08-ipad.png`. The page measures itself, and headless Chrome found 17 of 17 frames fit with no scrolling.

## Haylee's decisions in this round (2026-11-17)
- "Show" → "game" everywhere (approved for the whole app's grown-up wording).
- AI is required, so the privacy page has one action and no "Not now" or decline page.
- Usage counts are always on, with no switch and no usage line in onboarding. They are covered in the privacy policy.
- Privacy and the mic are one step: "I agree, turn on the mic".
- No duration anywhere ("15–25 minutes" is gone).
- The plans page shows the renewal price in plain words, no strike-through and no Monthly/Yearly switch (yearly lives in Grown-ups → Plans).
- Page 1 uses the start-screen art; the last page uses the logo.

## Pages (7 → 6)
| # | Page | Purpose | Visual |
|---|---|---|---|
| 1 | Welcome to PretendThat | Welcome. Nutmeg's "get a grown-up" clip plays here. No back button. | The start screen's art, composed from the app's pieces: Nutmeg in her open toy chest on the wood floor, a block and a spinning top, the sky as a soft circle, no curtains |
| 2 | How it works | The kid's four steps | Four rows: an icon on a soft tile, one word, one line |
| 3 | What you'll need | Supplies | Three small tiles: printer, crayons, rug |
| 4 | Private by design | **Required** AI consent combined with the mic pre-prompt. One button. Names OpenAI and Anthropic, includes the privacy policy link, and warns that the system mic prompt comes next. | Green shield with a check |
| 4b | No mic? Kids can type. | If the mic is denied: Next / Open Settings | Gray mic |
| 5 | Start with 2 free games | Plans. The Free Preview is the main button; two plan rows have StoreKit "Get" buttons (no gate); auto-renew line; Restore · Terms · Privacy | Ticket |
| 6 | You're all set | Hand-off: "Start our first game" or "Go to the home page" | PretendThat logo (logo-nutmeg-top) |

## Cut or merged
- v2's separate "Hold to talk" page → merged into page 4. Its explanation that she listens only while the button is held is gone from onboarding; the game teaches it.
- v2's "Not now" and decline page → removed (AI is required).
- The usage switch → removed, with no usage line either (always on, covered in the privacy policy).
- Eyebrows, the How it works tagline, the stage frame, curtains and the floor disc on every page → gone.
- The plan cards' Monthly/Yearly switch and "Unlimited replays" bullets → removed. The free-replays line is under the title.

## Copy, old → new
| Page | Element | Old (v2) | New (v3) |
|---|---|---|---|
| 1 | Title | Hi, grown-up! | Welcome to PretendThat |
| 1 | Line | This part is for grown-ups. A quick look at how PretendThat works and how we keep it private. | Turn your living room into a pretend-play adventure. |
| 1 | Button | Let's get started | Get started |
| 2 | Title | How it works | How it works |
| 2 | Tagline | Turn your living room into a pretend-play adventure. | Moved to page 1 |
| 2 | Pick | Your child picks a story and a role with Nutmeg. | Pick a game by talking with Nutmeg |
| 2 | Props | Nutmeg finds things you already have at home. | Find props around the house |
| 2 | Print | Print a kit: masks, signs, tickets to color. | Print your custom kit |
| 2 | Play | Nutmeg guides each scene, then steps back. | Play scene by scene, off the screen |
| 3 | Title | What you'll need | What you'll need |
| 3 | Line | Nothing fancy. Most of it is already in your home. | Most of it is already in your home. |
| 3 | Tiles | A printer (For the kit) · Crayons (To color it in) · Space (Room to move) · 15–25 min (Per show) | A printer (For the kit) · Crayons & scissors (To color and cut) · Space to play (Room to move) |
| 4 | Title | Private by design | Private by design |
| 4 | Line | 4 checked sentences | Nutmeg uses AI. Words, with names removed, go to OpenAI and Anthropic. Privacy policy |
| 4 | Switch | Share anonymous usage counts (never anything about your child), OFF | Removed, and no usage line |
| 4 | Buttons | I agree, let's play · Not now (then a mic page with Continue) | I agree, turn on the mic (the only button) |
| 4 | Small | Next, your iPad will ask to use the microphone. | Your iPhone will ask to use the microphone next. |
| 4b | Denied | No problem. Kids can type instead. / To turn the mic on later, open Settings → Apps → PretendThat… | No mic? Kids can type. / Turn on the microphone in Settings anytime. · Next · Open Settings |
| 5 | Title | Start free, upgrade anytime | Start with 2 free games |
| 5 | Line | Want more new shows later? Pick a pass whenever you like. + "2 free shows, on the house! No card. Nothing to cancel." | Each new game is a fresh story and printable kit made just for your kids. Saved games are free to play again. |
| 5 | Rows | Cards with price, "for 12 months, then $14.99/month", "10 new shows a month", bullets, Monthly/Yearly | Show Pass · 10 new games a month · **$9.99/mo** for 12 months, then $14.99/mo · Get / Season Pass · Up to 30 new games a month · **$19.99/mo** for 12 months, then $29.99/mo · Get |
| 5 | Button | Start my Free Preview | Start with 2 free games |
| 5 | Footer | Restore purchases · Terms of Use · Privacy Policy | Billed by Apple. Renews until cancelled. / Restore · Terms · Privacy |
| 6 | Title | Hand the iPad to your child | You're all set |
| 6 | Line | Nutmeg will take it from here. | Hand your iPhone to your child. Nutmeg will take it from here. (iPad on iPad) |
| 6 | Buttons | Start our first game · Go to the home page | same |

## Claude's calls
- **Purple button (#5B2A86), not coral.** It matches the site's purple pill, so the app and the site look like one brand, and it's calmer for grown-ups. White text on purple passes contrast at any size, while white on coralStrong only passes for large text. Coral stays the kids' "go" color.
- The page is #FAF8FC, the visuals sit on a soft #F1EAF8 circle, and colors come from the site's tokens.
- Type is Poppins SemiBold 26 pt (30 on iPad) with Regular 15 pt gray lines. On pages 2 and 3 the title sits at the top, because the list is the visual.
- Page 1 composes the app's real assets the way `PTStartScreen` does on a phone: the open lid behind, the chest body, and Nutmeg cut off at the chest's front edge. Nutmeg is the existing idle-happy still (the start screen uses the same idle pose with her clipboard). The toys are toy-block and toy-top; the sky and floor colors come from Theme. Her art isn't edited.
- "Your device" in the hand-off line uses the device word (iPhone or iPad), like the app's `DeviceWord`.
- The printer icon is the onboarding's existing `OBPrinter` compact drawing. The app has no scissors art, so the crayons tile stands for "Crayons & scissors".
- I kept "Private by design" rather than "Private and safe", because "safe" is a new claim.

## For Haylee to decide
1. Is it OK that onboarding no longer says the mic only listens while the button is held? The game teaches it. It could go back as a third chip-free line on page 4, but that page is full.
2. Keep "Private by design" as the title, or use "Private and safe"? "Safe" is a broader claim.
3. Should the "Crayons & scissors" tile get real scissors art, generated the usual way (ChatGPT + vectorize), or keep the crayons?
