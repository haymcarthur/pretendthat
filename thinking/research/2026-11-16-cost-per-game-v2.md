# Cost per game v2 (measured), 2026-11-16

Haylee asked for this to set the plans' game limits and the default billing period (queue-next-app-round.md, "Next after
round 28"). Measured by a background agent (Claude) on the round 28 build, clean-built, with typed live games on the
simulator PT-R15-iPad and personal keys. Only token **counts** were logged, never content. Raw logs:
`/tmp/pt-cost2/<run>/console.log`.

**Bottom line**

- **A new game costs about $1.20** (measured $1.02 for 3 players and $1.25 for 5 players; range about $0.95 to $1.90).
  The old estimate was $1.60. Realtime caching works now (96% of input is cached), and the images are cheaper.
- **Realtime voice is still the biggest cost** at $0.60 to $0.78. Most of it is Nutmeg's audio output, and the play
  phase (hand-offs, checklist intros, cheers) now costs more than the planning talk.
- **Replays aren't quite free.** The first replay of a saved game costs $0.14, and later replays cost $0.03.
- **The smaller voice model (gpt-realtime-2.1-mini) brings a game down to about $0.65 to $0.70**, but it failed on
  steps and quality (section 5). Don't switch the conversation as it is.
- **At $1.20 a game, both plans lose money when a family uses every game**, and yearly at 33% off loses money sooner.
  See the margin table (section 6) and the recommendations (section 7).

## 1. What was run

| Run | Script | Result |
|---|---|---|
| Game A | 3 players, "pizza restaurant in the jungle", all 3 props found by voice, played to The End (12 checklist turns) | Completed: 46 Realtime responses, 4 Claude calls, 13 images, 19 moderation calls |
| Game B | 5 players, "pet shop for dragons", 4 props with 1 skipped, played to The End (20 checklist turns), saved | Completed: 59 responses, 4 Claude, 15 images, 19 moderation. Saved with 37 recorded clips |
| Replay of B (first) | Shelf → B → "Five of us" → 3 × "found it" → play to The End | 10 responses, 0 Claude, 0 images, 1 moderation. Clip hits 40/46 (87%) |
| Replay of B (second) | Same script | 4 responses, 0 audio out. Clip hits 46/46 (100%) |
| Replay of a seeded demo game (by mistake, shelf slot 0) | Same script; that game has no saved clips | 46 responses: the worst case, where every line is said live |
| Mini Game A | Game A's script with `-PTRealtimeModel gpt-realtime-2.1-mini` | Completed: 54 responses, 5 Claude, 13 images, 25 moderation |
| Guardrail probe, both models | doctor → "real knives and lots of blood" → "What's your favorite video game?" → teddy bear hospital → 2 → yes | Both redirected (section 5) |

Every number in this doc comes from these runs. Image token counts come from the API's `usage` field, Claude's from
`usage`, and Realtime's from `response.done` → `response.usage`.

## 2. Prices used (checked 2026-11-16)

**Anthropic**, from the `claude-api` skill (model table cached 2026-11-03): `claude-opus-5-5` costs $4 input and $20
output per 1M tokens. Cache reads are $0.20. Cache writes are 1.25x input for the 5-minute TTL ($5) and 2x for 1 hour.
For comparison, `claude-sonnet-5-5` costs $2 / $10 and `claude-haiku-5-5` costs $0.10 / $0.50.

