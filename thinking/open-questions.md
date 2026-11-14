# Open questions

- ~~**App name**~~: decided, **PretendThat**. See [decision](decisions/app-name-pretendthat.md).
- ~~**Mascot name**~~: decided, **Nutmeg** (she/her). See [decision](decisions/mascot-nutmeg.md).
- ~~**Names in image prompts?** Sending kids' first names to OpenAI so the art includes them is simpler, but weakens the "names never leave the iPad" pitch. **Built default:** art is generated with a blank name banner and the app overlays the names, so names are never sent to OpenAI. Haylee can still overrule.~~ Resolved by [roles-not-names](decisions/roles-not-names.md): we never ask for names.
- **OpenAI API key and cost:** Haylee will paste keys into the git-ignored `Secrets.xcconfig`. gpt-image costs per image; a kit of ≤ 6 pages is ≤ 6 images per game.
- **Relay ready?** Needs a Cloudflare account; direct-key dev mode until then.
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
