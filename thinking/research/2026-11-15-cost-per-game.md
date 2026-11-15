# Cost per game (AI credits), 2026-11-15

Haylee asked: "can you do some investigation on how much credits we are using for each run within this app?"
Read-only research by a background agent (Claude). Nothing in the app was changed or run.

**Bottom line:** one typical game costs about **$1.60** (range **$0.75 to $4.30**). About 95% of that is OpenAI:
Realtime voice (about $0.96) and the kit images (about $0.55). Claude is about $0.09. **OpenAI's $10 runs out first,
after about 6 or 7 typical games** (2 to 14 across the range). Anthropic's $10 lasts about 110 games.

Confidence: **medium-low overall.** The call counts come from code and real logs. The token counts are estimates,
because no log records API `usage` fields. The biggest unknown is how much of the Realtime context gets a cache hit
(it moves the Realtime cost by about 3x).

## 1. What one typical game calls

The game assumed here: 3 players, 4 props with 1 skip, the full kit, about 3 scenes played, voice (Realtime) path.

### Claude (`claude-opus-5-5`): 1 call, sometimes 2

In the voice path, ideas, roles and props come from the Realtime model's tools (`AdventureStore.apply`), not from
Claude. Claude is called only for:

| Call | When | Per game |
|---|---|---|
| `kit` (items + 4 to 6 scenes), effort medium | `finish_planning` → `makeKit()` | 1, plus a retry when `Validate.kit` fails (assume 15%), plus 1 more if the theme is corrected after planning (`lateCorrection` remakes the kit) |
| `help` (one idea during play), effort low | "Help" during a scene | 0 to 2 (assume 0.5) |
| `ideas`, `plan`, `props`, `turn` | tap fallback only (no Realtime key or it can't connect) | 0 in the voice path; 4 or more in the tap path |

Estimated kit call size (characters / 4, then about 1.1x for the Opus tokenizer):

- Input: about **3,300 tokens**, made of the system prompt (`Prompts.system`, 3,320 characters, about 850 tokens), the
  kit prompt with the recipe and the context JSON (about 800 tokens), and the strict JSON schema
  (`Schemas.kit()`, about 1,100 tokens, mostly the picture-id enum of about 65 ids, used twice).
- Output: about **3,000 tokens** (range 2,000 to 6,000). That's the kit JSON (about 1,500 to 2,200 tokens for
  6 items and 5 scenes of 4 steps) plus adaptive thinking at medium effort. `max_tokens` is 16,000. Live kit calls
  took 15 to 25 seconds (comment in `ClaudeClient.swift`), which fits that range.
- **No prompt caching:** `ClaudeClient` sends no `cache_control`. With one call per game, caching wouldn't help much
  anyway: a cache entry lives 5 minutes, and games are further apart than that.

### Images (`gpt-image-2.6-flare`, falling back to 2.5-flare and gpt-image-2): 11 to 13 per game

From `KitArtService.runMissingJobs` and `KitArtPrompt.size`, all at **medium** quality, PNG:

| Item | Images | Size |
|---|---|---|
| badges, sign, menu | 3 | 1024x1536 |
| money, tickets | 2 | 1536x1024 |
| cutouts (one image per cut-out, 6 to 8) | 6 to 8 (typically 7) | 1024x1024 |

That's **12 images in a typical game.** Prompt text is about 200 tokens per image. Stickers
(`ItemArtService`, low quality, transparent background) are drawn only for off-list props, which is about 0 per game,
since library props have hand-drawn art. A theme correction while the kit is being made, or on the print screen,
redraws all 12. A network failure retries only the pages that are missing.

### Realtime (`gpt-realtime-2.1`, push-to-talk, audio out): about 30 full responses and 20 fixed lines

How it bills: every `response.create` re-bills the **whole conversation** as input, meaning the instructions, the tools,
and all earlier audio and text items. OpenAI caches it automatically, best effort. User audio is 10 tokens per
second; assistant audio is 20 tokens per second. Assistant audio stays in the history as audio tokens.

