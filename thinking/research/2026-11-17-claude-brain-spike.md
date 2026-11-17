# Claude brain spike: Claude decides, the mini voice reads (2026-11-17)

Decision that started it: [decisions/2026-11-17-claude-brain-spike.md](../decisions/2026-11-17-claude-brain-spike.md)
(Haylee: do the spike, 1–2 games). Built and measured by a background agent (Claude) in its own worktree, simulator
PT-R15 only, personal keys copied in for the test and deleted after. Listen: [design/claude-brain-spike/index.html](../../design/claude-brain-spike/index.html).

**Bottom line**

- **Cost works:** her talking part (the brain plus every spoken line) cost **$0.18 a game** ($0.21 with a cold prompt cache),
  against about **$0.53** today. A whole game would be about **$0.70** instead of $1.03.
- **Speed doesn't:** after a kid's turn she starts talking after about **5.4 s** (range 3.0–7.3 s), against about
  **1.2 s** today. That's 4 extra seconds of silence on every planning answer. Kids ages 4–8 won't wait that long.
- **Quality is fine, with one scary miss:** Claude followed the steps, called the right tools, stayed short and kind,
  and handled "I don't know" and an off-topic question well. But the mini voice once **read a made-up greeting instead
  of the sentence it was given** (1 of 34 lines).
- **Recommendation:** don't build this as is. The mini-for-app-lines change (already flagged, approved by ear) keeps
  most of the voice savings that don't cost speed. If we want the brain savings too, the redesign below (one Claude call
  per turn) is the only version that could get near today's speed; it's worth a second spike only if cost matters more
  than about 2–3 extra seconds.

## 1. What was built (throwaway, DEBUG only)

- Flag: **`-PTClaudeBrain YES`** (launch argument; `CostFlags.isOn("PTClaudeBrain")`), **default off**, and the code
  only exists in DEBUG builds. With the flag off, nothing changes: the only edits to the normal path are that
  `RealtimeSocket` is no longer `final` and its network task is optional (for a local stand-in socket).
- `PretendThat/Voice/ClaudeBrainSocket.swift`: a stand-in for the Realtime **conversation** socket. `RealtimeSession`
  runs unchanged (step rules, tool-first passes, writing beat, prop lines, the turn check, barge-in): the socket takes
  the Realtime client events in and answers with Realtime server events.
  - Kid turns, the app's silent notes and tool outputs become Claude messages (notes as `[Silent app note…]` text;
    the history is append-only).
  - `response.create` runs **Claude Sonnet 5.5** (`claude-sonnet-5-5`, streaming, `thinking: between_tools`,
    effort low, `fallbacks: default`), with the **same 16.4k-char instructions** plus a short "text mode" addendum
    (`ClaudeBrainSpike.addendum`) and the **same 19 tools**. System + tools and the growing conversation are
    **prompt-cached**.
  - Tool calls come back as Realtime function-call events, so the app applies them exactly as today.
  - Her words are cut into sentences as they stream (`SentenceChunker`); each sentence goes to a
    **gpt-realtime-2.1-mini** session (the identical session.update: coral, server speed 1.0, same instructions)
    as an out-of-band `sayExactly`. Its audio is forwarded as the reply's audio, so it plays through
    `NutmegSpeaker` at **Varispeed 1.20** with lip sync, exactly like today.
  - The app's own fixed lines (scene openings, prop lines, kit line…) go straight to the same mini session.
- Reused the app's Claude path: the same `ClaudeConfig` (personal key in dev, or the relay's `/v1/messages`), the same
  API version and fallback beta. (The relay would need `claude-sonnet-5-5` on its allow-list and streaming support:
  not tested; the spike ran on personal keys.)
- Logs are counts and timings only (`[BRAIN] CLAUDE usage`, `MINI usage`, `TURN … marks`); her words only print in
  `-PTLive` tests, as before.
- Tests: `ClaudeBrainSpikeTests` (sentence cutting, tool conversion, flag off by default). NutmegCore `swift test`
  passes (512 tests); the app builds.

## 2. Latency: kid's turn sent → first sound heard

Today's numbers are from existing logs (no game spent on them): `/tmp/pt-cost3/game{A,B,D}` and the current build's
`/tmp/pt-round36/g1,g2`, `/tmp/pt-analytics`, `/tmp/pt-iphone/live-large` (typed turns, `LAT … heard`).

