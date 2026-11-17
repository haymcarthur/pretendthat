# Prop audit: why weird pairings still get through (2026-11-17)

**Question (Haylee):** in a live game Nutmeg said "Can you find a stuffed animal? It'll be the pet drying cloth!" Do we need
a more thorough audit so props never make weird pairings?

**Short answer:** yes, but we don't need a new system. The round-24 prop-fit check (`PropFit.swift`: tags per item, use
words → needed tags, one retry, then a curated fallback) is the right design. It has holes, and the stuffed-animal cloth
went straight through one of them. Six small fixes close most of the holes. Effort is about 1 to 1.5 days for one build
agent, and the extra cost is about 1¢ a game at most.

Research only: no app code changed, nothing committed, no paid calls. The checks below ran the real `PropFit` code from
a scratch package outside the project.

---

## 1. What actually happened with the stuffed animal

The check finds the use's "head noun" by reading the use's words **from the end** and stopping at the **first word it
knows**. "cloth" and "drying" aren't on any list, so it skipped past them to **"pet"**, which is on the creature list. A
stuffed animal is a creature, so the pair **passed**. That's the coordinator's guess, and it's confirmed:

```
PASS  stuffed-animal -> the pet drying cloth     [rule picked: creature]   ← should be rejected
PASS  stuffed-animal -> the patient's bandage    [rule picked: creature]   ← should be rejected
PASS  stuffed-animal -> the puppy's leash        [rule picked: creature]   ← should be rejected
PASS  stuffed-animal -> the pet shampoo          [rule picked: creature]   ← should be rejected
reject pillow -> the pet's food                  [rule picked: creature]   ← wrong rule (the use is food, not a pet)
```

So the problem is that **a describing word gets read as the thing itself** ("pet" in "pet drying cloth"). It isn't only
the "unknown use is allowed" default. Even with no "pet" in it, "the drying cloth" or "the grooming towel" would have
passed anyway, because unknown uses are allowed.

Two more things made it worse in that game (Pet Groomer in a Treehouse, round 42 log):
- **The game lost its pet.** A pet groomer game with a stuffed animal should make it *the pet*. Instead the pet became
  a cloth and the game had no pet prop at all.
- **The spoken reason didn't help.** "A stuffed animal can be a pet drying cloth!" just repeats the pair. The app keeps
  any 3-to-14-word reason that passes the kid-safety filter, even when it explains nothing.

---

## 2. Real examples: every pair I could find

