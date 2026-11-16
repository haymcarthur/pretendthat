# Round D3b: Nutmeg's real recorded voice on replays (voice clips)

**Date:** 2026-11-15 · **Decided by:** Haylee (replays use her REAL recorded voice, never the system / TTS voices, her
voice never changes; only app-scripted lines are recorded; answer 1: offline + a never-said line = a "please connect
to Wi-Fi" note and the game pauses on that line). Details are Claude's calls, noted. Design:
[saved games + replay design §D4, §10](../../docs/superpowers/specs/2026-11-15-saved-games-replay-design.md).

## Haylee's decisions (built)
- **Recorded:** only the app's own scripted lines (everything `NutmegSpeaker.say` sends as `sayExactly`: scene intros,
  checklist lines, cheers + congratulations, hand-offs, Repeat read-outs, print-ready / Paper / Draw it! lines, rail
  arrivals, the save line, the replay lines, The End). **Never:** the kid's mic audio, her conversational replies, the
  silence reminder, a safety steer, or any transcript.
- **Replays play her recorded clip** through the same speaker pipeline. **Never the device voice on a replay** (the D1
  "lines use the device voice" fallback and the Repeat AVSpeech fallback are gone for replays).
- **A line with no clip** (a role that didn't play before, the replay's own lines) is said live once in the same voice,
  then saved to the game.
