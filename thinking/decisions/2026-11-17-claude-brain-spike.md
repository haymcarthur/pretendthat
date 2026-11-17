# Spike: Claude decides what Nutmeg says, the mini voice reads it

- **Date:** 2026-11-17
- **Decision:** build a throwaway spike behind a default-off flag: the kid's words (on-device speech to text) go to Claude (Sonnet 5.5), which writes Nutmeg's reply and makes the game moves (tool calls); the Realtime mini model only reads the reply word for word, as coral at 1.20 through NutmegSpeaker. Measure on 1–2 live games: time to her first audio, cost per game, quality.
- **Why:** voice is the biggest part of a game's OpenAI cost (about $0.53). Estimated voice cost with this setup is $0.15–0.25 a game, with replies written by the stronger model. The risk is a slower first word (estimate 1.5–2.5 s vs about 0.8 s today).
- **Who decided:** Haylee (do the spike, 1–2 games); the design is Claude's suggestion.

## Result (2026-11-17): dropped
- The spike measured about 5.4 s before she answers (vs about 1.2 s today), at $0.18 a game for brain + voice (vs about $0.53). Haylee: drop the spike. The branch and worktree are deleted; the results stay in research/2026-11-17-claude-brain-spike.md and design/claude-brain-spike/.
- The spike found a real bug: after a spoken or typed "found it", the next prop line waits about 10 s. Haylee: fix it (queued in queue-next-app-round.md).