**OpenAI**, from the [pricing page](https://developers.openai.com/api/docs/pricing), fetched 2026-11-16, per 1M tokens:

| Model | Text in | Text cached | Text out | Audio in | Audio cached | Audio out |
|---|---|---|---|---|---|---|
| gpt-realtime-2.1 | $4.00 | $0.40 | $24.00 | $32.00 | $0.40 | $64.00 |
| gpt-realtime-2.1-mini | $0.60 | $0.06 | $2.40 | $10.00 | $0.30 | $20.00 |

- gpt-4o-mini-transcribe: $1.25 in / $5.00 out per 1M tokens, which OpenAI estimates at $0.003 per minute.
- gpt-image-2.6-flare (also 2.5-flare and gpt-image-2): text in $5, image in $8, **image out $30** per 1M tokens. The
  page doesn't list per-image prices, so the per-image cost here comes from the measured output tokens.
- omni-moderation-latest: **free**.
- **Unconfirmed:** whether a cached-audio discount applies to kid push-to-talk audio in practice (typed runs have no kid
  audio; see section 4). Also unconfirmed: whether the mini model's coral voice sounds the same as the full model's.
  It wasn't checked by ear.

## 3. Measured cost per new game (full model, gpt-realtime-2.1)

| Service | What | Game A (3 players) | Game B (5 players, 1 skip) |
|---|---|---|---|
| Realtime: text input, uncached | about 10 to 14k tokens (96.4 to 96.7% of input cached) | $0.041 | $0.057 |
| Realtime: text input, cached | 306k / 383k tokens | $0.122 | $0.153 |
| Realtime: text output | silent tool passes, tool arguments, transcripts (2.9k / 3.5k tokens) | $0.070 | $0.084 |
| Realtime: audio output | Nutmeg speaking (5.7k / 7.6k tokens, about 4.8 / 6.3 min) | $0.367 | $0.485 |
| **Realtime total** | 46 / 59 responses | **$0.601** | **$0.778** |
| └ planning (greeting → props → kit) | 23 / 22 responses | $0.25 | $0.26 |
| └ play (hand-offs, checklist intros, cheers, The End) | 23 / 37 responses | $0.35 | $0.52 |
| Claude Opus 5.5 | kit pages (effort medium) + early play guide + prop weave + a small check (all effort low), no cache hits | $0.143 (4 calls, 17.0k in, 3.8k out) | $0.150 (4 calls, 17.2k in, 4.1k out) |
| Images (2.6-flare, quality low) | both print styles (6 pages each) + the cover = 13; the skip added 2 square images | $0.275 (13 × about 664 output tokens, about $0.021 each) | $0.326 (15) |
| Moderation | 19 calls | $0 | $0 |
| Transcription | typed runs, none | $0 | $0 |
| **Total (typed)** | | **$1.02** | **$1.25** |

### New game: typical, low and high

| | Low | Typical | High |
|---|---|---|---|
| What | 2 to 3 players, kids tap ✓ in the hunt, little chatter | 3 to 5 players, 1 skip, about 10 push-to-talk turns | 6 players, 2 skips, a lot of chatter (+10 spoken replies), a theme change that remakes the kit, a reconnect |
| Realtime | $0.55 | $0.72 | $0.95 |
| Kid audio in + transcription (section 4) | $0.01 | $0.02 | $0.08 |
| Claude | $0.14 | $0.15 | $0.27 |
| Images | $0.27 | $0.30 | $0.62 |
| **Total** | **about $0.95** | **about $1.20** | **about $1.90** |

### Replays (measured)

| Replay | Cost | Why |
|---|---|---|
| First replay of a saved game | **$0.14** | The replay's own Pick and hunt lines (4) and 2 lines not recorded on the first play are said live, then saved. The first responses are uncached (the replay session starts cold) |
| Later replays | **$0.03** | Every line plays from saved clips (100%). What's left is 4 silent text-only tool passes for the spoken (typed) Pick and "found it" turns. With taps instead of voice, it's close to $0 |
| A game whose clips are missing (seen on a seeded demo game) | $0.61 | Every line is live: the cost of a new game's voice minus Claude and images |

So replays are nearly free after the first one. Recording the replay-hunt lines during the first play would bring the
first replay to about $0.03 too.

## 4. Typed turns vs real push-to-talk (estimate)

Typed turns enter the conversation as about 5 to 10 text tokens. Real push-to-talk sends kid audio at 10 tokens a
second (1 per 100 ms), and that audio stays in the history.

**Assumption:** a typical game has about 10 kid turns (4 planning, 4 to 6 hunt) of about 3 seconds each, including the
hold before and after a 4-to-8-year-old speaks. That's about 30 audio tokens a turn. The high case is 20 turns of
5 seconds.

- Each new kid clip is billed uncached on about 2 responses (the silent tool pass, then the spoken reply): 10 × 30 × 2 ×
  $32 per 1M = **$0.019**.
- Later responses re-bill it from cache at $0.40 per 1M: about $0.001.
- Transcription: 0.5 min × $0.003 = $0.0015. Moderation is free.
- **Typical: +$0.02 a game. High: +$0.08.** On the mini model (audio in $10, cached $0.30): typical +$0.007.

This is small, because play happens on the checklist with taps, and the planning talk is short. It's included in the
typical, low and high table above.

## 5. The smaller voice model (report only, nothing switched)

`gpt-realtime-2.1-mini` exists on OpenAI's pricing page and connects with the same GA session. The test used
`-PTRealtimeModel` with personal keys (a DEBUG launch argument added for this test). **To ship it, the relay would need
it:** `relay/src/index.ts` pins `REALTIME_MODEL = "gpt-realtime-2.1"` and forces it on every client secret. Also,
`SavedGame.voiceID` includes the model ("coral@gpt-realtime-2.1"), so switching models would change the voice ID on new
clips.

| | gpt-realtime-2.1 (Game A) | gpt-realtime-2.1-mini (same script) |
|---|---|---|
| Realtime cost | $0.601 | **$0.176** (54 responses, 94% cached) |
| Game total | $1.02 | **$0.63** (Claude $0.18 with 5 calls, images $0.28) |
| Correct tool calls | Yes. `show_next_prop` was called twice in a row on 2 of 3 hunt turns (harmless) | Yes, but `show_next_prop` was doubled on 4 of 5 turns |
| Steps followed | All. A twist question after the game choice, the recap, the confirm line, roles, props, the kit | **Skipped the twist question:** after "We want to play restaurant", her reply was empty (2 audio tokens), so a kid would hear nothing. **Skipped the confirm line** ("Great, let me put some plans together!") in the guardrail probe |
| One reply per turn | Yes (the confirm turn gives its 3 designed lines) | **No in the guardrail probe:** the greeting had an extra narration line first ("Let me think about a fun way to start."), then an odd "you can stay comfy where you are" |
| Silent passes stay silent | Yes | The silent pass wrote a spoken sentence once instead of only calling the tool (correctly kept off the speaker) |
| Quality | Sensible roles (Pizza Chef, Hungry Guest, Server) and props (bowl → mixing bowl) | Odd roles ("Chef of the Jungle Oven", "Shopkeeper of the Safari Menu", "Captain of the Clinic"). Prop reasons that make no sense ("a plastic cup ... the jungle pizza pad", "a bowl ... the jungle pizza cushion"). These long names then read badly in every checklist line ("First, chef of the Jungle Oven, chef, put on your badge!") |
| "Pretend that" scene intros | 4 of 4 | 4 of 4 (the lines come from Claude's guide) |
| Guardrails | The knives turn was blocked by the app's local filter before the model (both models), then she redirected well. Off-topic ("favorite video game") went back to the twist question | Same blocking. The off-topic redirect was fine |
| Latency (typed turn → first audio heard) | median 1.5 s, max 3.9 s. Confirm turn 1.5 s | median 2.4 s. **Confirm turn 8.0 s and 7.6 s** (slow tool chain). App lines 0.83 s vs 0.78 s |

**Failures on mini:** an empty reply (a skipped step), a skipped confirm line, an extra narration line, nonsense props and
role names, slow confirm turns, and more duplicate tool calls. Its app lines (fixed text from the app) were fine,
though. That suggests a hybrid: keep the full model for the conversation and use mini only for the fixed app lines in
play (lever 1 below), if the voice sounds the same by ear.

## 6. Margin table

Apple takes 15% (Small Business Program). Yearly prices are shown per month. "Every game" means the family uses its whole
monthly limit. Replays aren't included (about $0.03 each after the first).

| Plan | You keep per month after Apple | Every game, full model ($1.20/game) | Every game, mini ($0.70/game) | Break-even games/month (full / mini) |
|---|---|---|---|---|
| Show Pass monthly, $9.99, 10 shows | **$8.49** | cost $12.00 → **−$3.51** | cost $7.00 → **+$1.49** | 7.1 / 12.1 |
| Show Pass yearly, $79.99 ($6.67/mo) | **$5.67** | cost $12.00 → **−$6.33** | cost $7.00 → **−$1.33** | 4.7 / 8.1 |
| Season Pass monthly, $14.99, up to 30 | **$12.74** | cost $36.00 → **−$23.26** | cost $21.00 → **−$8.26** | 10.6 / 18.2 |
| Season Pass yearly, $119.99 ($10.00/mo) | **$8.50** | cost $36.00 → **−$27.50** | cost $21.00 → **−$12.50** | 7.1 / 12.1 |

Free Preview: 2 shows cost about $2.40 per family that tries it (about $1.40 on mini).

For Season Pass at 30 a month to break even when fully used, a game has to cost $0.42 (monthly) or $0.28 (yearly).

## 7. Recommendations

1. **Game limits.**
   - **If it ships at today's cost ($1.20):** Show Pass **6 new shows a month** ($7.20 when fully used, under the $8.49
     you keep) and Season Pass **10 a month** ($12.00, under $12.74).
   - **After levers 1 to 3 below (about $0.60 to $0.70 a game):** Show Pass **10** and Season Pass **20**.
   - **Don't promise 30** unless a game gets under about $0.42.
   - Most families won't use every game, but these limits keep a maxed-out family from losing money.
2. **Default billing period: monthly.** Monthly keeps 1.5x more per month than yearly ($8.49 vs $5.67 on Show Pass), and
   it lets prices follow the real cost while it's still moving.
3. **Yearly at 33% off isn't safe yet.** A yearly Show Pass family loses money after 4.7 games a month (8.1 on mini).
   Offer yearly at about 17% off ("2 months free": $99.99 and $149.99) until a game costs about $0.55 or less. At that
   cost, 33%-off yearly Show Pass breaks even at 10.3 games.
4. **Top remaining cost levers**, by savings on a typical game:
   1. **Play-phase app lines ($0.35 to $0.52, and it grows with players).** These are fixed text the app sends
      (`sayExactly`), so they don't need the big model's reasoning. Options: say them with gpt-realtime-2.1-mini (about
      $0.12 to $0.16 instead; saves about $0.25 to $0.35, but **the voice must sound identical, so check by ear**, since
      Haylee's rule is that her voice never changes; the relay would need the mini model), bundle the fixed parts
      (cheers, "Tap the green check when you have the iPad!"), and shorten the hand-off lines.
   2. **Draw only the print style the family picks** (or draw color first and outline only when asked): saves about 6
      images, **about $0.13**. Using the sign art as the cover saves $0.02 more.
   3. **Claude: 4 calls now ($0.15), not 1 ($0.09 estimated).** Move the play guide, prop weave and check to Sonnet 5.5
      (half price) or Haiku 5.5 for the small calls. Saves **$0.05 to $0.10**. Caching the shared system prompt across
      the 4 calls would save only about $0.01.
   4. **First replay:** record the replay Pick and hunt lines during the first play, which takes the first replay from
      $0.14 to about $0.03.
   5. **Switching the whole conversation to mini** saves about $0.45 more, but not until the failures in section 5 are
      fixed (prompt changes, then retest).

   Levers 1 to 3 together put a typical game at about **$0.65 to $0.70**. Adding the hybrid voice model gets it close to the
   $0.40 target in paid-app-direction.md.

## 8. Logging added (kept, DEBUG only, counts only)

- `[CLAUDE] usage detail`: effort, cache read/write tokens and model id, next to the existing in/out line.
- `[IMAGE] usage`: one line per image (model, size, quality, background, input text/image tokens, output tokens).
- `RealtimeUsage.line` now includes the output text/audio split.
- Driver turn `#cost`: AI call counts and token totals so far.
- `-PTRealtimeModel <id>`: try another Realtime model in DEBUG live tests (personal keys only; the relay pins its own).

Nothing logs prompts, transcripts, images or anything about kids.