- **Offline + no clip (answer 1):** a card "Nutmeg needs the internet … Grown-ups, please connect to Wi-Fi so Nutmeg can
  talk!" covers the stage (no taps reach the game; a "Leave the game" button), Nutmeg says the note in her own bundled
  recorded voice, and the game waits on that line. When the network is back, the voice reconnects, she says the owed
  line live (it's saved) and the card goes away.

## Claude's calls
- **Recorder (`ClipRecorder`, NutmegCore):** a recorded line's `sayExactly` carries `metadata: {pt_line: <tag>}`
  (checked live: response.created echoes it; metadata isn't model input, so the cached prefix is unchanged). Only a
  response with a tag the app issued is captured; its raw PCM16 24 kHz audio (before Varispeed) is buffered. Kept only
  if: status `completed`, not cut by a barge-in, **her output transcript matches the line after normalizing** (case,
  punctuation, apostrophes, &/and, numerals ↔ words), and 0.4–30 s after trimming silence (60 ms kept each side).
- **Key** = SHA-256 of `v1|voiceID|normalize(text)` (first 32 hex); lookup is by normalized text, so a clip from an
  older voice ID still plays (her voice never changes inside a game). Role and kind are metadata only.
- **Format: AAC-LC 24 kHz mono 32 kbps in an ADTS stream (`clips/<key>.aac`)**, not `.m4a`: the m4a writer reserves
  32 KB of header per file (a 1 s line was 37 KB); ADTS has none (~4.2 KB/s). The encoder's 2112 priming samples are
  trimmed on decode.
- **Storage:** first play: clips are held in memory for this game; Save writes them into the game folder with
  game.json's `clips`; Leave / New game drops them. Saved game (after Save and on every replay): a new clip is appended
  at once (`SavedGameStore.addClip`, first one for a key wins). `touch` now reads/writes under the lock.
- **Playback:** `NutmegSpeaker.say` is clip first → live (recorded) → `.waitForNetwork` on a replay. `playClip` feeds
  ~100 ms chunks into the ONE `schedule` path: same player → **Varispeed 1.20 applied once** (clips are stored
  pre-Varispeed; the timeline divides by the same rate), same lip sync analyzer, same speaking state, same barge-in
  `cancel()`. The chat gets her bubble (Repeat: none). The thinking face is skipped for clips. `stopSpeaking` stops a
  clip even with no session. The speaker's engine runs on its own during a replay (`holdEngine`, `startForClips`),
  so clips play before the voice connects, offline, and through a dropped session; the session only adds its mic tap.
- **Clip-aware lines:** cheers pick a praise/next-wording (or congrats + tail) whole line she already recorded; the
  Done! congratulations lead-in picks the variant whose whole line (lead-in + next line) was recorded.
- **Bundled common lines (9):** recorded LIVE from her real Realtime voice through the same recorder + gate
  (`-PTRecordCommon`, all 9 kept first try), shipped as `Resources/CommonClips/common-<key>.aac` (~140 KB): the Wi-Fi
  note, print ready, back to the checklist, the Paper question, the print screen line, "This is a saved game!",
  "How many friends are playing this time?", "No problem, we'll pretend!", "Almost ready!". No TTS anywhere. (The
  design's ~40 lines were mostly parts of composed lines, which are never said alone, so only whole generic lines.)
- **Hit-rate log** (`ClipHitLog`, counts only): `REPLAY clips: hit x/y, game, bundled, live, saved, rejected, waited
  for Wi-Fi; per kind`, plus Realtime usage since the replay started (`RealtimeUsage` now parses audio-out tokens).
- **DEBUG:** `-PTOffline`, driver `#offline` / `#online` / `#waitwifi` / `#clips` / `#waitclip`, `-PTNoClips` (the D1
  all-live baseline for the cost check). The driver's playthrough now waits for her line to start before the next tap.

## Tests and live checks
- NutmegCore **363 green** (+18 `RoundD3bVoiceClipsTests`: normalize table, keys, the transcript gate incl. "tap
  Start", recorder keeps only tagged/completed/matching lines and rejects cancelled/partial/short/long/paraphrased,
  tagged sayExactly is byte-identical apart from metadata, trim + chunks, index + older voice, routes, the Wi-Fi pause
  state, live-once-then-saved through the store, kinds/roles, clip-aware cheers/decks/lead-ins, a whole replay ×4
  (2nd at 3 = 100%, 1st at 5 partly live, 2nd at 5 = 100%), privacy: untagged replies never captured, a tagged line
  that says kid text is rejected, clip JSON fields locked, files only under clips/).
- Live typed runs on PT-R15-iPad (`/tmp/pt-roundD3b/`), "Bakery for Cupcakes and Cookies":
  - **A** first play at 3 → Save: 12 clips (572 KB) saved with it (+ the save line after). The fast driver cut the
    between-scene hand-offs, so those weren't recorded (fixed in the driver for later runs).
  - **B** replay at 3: **13/20 clips (65%)**; the 7 live (replay-only lines, the 3 cut hand-offs, The End's replay
    wording) were all saved. **C** the same replay with clips off (D1 baseline): 0/20, all live.
  - **D** replay at 5: **16/20 (80%)**: live once = the five-friends count line, the longer read-out, the 2 new roles'
    hand-offs; all saved. **E** replay at 5 again: **20/20 (100%), 0 Realtime responses.**
  - **Cost (Realtime, same replay):** D1 live voice 20 responses, 4,034 audio-out tokens (≈ $0.34 at assumed
    gpt-realtime list prices) → first clip replay 7 responses, 1,237 (≈ $0.11) → a replay with every line recorded
    0 responses, $0. Claude / image calls 0 in every replay.
  - **Barge-in on a clip** (a check tap during the Repeat read-out clip): player cleared in 1.7–11 ms (+10 ms output
    latency), chat line cut with "…", the new cheer clip plays. **Lip sync on clips:** peak mouth level 0.70–1.00 per
    clip (same metric as D3a's live lines). **Repeat** replays the read-out clip.
  - **F** offline replay at 6: greeting clip played; the never-said six-friends line → Wi-Fi card + her bundled note,
    paused; `#online` → voice reconnected, the line said live and saved, then Props / Paper / Play went on from clips.
- **Storage:** the game is 2.6 MB with 25 clips (260 s of her voice, 1.1 MB) + art 1.2 MB; 572 KB of clips after the
  first play.

## Not verified
- Listening by ear (seams, AAC quality) — Haylee's listening test; a real device (mic permission before the clip-only
  engine starts, route changes, background during an offline replay); a real network loss (only the in-app switch was
  used; `NWPathMonitor` is wired but untested); the no-printer Draw it! lines on a replay live; dollar figures are
  estimates from token counts, not billing.