Static prefix sent with every full response:

- Session instructions (`Realtime.instructions`, 12,972 characters): about **3,000 text tokens**, plus about 120 for
  today's game ideas.
- 17 tool definitions (the prop-id enum of 30 ids appears 3 times): about **1,700 tokens**.
- Total: about **4,800 text tokens** before any conversation.

Counts measured from live logs (`/tmp/pt-round15/live1`, `/tmp/pt-round16/live1`, `/tmp/pt-round13/run1-3`, which are
1-kid scripted runs with 3 props and 2 scenes):

| Log | Responses created | Silent text-only passes | sayExactly (app lines) | Nutmeg lines (words) | Heard audio |
|---|---|---|---|---|---|
| round 15 live1 | 25 | 6 | 8 | 17 (274) | 97 s |
| round 16 live1 | 25 | 6 | 9 | 17 (314) | 115 s |
| round 13 run3 | 25 | 6 | 9 | 17 (268) | n/a |
| round 13, Haylee's real session (90 min, 5 restarts, 3 reconnects) | 124 | 23 | 0 | 58 plays | 435 s |

Scaled up to the typical game (more kids, 4 props, a skip, the round 19 recap, some chatter, 3 scenes):

| Kind | Typical count | What it costs |
|---|---|---|
| Spoken full responses (greeting, game, theme, recap, confirm, roles, prop asks, chatter, play replies) | about 15 | full context in, about 6.5 s of audio out each |
| Silent text-only tool passes (`responseCreate(requiring:)`) | about 10 | full context in, about 40 text tokens out, no audio |
| Tool-chain responses with no speech (`set_roles` → `show_next_prop`, etc.) | about 5 | full context in, small text out |
| `sayExactly` lines (kit progress, kit ready, scene intros, hand-offs, checklist cheers, repeats, finale) | about 20 | about 150 text tokens in (out-of-band, `input: []`, so no history), about 3.5 s of audio out |
| Kid push-to-talk turns | about 14 × 3 s | audio in (enters the history) + transcription |
| Transcription (`gpt-4o-mini-transcribe`) | about 0.7 min | about $0.003 per minute |

The history grows to about 2,800 text tokens and about 2,400 audio tokens by the end, so the last responses cost
about twice the first ($0.019 → $0.041 each at the typical cache rate).

**Cache hit rate is the big unknown.** The app sends a *different `tools` array* on almost every response. Silent
passes send a per-step subset; spoken responses send every tool except `set_expression`. Tools sit at the start of the
prompt, so each change can break the cache for everything after it. The model assumes 60% of the non-instruction
input is cached in a typical game (85% low, 30% high).

## 2. What's measured vs estimated

| Item | Status |
|---|---|
| Which calls happen, and when | **Measured** from the code paths, and confirmed by the live logs (response counts, silent passes, app lines) |
| Response counts per game | **Measured** for 1-kid scripted runs (25); **estimated** for the typical 3-kid game (30 + 20) |
| Nutmeg audio length | **Measured** as heard playback (about 6 to 7 s per line, about 2.7 words per second); API audio seconds are estimated from it |
| Realtime tokens and cache hits | **Estimated.** The app never logs `response.done` usage (`responseDone` is logged as a bare marker) |
| Claude tokens | **Estimated** from prompt and schema sizes. No `usage` is logged |
| Image count, size and quality | **Measured** from the code. Per-image price is **estimated** (see below) |

**Measure it for real:** in DEBUG, log `response.done.response.usage` (`input_token_details.cached_tokens`,
text and audio splits), Claude's `usage` (input, output, cache read), and the image `usage.output_tokens`. Then play one
full 3-kid game. That turns every estimate here into a measured number.

## 3. Prices (checked 2026-11-15)

