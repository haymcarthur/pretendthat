# Cheaper voice options for Nutmeg (2026-11-17)

Haylee asked: "Does Claude or any other AI provider have a cheaper voice option that gives us voice and good responses for
cheaper, using the same model so it doesn't have the wait?"

Desk research by a background agent (Claude), web only, no paid API calls. Prices were checked on official pages where
they loaded (OpenAI, Google, xAI, ElevenLabs, AWS model card) on 2026-11-17. Where only third-party pages had a number, it
says so. Prices change often, so check again before switching anything.

**Bottom line**

- **Claude has no voice API.** Anthropic still only sells text (and image) in, text out. Claude's own voice mode in the
  apps is speech-to-text, then Claude, then a separate voice, the same shape as our spike that added about 4 s. So
  "Claude, one model, no wait" doesn't exist yet.
- **Only OpenAI can keep Nutmeg's voice.** "coral" is an OpenAI voice. Every other provider means a new voice. Even
  OpenAI's new per-minute product (gpt-live-1) doesn't offer coral.
- **The cheapest credible single-model option is OpenAI's own mini model** (gpt-realtime-2.1-mini) for the whole
  conversation: about **$0.15 to $0.17 a game** instead of about $0.53, same coral voice. The catch is quality: in the
  Nov 16 test it skipped steps, made odd role names and had slow confirm turns. It needs a retest on today's build.
- **Amazon Nova Sonic** is the only other provider that is clearly cheaper (about $0.08 to $0.18 a game) with tools and
  about 1.1 to 1.4 s to first sound. But it changes her voice, has a hard limit of 20 talking sessions at once per
  account per region (for Nova 2), and I found no written OK or ban on kids' apps.
- **Google Gemini Live is out for us:** its terms forbid apps "likely to be accessed by individuals under the age of 18".
- **Per-minute products cost more for us, not less** (Grok, ElevenLabs, gpt-live-1, Hume): they bill every connected
  minute, and a PretendThat game keeps the voice connected for 12 to 40 minutes while Nutmeg only talks about 4.
- **Recommendation:** stay on OpenAI. Ship the already approved mini voice for scripted lines (about $0.35 a game for
  voice), then retest mini for the whole conversation on the current build. If mini still slips on the planning steps,
  use the full model for planning and mini for the prop hunt (about $0.24 a game for voice). All three keep coral.

## 1. The numbers used for "cost per game"

From [cost per game v3](2026-11-16-cost-per-game-v3.md) (measured games A and B):

- 34 Realtime responses a game (28 replies + 6 scripted lines), kid turns sent as text (on-device speech).
- Nutmeg's audio out: 4,273 to 4,980 OpenAI audio tokens, about **3.6 to 4.2 minutes** of her voice (I use 3.9 min).
- Input: about **300k tokens a game** (the ~16k-character instructions + 19 tools re-read on every response), 95% cached.
  This is worked back from the bill: $0.49 total minus $0.27 audio out leaves about $0.22 for input + text out.
- About 2k text output tokens (tool calls).
- Today's voice bill: **about $0.53 a game** ($0.49 to $0.57).
- **Connected time** (only matters for per-minute products): not measured. Planning + prop hunt is at least about
  12 minutes; if the voice stays connected through the scenes (it says the scene openings live), 25 to 40 minutes.
  Per-minute prices below are shown at **12 min** and **30 min**.

For token-priced providers that don't cache, I assume they re-bill the whole conversation each turn (as OpenAI does,
just without the cache discount). Google's own staff and docs haven't confirmed this for Gemini Live; a developer forum
thread says it does.

## 2. Ranked table (cheapest credible first)

"Credible" = one model hears the text and speaks, calls our tools, about 1 s or less to first sound, and allowed in a
kids' app as far as I could find.