| Turn | Today (gpt-realtime-2.1) | Spike (Claude + mini) |
|---|---|---|
| Game pick (set_game) | 1.3–1.8 s | 4.8 s (smoke run 3.6 s) |
| "I don't know" (just_talk) | ~1.2 s | 5.5 s (smoke run 3.0 s) |
| Theme (set_theme) | 1.1–1.5 s | 7.3 s (the mini misread here, see §4) |
| Player count | 1.0–1.5 s | 4.9 s |
| Off-topic "Do mice like cheese?" | ~1.2 s | 6.0 s |
| Yes to the recap (confirm → roles) | 1.1–1.4 s | 5.4 s |
| "I can't find it" (swap_prop) | ~2.3 s | 5.2 s |
| "found it" (mark_found + next prop) | 12.2–14.3 s, **~2.3 s without the app's 10 s pause** | 14.7–17.4 s, **4.1–6.8 s without it** |
| Last prop (finish_planning → kit line) | 1.4–2.1 s | 3.2 s |
| **Median, planning answers** | **~1.2 s** | **5.4 s** (5.2 s with the 2 smoke turns) |

Where the spike's time goes (per planning turn, from the `TURN` marks):

| Step | Time |
|---|---|
| Claude call 1: the tool-first pass (picks the tool; tiny output) | 1.9–2.9 s (1.0–1.1 s in the smoke run) |
| Claude call 2: her reply after the tool result | 1.8–2.5 s (1.15–1.3 s in the smoke run) |
| Mini: first sentence sent → first audio | 0.6–1.1 s (2.1 s on the misread) |

- Claude's replies are short (30–60 tokens), so the whole reply lands at once; streaming barely helps. The wait is
  **Claude's time to first token, twice per turn** (about 1–2.7 s each with a 11–17k-token cached prompt; it was
  faster in the smoke run, so it varies with load).
- Every step that changes the game is two Claude calls (tool, then words after the tool result), same as today's
  two Realtime responses, but a Realtime response starts in ~0.15 s and Claude's in ~1–2.5 s.
