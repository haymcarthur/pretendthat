# Paid-app project: everything talked through (2026-11-15)

Status: **queued, needs a design doc first** (Claude writes it, Haylee reviews, then build in rounds).
Decisions are in decisions/2026-11-15-paid-app-direction.md. This file is the full checklist so nothing gets lost.

## A. Kit and player fixes (small, can go first): **DONE R23**
- **Players capped at 6.** Count buttons 1–6; if a kid says more, Nutmeg says up to six friends can play.
- **Badges = the exact player count** (bug today: 2–3 players still get 6 badges).
- **Money = one $1 bill page.** Menu prices stay small whole dollars ($1–5). (A "More money" button was built in R23 and removed at Haylee's request.)

## B. Clearer navigation back to earlier steps: **DONE R23** (steps renamed Pick · Props · Paper · Play)
- Finished steps on the step rail look tappable: a picture icon (game / props / printer / play) plus a small ↺.
- ~~A "Print again" button on the checklist screen and The End~~ (built in R23, removed by Haylee: the rail's ↺ marks are enough).
- Voice: "print it again" or "go back to the props" works.

## C. Generate for 6 with ranked roles
- Every game generates 6 ranked roles (1–2 core, 3–6 extras), a 6-up badge sheet (one image, sliced), and checklist steps for extra roles marked optional.
- Show and print only the current player count.

## D. Saved games and replays
- At The End, "Save it to play again ⭐" replaces "Play again". Unsaved games are discarded.
- Saved on the iPad and synced with the family's iCloud (CloudKit private database). No accounts, no backend. Game content only, never anything about kids.
- A "My games" shelf on the start screen: big picture cards. **No shelf cap.** Grown-up-gated delete (long press, then confirm).
- **Nutmeg's real voice on replays:** record her scripted lines on the first play and replay the recordings. Never the system voices; her voice never changes. Live voice only for new interaction (or a role line never said before, which is then saved too).
- Replay path (same stage, **same step rail: Pick → Props → Paper → Play** (renamed R23); Haylee 2026-11-15): on replay, the **Game** step only asks how many are playing this time (1–6), then **Get Ready / Props** (the whole list at once: "still have these?", with missing ones becoming pretend swaps) → **Print** ("everything" / "just the badges" / "skip, we have them") → **Play**. No AI calls when the count changes.

## E. Paid app (iPad only to start; Android only if it clearly matters)
- Plans (to set from the measured cost per game): a free trial (about 2 new games), **Pro** (a monthly cap on NEW games, unlimited replays), and **Unlimited** (a generous fair-use number of new games). Optional one-time "new game" purchase.
- StoreKit 2 subscriptions. Enforce caps on the relay too (anonymous signed App Store transactions, no accounts).
- **Kids Category rules:** a parental gate before purchases and external links; no ads or tracking.
- Cost work first: test the smaller realtime voice model side by side (report only, no switch without Haylee's OK); re-measure the cost per game after round 20.
- **A small "Grown-ups" corner behind a parental gate** (not a full settings menu): Manage subscription, Restore purchases (Apple requires it), privacy policy, help/contact, and manage saved games. **No login or logout:** iCloud and App Store purchases use the device's Apple ID automatically.

## F. Printer question + no-printer "Draw it!": **DONE R24**
- "Do you have a printer?" after the confirm yes; no printer = a hand-drawn kit (no images, cheaper) with "Save printables for later".
- Still to do: App Store copy says "Works best with a printer; no printer needed."
- Props make sense (shape/function tags, a spoken reason): **DONE R24**.

## Small queued items
- The Zzz on the real asleep state: in round 22.