| # | Option | Est. voice $/game | Voice | Wait (first sound) | Main catch |
|---|---|---|---|---|---|
| 1 | **OpenAI gpt-realtime-2.1-mini, whole conversation** | **~$0.16** (measured $0.176 vs $0.601 on the full model, same script, Nov 16 build) | **coral, same** | 0.3 to 0.9 s on plain lines; median 2.4 s on turns, 8 s on the confirm turn in the Nov 16 test | Quality: skipped a step (empty reply), skipped the confirm line, odd role names and prop reasons, doubled tool calls. Needs a retest |
| 2 | **OpenAI: full model for planning, mini for the prop hunt** (new idea) | **~$0.24** | coral, same | today's speed in planning | A second session mid-game (round 9's reconnect-with-state already does this). Untested |
| 3 | Amazon Nova 2.5 Sonic (Bedrock) | ~$0.08 to $0.18 | **new voice** ("tiffany", adult US female; few English voices) | ~1.1 to 1.4 s (P50 ~1.14 s) | New voice. 20 sessions at once per account per region, not raisable (Nova 2 card). No written kids' policy found. A full rewrite of the voice code (AWS bidirectional stream, not OpenAI's protocol) |
| 4 | **OpenAI: full model + mini for scripted lines** (already approved by ear) | **~$0.35** | coral, same | same as today, lines faster | Already decided; just needs the relay's second secret |
| 5 | Trims inside Realtime (any of the above) | −$0.05 to −$0.10 | same | same | Shorter replies cost words; see section 4 |
| — | OpenAI gpt-realtime-2.1 (today) | ~$0.53 | coral | ~1.2 s | the baseline |

Not cheaper, or blocked:

