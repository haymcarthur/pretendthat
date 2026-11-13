# Open questions

- ~~**App name**~~: decided, **PretendThat**. See [decision](decisions/app-name-pretendthat.md).
- ~~**Mascot name**~~: decided, **Nutmeg** (she/her). See [decision](decisions/mascot-nutmeg.md).
- **Names in image prompts?** Sending kids' first names to OpenAI so the art includes them is simpler, but weakens the "names never leave the iPad" pitch. **Built default:** art is generated with a blank name banner and the app overlays the names, so names are never sent to OpenAI. Haylee can still overrule.
- **OpenAI API key and cost:** Haylee will paste keys into the git-ignored `Secrets.xcconfig`. gpt-image costs per image; a kit of ≤ 6 pages is ≤ 6 images per game.
- **Relay ready?** Needs a Cloudflare account; direct-key dev mode until then.
- ~~**GitHub repo name**~~: `haymcarthur/pretendthat` (private).
- **Domain:** `pretendthat.app` looked free; the `.com` is parked. Register?
- **Font:** SF Rounded until a heavy rounded brand font is chosen.
- **Names without a mic:** if speech is unavailable (denied, or the simulator), players stay "Player 1…". Add a grown-up keyboard entry behind the parent gate?
