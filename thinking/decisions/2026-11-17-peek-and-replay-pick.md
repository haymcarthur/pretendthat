# iPhone peek over the scene card, Replay Pick without tiles, offline replays never block, no plain-paper props

**Date:** 2026-11-17 · **Decided by:** Haylee (the four asks below); Claude's calls are marked.

## 1. iPhone play scenes: Nutmeg peeks over the scene card (Haylee)
- iPhone only, play scenes only (setup, scenes, clean-up rows). Prop hunt, kit and The End are unchanged (Haylee: they're fine). iPad unchanged (checked before/after).
- Art: Haylee's Figma logo frame, `design/nutmeg/peek/nutmeg-peek-parts.svg`. Split by group with no shape edits (`tools/split_peek_parts.py`) into two vector imagesets on the same 1536×1024 canvas: `nutmeg-peek-back` (tail + body) and `nutmeg-peek-paws` (paw-left + paw-right). The art's static `head` group isn't in the app.
- Layering: tail + body BEHIND the card, paws IN FRONT of its top edge, and her real rig head on top of the body: head-base, the **focus eyes** (looking down at the rows), her mouth, the headset. She blinks and her mouth moves when she talks (same Motion as the stage rig). (`NutmegPeek` in NutmegCharacter.swift.)
- **Claude's call: head fit.** The rig head lines up with the peek body at 0.6 scale, turned −5°, the rig nose at art (795, 314), so no fallback to the static head was needed. The peek art's own head is a slightly different drawing (its right ear sits a bit wider), so the rig head isn't a pixel-exact match of the logo, but the neck/chin sits cleanly on the vest at the card edge.
- **Claude's call: size rule.** She's as big as the rows allow: 66% of the card width when it fits, stepping down (62, 58 … 34%) only when the rows wouldn't fit without scrolling. iPhone 18 Pro: 4 rows at 66%, 5 rows ~54%, 6 rows ~42% (all without scrolling). A new densest row tier for the phone (16 pt text, 30 pt pictures, 36 pt 🔊; the whole row stays the button) is the last step before she shrinks. Ears keep 6 pt of air under the top bar. The stage Nutmeg hides during these scenes and the card zone is the whole band.
- Small iPhone (SE 3rd gen, 375×667): 3 rows fit; 4–6 rows scroll inside the card (a cut-off row shows there's more; the scroll bar flashes on appear). Before this change the SE was worse (huge text, one row and a half visible).

## 2. Replay Pick: no number tiles, ever (Haylee)
- The 1–6 tiles are gone. With no voice session (offline, voice down, no keys) the kid types (chat) or speaks (on-device speech, offline) and the app reads the count ON THE DEVICE (`ReplayCount`): "3", "three", "we have four", "4 kids", "just me" = 1, "me and my sister" = 2, "me and 2 friends" = 3. Nothing is sent anywhere (no Claude, no moderation call): only the number is used. With a voice session nothing changes.
- 0 or more than 6: a text hint "I can play with 1 to 6 friends!" (chat only, never spoken: it isn't recorded) and her recorded question again ("How many friends are playing this time? Tell me!", a bundled clip). No number: the recorded question again. **Claude's call:** the kid's own answer shows in the chat (after the instant local filter).
- Checked in the simulator (no keys): typed "ten" → hint + re-ask; typed "we have four" → Props. The mic press on a simulator without speech permission shows the grown-up note with "Type instead" (no dead end); the spoken words take the same path as typed ones.

## 3. Offline replays never block (Haylee via the coordinator, from a live test game)
- A game's FIRST offline replay dead-ended on the full-screen "Nutmeg needs the internet" box (its greeting and count lines were never recorded). Now a line with no clip and no voice is shown as her text (a caption at the top of the stage and a chat bubble), a recorded generic line plays when one fits (the "How many friends…" question for the greeting, "No problem, we'll pretend!" for pretend lines), and the game carries on (`OfflineLine`, `LineRoute.caption`). Repeat does the same (caption again).
- It's recorded later the normal way: the next time she says that line live (any later replay with a voice session). **Claude's call:** no separate "say the owed lines once the Wi-Fi is back" queue.
- This supersedes Haylee's answer 1 (the Wi-Fi pause) for replays. The `PTWiFiNote` view and `WiFiPause` type are still in the code but nothing pauses on a replay any more.

## 4. Plain paper is never a prop (Haylee via the coordinator, from a live test game)
- "Paper" became the "recipe sheet" (a printed thing). Plain paper is retired from the prop library (kept in `retired` so old saved games still show its name and art), its tags and curated uses are gone, and `PropLibrary.isPlainPaper` rejects paper / cardstock / a sheet of paper / printer, construction or newspaper by name. Paper THINGS stay: paper plate, paper bag, paper towel tube.
- Printed-word rules: "recipe", "worksheet", "printout", "handout", "form" are printed things, and a "sheet" is printed when a printout word comes before it ("recipe sheet", "score sheet", "coloring sheet", "sheet of paper"). A plain "sheet" / "bed sheet" / "baking sheet" stays allowed (cloth, a tray).

## Tests
NutmegCore 669 → 681 (ReplayCountTests: parser, decide, on-device rule, the no-voice store path, a never-replayed game offline; PaperPropTests). Round 30/42/43 tests updated for the retired paper item.

## For Haylee to look at
- The 6-row size on iPhone 18 Pro (~42% of the card) is smaller than the 60–70% ask: with 6 rows there's no room for a bigger peek without scrolling. Options: accept, allow scrolling at 6 rows to keep her big, or a tighter row look.
- The offline caption is new on-stage text (it only shows on an offline replay, for lines she never recorded).
- Retake the App Store play-scene screenshot (05).