| Option | Est. voice $/game | Voice | Why not |
|---|---|---|---|
| Google Gemini 3.8 Live | ~$0.30 to $0.55 (no cache listed) | new voice | **Terms forbid apps likely used by under-18s.** Also not clearly cheaper without caching |
| Microsoft Azure OpenAI (gpt-realtime-2.1 / mini) | same as OpenAI (~$0.53 / ~$0.16) | coral (same models) | Not cheaper. Only a different contract and data path (see section 5) |
| OpenAI gpt-live-1 | $0.60 (12 min) to $1.50 (30 min) + backend tokens | **no coral** (marin default) | Billed per connected minute; our tools run on a backend model (2.8 to 6.3 s to the answer) |
| ElevenLabs Eleven Realtime v1 Mini / Max | $0.96 to $2.40 + LLM ($0.07 Mini, ~$0.56 Max) | new voice (big library) | Per connected minute; zero retention is enterprise-only; access still rolling out |
| xAI Grok Voice 3.0 | $1.10 (12 min) to $2.54 (30 min) | new voice ("eve" default) | Per minute + $0.004 per text input; terms bar personal info of under-13s |
| Hume EVI 4 mini | $0.24 to $1.05 + a separate LLM | new voice | Needs a separate LLM (so it's a pipeline); public prices removed in Oct 2026 |
| Anthropic Claude + a voice (spike, or Inworld's realtime API with Claude) | ~$0.18 | new voice, or coral via mini | Two hops: the spike measured ~5.4 s to first sound. Inworld doesn't fix Claude's own start time |

## 3. Each option

### OpenAI (keeps coral)

Prices from the [OpenAI pricing page](https://developers.openai.com/api/docs/pricing), per 1M tokens:

| Model | Text in | Cached | Text out | Audio in | Audio cached | Audio out |
|---|---|---|---|---|---|---|
| gpt-realtime-2.1 | $4.00 | $0.40 | $24.00 | $32.00 | $0.40 | $64.00 |
| gpt-realtime-2.1-mini | $0.60 | $0.06 | $2.40 | $10.00 | $0.30 | $20.00 |

- **No newer or cheaper Realtime model** than 2.1-mini. gpt-realtime-2 and -1.5 cost the same as 2.1 (1.5 has $16
  text out); gpt-realtime-mini costs the same as 2.1-mini.
- **gpt-realtime-2.1-mini for everything:** measured in [cost v2 §5](2026-11-16-cost-per-game-v2.md): $0.176 vs
  $0.601 for the full model on the same script (×0.29). Applied to today's $0.53: **about $0.15 to $0.17**. Coral, and
  Haylee already couldn't hear a difference between full and mini (A/B v2). Tools: yes. Kid-safe: same OpenAI rules.
  The problems were steps and judgment, not voice. That test ran on the Nov 16 build, before rounds 33 to 37 changed
  the instructions, so a fresh 1 to 2 game test (the
  [existing idea](../ideas/2026-11-17-mini-voice-full-conversation.md)) is cheap and worth it.
- **Planning on full, hunt on mini (new idea):** the hunt is many short, repetitive turns ("found it", next prop),
  where the mini's weaknesses matter least; planning (game, theme, recap, roles) is where it slipped. Roughly half of
  the conversation bill is the hunt, so this saves about another $0.11 on top of row 4: **about $0.24**. A Realtime
  session can't change model mid-way, so it means opening a new session with the game state, which round 9's silent
  reconnect already does.
- **gpt-live-1** (new, Sep 2026, [model page](https://developers.openai.com/api/docs/models/gpt-live-1)): $0.05 per
  minute of open session (silence counts), billed by the second, plus the backend model's tokens. The live model says
  short things itself and hands tools and reasoning to a backend model; in a third-party test the spoken answer came
  2.8 to 6.3 s after a tool question. Voices: marin (default), cedar, quartz and others; **coral isn't listed**. Not a
  fit: more expensive at our session length, slower on tool turns, and a voice change.

### Anthropic (Claude)

- **No speech-to-speech or voice-output API** as of today. The [platform intro](https://platform.claude.com/docs/en/intro)
  lists text and image in, text out, tool use. Claude's voice mode in the Claude apps is a pipeline (speech to text →
  Claude → a voice), and Anthropic has used ElevenLabs for the voice part.
- So with Claude the only route is two hops, like our [brain spike](2026-11-17-claude-brain-spike.md): cheap ($0.18)
  but about 5.4 s to first sound, because Claude takes about 1 to 2.5 s to start, twice a turn.
- Third-party "realtime" platforms such as [Inworld](https://inworld.ai/realtime-api) can run Claude behind an
  OpenAI-style socket with their own voices, billed per part (their TTS-2 is $25 per 1M characters, about $0.08 of
  Nutmeg's speech a game). It's still two hops, and the wait is Claude's start time, which they can't remove.

### Google Gemini Live

- `gemini-3.8-live` (also `-extended-thinking`, and `gemini-3.1-flash-live-preview`, which is being shut down):
  text in $0.75, audio in $3.00, text out $4.50, audio out $12.00 per 1M (about $0.018 per minute of her voice). **No
  cached-input price listed** ([pricing](https://aistudio.google.com/docs/pricing)).
- Estimate: her audio out ~$0.07, but without a cache the ~300k re-read tokens cost ~$0.23, plus any of her audio kept
  in the context: **~$0.30 to $0.55**. Not clearly cheaper.
- Tools: yes. Voices: Google's own (new voice for Nutmeg). Latency: sub-second is typical.
- **Blocker:** the [Gemini API terms](https://aistudio.google.com/docs/terms) (effective Mar 23, 2026) say you must be
  18+ and "will not use the Services as part of a website, application, or other service... that is directed towards
  or is likely to be accessed by individuals under the age of 18." Vertex AI reportedly has similar wording (not
  verified). Paid tier: prompts not used for training, logged for a limited time for abuse checks.

### Amazon Nova Sonic (Bedrock)

- `amazon.nova-2-sonic-v1:0` (Dec 2025; end-of-life no sooner than Dec 2, 2026) and **Nova 2.5 Sonic** (GA Oct 5,
  2026). Third-party pages list speech in $3.00, speech out $12.00, text in $0.33, text out $2.75 per 1M; the
  [AWS model card](https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-nova-2-sonic.html) points to
  the [Bedrock pricing page](https://aws.amazon.com/bedrock/pricing/), which I couldn't load. Some list Nova 2.5 at a
  lower audio-in price.
- Estimate: speech out ~$0.07 + text input $0.01 to $0.10 (depending on whether the prompt is re-billed each turn):
  **~$0.08 to $0.18 a game**.
- Tools: yes (asynchronous tool calls), mixed text and voice in one session. First sound ~1.1 to 1.4 s (AWS and third
  parties).
- Voices: US English "tiffany" (female) and "matthew"; UK "amy", Australian "olivia". Adult, assistant-style; nothing
  close to a squeaky young mouse without our own pitch shift.
- Limits: **20 sessions at once per account per region, not adjustable** (Nova 2 card). That caps how many families can
  play at the same moment, unless 2.5 raised it.
- Data: AWS says Bedrock doesn't store or review prompts and outputs and doesn't train on them; logging is off by
  default ([Bedrock data protection](https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html)). That's
  close to zero retention by default. **Kids:** I found no AWS rule for or against child-directed apps; check the AWS
  Responsible AI Policy and Service Terms.
- Effort: a new protocol (AWS bidirectional stream, AWS keys through the relay), new voice, retune all prompts.

### Microsoft Azure OpenAI

- Same gpt-realtime-2.1 and 2.1-mini, same prices as OpenAI per third-party listings (audio in $32, out $64, cached
  $0.40 for 2.1). Some Azure deployment types cost a little more; check the Azure pricing page.
- Same voices, so **coral stays**. Not cheaper.
- Why it might still matter: Microsoft's data terms (no training, abuse monitoring that can be switched off with an
  approved request) are another route to "nothing kept" if OpenAI's ZDR approval is slow. Kids' rules: not checked in
  depth.

### Per-minute products (all change her voice)

- **xAI Grok Voice 3.0** ([models](https://docs.x.ai/docs/models)): $0.08 per minute + $0.004 per text input. At 12
  to 30 connected minutes plus ~34 text inputs: **$1.10 to $2.54**. Default voice "eve"; built-in tools (custom
  function calls not clearly documented); "sub-second" claimed; ZDR offered. xAI's enterprise terms (2024 version) bar
  uploading personal info of children under 13.
- **ElevenLabs Eleven Realtime v1 Mini / Max** (Oct 20, 2026, [pricing](https://elevenlabs.io/pricing/api)): $0.08 per
  connected minute + LLM tokens (Mini $0.20 in / $6 out per 1M; Max $1.80 / $9). **$1.00 to $3.00 a game.** First
  sound ~0.5 to 0.6 s (company figures), tool calls, a huge voice library (the closest to "bright, playful young
  female" of anyone). Zero Retention Mode is enterprise-only; its privacy policy says the service isn't aimed at
  under-13s (secondary source).
- **Hume EVI 4 mini**: about $0.02 to $0.035 per minute depending on plan (third-party; Hume removed its public prices
  in Oct 2026) and it needs a separate LLM. $0.24 to $1.05 + LLM.
- **OpenAI gpt-live-1**: see above.

## 4. Cutting cost inside Realtime (keeps coral)

Where today's ~$0.53 goes: her audio out ~$0.27 to $0.32 (55 to 60%), re-read input ~$0.17, tool-call text ~$0.05.

| Lever | Saves per game | Notes |
|---|---|---|
| Mini for scripted lines (approved) | ~$0.16 | Already measured in v3 |
| Mini for the prop hunt | ~$0.11 | New session at the hunt |
| Mini for everything | ~$0.37 | Quality retest first |
| Shorter replies | ~$0.03 per 10% fewer spoken seconds | On the full model; scene openings are already shorter (round 34) |
| Shorter instructions + fewer tools in each step | ~$0.03 to $0.05 for half the prompt | Cached input is only $0.40/M (mini $0.06/M), so this saves little |
| Fewer responses (merge the silent tool-first pass into the reply where safe) | ~$0.01 to $0.02 each removed per turn type | Each response re-reads the ~8k prefix |
| Text-in only | already done (round 31) | Kid audio no longer billed |

## 5. Kids' data (COPPA) per provider

| Provider | Default retention | Zero retention | Kids' apps |
|---|---|---|---|
| OpenAI (`/v1/realtime`) | Abuse logs up to 30 days, no app state stored | **ZDR eligible** (also Modified Abuse Monitoring); needs sales approval ([your data](https://developers.openai.com/api/docs/guides/your-data)) | Allowed with ZDR for under-13 data ([under-18 guidance](https://developers.openai.com/api/docs/guides/safety-checks/under-18-api-guidance)); same blocker as the [compliance list](2026-11-16-app-store-compliance.md) |
| OpenAI gpt-live-1 (`/v1/live/sessions`) | 30 days abuse logs; recordings 30 days if `store` is on | ZDR "with limitations" | same as above |
| Anthropic | n/a (no voice API) | ZDR by agreement | Allowed with the minors safeguards (disclosure, COPPA statement, safety prompt) |
| Google Gemini API | Paid: logged for a limited time for abuse checks | n/a | **Not allowed** (18+, not in apps likely used by under-18s) |
| Amazon Bedrock (Nova) | Not stored or reviewed; logging off by default | effectively by default | No rule found either way; check |
| Azure OpenAI | Abuse monitoring unless an exemption is approved | Modified abuse monitoring by request | Not checked in depth |
| ElevenLabs | Kept for history/debug | Zero Retention Mode, enterprise only | Privacy policy: not aimed at under-13s (secondary source) |
| xAI | Not checked | ZDR offered | Enterprise terms (2024): no under-13 personal info |
| Hume | Not checked | Not checked | Not checked |

## 6. Recommendation

1. **Stay on OpenAI.** It's the only way to keep coral, and its mini model is already the cheapest credible single model
   for us. Switching provider means a new Nutmeg voice, a new protocol and new kids' paperwork, for at best $0.05 to
   $0.10 less than mini.
2. **Ship the mini scripted lines** (approved): voice ~$0.53 → ~$0.35.
3. **Retest mini for the whole conversation** on the current build (1 to 2 typed games, same checks as cost v2 §5). If
   it follows the steps now: ~$0.16. If planning still slips: **full for planning, mini for the hunt** (~$0.24).
4. **Keep ZDR on the list** whatever we pick: it's needed for OpenAI either way, and Azure is a backup route to the same
   models and voice.
5. Look at **Nova 2.5 Sonic** only if Haylee would accept a new voice and the 20-session cap is lifted. Don't use Gemini
   (terms) or the per-minute products (cost more at our session length).

## Sources

- OpenAI pricing: https://developers.openai.com/api/docs/pricing
- OpenAI gpt-live-1: https://developers.openai.com/api/docs/models/gpt-live-1 · https://developers.openai.com/api/docs/guides/live-conversations · https://flaviocopes.com/gpt-live-1/ · https://www.datacamp.com/tutorial/gpt-live-1-api
- OpenAI data controls: https://developers.openai.com/api/docs/guides/your-data
- Anthropic platform: https://platform.claude.com/docs/en/intro · https://the-decoder.com/anthropics-claude-uses-elevenlabs-technology-for-speech-features-rather-than-an-in-house-model/
- Google pricing and terms: https://aistudio.google.com/docs/pricing · https://aistudio.google.com/docs/terms · https://discuss.ai.google.dev/t/does-gemini-live-native-audio-bill-cumulative-prompt-tokens-on-every-turn-cost-seems-to-scale-with-turn-count-not-call-duration/173248
- Amazon Nova Sonic: https://docs.aws.amazon.com/bedrock/latest/userguide/model-card-amazon-nova-2-sonic.html · https://docs.aws.amazon.com/nova/latest/nova2-userguide/sonic-language-support.html · https://www.deeplearning.ai/the-batch/nova-2-family-boosts-cost-effective-performance-adds-new-agentic-features · https://www.llmreference.com/model/nova-2-sonic · https://aws-news.com/article/2026-10-05-announcing-amazon-nova-25-sonic-with-improved-reasoning-for-voice-agents · https://docs.aws.amazon.com/bedrock/latest/userguide/data-protection.html
- Azure (third-party price listings): https://cloudprice.net/models/azure/gpt-realtime-2.1-2026-07-07 · https://futureagi.com/llm-cost-calculator/azure-openai/gpt-realtime-2-1
- xAI: https://docs.x.ai/docs/models · https://docs.x.ai/docs/guides/voice · https://x.ai/legal/terms-of-service-enterprise/previous-2024-10-29
- ElevenLabs: https://elevenlabs.io/pricing/api · https://explainx.ai/blog/elevenlabs-eleven-realtime-v1-mini-max-speech-to-speech-openai-compatible-api-2026 · https://elevenlabs.io/docs/resources/zero-retention-mode
- Hume: https://www.eesel.ai/blog/hume-ai-pricing · https://www.usagepricing.com/blueprint/hume-ai
- Inworld: https://inworld.ai/realtime-api · https://docs.inworld.ai/realtime/resources/billing