- **Found by accident (today's build, not the spike):** on a typed "found it" the app's prop line waits ~10–11 s
  before it plays (`sayAppPropLine` waits up to 10 s while `isBusy`; after a tool-first pass with no spoken follow-up,
  `awaitingReply` stays true). It shows in every recent log (round 36, analytics, iPhone runs). Taps on the card
  don't go through this path. Worth its own fix; see Open below.

## 3. Cost per game (count-only usage logs)

Measured game: 3 players, "pizza restaurant in the jungle", "I don't know" + an off-topic question, 5 props with one
swap, kit, 5 scenes to The End (fake art, so no image calls). 23 Claude brain calls, 21 mini reply sentences,
13 mini app lines.

| Part | Today (v3, $0.97–1.09 game) | Spike (this game) |
|---|---|---|
| Deciding what she says | Realtime conversation $0.31 | Claude Sonnet 5.5 **$0.072** (in 74, cache read 309k, cache write 7.1k, out 2.3k); **$0.098** if the prompt cache is cold (first call writes ~11k tokens) |
| Her replies spoken | (in the $0.31 above) | Mini **$0.049** (21 sentences: 1,547 audio tokens out; ~6.9k cached text in each) |
| App lines (scenes, prop lines, kit, The End) | Full model $0.18–0.25 (mini flag: ~$0.04 for 6 lines) | Mini **$0.059** (13 lines, 2,385 audio tokens; all 13 kept as clips = said exactly) |
| **Voice + brain** | **~$0.53** | **$0.18 warm / $0.21 cold** |
| Claude kit, guide, weaves (Opus, unchanged) | ~$0.20 | $0.224 measured (6 calls) |
| Images | $0.28–0.33 | not run (fake art); same as today |
| **Whole game** | **~$1.03** | **~$0.70** (~$0.60 with v3's Sonnet guide/weave flag) |

Prices: Sonnet 5.5 $2 in, $2.50 cache write, $0.10 cache read, $10 out per 1M; mini $0.60 text in, $0.06 cached,
$2.40 text out, $20 audio out per 1M (v3's table). The prompt cache is shared by every game with the same
instructions, so in real use it's mostly warm.

Against the v3 "both flags" build ($0.78), the brain saves another ~$0.10–0.13 a game. Most of today's voice saving
comes from the mini model saying the words, which the already-approved mini-lines change partly gets.

## 4. Quality

- **Game flow: followed.** set_game → theme ideas from the tool result → set_theme → count → word-for-word recap →
  confirm_plan → start_planning (writing beat) → set_roles → show_next_prop → roles announced → app prop line.
  Hunt: mark_found + show_next_prop in one pass each time; "I can't find it" → swap_prop (hat → scarf); last prop →
  finish_planning. Right tools every turn; no off-step tool refused.
- **"I don't know":** just_talk, then "That's okay, it's tricky to pick! Should our restaurant be back in time, on a
  snowy mountain, or in the jungle?" (same ideas, kind).
- **Off-topic:** "Do mice like cheese?" → just_talk, "Ha, mice love cheese, especially on pizza!" then the recap
  again. Good.
- **Short and kid-friendly:** 1–3 short sentences, no emoji or stage directions, no narration except one: after the
  "yes" she said "Great, let me put some plans together!" before the writing beat (the rules frown on narration).
  One extra show_next_prop in a spoken follow-up (also seen today).
- **The mini didn't read exactly once (1 of 21 reply sentences; 0 of 13 app lines):** given "Ooh, pizza in the
  jungle, with monkeys and parrots!", it said a made-up greeting instead ("Hi there! I'm Nutmeg, your party plan
  buddy… Maybe a moon bakery, a space zoo, or a treasure ship?"). Kids heard a wrong line with different game ideas.
  Cause, likely: the mini session carries the full conversation instructions; short, exclamation-only sentences give
  it room to improvise. All other 33 lines matched.
- **Sound:** sentence-by-sentence reading means each sentence is its own take; listen in the page for seams between
  sentences (not checked by ear by the agent).

## 5. What a real build would take

1. **One Claude call per turn, not two** (the only way near today's speed): give Claude what the tool results say
   (theme ideas, count limits, recap wording, prop list rules) up front in the notes, let it call the tool AND write
   its words in the same response, and have the app check the tool afterwards (refuse/redo only on a bad call). The
   tool-first pass goes away. Expect ~1.5–2.5 s + mini ~0.7 s ≈ 2.2–3.2 s. Still slower than 1.2 s.
2. A faster model for the brain (Haiku 5.5: v3 found it breaks formats) or fast mode (Opus 5.5 only, 2× price) to cut
   time to first token; would need its own quality check.
3. Make the mini read safely: tiny dedicated "read exactly" instructions and no tools for the reading session, check
   the transcript, and re-say or fall back on a mismatch.
4. Relay: allow `claude-sonnet-5-5`, pass the stream through, count it toward the show ticket; mint mini secrets
   (round 35 prep already added that).
5. Barge-in: today a mic press cancels one Realtime response; here it must cancel the Claude stream, the queued
   sentences and the playing mini response, and record in Claude's history what she actually got out (the spike only
   keeps the partial text, it doesn't cut at what was heard). Not tested live.
6. Reconnect after lock/background (round 9) for both the Claude history and the mini socket; replay clips' voice ID.
7. Safety: today's output checks run on her transcript; they'd need to run on Claude's text before it's spoken.

## 6. Risks

- **Wait time** is the deal-breaker: 4+ seconds of silence after every answer (the thinking face helps, but not that much).
- **Wrong words out loud** if the mini improvises (seen once).
- **Barge-in and the history** get harder (two services, sentence queue).
- **Two vendors on every turn**: an Anthropic slowdown now stalls the conversation itself, not just the kit.
- Seams between sentences in her voice.

## Open

- Haylee: listen to `design/claude-brain-spike/index.html` (the silences are the real waits). Keep going with a
  one-call redesign spike, or drop it?
- The ~10 s pause before the next prop line after a typed/spoken "found it" in today's build (see §2): fix it?
  (Not touched here.)

## Test log

- Smoke run (2 turns, then stopped) + 1 full game on PT-R15 = within the 2-game limit. Logs (local, not committed):
  the agent's scratchpad `smoke/` and `game1/console.log`. Secrets.xcconfig copied in for the runs, deleted after, and
  the app rebuilt without keys (checked: no key in the built Info.plist); the test app was uninstalled from PT-R15.