**Anthropic** (from the `claude-api` skill's model table, cached 2026-11-03): `claude-opus-5-5` costs **$4 / $20** per
1M input/output tokens. Cache reads are $0.20, and 5-minute cache writes are 1.25x input. For comparison,
`claude-sonnet-5-5` is $2 / $10 and `claude-haiku-5-5` is $0.10 / $0.50.

**OpenAI** ([pricing page](https://developers.openai.com/api/docs/pricing), checked 2026-11-15), per 1M tokens:

| Model | Text in | Text cached | Text out | Audio in | Audio cached | Audio out |
|---|---|---|---|---|---|---|
| gpt-realtime-2.1 | $4.00 | $0.40 | $24.00 | $32.00 | $0.40 | $64.00 |
| gpt-realtime-2.1-mini | $0.60 | $0.06 | $2.40 | $10.00 | $0.30 | $20.00 |

- gpt-4o-mini-transcribe: $1.25 in / $5.00 out per 1M tokens, which OpenAI estimates at **$0.003 per minute** (same page).
- Image models: gpt-image-2.6-flare, 2.5-flare and gpt-image-2 all list image output at **$30 per 1M tokens**, text
  input at $5 per 1M, and image input at $8 per 1M
  ([pricing page](https://developers.openai.com/api/docs/pricing),
  [gpt-image-2.6-flare model page](https://developers.openai.com/api/docs/models/gpt-image-2.6-flare)).
- **The per-image price for 2.6-flare is not published.** The
  [image generation guide](https://developers.openai.com/api/docs/guides/image-generation) lists gpt-image-2 per image
  as: medium $0.053 (1024x1024) and $0.041 (1024x1536 or 1536x1024); low $0.005 to $0.006; high $0.165 to $0.211.
  Third-party measurements put 2.6-flare medium 1024x1024 at about 1,449 output tokens, or about $0.043. This doc uses
  **$0.035 to $0.055 per medium image, $0.045 typical.** Unconfirmed.
- Realtime token rules: the [Realtime costs guide](https://developers.openai.com/api/docs/guides/realtime-costs)
  covers the whole conversation being re-billed on each response, automatic best-effort caching, and audio at
  1 token per 100 ms (user) or per 50 ms (assistant).

## 4. Cost per game

| Service | Step | Low | Typical | High |
|---|---|---|---|---|
| OpenAI Realtime | Planning talk (greeting → game → theme → count → recap → roles), about 15 responses | $0.10 | $0.29 | $0.95 |
| OpenAI Realtime | Prop hunt (4 props, 1 skip, silent pass + spoken line each), about 12 responses | $0.12 | $0.42 | $1.60 |
| OpenAI Realtime | Kit wait + print + play (about 20 sayExactly lines + about 3 spoken replies) | $0.09 | $0.25 | $0.72 |
| OpenAI transcription | about 0.7 min of kid audio | $0.001 | $0.002 | $0.004 |
| **OpenAI Realtime total** | | **$0.31** | **$0.96** | **$3.27** |
| OpenAI Images | 5 item pages + 6 to 8 cut-outs, medium | $0.39 | $0.55 | $0.72 (×2 with a kit remake) |
| **OpenAI total** | | **$0.70** | **$1.51** | **$4.00** |
| Anthropic | Kit call (+15% retry), Opus 5.5 | $0.05 | $0.08 | $0.20 |
| Anthropic | Help during play | $0 | $0.01 | $0.05 |
| **Anthropic total** | | **$0.05** | **$0.09** | **$0.25** |
| **Total per game** | | **about $0.75** | **about $1.60** | **about $4.25** |

The typical Realtime cost breaks down as: audio input (re-billed history) $0.46, text input $0.25, audio output $0.21
(sayExactly lines are $0.09 of that), text output $0.03.

Restarted or abandoned sessions (Haylee's real session had 5 restarts in 90 minutes) add about $0.02 to $0.05 each.
So do reconnects after a lock, since the first response after one is uncached.

### Games per $20 a month ($10 OpenAI + $10 Anthropic)

| | Low-cost game | Typical | High-cost game |
|---|---|---|---|
| Games per $10 of OpenAI | 14 | **6 to 7** | 2 to 3 |
| Games per $10 of Anthropic | 200 | about 110 | 40 |

**OpenAI runs out first, by more than 10x.** The Anthropic budget is not the limit.

## 5. Biggest levers, ranked by savings on a typical game

1. **Realtime caching: send the same `tools` array on every response (saves about $0.45, about 30% of the game).**
   Today, silent passes send a per-step tool subset and spoken responses drop `set_expression`, so the prompt changes
   near its start on most responses. Keep one fixed list (the session tools), and steer with `tool_choice` and the
   instructions instead. That should raise cached input from about 60% to about 90%, which takes Realtime from
   $0.96 to about $0.52. Risk: the model may call a tool that's off-step more often, which `apply()` already rejects
   politely. Measure it with `cached_tokens` first.
2. **`gpt-realtime-2.1-mini` (saves about $0.70, about 45%).** Realtime drops to about $0.26 (about $0.14 with lever 1).
   Risk: weaker instruction following and tool calling, which this app depends on heavily (tool-first turns, the recap,
   the prop hunt). Run the scripted live runs on it before switching.
3. **Images: low quality or fewer images (saves $0.30 to $0.48).** The pages are black-and-white line art for coloring,
   so low quality (about $0.006 per image, about $0.07 a game) may be good enough; check a printed page. Or draw the
   6 to 8 cut-outs as one image instead of one each, which saves about $0.29. The trade-off is that cut-outs can no
   longer be checklist pictures (checklist-pictures.md).
4. **Fewer silent passes and a shorter history (saves about $0.15 to $0.25).** Each silent pass re-bills the full
   context. Removing about 10 of them takes Realtime from $0.96 to about $0.71. Trimming old audio items
   (`conversation.item.delete`, or `truncation` with `retention_ratio` 0.8) lowers the audio-input re-billing, the
   biggest single line. Shorter Nutmeg lines (4.5 s instead of 6.5 s) save about $0.17.
5. **Claude model or effort (saves about $0.04 to $0.08, but on the budget that isn't the limit).** Sonnet 5.5 halves
   the kit call, to about $0.04. Haiku 5.5 makes it about $0.003. Effort `low` cuts the thinking tokens. Prompt
   caching doesn't help with one call per game. Only worth doing for speed or quality, not cost.

Smaller levers: shortening the instructions saves only about $0.03, because they're mostly cached at $0.40 per 1M.
Pre-recording the fixed sayExactly lines (cheers, kit progress lines) as local audio would save part of the $0.09.

Levers 1 and 3 together put a typical game at about **$0.65**, or about 15 games per $10 of OpenAI. Adding mini makes
it about **$0.25 to $0.30**, or about 35 games.

## 6. How the round 20 plan changes this

- **Making the kit during the prop hunt:** cost-neutral if the kit call starts once and ignores later prop changes.
  If a prop swap or skip after the kit starts triggers a remake, each remake adds about $0.08 (Claude). It adds about
  $0.55 more if the images have already started and must be redrawn. Suggestion: start the Claude kit call early, but
  start the images only after `finish_planning`. Or only remake the call when a changed prop is actually used in the
  kit. The Realtime cost doesn't change, except that the kit-wait sayExactly lines may shrink, which saves a few cents.
- **Optional full-color pages:**
  - If color *replaces* line art at the same size and quality, the cost per image is about the same, since output
    tokens depend on size and quality, not on content.
  - If color is a *second* set on top of line art, add about $0.55 per game when chosen (+35%).
  - If color needs **high** quality to look good, it's about $0.17 to $0.21 per image, or about $2.20 per game for 12
    images. That alone would cost more than everything else in the game combined.
  - Suggestion: keep color at medium, color only the item pages (5 images, about $0.23) and not the cut-outs, and make
    it opt-in per game.
