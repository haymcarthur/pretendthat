# Paid-app direction (talked through, not built yet)

**Date:** 2026-11-15 · **Who decided:** Haylee (Claude's suggestions noted)

- **Platform:** iPad only to start. Consider Android later only if it would clearly make a difference.
- **Saved games:** on the device, synced through the family's own iCloud (CloudKit private database). No accounts and no backend database. What's stored is game content, never anything about kids.
- **Replays keep Nutmeg's real voice:** NEVER the free system voices, and her voice never changes between plays. Claude's suggestion: record her scripted lines on the first play and replay those recordings, using the live voice only for new interaction.
- **Players capped at 6** (replaces "any number, one holds the iPad"). The badges page has exactly one badge per player/role, not always 6. (Known bug to fix: 2–3 players still get 6 badges.)
- **Money is a single $1 bill page.** Kids print more copies for more money. Menu prices should be small whole dollars to match.
- **Open:** the replay flow and UI, changing the player count on replay, and clearer navigation back to earlier steps (for example reprinting). See the conversation recap in the next round brief.

## Replay decisions (Haylee, 2026-11-15)
- **Generate for 6 every time, with ranked roles:** roles 1–2 are the core and 3–6 are extras. Badges are drawn as one 6-up sheet and sliced; checklist steps for extra roles are optional and only show when that role is playing. A replay with a different count (1–6) needs no AI calls. The only exception is a voice line for a role that wasn't present the first time; it's said live once in the same voice and then saved.
- **Save at The End instead of "Play again":** a "Save it to play again ⭐" button. Unsaved games are discarded when they leave.
- **No shelf cap.**
- **Grown-up delete:** a grown-up-gated delete on the saved-game shelf (for example a long press plus a confirm).

## Pricing (Haylee, 2026-11-15)
- **Pro:** $9.99/mo or $79.99/yr, **10 new games a month**, unlimited replays.
- **Unlimited:** $14.99/mo or $119.99/yr, with a large fair-use cap on new games (Claude suggests 30/mo, about one a day; to be confirmed after re-measuring the cost per game).
- Margins depend on getting the cost per new game to about $0.40 (see the conversation and research/2026-11-15-cost-per-game.md). No-printer games skip images, so they cost less.
