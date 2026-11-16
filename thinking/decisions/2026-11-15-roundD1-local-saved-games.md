# Round D1: local saved games, My games bookshelf, replays (live voice)

**Date:** 2026-11-15 · **Decided by:** Haylee (the design, her answers in §10 and the My games UI in §11, the approved
mockup). Details are Claude's calls, noted. Design: [saved games + replay design §D, §10, §11](../../docs/superpowers/specs/2026-11-15-saved-games-replay-design.md).

## Haylee's decisions (built)
- **"Save it to play again ⭐" at The End** replaces "Play again". An unsaved game is thrown away when they leave
  (New game, the X, Leave). Once saved (and on a replay) the button is **"Play it again"**.
- **Saved on this iPad only** for now (Application Support/SavedGames). iCloud sync comes in D4, once Haylee joins
  the paid Apple Developer Program. No backend, no accounts.
- **Only game content is stored, never anything about kids:** no names, no player count, no chat transcript (Nutmeg's
  side included), no kid audio or text. A privacy test enforces it.
- **Start screen unchanged** (big Nutmeg). Once a game is saved, a white **My games** button with a bookshelf icon sits
  beside the yellow Let's play! (mockup state 2).
- **My games bookshelf screen** (mockup states 3–4): the same stage, Nutmeg beside the shelf pointing at it, Haylee's
  bookshelf art (vector asset `bookshelf`, slots from bookshelf-slots.json), 3 cards per shelf, newest first, name
  labels on the shelf edge, a yellow arrow or a swipe to the next bookshelf with page dots, a back arrow top-left, tap
  a card to replay. **No delete** (Grown-ups corner, D2). No cap.
- **Replay flow** on the same rail: Pick asks only how many (1–6) → Props shows the whole saved list ("Do you still
  have these?"), missing ones become pretend swaps → Paper: Print everything / Just the badges / Skip (no printer:
  Draw it! again from the saved guide) → Play with the saved scenes for the current count. **No AI calls for content.**
  The live voice says every line (recorded clips are D3b). Barge-in and the kid-safety gates are unchanged.
- **`GameLedger`** no-op hook (new games vs replays) for section E.

## Claude's calls
- **What's stored** (`SavedGame` v1, exactly the design's §D2 fields; the key set is locked by a test): id,
  schemaVersion, createdAt/lastPlayedAt, title, the 6 ranked roles, props (library id, item, becomes, reason,
  alternates, `pretendOnFirstPlay`), the kit for 6 (pages + play guide), hasPrinter/printStyle, the Draw it! guide,
  page art (HEIC, keys `img:<item>` / `cut:<item>:<n>`, badge slices included), printablesMade + their pages, a 600 px
  JPEG cover cut from the sign art, `clips` (empty in D1), voiceID. The PDF is always rebuilt, never stored. Folder
  writes are atomic (`<uuid>.tmp` then rename), file protection `completeUntilFirstUserAuthentication`.
- **Shelf order:** newest saved first (Haylee's §11 wording, over D6's "most recently played"). `lastPlayedAt` is still
  updated on each replay for later.
- **Save line:** one app line, "<Title>! It's on your shelf now. Play it again anytime!" plus a celebrate (the design's
  two back-to-back lines are for D3b's separate title clip; two out-of-band responses at once risk overlapping).
- **Cards:** a printer game's card is its sign art; a game without sign art shows up to 3 of its prop stickers on
  cream (mockup). The bookshelf screen sits over the start screen (the phase stays Hello, so the start screen keeps its
  state and the voice socket stays pre-connected); a card tap crossfades into the game stage (not the chest hop).
- **Replay Pick:** the 1–6 count tiles, then the playing roles' badges and **Let's go!**. Her line after a count is the
  C1 count line ("Three friends! Our crew is a Captain, a Navigator and a Lookout!").
- **Replay Props:** every card starts as Got it (Haylee). Don't have it = the pretend look + "No problem, we'll
  pretend!", and the play guide is rewritten with no call (`ReplayProps.apply`, the guide-prefetch `GuideWeave.finalize`
  on the saved steps: "the pretend …", the printed cut-out picture when the kit has one). The saved alternate is one
  tap ("Use a towel instead?"). A prop that was pretend on the first play is real again when the kids have it now
  (its "pretend" is dropped). Her read-out is the item list ("A pot for the captain's hat, …"), not every reason, to
  keep it short for kids.
