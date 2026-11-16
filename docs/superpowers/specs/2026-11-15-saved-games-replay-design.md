# Design: Generate for 6 (C) and Saved games + real-voice replays (D)

**Date:** 2026-11-15 · **Author:** Claude (design only, nothing built) · **Reviewer:** Haylee
**Source checklist:** [paid-app project](../../../thinking/ideas/2026-11-15-paid-app-project.md) sections C and D ·
**Decisions it builds on:** [paid-app direction](../../../thinking/decisions/2026-11-15-paid-app-direction.md), rounds 19–24.

How to read this doc:
- Unmarked rules come from **Haylee's decisions** (the paid-app direction file, the replay decisions, and her
  correction about where delete lives).
- **[Claude's call]** marks a detail Claude chose so a builder can go ahead without asking. Haylee can overrule any of them.
- **[Open: Haylee]** marks one of the few questions only Haylee can answer (all of them are collected in §9).

Out of scope: StoreKit, plans and pricing (section E) and the iPhone layout. §7 lists the hooks E will need.

---

## 0. Summary

1. **Every game is written for 6.** It gets 6 ranked roles (R1–R2 core, R3–R6 extras), one 6-up badge sheet image
   (sliced), and checklist steps tagged by role. The app shows and prints only the current player count. Changing the
   count makes **no AI calls**, in first plays and in replays.
2. **Save at The End.** "Save it to play again ⭐" replaces "Play again". A game that isn't saved is thrown away.
3. **Storage:** the game folder lives on the iPad and syncs to the family's own iCloud (the CloudKit **private**
   database). There are no accounts and no backend. Only game content is stored, never anything about kids. A game
   takes about 3–5 MB (about 1 MB with no printer).
4. **My games shelf** on the start screen: big picture cards, no cap, and **no delete on the shelf**. Grown-ups
   delete games in a minimal **Grown-ups corner** behind a parental gate, built so section E can add to it later.
5. **Nutmeg's real voice on replays.** Her app-scripted lines are recorded from the Realtime audio stream the first
   time she says them, then played back on later plays: same pipeline, same Varispeed, same lip sync, same barge-in.
   The live voice is used only for new interaction or a line she has never said, and that line is saved too.
   Never the system voices.
6. **The replay flow** uses the same rail, Pick · Props · Paper · Play: how many are playing → the whole prop list
   ("still have these?") → print everything / just the badges / skip (or Draw it! again) → Play.

---

## C. Generate for 6 with ranked roles

### C1. What changes in the game data

