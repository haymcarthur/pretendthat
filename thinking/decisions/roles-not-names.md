# Roles, not names

- **Date:** 2026-11-13
- **Decided by:** Haylee
- **Supersedes:** [names tokenized](names-tokenized.md), [players and Director mode](players-and-director-mode.md); updates [tablet hand-off](tablet-handoff.md) and the kit recipe's badges.

## Decision
- **No kids' names anywhere.** Nutmeg never asks for names. Planning is purely conversational and covers only (1) what game, (2) the theme/twist ("a pancake restaurant on the moon"), (3) how many kids. She can riff and react, but needs nothing else before props.
- **The number of kids decides the roles.** Nutmeg (Realtime `set_player_count`, then `set_roles`) proposes exactly N roles that fit the game and theme (3 → Captain, Flight Attendant, Passenger). Kids don't pick or claim roles in the app: no "find your role", no swap, no name capture.
- **5+ kids:** Director mode is dropped (it only existed because names didn't scale). Up to 8 kids; at most 4 distinct roles (R1–R4, which also give the role colors) with a `count` so the roles add up to N, e.g. 2 Passengers.
- **Badges:** one per kid, grouped by role, printed with the ROLE TITLE and a blank "Name: ________" line kids write on themselves. Kids pick their badge after printing. Same shared role-neutral badge art; the app overlays the text (no name).
- **Tickets and passes** print a blank name line instead of a name. **Hand-offs** say "Pass the tablet to the Captain!" with the role title and role color. Scene ownership is by role; checklists are per role.
- `{P1}` name tokens and the substitution code (`NameTokens`) are removed; role IDs `R1`…`R4` replace them in the Claude plan/kit/scene schemas.
- **Privacy wording:** "We never ask for kids' names."

### Addition (Haylee, same day): no role or idea cards
- During planning the ONLY cards on the stage are the **prop cards** (household-prop library art). There is no role art, so there are no role cards: Nutmeg decides and mentions the N roles in conversation, and they still drive the badges, tickets, hand-offs and checklists.
- No game-idea cards either (they used generated stickers): Nutmeg suggests games by voice; the chat panel shows them as text. The step rail stays.

## Why
Names were the one piece of personal data the app touched; asking for them slowed planning and made 5+ kids awkward. Roles are what the game needs, and kids writing their own names on paper is part of the fun.

## Implementation notes (Claude)
- `RoleCast.normalize` merges same titles, caps 4 distinct roles and makes counts add up to the kids (the last role takes extras). The bundled airplane game moves Passenger last when there are more than 4 kids, so extras become Passengers.
- Tap fallback screen: count picker 1–6+, then "Pick our jobs!" shows role badges (title only), then props.