Sources: saved games on the test simulators (PTi-iPhone17e, PTi-iPhone18Pro, PTi-iPad13, PT-Site-iPad/iPhone, PT-R39,
PT-R40, PT-R41 ×3; PT-R15 has none; Haylee's AF512F6A / 1820E3FA not opened) and Nutmeg's spoken prop lines in
`/tmp/pt-round*/` logs (about 75 different pairs). Most saved games on R39–R41 are the **bundled airplane game re-titled
by the test seeder** (for example "Pet Vet" with airplane seats). That's a test artifact, not real output, and isn't
counted below.

**Fine (most of them):** sheet → the pirate sail · cardboard box → the treasure chest · chair → the airplane seats ·
hat → the captain's hat · tray → the snack cart · towel → the pet bed · apron → the baker's apron · baking sheet → the
cookie tray · flashlight → the guard's flashlight · stuffed animal → the baby dinosaur · blanket → the dino nest ·
bag → the animal carrier · basket → the pet carrier · table → the grooming table · bowl → the feeding dish.

**Odd ones (flagged):**

| Pair seen | Game | What's wrong | Does today's check catch it? |
|---|---|---|---|
| stuffed animal → the pet drying cloth | Pet groomer | wrong material; the pet is lost | no ("pet" read as the head) |
| plastic cup → the lookout scope | Rainbow pirate ship | a cup isn't long or a tube | no ("scope" unknown → allowed) |
| towel → the cooling rack | Bakery | a towel isn't a rack | no (unknown) |
| towel → decorating cloth | Bakery | vague, no real job | no (unknown) |
| pillow → the moon counter | Moon bakery | a soft pillow as a counter | no (pillow is tagged flat) |
| tray → the check-in desk | Vet / hotel | a tray is far too small for a desk | no (flat is enough) |
| bowl → the robot repair hub / tray | Robot shop | "hub" is abstract; bowl isn't a tray | hub: no · tray: yes |
| tray → the sorting station, basket → supply sorter | Shops | abstract "station/sorter" | no (unknown) |
| plate → our moon-ship steering wheel *for the bakery* | Moon bakery | the theme leaked in; a bakery has no wheel | yes by shape; game fit isn't checked |
| bowl → the mixing bowl | Vet Clinic for Sea Animals | a bakery prop in a vet game | game fit isn't checked |
| paper → the patient chart | Vet Clinic (before round 42) | a printed thing | yes now (round 42) |
| backpack → Suitcase | the **bundled** airplane game | the kit also prints a Suitcase cut-out | no: bundled data is never checked |

"bowl → the mixing bowl" is the most common pair in the logs (12+ times, across bakeries, a vet clinic and a pet
groomer as "soap mixing bowl"). The realtime instructions use it as their example ("a bakery: a bowl for the mixing
bowl"), and the model copies it into games where it doesn't belong.

---

## 3. Every place a prop is picked or checked

| # | Where | What it does | Checked by PropFit? |
|---|---|---|---|
| 1 | Realtime instructions (`RealtimeProtocol.swift`): PROPS ARE NEVER PRINTED THINGS, PICK PROPS FOR THIS GAME, prop safety, soft household items | guidance | prompt only |
| 2 | `show_next_prop` tool: item id from the 60-item list (enum), `becomes`, `alternates`, `reason` | **fits + printed check**, 1 retry, then `sensibleFallback` | ✅ |
| 3 | Recent-props swap (`RecentProps.fresher`): an item used in the last 5 games gives way to a fitting alternate | fits only | ✅ (but loose tags let odd alternates in) |
| 4 | `swap_prop` (kid: "we don't have one") | fits + printed, 1 retry, then fallback | ⚠️ **bug, see F3** |
| 5 | `skip_prop` → pretend card + printed cut-out | none needed | n/a |
| 6 | Tap path: Claude's prop list (`Prompts.props` → `Validate.props` → `PropFit.repair`) | fits, 1 re-ask, then repair | ✅ (repeats not checked) |
| 7 | Guide weave (`GuideWeave.prompt/apply`): each prop worked into 1–3 tasks + setup/clean-up jobs | text only | ❌ (but it gets "a X that becomes Y", so it follows whatever the pair is) |
| 8 | `GuideWeave.finalize` after swaps/skips: step picture is the prop only if it still fits | fits (for the picture) | ✅ |
| 9 | Replay ✗ → the saved alternate | none | ❌ (alternates were filtered once, but not again after a swap changed the use) |
| 10 | Bundled airplane game (`airplane-fallback.json`), and the "guide failed" fallback, which uses the **airplane scenes for any game** (`AdventureStore` line ~1340) | none | ❌ |
| 11 | Kid-safety filter on `becomes` / `reason` (round 21 gate; blocks "medicine" and others) | safety | separate, works |
| 12 | Round-42 printed filter (`PrintedProps`): by word + by this kit's own pages | inside `fits` and the store | ✅ |

The voice path can't name anything off the list (the item id is an enum), so off-list items aren't a real risk there.
The 60 items are 30 from round 24 plus 30 from round 30.

---

## 4. Failure taxonomy (the kinds of weird pairing)

| # | Kind | Example | Today | After the fixes |
|---|---|---|---|---|
| A | **Describing word read as the head noun** | stuffed animal → the pet drying cloth; pet's food → creature rule | passes / wrong rule | head = last word, possessives skipped (F1) |
| B | **Unknown use word = allowed** | cup → the lookout scope; towel → cooling rack; box → cash register | passes | more words + "identity items" (F2, F4) |
| C | **Missing words / plurals** | 24 of the 110 *curated* uses have a head the rules don't know (gloves, boots, goggles, keys, wall, tower, snowball, jug, sash, portal…); "brushes", "boxes", "puppies" don't fold to singular (only a trailing "s" is dropped) | treated as unknown | vocabulary + shared `singular` (F2) |
| D | **Tags too loose**: "wearable" doesn't say *where* | sneakers → the knight's helmet ✔, mittens → the crown ✔, ball → the crown ✔ (all PASS today) | passes | where it's worn (head/hand/feet/face/back/body) (F4) |
| E | **Size ignored** | egg carton → the rocket ship ✔, books → the boat ✔, tray → the check-in desk ✔, paper → the tent ✔ | passes | rides and shelters need `big`; desks and counters need a real surface (F4) |
| F | **Wrong material** | paper → the superhero cape ✔, rug → the cape ✔, pillow → the moon counter ✔, sticky notes → the shop counter ✔ | passes | a `fabric` tag; `flat` alone no longer makes a counter (F4) |
| G | **Swap worse than the original** | no item fits "the patient" except the stuffed animal → the swap fallback keeps **only the item** of an unrelated curated pair: the card says **"Pillow → the patient"** (traced: fallback = pillow/"the shield", swap keeps "the patient") | bug | nothing fits → pretend card (F3) |
| H | **Same item or use twice** | `show_next_prop` and `swap_prop` accept an item already in this hunt (the second card gets id "bowl-3"); two "treasure chests" aren't caught | allowed | reject repeats, 1 retry then fallback (F5) |
| I | **Printed item** | paper → the boarding passes; the bundled game's backpack → Suitcase + a Suitcase cut-out | fixed in round 42, except bundled data | test the bundled game (F6) |
| J | **Doesn't fit the game** | bowl → the mixing bowl in a vet clinic; a steering wheel in a bakery | prompt only | prompt fix + identity items keep the stuffed animal as the pet (F4, F6) |
| K | **Abstract use** | bowl → the robot repair hub; tray → the sorting station | passes | abstract heads count as unknown (identity items reject them) (F2) |
| L | **Unsafe or iffy items on the list** | lamp (unplugged) has a cord and a bulb, and its reason says it "lights up"; jump rope ("rope" is on the off-list unsafe list); lamp → the sword passes | allowed | question for Haylee (drop the lamp, keep the jump rope on the floor only) |
| M | **Not in most homes / toy-like** | doll bed, toy keys, toy broom, wagon, hula hoop, sidewalk chalk | allowed by design (round 30) | optional: a `common` flag so the first prop and fallbacks prefer everyday things |
| N | **Used once, never again** | weave gives each prop 1–3 tasks; the setup/clean-up jobs name every prop (round 36/40) | already covered | none |
| O | **Too big or heavy** | table, couch, rug as hunt items | furniture: "find a table" is fine | none (keep as is) |

---

## 5. Proposed fixes (to the existing `PropFit`, no parallel system)

### F1. Head-noun parsing (fixes A)
- The head noun is the **last word of the head phrase** (before for/of/with…), and only that word. Don't walk back to
  earlier words. "pet drying cloth" → cloth; "pirate ship sail" → sail; "treasure chest" → chest; "soap mixing bowl" → bowl.
- A possessive ("pet's", "patient's", "captain's") is never the head: "the pet's food" → food, "the captain's hat" → hat.
- Use `PrintedProps.singular` for plurals in `PropFit` too (boxes, brushes, puppies, benches). Today `PropFit` only
  drops a single trailing "s".

### F2. Vocabulary (fixes B, C, K)
New and extended use words, each pointing at the tags it needs:
- **cloth** (needs `fabric`): cloth, rag, napkin, towel, bandage, bib, diaper, tablecloth, sash, leash, blanket-as-a-cover.
- **glove** (`hand`): glove, gloves, mitt. **boot** (`feet`): boots, shoes, skates, flippers. **goggles** (`face`):
  goggles, glasses, mask.
- **keys** (`keys`, only toy keys): key, keys. **wall/tower** (`rigid` or `big`): wall, walls, tower, gate, fence, door.
- **panel** (`surface`, `boxy`): panel, console, dashboard, controls. **desk** joins counter, with `rack` and
  `stand` (needs a real surface).
- **round things**: snowball, apple, egg, ball (`ball`, soft). **tube** (`long` or `tube`): scope, telescope, horn.
- **pour**: jug, pitcher, watering can (`container`). **portal/hoop** (`ring`). **cloud** (`soft`).
  **suitcase/luggage** (`container`, carried).
- **abstract heads**, which count as unknown: hub, station, area, zone, spot, center, sorter, thing, stuff, helper,
  machine.

Target: every curated use's head is a known word (today 24 of 110 aren't).

### F3. Swap fallback bug (fixes G)
In `swap_prop`, when the second try still doesn't fit, the code takes only the **item** from `PropFit.fallback`, which
can be a curated pair for a *different* use, and keeps the old use (`newID = PropFit.fallback(...).itemID`). New
behavior:
1. Take the first library item that fits **the same use** and isn't already in the hunt.
2. If none fits, **turn it into a pretend prop**, the same as `skip_prop` (the kit prints its cut-out). This is what a
   kid who has no stuffed animal for "the patient" expects. Never show a random pair.

The replay ✗ path re-checks its saved alternate with `fits` before offering it.

### F4. Better tags, plus "identity items" (fixes B, D, E, F, J)
Small, targeted changes to `PropTag`. Most items keep their tags.
- **Where it's worn** replaces `wearable` in the needs: `head` (hat, bowl, pot, colander, bucket, headband), `hand`
  (mittens, oven mitt, sock), `feet` (sneakers), `face` (sunglasses), `back` (backpack), `body` (apron, scarf, towel,
  blanket, sheet, pillowcase). `wearable` stays as the umbrella tag for the spoken reasons.
- **`fabric`** (new): towel, blanket, sheet, pillowcase, apron, scarf, sock, mittens, oven mitt. Capes, sashes and cloths
  need it. Paper and the rug lose `sheet`, so paper is no longer a cape or a tent.
- **Round is split**: `disc` (plate, paper plate), `ball` (ball), `ring` (hula hoop, headband, tape). Crowns need a ring
  or a head item, a planet or snowball needs a ball (or a sock), and a wheel needs a disc, a ring or a two-hand grip.
- **Size**: rides need `vehicle`, or `big` together with sittable/boxy. That rules out the egg carton rocket and the
  books boat. Shelters need `big`. Counters, desks and stages need `surface` (table, stool, tray only for a snack cart
  or tray, baking sheet, box), and `flat` alone (pillow, paper, sticky notes) no longer counts.
- **Identity items**: a few things are so clearly themselves that they may only become what they're shaped like, and
  unknown or abstract uses are rejected for them:
  stuffed animal → only creatures (pet, patient, baby, passenger, customer) · sneakers → feet · mittens, oven mitt,
  sock → hand (sock also a puppet or snowball) · sunglasses → face · toy car → vehicles · toy keys → keys · ball → round
  things · crayons, chalk → drawing or a small wand · flashlight → lights or a scanner · umbrella (closed) → cane, wand ·
  jump rope, hula hoop → floor shapes (hoop also a portal or wheel).
  Everything else (box, blanket, sheet, towel, pillow, bowl, cup, tray, plate, basket, bucket, container, bags, tube…)
  stays **flexible**: an unknown use is still allowed (and logged in DEBUG as "PROP unknown use"), so kids' creative
  pairs aren't turned away.
- The kept reason has to explain something: if the model's reason just repeats the pair ("A stuffed animal can be a pet
  drying cloth!"), use the app's tag-based reason instead.

**Common uses → what they need** (one table for the prompt and the code):

| Pretend use | Needs (any one) | Good | Rejected |
|---|---|---|---|
| hat, helmet, crown, tiara | head (crown also ring) | bowl, pot, colander, hat, headband | sneakers, mittens, ball, plate |
| cape, sash, robe, apron | fabric + body | towel, blanket, sheet, scarf, pillowcase, apron | paper, rug |
| cloth, rag, bandage, napkin, tablecloth | fabric | towel, sock, scarf, pillowcase | stuffed animal, paper |
| glove(s) / boots / goggles | hand / feet / face | mittens, oven mitt / sneakers / sunglasses | anything else |
| pet, patient, baby, animal, dragon | creature | stuffed animal | towel, pillow |
| bed, nest, pet bed | fabric, cushion, container | blanket, towel, pillow, box, basket, doll bed | stuffed animal |
| boat, rocket, car, train, plane | vehicle, or big + sittable/boxy | box, laundry basket, wagon, chair, couch | egg carton, books |
| tent, cave, fort | big + sheet, or big | sheet, blanket, table | paper, scarf |
| counter, desk, stage, panel, console | surface | table, stool, box, baking sheet | pillow, paper, sticky notes, tray (desk) |
| chest, carrier, cage, suitcase, pot, cauldron | container | box, basket, bag, backpack, pot, bowl | flat things |
| sword, wand, oar, mast, microphone, spoon, stirrer | long | paper towel tube, wooden spoon, broom, umbrella | lamp |
| telescope, scope, spyglass | long or tube | paper towel tube, flashlight | cup |
| wheel, dial | disc, ring, grip | plate, paper plate, hula hoop, baking sheet | ball |
| shield | disc, flat + rigid, or soft-flat | pillow, baking sheet, plate | ball, tape |
| ocean, river, lava, path, finish line | sheet, surface, outline | blanket, sheet, rug, tape, jump rope | stool, table |
| planet, snowball, apple | ball, soft-round | ball, sock, scrunched paper | hula hoop |
| light, lantern, scanner | light | flashlight | lamp (if removed) |

### F5. No repeats in one hunt (fixes H)
`show_next_prop` and `swap_prop` reject a library item that's already a card in this hunt, and reject a use that's
already a card ("the treasure chest" twice). Same one retry, then the fallback skips used items, which it already does.
`PropFit.repair` (tap path) does the same.

### F6. Bundled data and prompts (fixes I, J)
- A test runs the bundled airplane game through `PrintedProps.clash(kit:)` and `fits`. Fix the data: backpack →
  "the carry-on bag", or drop the Suitcase cut-out.
- The "guide failed" fallback shouldn't put airplane scenes into a non-airplane game. It should fall back to the
  whole airplane game, as `useFallbackGame` does, or retry once more. That's outside prop pairs, so it's only noted here.
- Realtime instructions: swap the anchoring example ("a bakery: a bowl for the mixing bowl") for a rotating set of
  examples drawn from today's game, and add one line: "If the game has animals or patients, the stuffed animal is the
  animal or patient, never a thing for it." The model also gets one sentence of the tag table ("cloths and capes are
  fabric: towel, blanket, sheet, scarf").

### What the model gets on a rejection
The existing `retryOutput`, with the reason named and the item's own good uses listed:
> Not shown: a stuffed animal can't become the pet drying cloth (a cloth needs fabric). Say nothing yet: call
> show_next_prop again with an item that fits, e.g. towel, sock, pillowcase, or keep the stuffed animal as what it
> really is: the pet, the patient. Add a short reason.

The second miss gets the app's fallback, as today. With F3, a swap with nothing that fits becomes a pretend prop.

### Tests (table-driven, in a new `PropAuditTests`)
1. **Pair table** of about 60 rows, each item + use + expected verdict + the rule picked. It includes:
   stuffed animal → the pet drying cloth ✗ (rule: cloth) · → the patient ✓ · → the pet bed ✗ · → the puppy's leash ✗ ·
   pillow → the pet's food (rule: food, not creature) · sneakers → the knight's helmet ✗ · mittens → the crown ✗ ·
   egg carton → the rocket ship ✗ · paper → the cape ✗ · pillow → the moon counter ✗ · cup → the lookout scope ✗ ·
   towel → the drying cloth ✓ · box → the control panel ✓ · paper towel tube → the lookout scope ✓.
2. **Golden pairs from real logs**: the ~75 observed pairs in section 2, with the fine ones still passing. This guards
   against turning good, creative pairs away.
3. Every curated use passes `fits` **and** has a known head word (today 24 don't).
4. Plurals: boxes, brushes, puppies, benches fold to singular.
5. `swap_prop` with nothing fitting ("the patient", no stuffed animal) → a pretend card, never "Pillow → the patient".
6. Repeats: the same item or use twice in one hunt → retry, then a different item.
7. The bundled airplane game passes the printed + fit checks.
8. A replay ✗ alternate always fits the current use.

---

## 6. Effort and cost

| Piece | Effort |
|---|---|
| F1 parsing + plurals, F3 swap bug, F5 repeats, F6 bundled-game test | ~0.5 day |
| F2 vocabulary + F4 tags/identity items, re-checking the 110 curated uses and reasons | ~0.5–0.75 day |
| Tests (pair table, golden log pairs, store paths) + fixing older round-24/30/42 tests that move | ~0.25 day |
| Prompt lines + one short live check (typed, 2 games: a vet/pet game and a pirate game) | ~0.25 day |
| **Total** | **~1–1.5 days, one build agent** |

**Cost:** a rejected prop costs one extra silent realtime response. At round 42's measured rate (24 responses ≈ 24.6¢)
that's about **1¢ per retry**, plus about 0.5–1 s before she speaks. If the stricter rules turn away about 1 prop in 5,
that's about 1 retry a game, so **≈ +1¢ a game** (about 2% of ≈ 53¢). F3 and F5 add no calls; the second miss is handled
by the app. The live check costs about 50¢ (one keyed run).

---

## 7. Questions for Haylee
1. **Identity items:** is it OK that a stuffed animal can *only* be a creature (pet, patient, baby, passenger), never a
   thing (cloth, pillow, bed)?
2. **Swap with nothing that fits:** when the kids don't have the only item that works (no stuffed animal for "the
   patient"), should it become a pretend prop with a printed cut-out (my pick), or should Nutmeg pick a different
   prop altogether?
3. **Unknown uses on flexible items** (box → the control panel, blanket → the castle walls): keep allowing them (my
   pick; most are good), or make the model always retry with a known word (about 1–2¢ more a game, and fewer creative
   pairs)?
4. **Lamp (unplugged):** remove it from the list (cord + bulb, and it can't light up)? And keep the jump rope only as a
   floor shape (river, finish line)?
5. **Toy-ish items** (doll bed, toy keys, toy broom, wagon, hula hoop, chalk): keep them as they are, or prefer
   everyday things for the first prop and for fallbacks?