| Thing | Today | After C |
|---|---|---|
| Role ids | `RoleID` R1–R4. Kids past 4 share a role (`RoleCast.normalize` merges roles and adds counts) | **R1–R6.** One role per kid, always 6 distinct ranked roles. `Role.count` is always 1 (kept in the type so old data still decodes) |
| Who decides the roles | `set_roles` (Realtime tool), one entry per kid | `set_roles` **always returns 6 entries in rank order**. The voice model is told the rank rules (below) |
| Which roles are playing | all of them | **the first N** (`playingRoles = roles.prefix(N)`), where N is the player count (1–6) |
| Scene owners | R1–R4 or `all` | **R1, R2 or `all` only** [Claude's call]. Extras never own a scene, so hand-offs only happen between the core roles, and a scene never belongs to a role that isn't playing |
| Checklist steps | `Step(picture, text)` | `Step(picture, text, role)`, where `role` is `all`, R1…R6. Steps for **R3–R6 are optional**: shown only when that role is playing |
| Badge art | one shared, role-neutral badge image; the app prints each role title | **one 6-up badge sheet image** (one badge picture per role), sliced into 6 |
| Picture ids | `badge:R1…R4` | `badge:R1…R6` |
| Role colors | 4 player colors (`Theme.playerColor` wraps `% 4`) | **6 colors**: two brand colors added for R5/R6 [Claude's call: picked from the existing brand palette, shown to Haylee in the build round's screenshots] |

**Rank rules** (in the `set_roles` description and in `Prompts.plan` for the tap path):
- R1 is the lead role the game can't run without (Captain, Head Baker, Vet).
- R2 is the second core role (Navigator, Assistant Baker). With 1 kid, R2 is played by a stuffed animal, as today
  ("If there is 1 kid, stuffed animals can play the other parts").
- R3–R6 are fun extras that add to the game but are never needed (Parrot Keeper, Cook, Ticket Taker, Lookout).
- Six distinct titles, never "Passenger" twice. [Claude's call: the app de-duplicates repeated titles. A duplicate
  gets an alternate from a short bundled list per theme family, or "Helper" as the last resort.]

**Step visibility (pure function, unit-tested):**
`visibleSteps(scene, playerCount N) = scene.steps.filter { $0.role == .all || $0.role ∈ {R1, R2} || rank($0.role) <= N }`
- R2 steps always show, even with 1 kid (core, done by the kid or the stuffed animal). [Claude's call, matching today's 1-kid rule.]
- Every scene must have **at least 3 steps that are always visible** (`all`, R1, R2), so a 1-kid game never shows a
  2-step list. `Validate.kitScenes` checks this. A scene that fails gets one regenerate (the existing retry), then
  its optional steps are relabeled `all`.
- **At most 2 optional steps per scene** and at most 6 visible steps at 6 players (the checklist fit from rounds 10/14
  is built for 3–5 steps; 6 needs a fit check in the build round). [Claude's call]
- Text rules: scene lines (`nutmegSays`) and core steps may name **only** R1/R2 (or no role). An extra's step names
  that extra ("Lookout, look for land with your telescope!"). That way no line ever names a role that isn't playing.
- `ChecklistCheers`, `HandOffLines.repeatText`, "Done!" auto-check and the "First, …!" intro all work on
  `visibleSteps`, never on the raw list.

### C2. What Nutmeg says about roles

- In the roles announcement she names **only the N playing roles**, as today. The `set_roles` result tells her which
  ones: "Roles set (ranked): …. N = 3 are playing: announce ONLY Captain, Navigator, Parrot Keeper."
- First-play count change after the roles (new, thanks to C) [Claude's call]: changing the count at Props or Paper
  no longer means "tap New game". The roles stay, `playingRoles` changes, the badges re-slice, and she says one line:
  "Four friends! I'll add a badge for the Lookout." Round 19's rule "a count change after the kit is made isn't
  remade" now becomes "isn't remade, and doesn't need to be". A game or theme change still remakes the kit (round 19).

### C3. The 6-up badge sheet

- **One image**, `1024x1536` (portrait) [Claude's call], drawn as a **3 × 2 grid of 6 portrait badges**. That is the
  same 3 × 2 layout `KitLayout.grid(.badge)` prints on a Letter page, so with 6 players the page prints almost 1:1.
  Each badge has a blank top banner and a blank bottom banner, and in the middle one themed picture **for that role**
  (rank order, left to right then top to bottom). No words or letters, as today. The safety suffix and
  `moderation: auto` are unchanged.
- The prompt names each role and its job in order ("1: Captain — steers the ship; 2: Navigator — reads the map; …").
  This comes from the roles, so **Claude's kit call doesn't change for badges**.
- **Slicing:** reuse `CutoutSheet.cells`'s boundary search (the emptiest line near each grid line), but **skip the
  square trim** for badges: cells stay portrait, trimmed only to the badge's outer edge plus a margin. Add a
  `trimToSquare: Bool` parameter (default true, so cut-outs are unchanged).
- **Role title and name line on a slice:** drawn by the app at fixed fractions of each cell (top banner about 0–18%,
  bottom about 82–100%), the same overlay the single badge uses today, scaled to the cell. [Claude's call]
- **Printing N badges:** `KitLayout.pages` takes `playingRoles` and lays out cells 1…N in the 3 × 2 page grid (the
  rest of the page stays blank, round 23). The app still prints the role title on the top banner and "Name: ____" on
  the bottom one.
- **Fallback:** if slicing finds fewer than 6 cells, or the sheet fails twice, the old single role-neutral badge
  image is drawn and used for every role (today's behavior). [Claude's call]
- **Resolution risk:** each cell is about 341 × 768 px, so about 120 dpi at the printed size (about 2.8 × 6.4 in).
  Round 20 judged low quality crisp at full page. This needs a printed check at the build round (see §8). If it looks
  soft, switch the sheet to `quality: medium` for this one image (about +2–3¢) before anything else.
- **Checklist pictures:** `badge:Rk` shows slice k (today all badges show the same picture).

### C4. The no-printer Draw it! path

- No images, as today. The badge piece's count is the **current player count** (`DrawIt.clean` already sets
  `badges, tickets = kids`). The guide stores `count = 1` from Claude; the app computes counts at display time from N.
  Then a replay with another count just re-reads the saved guide. [Claude's call: move the count out of the stored
  guide and into `DrawIt.line(guide, i, playerCount:)`.]
- The badge instruction stays role-neutral ("Draw a big star. Write your job on it."), so 6 ranked roles don't change
  the guide. Claude's draw-guide prompt doesn't change.
- "Save printables for later" makes the normal printer kit, with the 6-up badge sheet.

### C5. Schema and prompt changes (builder checklist)

| File | Change |
|---|---|
| `Models.swift` | `RoleID` + R5, R6. `SceneOwner` + R5, R6 (decoding only; the cleaner maps R3–R6 owners to `all`). `Step.role: SceneOwner` (decodes missing → `all`, so old JSON works). `Players.max` stays 6 |
| `Schemas.swift` | `roleIDs` covers R1–R6. Scene `owner` enum = R1, R2, all. Step gains `role` (enum all, R1–R6). Picture description says `badge:R1..R6` |
| `Picture.swift` | `kitIDs` includes badge:R5, badge:R6 |
| `Prompts.swift` | System prompt: "Roles have ids R1…R6, ranked: R1–R2 core, R3–R6 extras". `plan()`: always 6 ranked roles. `kitScenes()`: owners R1/R2/all; each scene has ≥3 steps for all/R1/R2 and 0–2 optional steps, each tagged with one extra role that names it; core lines never name an extra. `kit()` (one-call fallback): the same |
| `RealtimeProtocol.swift` | `set_roles`: "Exactly 6 ranked roles for this game, whatever the number of kids…". Instructions step 4: announce only the playing roles named in the result |
| `Sanitizer.swift` / `RoleCast` | `normalize` becomes `rank(_:)`: exactly 6 distinct titles, ids R1–R6 by position, count 1. A new `playing(_ roles:, kids:)` |
| `KitLayout.swift` | badges from `playingRoles`, slot k → slice k |
| `KitArtPrompt` / `KitArtService` | badge sheet prompt + slicing (C3) |
| `AdventureStore` | `playingRoles`, `visibleSteps(sceneIndex)`, `goToScene` hand-offs use R1/R2 only, count change after roles allowed (C2) |
| `DrawGuide.swift` | counts computed from N at display time (C4) |
| `Fallback.swift` (airplane) | 6 ranked roles and tagged steps |

### C6. Cost impact

- **Claude:** `kitScenes` writes 0–2 extra optional steps per scene (about 8–10 more steps, about 250–400 more output
  tokens with thinking) plus a `role` field on each step. **About +1–3¢ a game.** `kitPages` is unchanged.
- **Realtime:** `set_roles` sends 6 short entries instead of N (a few dozen tokens). The roles announcement is the same
  length. About +0¢.
- **Images:** unchanged. The badge sheet replaces the single badge image (1 → 1). +0¢ (or about +2–3¢ if the sheet
  needs medium quality, C3).
- **Saving:** every count change, on a first play or a replay, used to mean "New game", which is a whole new
  ~$1.60 game. Now it costs $0.

---

## D. Saved games and replays

### D1. Saving at The End

- At The End, the buttons are **"Save it to play again ⭐"** (primary) and **"New game"**. There's no "Play again"
  button anymore. (`EndView`, `HandOffLines.end`: "The end! What a show! Take a bow! Tap Save it to play again, or
  New game for a new adventure!")
- **The ⭐:** [Claude's call] Brand rules say no emoji, so the star is the SF Symbol `star.fill` in brand yellow, in
  the button's icon slot (like the other buttons). It is not an emoji character in the label.
- **Tap Save:** the game is written to disk at once (a few hundred ms; the images are already in memory). Nutmeg says
  one line, said as two back-to-back app lines so the title is its own clip for the shelf and the replay greeting:
  "**<Title>!**" then "It's on your shelf now. Play it again anytime!" She does a celebrate gesture. The button turns
  into **"Play it again ⭐"**, which starts the replay flow (D5) on the saved game. New game stays. [Claude's call:
  after saving, "play again" still works, as a replay]
- **Pages that never got AI art** (an image failed twice, so the page is app-drawn): saved with `appDrawn: true` and no
  image. A replay draws them the same way. [Claude's call]
- **Tap New game without saving, or the X, or Leave:** the game is discarded (`leave()` is unchanged). There's no
  "are you sure" nag. [Claude's call: Haylee decided unsaved games are discarded, and the round 6 leave dialog already
  warns that the game ends.]
- **Saving mid-game:** not offered. A game becomes saveable only at The End. [Claude's call: the replay needs the play
  guide and at least one played-through set of lines.]
- **Saving a replay:** a replay is already saved. At The End of a replay the buttons are "Play it again" (it goes back
  to Pick on the same game) and "New game". New clips recorded during the replay are saved as they finish (D4), so
  there's nothing to save at the end.
- **Tap-fallback games** (no Realtime session) can be saved too. They just have no clips yet, so the first replay says
  everything live (and records it).

### D2. What is stored (and what never is)

**Stored, per saved game** (`SavedGame`, schema version 1):

| Field | Content | Notes |
|---|---|---|
| `id` | UUID | |
| `schemaVersion` | 1 | decoder migrates older versions |
| `createdAt`, `lastPlayedAt` | dates | shelf order. Device usage, not about a kid |
| `title` | the current title (`currentTitle`) | |
| `roles` | 6 ranked `Role`s (title, job, symbol) | |
| `props` | each `Prop`: library id, household item, becomes, **reason**, alternates, and `pretendOnFirstPlay` | the round 24 reasons are kept for the replay readout |
| `kit` | `KitItem`s (6 recipe pages) + `scenes` (with role-tagged steps) | play guide |
| `hasPrinter`, `printStyle` | the printer and color choices | |
| `drawGuide` | the Draw it! guide (no-printer games) | counts computed at play time (C4) |
| `art` | page images: badge sheet, sign, money, tickets, menu, cut-out sheet, ≤2 skipped-prop cut-outs | stored as HEIC [Claude's call]; the PDF is **rebuilt** with `KitPrinter.pdf` when needed, never stored |
| `printablesMade` | Bool: a no-printer game made "Save printables for later" | if true, its pages are stored too and Paper can print them |
| `cover` | a 600 px picture-card image for the shelf | see D3 |
| `clips` | Nutmeg's recorded lines (D4): key, text, kind, role, duration, file | added to on later plays |
| `voiceID` | "coral@gpt-realtime-2.1" | the voice the clips were recorded in (D4) |

**Never stored** (enforced by code and a test, §8):
- No kids' names. The app never asks for them anyway (roles-not-names).
- No kid audio, no kid transcripts, no typed kid text, and **no chat transcript at all**, Nutmeg's side included.
  Only the app-authored lines in `clips` are kept (D4), and their text is the app's own script.
- **No player count** from any play [Claude's call: the replay asks again, and storing who played adds nothing].
- No moderation or safety results, no device ids, no timing logs.
- Nothing goes to any server of ours. There's no server for it.

**Sizes (estimates, checked in the build round):**

| Part | Size |
|---|---|
| Game JSON (roles, props, kit, scenes, guide, clip index) | 20–40 KB |
| Page art, 6–8 images as HEIC (from about 1–2 MB PNGs) | 1.5–3 MB |
| Cover | about 60 KB |
| Voice clips, AAC 32 kbps mono, about 4 KB a second. A first play has about 35–45 app lines (about 150 s) | 0.6 MB, growing to about 1–1.5 MB after a few replays at other counts |
| **Total per printer game** | **about 3–5 MB** |
| **Total per no-printer game** | **about 1 MB** |

100 saved games is about 0.3–0.5 GB of the family's iCloud (the free tier is 5 GB, shared with photos and backups).

### D3. Where it's stored: the iPad + the family's iCloud

**On the iPad** (the source of truth for playing; a replay never waits on the network):
`Application Support/SavedGames/<uuid>/` with `game.json`, `art/<itemID>.heic`, `clips/<key>.m4a`, `cover.jpg`.
File protection `completeUntilFirstUserAuthentication`. Writes are atomic: write to `<uuid>.tmp/`, then rename.
[Claude's call]

**In iCloud:** CloudKit **private database**, custom zone `SavedGames`, synced with **`CKSyncEngine`** (iOS 17+; the
app's iPadOS target already allows it) [Claude's call: CKSyncEngine handles change tokens, retries, account changes
and push. It isn't NSPersistentCloudKitContainer, because the app has no Core Data].

| Record type | Fields | Why |
|---|---|---|
| `SavedGame` | id, schemaVersion, title, createdAt, lastPlayedAt, `content` (CKAsset: game.json gzipped), `cover` (CKAsset), `art` (CKAsset list), voiceID | the game itself rarely changes after saving |
| `VoiceClip` | key, kind, role, text, duration, `audio` (CKAsset), parent → SavedGame | clips are added on later plays. Separate records, so a new clip uploads alone and never rewrites the game |

- **The developer can't see any of it** (private database). The App Store privacy label stays "Data Not Collected".
- **Entitlements to add:** iCloud (CloudKit) with container `iCloud.app.pretendthat` [Claude's call on the name] and
  Background Modes → Remote notifications (silent CloudKit pushes). The schema goes from the Development to the
  Production environment before release (a release checklist item).

**Offline:**
- Saving, the shelf, replays and Grown-ups delete all work offline, from the local folder. Changes queue in
  CKSyncEngine and upload when the iPad is back online.
- A game saved on another iPad shows on the shelf once it has fully downloaded. A half-downloaded game doesn't show
  [Claude's call: no "loading" cards for kids].
- Offline replays use only stored clips. For a line with no clip, see §D4.6.

**Sync conflicts** (simple, because the content can't be edited after saving):
- `SavedGame` content is **immutable after save**. Only `lastPlayedAt` changes. Merge: keep the later date.
- `VoiceClip`s are **append-only**, keyed by `(gameID, key)`. If two iPads record the same key, the first one saved
  on the server wins and the other is dropped (both are her real voice saying the same line).
- **Delete wins:** a deleted game removes its `VoiceClip`s (parent reference plus an explicit delete of the children).
  A clip that arrives for a deleted game is dropped.
- Two iPads saving the *same* first play can't happen: a game exists on one iPad until it's saved.

**When iCloud is off** (no account, iCloud Drive off for the app, or Restricted):
- Everything works on this iPad only. The kids see no difference.
- Grown-ups → Saved games shows one plain line: "Saved on this iPad only. Turn on iCloud to keep them on your
  family's other iPads."
- When iCloud turns on later, the local games upload.
- **Account change** (someone signs out, or a different Apple ID signs in) [Claude's call, following Apple's
  CKSyncEngine guidance]: games that came from the old account are removed from this iPad. Games that were
  only ever on this iPad stay, and upload to the new account.
- **iCloud full** (`quotaExceeded`): the game is still saved on the iPad. Grown-ups shows "iCloud is full, so this
  game is saved on this iPad only." CKSyncEngine retries later.

### D4. Nutmeg's real voice on replays

#### D4.1 What gets recorded (and what never does)

- Recorded: **only the app-authored lines** she says through `Realtime.sayExactly` (out of band, `conversation:
  none`). These are the scene intros ("Pretend that…"), the checklist intros, the checklist cheers and the one
  congratulations, the hand-off lines, the "Hear it again" read-outs, the print-ready line, the Draw it! lines, the
  rail arrival lines, the save line, the replay lines (D5), and The End.
- **Never recorded:** her conversational replies (the planning chat, prop-hunt lines, answers to the kid), and **the
  kid's mic audio, ever**. The recorder only takes audio deltas from responses the app started with `sayExactly`.
  It can't see the mic path.
- The Realtime session's header comment ("Nothing is recorded or stored") is updated to say exactly this.

#### D4.2 How a clip is captured

1. `RealtimeSession.say(line, record: ClipRequest?)` sends `sayExactly` and remembers which response id the line
   belongs to (the round 19 `SpeechStop` already tracks every id).
2. As that response's `audioDelta`s arrive, the raw **PCM16 24 kHz source audio** (before Varispeed) is appended to
   a buffer for that id. It's the same bytes `play(_:)` already gets.
3. On `response.done` the clip is **kept only if all of these hold**:
   - The response wasn't cancelled or cut off by barge-in. Partial clips are dropped.
   - Its output transcript matches the requested line after normalizing (case, punctuation, whitespace, "&"/"and",
     numerals vs words). This catches round 24's "tap Start" paraphrase. A mismatch isn't saved, so the line stays
     "never said" and is said live next time.
   - It's between 0.4 s and 30 s long.
4. Leading and trailing silence is trimmed (keeping 60 ms). The clip is encoded to **AAC-LC, 24 kHz mono, 32 kbps,
   `.m4a`** with `AVAudioFile` [Claude's call: hardware encode, about 12× smaller than PCM, transparent for speech;
   the encoder's priming samples are trimmed on decode]. It's written into the game folder and synced as a `VoiceClip`.
5. **First play (not saved yet):** clips are kept in memory and in a temp folder for the current game. Save moves them
   in. Leave or New game deletes them, along with the rest of the unsaved game.

#### D4.3 How clips are keyed and matched

- **Key** = SHA-256 (hex, first 32 characters) of `"v1|" + voiceID + "|" + normalize(lineText)`.
  - The line text already contains the role where it matters ("Pass the iPad to the Navigator, then tap I'm the
    Navigator!"), so **text + role is covered by the text**. The clip also stores `role` (R1…R6 or nil) and `kind`
    (sceneIntro, checklistIntro, cheer, congrats, handoff, readout, printReady, draw, arrival, save, replay, end)
    as metadata. These say which roles have their lines (for the builder's hit-rate log) and pick fallbacks (D4.6).
  - `normalize` is the same function used for the transcript check (D4.2), in NutmegCore, unit-tested.
- **Lookup at play time:** `ClipStore.clip(for: line)` gives a clip, or nil when the line is never-said.
- **Lines that are picked at random** (`ChecklistCheers` praise, next-step wording, congrats, done tails, the 42 kit
  lines): on a replay, `LineDeck` gets a **clip-aware draw**. It picks first from the variants that already have a
  clip in this game, and only picks a new variant when none of them has one. Then a replay sounds recorded almost
  everywhere, and over many plays the variety still grows a little. [Claude's call]
- **Lines that depend on order** (a cheer names the next unchecked step): these are deterministic once the order is
  the same. Kids mostly check in order, so most cheers hit. A different order is a never-said line: live once, then
  saved.
- **Whole lines, not sentences** [Claude's call]: a line is recorded and keyed as one clip, exactly as it is said
  today, so the first play sounds exactly as it does now. Splitting lines into sentence clips was considered (it
  would raise the hit rate for composed lines) but was set aside. It means several back-to-back responses with small
  gaps and odd joins between them. Revisit only if the measured hit rate on second plays is under about 85% (§8).

#### D4.4 Playback, lip sync and barge-in

- **One pipeline:** a clip is decoded to float PCM at 24 kHz and fed in chunks of about 100 ms into the **same**
  `RealtimeSession` playback path as live audio (a new `playClip(_:)` next to `play(_:)`). So it goes through the
  same player node, the same **Varispeed 1.20** pitch unit, the same `queueMouth` / `LipSyncAnalyzer` /
  `MouthShaper` lip sync (loudness plus the spectral split), the same `isSpeaking` / `speakingUntil` tail, the same
  mic gate, and the same expression blips. Because the clip is stored *before* Varispeed, it sounds exactly like her
  live voice.
- **The audio engine without a live session:** the playback engine is split out of the socket, so clips play even
  when Realtime isn't connected (offline, or not connected yet). [Claude's call: refactor `RealtimeSession`'s audio
  half into a `NutmegSpeaker` owned by `AppModel`, which the session uses for live audio too.]
- **Barge-in:** a clip plays as a pseudo-response tracked in `SpeechStop`. Every `UserAction` that stops her speech
  (round 19), a typed turn and a mic press (round 20) stop a clip the same way: the player is cleared, the mouth
  resets, the chat line is cut with "…", and pending cheers are dropped. A cut clip is just stopped, and the stored
  clip is unchanged.
- **The chat panel:** a played clip adds her line as a normal Nutmeg bubble (its stored text), so the chat reads the
  same as a live play. "Hear it again" replays the same clip (`echo`, no new bubble).
- **Timing:** a clip starts at once (no network), so replays feel faster than first plays. The thinking face and dots
  (round 13) are skipped when a clip is ready.

#### D4.5 Never-said lines (live once, then saved)

- If `ClipStore` has no clip and the session is live, the line goes through `sayExactly` as today, with
  `record:` set. If it passes D4.2, it's saved into the game (and synced).
- Typical never-said lines: the replay lines (D5), a hand-off or optional-step cheer for a role that didn't play
  before, the Draw it! count line for a new count, a cheer for a different check order, and a different Paper choice's
  line.
- **The live voice is the same voice:** `VoiceConfig.nutmeg` (coral, Varispeed 1.20) is frozen. A unit test locks the
  voice name, model and Varispeed rate. If OpenAI ever retires the voice, that's a product decision for Haylee, not a
  silent change. Clips store `voiceID`; a clip whose `voiceID` doesn't match the current one is still played (her
  voice never changes inside a game), and new lines use the current voice. [Claude's call: replacing everything
  would mean she has two voices during the switch-over anyway.]

#### D4.6 A never-said line with no network

Never the system voice (Haylee). The plan:
1. **Common-line clips bundled with the app** [Claude's call]: about 40 generic lines recorded once in development
   from the same Realtime voice and pipeline, shipped in the app bundle (about 200 KB). These are the praise words,
   "Tap the steps as you go, then tap Done!", "Tap Done for what's next!", "No problem, we'll pretend!", the counts
   "Just you!" through "Six friends!", "How many friends are playing this time?", "Do you still have these?", and the
   generic Paper and Play prompts. They're the last fallback before silence, and they also make the first replay
   sound recorded.
2. Otherwise: **she says nothing**. The line appears as her chat bubble, she does a matching gesture (point at the
   checklist, wave at a hand-off), and the screen's own buttons carry the step. The line is marked "owed" and is
   said and recorded live the next time it comes up online.
- **[Open: Haylee]** Is silent-plus-text acceptable for an offline line she never said, or should an offline replay
  that's missing lines show a "Nutmeg needs the internet for a new line" state instead? (§9, Q1)

### D5. The replay flow (same stage, same rail: Pick · Props · Paper · Play)

Start: the kid taps a game card on the My games shelf. The usual start-screen exit runs (Nutmeg hops onto the stage,
round 11). The rail shows all four steps, with Pick current. **No Claude calls and no image calls happen anywhere in
a replay.** Realtime is pre-connected when online, but only answers the mic or says never-said lines.

| Step | What happens | What she says (clip-first) |
|---|---|---|
| **Pick** | Only "how many are playing?" Six big number buttons **1–6** (the round 23 tap picker), or voice (the mic → `set_player_count`, the same cap line over 6). No game, theme, confirm, printer or color questions: those were saved | "**<Title>!**" (the save clip) + "How many friends are playing this time?" After the answer: the count line ("Three friends!"), then the playing roles ("We need a Captain, a Navigator and a Parrot Keeper!") |
| **Props** | **The whole saved list at once** (the round 23 `PropsView` grid, with live-card styling): every card has **Got it** / **Don't have it**, and they all start as Got it. Don't have it turns the card into a **pretend swap**: it gets the "pretend" look (like a skipped prop today), its cut-out (if one exists) is used in the play guide, and if the prop has a saved alternate the card offers it in one tap ("Use a towel instead?") [Claude's call]. One big **All set!** button | "Do you still have these?" + a read-out of the list with the saved reasons, said live once and then saved. A pretend swap: "No problem, we'll pretend!" |
| **Paper (printer)** | Three big choices: **Print everything**, **Just the badges**, **Skip, we have them**. Print uses the saved art. The PDF is rebuilt for the current count (N badges from the sheet, tickets for N) and goes to the AirPrint sheet. Then **Let's play!** | "Do you want to print everything, just the badges, or skip it?" (or her print-ready line after printing) |
| **Paper (no printer)** | **Draw it!** runs again from the saved guide, with counts for N (C4). If `printablesMade`, the three print choices show instead, plus "Draw it instead" [Claude's call]. "Save printables for later" is hidden on a replay (it would be an image call) [Claude's call; see the E hook] | the saved Draw it! lines. A new count line ("Make four, one for each friend.") is said live once |
| **Play** | The saved scenes, with `visibleSteps(N)` and hand-offs between R1/R2 only. This is the same play engine as a first play | the scene intro, checklist, cheer and hand-off clips |
| **The End** | "Play it again" (back to Pick on this game) and "New game" | The End clip |

- **Rail:** back-navigation works as in round 23. Going back to Pick and changing the count re-slices the badges and
  re-filters the steps, with no AI calls.
- **Voice in a replay:** a replay tool set, offered on the tool-first pass: `set_player_count`, `prop_status`
  (have/missing), `paper_choice` (all/badges/skip), `go_to_step`, `start_play`, `draw_step`, `just_talk`. When the
  session connects, it gets one system note with the saved game (title, playing roles, props, the current step, and
  the scene titles), modeled on the round 9 `ResumeContext`. [Claude's call]
- **Loading a replay:** `AdventureStore.loadReplay(_ game: SavedGame)` sets the title, roles, props, kit, guide and
  printer/color choices, and `mode = .replay`. `playerCount` is 0 until Pick. Planning steps are skipped. The replay
  note is a **system item**, never a change to the session `instructions`, so round 20's cached prefix stays the
  same. [Claude's call]
- **Changing the game in a replay** ("make it pirates instead"): she says "This is a saved game! Tap New game for a
  new adventure." Nothing is regenerated. [Claude's call]
- **Safety:** replays add no new generated content. Kid speech on the mic is handled exactly as today (round 19/21
  gates).

### D6. My games shelf (start screen) and the Grown-ups corner

**Shelf** [Claude's calls on placement and look, to be mocked up for Haylee before the build round]:
- It shows only when at least one game is saved. It's a horizontal row of **big picture cards** (about 220 × 260 pt)
  along the lower part of the start screen, popping in with the logo and the Let's play! button (round 11
  choreography). It scrolls sideways, and there's **no cap**.
- **Card picture:** printer games use the **sign** page art (it carries the place's name), cropped. No-printer games
  use an app-drawn card: the game's prop stickers on the brand cream card. The title is under the picture.
- Order: most recently played first.
- **Tap:** starts the replay. **Long press:** plays the title clip ("Pirates on the Moon!") with lip sync. There's no
  system voice (the round 5 `ptSpeakOnLongPress` uses the app's `speak`, which must take the clip path here).
- **No delete, no edit, no menus on the shelf** (Haylee's correction). Kids can't remove a game.

**Grown-ups corner, minimal version** (Haylee: delete lives in the Grown-ups area; E adds the rest later):
- **Entry:** a small "Grown-ups" text button in the start screen's top-right corner (not shown during a game).
- **Gate** [Claude's call]: `GrownUpGate`, a reusable component. Step 1: hold for 2 seconds (the existing
  `PTParentGate` pattern). Step 2: a grown-up question a 4–8 year old can't easily answer: "Tap the number
  *forty-seven*" from 4 numerals, with a new random pair each time. Apple's Kids Category needs a real gate before
  purchases and outside links, which E needs anyway, so it's built once here. Three wrong answers close the gate.
  VoiceOver gets an accessible version of the same question.
- **Screen:** `GrownUpsView`, a native `NavigationStack` + `List` (components-first: native controls), in sections:
  - **Saved games** (now): every saved game with its cover thumbnail, title, saved date, size, and where it is ("On
    this iPad and iCloud" / "On this iPad only"). Swipe to delete, or Edit → select → Delete. **Confirm:** "Delete
    'Pirates on the Moon'? It will be removed from this iPad and your family's other iPads. This can't be undone."
    (Delete / Cancel). The delete is permanent, because there's no trash for kids' games [Claude's call]. It removes
    the local folder and the CloudKit records.
  - **About saved games** (now): the privacy text from §D7 and the iCloud status line (D3).
  - Built as a `GrownUpsSection` list so E can add **Subscription**, **Restore purchases**, **Privacy policy**,
    **Help & contact** as new sections, with no layout change.
- The round 20 rule "no settings menu" still holds: there are no settings here, only managing saved games.

### D7. The privacy story for parents

The plain version, for the Grown-ups corner, the App Store page and the privacy policy:

> **What PretendThat saves:** only the games you choose to save: the game's title, roles, props, play guide,
> printable pages and Nutmeg's own lines, so she can play them again in her real voice.
> **What it never saves:** your child's name, voice, words or picture. Nutmeg listens only while the mic button is
> held, and nothing your child says is ever kept.
> **Where it lives:** on this iPad and in your family's own iCloud. We don't have servers that store your games, and
> there are no accounts. We can't see your saved games.
> **You're in charge:** delete any game in Grown-ups. Unsaved games are gone when you leave them.

- The App Store privacy label stays **Data Not Collected** (the private CloudKit database isn't collection by the
  developer). The OpenAI and Anthropic calls are unchanged from today and already covered.
- Rule 6 in CLAUDE.md ("Never store anything about kids") holds. Saved games are game content. Update the
  [no-backend decision](../../../thinking/decisions/no-backend-no-accounts.md) with a note that iCloud private sync
  isn't a backend.

---

## 7. Hooks section E will need (not built here)

- **`GameLedger`** (protocol in NutmegCore, no-op for now): `newGameStarted(id:)`, `replayStarted(id:)`,
  `paidAICall(kind:)`.
  - **A new game counts at the confirm-step yes** (`confirm_plan`), the moment before the first paid AI call (the
    kit pages and art) [Claude's call: earlier is free chatter; later lets a kid get the kit without it counting].
  - Replays never count as new games.
  - Live never-said lines on a replay are small Realtime costs (about 0.5–1¢ each). They're reported as
    `paidAICall(.replayLine)` so E can watch them, but they don't count against plans.
- **"Save printables for later" on a replay** is the one replay action that would cost images (about 30–50¢). It's
  hidden in replays until E decides whether to allow it.
- **The Realtime connection on a replay** costs nothing until a response is made. The relay may want a replay-mode
  token with a lower cap (E).
- **Grown-ups corner and `GrownUpGate`** are ready for the Subscription / Restore / Privacy / Help sections.
- **The saved-game count** is available for E (for example, a free trial that keeps saved games playable).

---

## 8. Risks, tests and the build plan

### Risks

| Risk | Mitigation |
|---|---|
| The badge sheet is too soft at about 120 dpi, or the model draws the wrong order or merges badges | Print check in round C2. If soft, medium quality for this one image. Ink-based slicing plus a fallback to the single shared badge. Order check: cell count must be 6 |
| Ranked roles get worse (extras feel tacked on, or duplicate titles) | Live runs across 6 themes. App de-duplication. Haylee listens to the announcements |
| A 6-player checklist doesn't fit (up to 6 visible steps) | Fit check at 6 in round C1. At most 2 optional steps per scene |
| The clip hit rate is low (order-dependent cheers, paraphrased lines) | Clip-aware decks, the transcript match, bundled common lines. Log `replay clips: hit/total` per play. If under 85% on a second play at the same count, revisit sentence clips (D4.3) |
| `sayExactly` paraphrases, and a wrong line gets saved | The transcript-match gate (D4.2) |
| The engine refactor (`NutmegSpeaker`) breaks live lip sync or barge-in | A refactor-only round first, then the existing lip-sync and SpeechStop tests, plus a live typed run before any clip work |
| CloudKit edge cases: account switches, quota, the Production schema | CKSyncEngine, the rules in D3, a two-simulator test on one Apple ID, and a release checklist item for the Production schema |
| Storage grows with no cap | About 3–5 MB a game, shown per game in Grown-ups. Delete lives there |
| OpenAI retires the coral voice or model | Clips keep old games in her voice. A new voice is Haylee's decision (D4.5) |
| Older saved games after schema changes | `schemaVersion` plus migration tests from v1 fixtures |

### Test strategy

**NutmegCore unit tests (pure, no network):**
- **Ranked roles:** `RoleCast.rank` always gives 6 distinct titles, R1–R6. `playing(kids:)` for 1…6.
- **Step visibility:** a table for N = 1…6 (R2 always shown, R3–R6 only when ≤ N, ≥3 always visible). Cheers,
  read-outs and the Done auto-check use only visible steps. Lines never name a role that isn't playing.
- **Badges:** slicing a fixture 3 × 2 portrait sheet gives 6 portrait cells. `KitLayout` prints cells 1…N. The
  fallback when slicing fails.
- **Draw it!:** counts come from N at display time, and the saved guide decodes.
- **Clips:** key normalization (a punctuation and numerals table). The transcript-match accept/reject table (including
  "tap Start" vs "tap Let's play"). Partial or cancelled clips rejected. Clip-aware `LineDeck` picks recorded variants
  first. A voiceID-mismatched clip still plays.
- **SavedGame:** a Codable round trip. v1 fixtures decode. **A privacy test:** encode a saved game made from a full
  live-like store (with a chat transcript, kid text and a player count present in memory) and assert that the JSON
  has none of them (a deny-list of keys and of the fixture's kid strings). The recorder only accepts response ids
  started by `sayExactly`.
- **Sync merge rules:** pure functions (the later `lastPlayedAt` wins, clips are append-only with first-wins, delete
  wins over clips that arrive late).
- **The no-AI replay:** a replay driven through Pick (counts 1→6→2) → Props (with a missing prop) → Paper (each
  choice) → Play → The End, with spy `PhaseService` / `ImageClient` / Realtime responses: **zero** Claude and image
  calls, and Realtime responses only for lines with no clip.
- **Ledger:** `newGameStarted` fires once at confirm, never in a replay.

**App and live checks (simulator, typed `-PTLive` runs, as in rounds 19–24):**
- A first play at 3 players → Save → replay at 6 → replay at 1, logging the clip hit rate and listing every live line.
- Barge-in during a clip (taps, typing, the mic). Lip-sync screenshots during a clip vs a live line.
- Airplane mode: save, replay, the offline never-said behavior (D4.6).
- Two simulators on one iCloud test account: save on A → it appears on B. Delete on B → it's gone on A. iCloud off →
  the "this iPad only" line.
- A printed badge page at 2 and 6 players (the resolution check, on a real printer).
- **Haylee's listening test:** a replay should sound like the first play (the same voice, no seams).

### Phased build plan (each round shippable; one build agent at a time; 3–5 items a round)

| Round | Items | Ships |
|---|---|---|
| **C1: ranked roles** | R1–R6 + colors. `set_roles`/plan always 6 ranked. Role-tagged steps + `visibleSteps`. Owners R1/R2/all. A count change after the roles needs no remake | First plays support any count change at Props/Paper/Play with no AI calls |
| **C2: the badge sheet** | The 6-up portrait sheet prompt + portrait slicing + fallback. `KitLayout` prints N. `badge:Rk` checklist pictures. Draw it! counts from N. Print check | Role-specific badges |
| **D1: local saved games** | `SavedGame` model + the local store + the privacy test. "Save it to play again ⭐" at The End. The My games shelf (after a mockup Haylee approves). The replay flow (Pick count / Props list / Paper choices / Play) **with the live voice** for every line. The `GameLedger` no-op | Saving and replaying on one iPad (replays still use live voice, which is cheap) |
| **D2: Grown-ups + delete** | `GrownUpGate`. `GrownUpsView` with Saved games (delete + confirm) and About saved games. Space for E's sections | Grown-ups can manage games |
| **D3a: the speaker refactor** | Split `NutmegSpeaker` out of `RealtimeSession` (no behavior change). Live regression run | Groundwork, safe on its own |
| **D3b: voice clips** | The recorder + transcript gate + AAC. `ClipStore`. Clip-first playback with lip sync and barge-in. Live-once-then-save. Clip-aware decks. Bundled common lines. The hit-rate log | Replays in her recorded voice |
| **D4: iCloud** | The CloudKit container + CKSyncEngine. The record types. Merge rules. iCloud-off, quota and account-change states. The privacy copy. The Production schema checklist | Games on every family iPad |

D1 and D2 can switch places. D3a must come before D3b. D4 can come any time after D1; it's put last because it's
the only round that needs Haylee's Apple Developer account setup (the CloudKit container).

---

## 9. Open questions only Haylee can answer

1. **An offline line she never said** (D4.6): with no network and no clip, she stays quiet and the line shows as text
   (with bundled common-line clips covering the generic ones). OK, or should offline replays be blocked or warned?
2. **Extras' part in the play** (C1): extras get only optional steps, never their own scene or a hand-off (so the
   game always works at 1–2 kids). Enough for a 5- or 6-kid game, or should extras sometimes lead a short scene when
   they're playing?
3. **The shelf's look and place** on the start screen (D6): a card row along the bottom, cards showing the sign art.
   Claude will mock it up before D1. Any direction first?
4. **The Grown-ups gate** (D6): hold 2 s + "tap the number forty-seven" (strong enough for Apple's Kids Category). OK,
   or another style?
5. **iCloud setup:** D4 needs the CloudKit container on Haylee's Apple Developer account (`iCloud.app.pretendthat`)
   and her OK on the Production schema before release.

## 10. Haylee's answers (2026-11-15)
1. **Offline, unrecorded line on a replay:** ask to go online. A friendly note asks a grown-up to connect to Wi-Fi so Nutmeg can talk, and the game pauses on that line until the connection is back (it doesn't show it as silent text).
2. **Every role gets called out (CHANGED, Haylee):** kids would feel left out otherwise. Every role that's playing (1–6) gets its OWN checklist steps, called out by role name, in every scene, never optional extras. [Claude's interpretation: each scene's checklist has at least one step per playing role. Hand-offs rotate through all playing roles across the scenes, so each kid gets a turn holding the iPad. Claude generates per-role steps for all 6 ranked roles, and the app shows the steps for the roles currently playing. That still means no AI calls on a count change.] This supersedes the 'only R1/R2 lead; extras get optional steps' parts of section C.
3. **Parental gate:** hold 2 seconds, then tap the number that's spelled out (for example "forty-seven").
4. **Shelf mockup and CloudKit:** Claude's suggestions accepted. Mock up the shelf first. Build saving on the iPad only first, and add iCloud sync once Haylee joins the paid Apple Developer Program.
