# Brand fonts sampler (2026-11-17)

**Why:** Haylee says the site (Fredoka + Inter) and the onboarding screens (SF Rounded) don't look right, mostly the fonts. Inspiration: the "Likelingo" (Duolingo-like) landing page: very heavy, tight rounded-geometric headlines with a few words in a bright color, friendly body text, chunky 3D buttons, an outlined secondary button.

**Scope (Haylee):** the new font is for **grown-up-facing** things only: the marketing site, parent onboarding and the Grown-ups section in the app. **Kid screens keep SF Rounded** as they are.

**Sampler:** [design/brand-fonts/index.html](../../design/brand-fonts/index.html). It starts in blind mode (shuffled letters A–E, with Reveal and Reshuffle buttons), works at phone width, loads fonts from Google Fonts, and is forced to light mode. Every candidate shows the same three samples with the same brand colors (BrandPalette + site.css) and the same chunky 3D buttons:
1. The site hero (real hero copy, "Start free" + "See how it works").
2. Two onboarding v2 iPad pages ("Hi, grown-up!" and "How it works", real `OnboardingCopy` strings).
3. Grown-ups: the menu (Saved games, Plans, Manage subscription, Restore purchases, AI partners) and the Plans card (Show Pass $14.99, Season Pass $29.99), both with real app strings. Next to them is a fixed reference: a real screenshot of today's kid screen in SF Rounded (prop hunt + step rail), so Haylee can judge whether grown-up and kid screens feel like one brand.

Today's Fredoka + Inter is a small, labeled baseline (not lettered, not a candidate). Screenshots in the same folder: `candidate-{momo,cal,tilt,poppins,lexend}.png`, `baseline-fredoka.png`, `quick-compare.png`, `quick-compare-blind.png`, `phone-width.png`.

Round 1 (Nunito, Baloo 2, Lilita One, Rubik, M PLUS Rounded 1c) was rejected by Haylee. These are her five heading fonts.

## Candidates (heading + body)

All five load from Google Fonts. I checked with the Google Fonts CSS API that each one loads, and confirmed in headless Chrome that each one actually renders. The license comes from google/fonts METADATA. All are **SIL OFL 1.1**: free to embed in a paid app and to use on the web.

| Heading (weight used) | Body | License | Notes |
|---|---|---|---|
| Momo Trust Display (single weight, 400) | Momo Trust Sans 500/600 (its sibling sans; neutral, not rounded) | OFL (Type Associates, 2025) | Wide, soft display shapes. One weight only, so the body uses the sibling family. |
| Cal Sans (single weight, 400) | Nunito 600/700 (neutral rounded-ish) | OFL (Cal.com, 2025) | Tight grotesk display. Crisp "startup" look, not rounded. One weight only. |
| Tilt Warp (single weight, 400) | Nunito 600/700 (neutral rounded-ish) | OFL (Andy Clymer) | Very heavy, soft, puffy corners. The most "kids brand" of the five. One weight only. |
| Poppins ExtraBold 800 | Poppins 400/500 | OFL (Indian Type Foundry) | Full weight range, one family. Clean geometric, very common on app sites. |
| Lexend ExtraBold 800 | Lexend 400/500 | OFL (Bonnie Shaver-Troup et al.) | Full weight range, one family. Built for reading ease: wide and open. |

All five are freely licensed and they all loaded; none had to be dropped.

## Claude's pick (Haylee decides)

**Tilt Warp headings + Nunito body.** It's the closest of the five to the Likelingo headline: very heavy, with soft rounded corners. It's also the one that sits most naturally next to the kid screens' SF Rounded, so grown-up and kid screens read as one brand. Nunito keeps body text rounded-friendly and has every weight for Dynamic Type.
- Downsides: Tilt Warp has a single weight, so it's for titles, row titles and buttons only (keep it at about 17 pt and up), and every screen needs two font families.
- **Runner-up: Lexend**, one family for everything, the most readable for parents, and the easiest Dynamic Type story, but it's more neutral and less playful.
- Poppins is clean but generic. Cal Sans reads as "tech", not "toy", next to the kid screens. Momo Trust Display is pleasant but the least distinctive at heavy sizes.

## What adopting the winner means

**App (iOS), grown-up surfaces only:**
- **Bundle the fonts.** Add `TiltWarp-Regular.ttf` plus Nunito static TTFs (SemiBold, Bold, maybe ExtraBold) and list them under `UIAppFonts` in Info.plist. Ship `OFL.txt` and add a credit line in Grown-ups → About. Add the fonts to the team profile.
- **Swap only the grown-up tokens.** That's `OBType` (Screens/OnboardingView.swift), the Grown-ups screens' text styles, and the grown-up button label (`OBPrimaryButton`). Leave `PTText` and the kid design-system styles on SF Rounded.
- **Keep Dynamic Type.** Use `Font.custom("TiltWarp-Regular", size: 34, relativeTo: .largeTitle)` and `Font.custom("Nunito-SemiBold", size: 20, relativeTo: .title3)` etc., keeping today's text-style mapping so sizes still scale.
- **Recheck layouts.** Test at the largest accessibility sizes: Tilt Warp is wide, so long Grown-ups row titles like "Manage subscription" may wrap. Keep SF Rounded as the fallback.

**Site:**
- Swap the Google Fonts link to `Tilt+Warp` + `Nunito:wght@600;700;800`.
- Set `h1–h3` to Tilt Warp and body to Nunito 600.
- Make buttons Tilt Warp with the 3D bottom edge (`box-shadow: 0 6px 0 <shade>`, pressing moves the button down 4px), plus an outlined secondary button.
- Optionally self-host the woff2 files.

Nothing in the app or the site was changed for this note.