- **Replay Paper:** Print everything / Just the badges open the print screen with the saved art rebuilt for the current
  count; **Skip, we have them** goes straight to Play; after a print, Let's play! shows. "Save printables for later" is
  hidden on a replay (it would be an image call; section E decides).
- **Voice on a replay uses only the existing session tools** (set_player_count, go_to_step, start_play, print_kit,
  draw_step, confirm_handoff, just_talk), so the cached Realtime prefix is unchanged. Got it / Don't have it and the
  Paper choices are taps ("print it" by voice = Print everything). The session gets ONE system note with the saved game
  (title, roles, playing roles, props, step, scene titles), and a short note at each step. Planning calls (game, theme,
  roles, props, printer, color) on a replay answer "This is a saved game! Tap New game for a new adventure." and change
  nothing.
- **No AI on a replay, enforced in code:** the kit-art and draft hooks return early on a replay, the art comes back
  from disk (`KitArtService.restore`), and the store never reaches a Claude call. `AICallLog` counts Claude, image and
  moderation calls (numbers only); the live run logs the difference since the replay started.
- **Ledger:** `newGameStarted` once per game at the confirm-step yes (the tap path's "Pick our jobs!" too), never on a
  replay; `replayStarted` at load; a live replay line reports `paidAICall(.replayLine)`.
- The End's line now says "Tap Save it to play again" (first play) or "Tap Play it again" (replay).

- Layout fixes after the first screenshots: the replay's count tiles are 2 rows of 3 and the role badges rows of 3
  (6 in a row reached Nutmeg's face); Got it / Don't have it stack; the pretend line names the prop ("No problem,
  we'll pretend the captain's hat!") so two in a row are both said.

## Tests and live checks
- NutmegCore **329 green** (`RoundD1SavedGamesTests`: model round trip + newer-schema refusal, art keys, the local
  store (newest first, `.tmp` ignored, touch, delete), **the privacy test** (a live-like store with a count of 4, kid
  text and her chat line: the JSON has only the allowed keys and none of them), save-once at The End, the full replay
  Pick 1→6→2 / voice count / planning calls refused / Props pretend + alternate / Paper badges / Play / rail back to
  Pick with **0 Claude calls**, first-play pretend undone, no-printer Draw it! for the count + printables choice,
  replay note, replay tools ⊂ session tools, ledger once at confirm and never on a replay).
- Live typed runs on PT-R15-iPad (`/tmp/pt-roundD1/`): a 3-player "Pirate Ship on the Moon" first play → **Save**
  (1.24 s, 16 art files, ~1.2 MB on disk; `game.json` has no count/chat keys) → home (My games shows) → bookshelf →
  replay at **5 players** (her count line named all 5 roles) → "make it dinosaurs instead" typed (she said the
  saved-game line) → Props (2 missing, 1 swapped to the bowl alternate) → Paper **Just the badges** (1 page, 5 badges,
  print sheet opened) → Play (hand-offs R1→R5→R1, every scene with a step per playing role) → The End ("Play it
  again"). **AI calls on the replay: Claude 0, images 0** (1 moderation call: the typed kid turn's safety check).
- Not checked: the mic (spoken) path on a replay, a no-printer replay live (unit test only), "Play it again" live,
  barge-in during a replay line (same code path as first plays), a printed badge page, more than 9 games (paging),
  HEIC vs JPEG fallback on a device.
