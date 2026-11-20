# Session handoff (2026-11-20 → 11-21): pick up here after the repo transfer

Read this after CLAUDE.md and before status-latest.md. Status-latest's MORNING SUMMARY has the Mac checklist. This file has the whole arc of the session, where everything lives, and the transfer steps.

## Where the code is
- All work is on branch **`claude/optimistic-allen-mifsgp`**, pushed, **not merged to main** and **not in a TestFlight build**. Last build on TestFlight is still 1.0 (4) (commit 933c6c6).
- The app files from these rounds were never compiled in the cloud (no Xcode there). Haylee built an earlier one-scene version on her Mac (it compiled and she played it). The scenarios/ownership, music-code and game-plan rounds came after that and are uncompiled; expect small fixes on the first Mac build.
- Next step after the transfer: pull, `xcodegen`, build, run the demo checks, play ONE live game (status-latest.md has the exact flags). Then decide whether to merge the branch to main (a PR) and cut a TestFlight build (only when Haylee says).

## How the session went (decisions in order; each links to its file)
1. **Family test of build 4** found a voice stall, no way back a scene, no skip on relaunch, tasks too long. → [voice-stall-fix](decisions/2026-11-20-voice-stall-fix.md) (same-game takes cache, lines-socket health + fallback, per-request cancel tags, suspended fix, watchdog).
2. **Checklists then scenario per scene** → [checklist-then-scenario-scenes](decisions/2026-11-20-checklist-then-scenario-scenes.md) and its build [round-checklist-scenes-build](decisions/2026-11-20-round-checklist-scenes-build.md). Thinner button edges: [thinner-button-depth](decisions/2026-11-20-thinner-button-depth.md). **Superseded for new games** by step 3 (old saves still replay).
3. **One 10-minute scene with music and Nutmeg's events** (Haylee and her husband's idea) → [one-scene-music-beats](decisions/2026-11-21-one-scene-music-beats.md), build [round-one-scene-build](decisions/2026-11-21-round-one-scene-build.md). Setup checklist → ▶ → events by beat (calm/tense, calm-again lines never credit the kids, fair calls) → finale → clean-up. No kid buttons in play except Pause (plus later: hear-again, End scene, music toggle).
4. **First live test of the one scene** → [events-are-scenarios-and-ownership](decisions/2026-11-21-events-are-scenarios-and-ownership.md), build [round-scenarios-ownership-build](decisions/2026-11-21-round-scenarios-ownership-build.md): events are scenarios to act out (not one-off gestures), the card stays up with 🔊 hear-again (no auto repeat), one owner per object, prop stand-ins (design/prop-stand-ins.md, approved), pretend-name wording, End scene, never-blocked checklist buttons, speakable check, music on/off, face-drift fix, and the **safety rule** (everything is pretend; hazards rewritten in the stored text, shown == spoken).
5. **Everything should flow and belong together** → [one-game-plan](decisions/2026-11-21-one-game-plan.md), build [round-game-plan-build](decisions/2026-11-21-round-game-plan-build.md): one plan call writes areas and every object's life cycle; setup by area; printouts get play jobs; traceability check; calm-stretch idea cards; one props call replaces the weave calls.

## Art (Figma)
- Figma file: `PretendThat`, key `8e4btNgdUzrGeaA6TYH8Zq`. Haylee's vectorized frames: alarmed `171:5`, phew `171:46`. The cleaned copies Claude made: `nutmeg-face-alarmed` (`173:2`) and `nutmeg-face-phew` (`175:2`): eyes, lashes and mouth only, no eyebrows, her palette.
- Exported to design/export/nutmeg/nutmeg-face-{alarmed,phew}.svg and imported with tools/import_art.py. **Careful:** a full import_art.py run also rewrites some unrelated assets (bookshelf Contents.json, focus mouth, writing crayon, sit-perky); revert those unless you mean to update them.
- Prompts that worked: design/nutmeg/faces-regen/prompts.md (v2: attach reference-ooh.png, "redraw this exact image, change only eyes/brows/mouth"). Phew eyes are placed to match her yay face.
- Mockups: design/mockups/checklist-scenes/ (superseded), design/mockups/one-scene/, design/mockups/area-setup/ (approved).

## Music (ElevenLabs)
- Account: Creator plan. About **30,000 credits left** this cycle; refill around **Dec 20**. Generation runs through the ElevenLabs MCP connector (music model eleven_music_v2_5, instrumental). Never re-run a node to retry (each run is charged).
- 14 families in PretendThat/Resources/Music/<family>/{calm,calm2,tense,win}.m4a plus the shared chime.m4a: space-adventure, jungle-outdoors, magical, cozy-shop, spooky-silly, under-the-sea, desert-western, superhero-city, pirate-adventure, rescue-team, snowy-north, robot-lab, circus-carnival, race-day. Takes, prompts (with flow ids), picks and loop tests are in design/music-test/<family>/. Processing scripts: tools/process_music*.py (loop to whole bars, sample-exact, −16 LUFS, AAC 96 kbps, MP4 edit list to avoid the encoder click). tools/make_placeholder_music.py never overwrites real music.
- **Waiting on Haylee's ear:** magical calm A→B→A (calm2 came out in C vs F; delete calm2 if it jars), the new magical win, the new superhero win, the race-day win (minor color), the circus tense (busy?). Robot win's ring-out is short.
- Ideas not done: more themes later if needed; a live check that calm → calm2 hand-over has no click.

## Cloud environment notes
- This session used a personal cloud environment named **"pretendthat"** that allows `elevenlabsusercontent.com` (needed to download music takes). Pick it for new sessions that download music.
- The container restarted twice during heavy Swift builds. Agents now build NutmegCore tests with `-j 1`, run only the relevant suites and commit small. A Linux Swift 6.0.3 toolchain + a NutmegCore harness lived in the session scratchpad (gone in a new session; the agents rebuilt it from Docker image layers since swift.org downloads were blocked). The harness skips Accelerate/SpeakerGraph/CloudKit and has 10 known environment-only failures.

## Still open
- Haylee's Mac build + demo checks + one live game (the game plan's real test: does it flow, are printouts used, cost per game from Console token lines, "PROP stand-in" and "[PLAN]" lines).
- The 5 music clips above.
- Merge the branch / TestFlight: Haylee's call.
- Older open items: thinking/open-questions.md.

## Repo transfer steps (Haylee)
1. Transfer `haymcarthur/pretendthat` (and `pretendthat-site` if wanted) on GitHub: repo → Settings → General → Danger Zone → Transfer ownership. History and all branches move with it, and GitHub redirects the old URL.
2. On the new owner account, install the Claude GitHub App with `pretendthat` selected, and link that GitHub account in claude.ai settings (Connectors / GitHub).
3. Start a **new** Claude Code session on the transferred repo (this session's GitHub access is tied to the old path). Pick the "pretendthat" environment if the work needs ElevenLabs downloads. First message: "Read CLAUDE.md, thinking/INDEX.md, thinking/session-handoff-2026-11-21.md and thinking/status-latest.md, then check out claude/optimistic-allen-mifsgp."
4. On the Mac, in the pretendthat folder: `git remote set-url origin https://github.com/NEW-OWNER/pretendthat.git`
5. Check anything that points at the old URL: the website, App Store Connect support/marketing links, the relay deploy.
