# Printables library: a custom kit per game (research, 2026-11-17)

Research only: no code changed, no API calls. Visual overview: [design/printables-library/index.html](../../design/printables-library/index.html).

**Short version**
- **The double frame on badges and tickets is built in.** The image prompt tells the model to *draw* blank banners, and
  then the app draws its *own* banners on top at fixed spots. The two never line up, so you see a box on a box.
- **The baked-in words on tickets are also built in.** The ticket prompt asks the model to *spell* the ticket's lines
  ("Boarding Pass", "Seat: Deck"). One image is then copied 8 times on the page, so every copy is the same, seat number included.
- **The fix is one rule:** the art is only a picture. No words, no frames, no blank boxes. The app draws every frame,
  field and word, in its own area *next to* the picture, never on top of it.
- **Then a kit can be custom:** a library of 17 printable types (6 of them are today's, reworked). The kit call picks
  4 to 6 that the scenes really use. Layout variants are drawn by the app, so they cost nothing.
- **Cost stays the same or goes down:** about 7 to 11 images a game instead of 13 (both styles + cover), because more
  pages reuse the two picture sheets the app already slices.

---

## 1. Why the badges and tickets look like a frame on a frame

What happens today (`NutmegCore/Sources/NutmegCore/KitLayout.swift`, `KitArtPrompt.prompt` and `badgeSheetPrompt`;
`PretendThat/Print/KitPageView.swift`, `KitCardView`):

| Step | What the code does |
|---|---|
| 1. Image prompt (badges) | "Every badge has a BLANK white rounded banner across its top quarter and a second BLANK white rounded banner across its bottom fifth". So the model **draws two outlined boxes** into the art. |
| 1. Image prompt (tickets, keycards) | "Leave a BLANK white rounded banner across the top quarter", **and also** "Spell these words exactly, in big rounded letters: ..." with the ticket's lines, plus "Show the big number or code". |
| 2. Page renderer | `KitCardView` puts the art down, then draws its **own** "Name: ________" capsule (white fill, 2 pt ink outline) at a fixed 5% from the top, 17% of the art's height. Badges also get a role-title box (white fill, 2 pt outline) at 6% from the bottom, 13% high. |
| 3. Result | The model's boxes are never at exactly those spots or sizes (in the saved Rainbow Pirate Ship badge, the model's top box starts about 13% down, under the clip hole). The app's white capsule covers part of the model's box, and the model's outline still shows around it: **two frames**. Badges are also sliced out of a 6-up sheet and trimmed, which moves the model's boxes further from the app's fixed spots (that slice also shows a sliver of the next badge's edge). |

Tickets have two more problems from the same code:

- **Baked-in text.** Claude writes the ticket's `lines` ("Mission Pass", "Secret Base Entry", "Agent Level: Super"),
  and the prompt asks the image model to spell them inside the art. The saved Rainbow Pirate Ship pass shows it: "Boarding
  Pass / Rainbow Pirate Ship / Seat: Deck / Trip: Treasure Island", all drawn by the model, plus an empty banner on top.
- **Identical copies.** Tickets are one image (`img_tickets`), and `KitLayout.pages` fills the page to 8 slots. Every
  slot gets the same image. The app does have per-copy seat numbers (`KitLayout.bigNumber`: 1A, 1B, 1C ...), but they
  are only drawn when there is no art (the app-drawn fallback). With art, the model's single number is the one you see on all 8.

The sign and menu use the same "spell these words" instruction. That is why the Spy Gear Shop price list came out
fine: when the model spells well, it looks great. When it misspells, or adds its own words, nothing can fix it.

**Root cause in one line:** the art and the app both try to own the same space (the banners and the words), so they
fight. **Fix:** the art never has words, frames or blank boxes. The app draws the card, its border, its fields and all
text, and puts the picture in its own box beside them. Even if the model ignores the rule a little, nothing overlaps.

---

## 2. What the saved games got (task A)

Read-only look at the test simulators (PT-R15-iPad had no saved games; PT-Site-iPad, PT-Site-iPhone and PTi-iPhone17e did).

| Saved game | Kit (title of each page) | Made sense? |
|---|---|---|
| Vet Clinic for Sea Animals | Sea Clinic Team badges · Seashell Sea Vet Clinic sign · Sea Bucks · Appointment Card · Clinic Care List ($1–5) · Sea Vet Tools and Treats | **Yes, all 6.** A vet fits the fixed set well. The appointment card has "Time: ____ / Animal: ____" fields, which the art would now draw badly; the app should draw them. |
| Rainbow Pirate Ship | Pirate Crew badges · Rainbow Pirate Ship sign · Pirate Dollars · Ship Boarding Pass · Ship Fun List ("Ship Ride $2, Map Reading $1, Treasure Hunt $3, Flag Coloring $1") · Pirate Treasure cut-outs | **Half.** Badges, sign and cut-outs are right. Paying $1 for "Map Reading" is forced, and a boarding pass is a stretch. A pirate game wants a **treasure map, gold coins and a captain's log** instead. |
| Sky Airlines | Crew Badge · Sky Airlines Gate 3 · Sky Dollars · Boarding Pass · Snack Menu · Travel cut-outs | Yes (this is the bundled airplane kit). |
| Pet Vet, Pirate Ship on the Moon, Moon Crumbs Bakery, Bug Theater | All have the **Sky Airlines kit** | Not real games: `DemoDriver` seeds shelf screenshots with the airplane kit under other titles. Not a bug, but don't use them as evidence. |

What the round 36/37 rules already ask for is "every page used on purpose", and the `purpose` sentences show the
strain: "Passengers pay for rides and snacks with them" on a pirate ship is the fixed set being bent to fit.

---

## 3. What each game would really use (task B)

The 42 games Nutmeg suggests come from `Suggestions.games` (`NutmegCore/Sources/NutmegCore/Suggestions.swift`; 3 a
session, plus a theme twist). Spy and superheroes are not on the list but come up often (spy through "detective" or a kid's own idea).

Codes are the library types in section 4. **Badges are in every kit.** The sign is in most kits, but not where there is
no "place" to name (treasure hunt, spy mission, mail route, bird-watching, weather report).

| Game | Picks (4–6) | Sign? | Why these |
|---|---|---|---|
| Restaurant | Badge · Sign · Menu · Order slips · Money · Cut-outs (food) | yes | Order, cook, serve, pay. Today's set minus tickets, plus order slips. |
| Vet clinic | Badge · Sign · Appointment card · Patient chart · Cut-outs (tools) · Stickers ("brave pet") | yes | Check in, check up, chart it, a sticker at the end. |
| Airplane trip | Badge (crew ID card) · Sign (gate) · Boarding pass · Passport · Snack menu · Cut-outs | yes | Today's airplane kit works; a passport with stamps adds a job. |
| Pirate ship | Badge (round pin) · Sign (ship flag) · Treasure map · Gold coins · Captain's log · Cut-outs | yes | Sail, follow the map, count the coins, write the log. |
| Post office | Badge · Sign · Letters & postcards · Stamps · Labels (address) · Money | yes | Write, stamp, sort, pay. |
| Space station | Badge (ID card) · Sign · Control panel · Mission cards · Logbook · Cut-outs | yes | Press buttons, do missions, log them. |
| Grocery store | Badge · Sign · Price tags · Money · Shopping list · Cut-outs (food) | yes | Tag, shop from a list, pay. |
| Firefighters | Badge (round pin) · Sign (station) · Mission cards (calls) · Control panel (truck) · Medals · Cut-outs (hose, helmet) | yes | Take a call, drive, rescue, a medal at the end. |
| Hair salon | Badge · Sign · Appointment card · Menu (styles + prices) · Money · Cut-outs (combs, bows) | yes | Book, choose a style, pay. |
| Library | Badge · Sign · Library card (ID card) · Labels (book labels) · Stamps (due date) · Logbook (checkout list) | yes | Check out, stamp, return. |
| Ice cream truck | Badge · Sign · Menu · Order slips · Money · Cut-outs (scoops, cones) | yes | Same shape as a restaurant. |
| Dinosaur dig | Badge · Map (dig site) · Field notes · Labels (fossil tags) · Medals · Cut-outs (bones) | no | Dig, tag, write it down. A sign is optional ("Dino Dig Site"). |
| Bakery | Badge · Sign · Menu · Order slips · Money · Cut-outs (treats) | yes | Same as restaurant. |
| Doctor's office | Badge · Sign · Appointment card · Patient chart · Stickers · Cut-outs (tools) | yes | Same as vet. |
| Train ride | Badge (conductor ID) · Sign (station) · Tickets (numbered seats) · Passport (stamp each stop) · Snack menu · Money | yes | Punch the ticket, stop at stations. |
| Camping trip | Badge (round pin) · Map (trail) · Mission cards (nature jobs) · Field notes (spotted list) · Medals (merit) · Cut-outs (s'mores, lantern) | no | Hike, find things, earn a merit badge. |
| Zoo | Badge · Sign · Admission ticket · Map · Labels (animal signs) · Passport (stamp each animal) | yes | Tickets in, follow the map, stamp each animal. |
| School | Badge (name tag) · Sign (classroom) · Logbook (attendance) · Mission cards (lessons) · Awards (certificates) · Stickers | yes | Roll call, a lesson, gold stars. |
| Pizza shop | Badge · Sign · Menu · Order slips · Money · Cut-outs (toppings) | yes | Build pizzas from slips. |
| Toy shop | Badge · Sign · Price tags · Money · Labels (gift tags) · Cut-outs (toys) | yes | Tag, sell, wrap. |
| Farm | Badge · Sign · Labels (stall name signs) · Logbook (chores chart) · Price tags (farm stand) · Cut-outs (eggs, carrots) | yes | Chores, then sell at the stand. |
| Rocket launch | Badge (ID card) · Control panel · Mission cards · Logbook · Passport (planet stamps) · Cut-outs | no | Countdown, missions, log. |
| Submarine | Badge · Control panel · Map (ocean) · Logbook · Labels (sea creature cards) · Cut-outs | no | Steer by the panel, spot creatures. |
| Tea party | Badge · Sign · Menu · Labels (place cards) · Award (invitations as certificates) · Cut-outs (cakes, cups) | yes | Invite, seat, serve. |
| Detective mystery | Badge (ID card) · Clue cards · Code decoder · Case notes (logbook) · Map · Cut-outs (evidence) | no | Find clues, decode, solve. |
| Construction site | Badge (hard-hat pin) · Sign · Mission cards (work orders) · Blueprint (map) · Labels (caution tags) · Cut-outs (tools) | yes | Read the blueprint, build, inspect. |
| Car wash | Badge · Sign · Menu (wash list) · Tickets (numbered car tickets) · Money · Cut-outs (sponges) | yes | Pick a wash, take a number, pay. |
| Flower shop | Badge · Sign · Price tags · Labels (gift cards) · Money · Cut-outs (flowers) | yes | Arrange, tag, sell. |
| Museum | Badge · Sign · Admission ticket · Map · Labels (exhibit cards) · Passport (stamp each room) | yes | Tour with a map, stamp each room. |
| Circus show | Badge · Sign (big top) · Admission ticket · Program (list sheet) · Medals · Money (tokens) | yes | Tickets, a show list, bows and medals. |
| Puppet show | Badge · Sign · Admission ticket · Program · Money · Cut-outs (puppets) | yes | Puppets are cut-outs here. |
| Hotel | Badge · Sign · Room keycard (ticket) · Menu (room service) · Labels (do-not-disturb tags) · Money | yes | Check in with a keycard, order room service. |
| Pet groomer | Badge · Sign · Appointment card · Menu (services) · Money · Cut-outs (brush, bows) | yes | Same shape as a hair salon. |
| Treasure hunt | Badge (round pin) · Treasure map · Clue cards · Gold coins · Captain's log · Cut-outs (chest, key) | no | Map, clues, coins, log. |
| Bus ride | Badge · Sign (bus stop) · Tickets (numbered) · Map (route) · Passport (stops) · Money | yes | Pay, punch, follow the route. |
| Lemonade stand | Badge · Sign · Menu · Money · Order slips · Cut-outs (cups, lemons) | yes | The simplest shop. |
| Cooking show | Badge · Sign (show title) · Recipe cards (mission cards) · Menu (judges' list) · Medals · Cut-outs (ingredients) | yes | Cook from a card, judge, award. |
| Knights at a castle | Badge (round pin / shield) · Sign (banner) · Mission cards (quests) · Gold coins · Medals · Cut-outs (shield, crown) | yes | Quests, gold, a knighting. |
| Bird-watching trip | Badge · Field notes (spotted checklist) · Map · Labels (bird cards) · Medals · Cut-outs (binoculars, birds) | no | Spot and check off. |
| Mail delivery route | Badge · Letters & postcards · Stamps · Labels (addresses) · Map (route) · Logbook (delivered list) | no | Same family as post office. |
| Weather report | Badge (ID card) · Control panel (weather board) · Mission cards (forecasts) · Logbook (weather chart) · Cut-outs (sun, cloud, umbrella) | no | Read the board, report, chart. |
| Marching band | Badge · Sign (parade banner) · Program · Admission ticket · Medals · Cut-outs (instruments) | yes | A parade with a show list. |
| Spy mission | Badge (agent ID card) · Code decoder · Mission cards (briefings) · Gear shop (price list) · Money · Clue cards | no | Matches your idea: ID cards, decoder, briefings, gear shop. Price list stays (it was fine). |
| Superheroes | Badge (hero ID card) · Mission cards (rescues) · Control panel (hero HQ) · Medals · Logbook (hero log) · Cut-outs (masks, capes) | optional (HQ sign) | Rescues and medals, no tickets or prices. |

**Takeaways:** the old six are still the best set for shops, food and clinics (about 20 of the 44). Adventure, mission
and travel games are where the fixed set breaks, and those need maps, clue/mission cards, coins, logs and decoders.

---

## 4. The library: 17 printable types (task C)

Rule for every type: **the art is a picture only** (no words, letters, numbers, frames, borders, banners or blank
boxes). **The app draws** the card shape, border, title, every field and line, numbers and cut lines. The picture sits
in its own box and the text never sits on top of it. Both styles stay: full color or "I'll color them" (the app's lines
and text are always black outline so they print and color the same in both).

**Where the art comes from** (keeps the image count low):
- **Character sheet** (today's badge sheet, 1 image): 6 role pictures, now drawn as characters only, no badge shapes.
- **Picture sheet** (today's cut-out sheet, 1 image): 6 themed things. Already text-free, already sliced. Many cards reuse these pictures.
- **Spot sheet** (new, optional, 1 image): 6 more small themed pictures for cards when the cut-outs don't fit (a key, a magnifier, a star badge).
- **Hero picture** (1 image when needed): one big picture for a sign, a map or a postcard.

| # | Type | What kids do with it | Layout (per page) | App draws | Art | Games |
|---|---|---|---|---|---|---|
| 1 | **Role badge** (stays, reworked) | Wear it so everyone knows their job | 6 a page (variants below) | Card shape, clip hole, role title, "Name: ____" line | Character sheet slice (character only) | Every game |
| 2 | **Place sign** (stays, reworked) | Hang it up: "the shop is open" | 1 page (variants below) | The place's name, a tagline, the border | Hero picture in a box above or beside the name | Most games with a place |
| 3 | **Play money** (stays, more shapes) | Pay and give change | Bills 8 a page, coins 12 a page | "$1", border pattern, the game's money name | One emblem (picture sheet or spot sheet slice) | Shops, food, pirates, knights, spy |
| 4 | **Tickets & passes** (stays, reworked) | Show it to get in, punch it | 8 a page, every copy numbered (1A, 1B ...) | Ticket shape, stub, perforation, title, seat/row, name line | A small picture, a different one per copy from the sheets | Airplane, train, bus, zoo, museum, circus, hotel (keycard), car wash |
| 5 | **Menu / price list / program** (stays, reworked) | Read it to choose | 1 page | Title, every item line and price ($1–5), or the acts of a show | Each line's picture from the picture sheet; small corner picture | Food, shops, salon, circus, puppet show, spy gear shop |
| 6 | **Prop cut-outs** (stays as is) | Cut out and use as pretend things | 1 page, 6–8 cells | Title, dashed cut lines | Picture sheet (as today) | Most games |
| 7 | **Order slips** (new) | Waiter writes or ticks the order, cook makes it | 8 a page | Slip shape, "Table __", tick boxes next to pictures | Menu pictures reused (no new image) | Restaurant, bakery, pizza, ice cream, lemonade |
| 8 | **Map** (new) | Follow it, mark the X, find the next stop | 1 page | Title ribbon in the margin, a compass, numbered stops (1–4) in circles, an empty X spot | Hero picture: a text-free island/trail/site map | Treasure hunt, pirate, camping, zoo, museum, dino dig, submarine, bus |
| 9 | **Clue cards** (new) | Hide them, find them, read the next clue | 6 a page, numbered 1–6 | Card, number, one short clue (3–8 words, names a found prop or a room spot) | Spot sheet slice per card | Treasure hunt, detective, spy |
| 10 | **Mission / job cards** (new) | Draw a card, do the job | 6 a page | Card, mission title, one line, a done tick box | Spot or picture sheet slice | Spy, superheroes, firefighters, space, construction, camping, cooking show, knights |
| 11 | **Log / chart sheet** (new) | Write or tick what happened | 1 page | Title, ruled lines or a tick grid with pictures, "date" and "by" lines | Small header picture (sheet slice) | Pirate (captain's log), vet/doctor (patient chart), school, space, weather, bird-watching, detective |
| 12 | **Medals & certificates** (new) | Give one at the end of a scene | Medals 6 round a page, or certificates 2 a page | Ribbon, "Bravest Pirate" style title, "Awarded to ____" line | Center picture from the sheets | Firefighters, school, superheroes, circus, knights, camping, cooking show, band |
| 13 | **Stickers & stamps** (new) | Stamp a passport, reward a patient | 12–20 small circles | Circle/scalloped edge, tiny word ("Brave!", "Visited") | Sheet slices | Vet, doctor, school, zoo, museum, post office, library |
| 14 | **Passport / booklet** (new) | Get a stamp at each stop | 1 page that folds into a 4-page booklet | Cover title, "Name ____", 6 empty stamp boxes | Cover picture (sheet slice) | Airplane, train, bus, zoo, museum, rocket |
| 15 | **Labels & tags** (new) | Tag prices, label animals, address parcels | 12 a page | Tag shape with a string hole, the label word or price | Small picture per tag (sheet slices) | Grocery, toy shop, flower shop, farm, zoo, museum, library, post office, dino dig |
| 16 | **Code decoder** (new) | Decode a secret message | 1 page: a decoder strip + 3 secret messages | Everything: letters to picture symbols, the messages | None (all app-drawn) | Spy, detective |
| 17 | **Control panel** (new) | Press the buttons, turn the dials | 1 page | Buttons, dials, switches, labels under each | Optional: picture sheet slices on the big buttons | Space, rocket, submarine, firefighter truck, superhero HQ, weather board, airplane cockpit |
| (17b) | **Letters & postcards** (new, folds into 15 if we want fewer types) | Write, stamp, deliver | 4 postcards a page | Address lines, stamp box | Postcard front: hero or sheet slice | Post office, mail route |

**Stays as is:** cut-outs (6). **Stays but reworked** (same job, the art no longer draws frames or words): badges (1),
sign (2), money (3), tickets (4), menu (5). Nothing about the cut-out sheet or the character sheet slicing needs to change
except the badge prompt (characters only, no badge shapes).

---

## 5. Layout variants (task D)

Because the app draws every frame now, a variant is just a different app template: **no extra image cost**.

| Type | Variant A | Variant B | Variant C |
|---|---|---|---|
| Badge | **Lanyard tag** (tall, clip hole; today's shape) | **Round pin** (circle, role title on a curved ribbon below) | **ID card** (landscape, picture left like a photo, title and name right) |
| Sign | **Door sign** (portrait, picture on top, name below) | **Hanging banner** (landscape pennant, picture in the middle, name across) | **Marquee / arch** (arch of "lights" around the name, picture under) |
| Money | **Bills** (8 a page) | **Coins** (12 round a page) | **Tokens** (12 tickets with a star, for fairs and circuses) |
| Tickets | **Boarding pass** (stub on the right, seat) | **Admission ticket** (notched corners, perforated stub) | **Keycard / appointment card** (rounded card, time line) |
| Menu / list | **Menu card** (2 columns, picture per line) | **Chalkboard board** (one column, big prices) | **Show program** (numbered acts, no prices) |
| Mission / clue cards | **Playing-card size** (6 a page) | **Envelope cards** (fold over, "Top secret" flap) | — |
| Log sheet | **Ruled log** (lines) | **Tick chart** (rows × pictures) | — |

**How the variant is chosen (app, not Claude):**
1. Each game family has a default (workplaces → lanyard tag; spy, detective, crew, space → ID card; pirates, superheroes,
   knights, circus, camping, school → round pin; pirates, knights, treasure → coins).
2. The app avoids the variant used in the last 2–3 games (same idea as the round 30 prop anti-repeat memory, IDs only).
3. Claude may suggest a variant in the kit JSON; the app keeps it if it's allowed for that type.

This keeps it free, predictable and never a broken layout. Two games of the same kind still look different.

---

## 6. Cost (task E)

Measured today (round 27, cost v2): **13 images a game** = 6 pages × 2 styles + 1 cover, about **$0.021 each, $0.275 a game**
(+2 images per skipped prop).

| Plan | Images per style | Per game (both styles + cover) | Cost | vs today |
|---|---|---|---|---|
| Today (fixed 6) | badge sheet, sign, money, tickets, menu, cut-out sheet = 6 | 13 | $0.275 | — |
| **Shared sheets (recommended)** | character sheet + picture sheet + 1–2 of (spot sheet, hero) = 3–4 | **7–9** | **$0.15–0.19** | **−$0.08 to −$0.13** |
| One picture per printable | character sheet + cut-outs + 1 per other printable that has art (2–4) = 4–6 | 9–13 | $0.19–0.28 | same or less |

**What would raise cost (avoid):**
- A different image for each copy of a ticket, card or medal. Use sheet slices instead (6 pictures for free).
- More than one hero image per style (a map **and** a sign **and** a postcard). Cap: 2 non-sheet images per style.
- Separate badge images per variant. The character sheet works for all three badge shapes (the app crops a circle for pins).
- Code decoder, order slips, log sheets and control panels need **no** image. Kits with these cost less.
- The kit call's JSON gets a little longer (more types to describe): about +$0.005 a game. Skipped-prop cut-outs: unchanged.

---

## 7. How the planner picks (task F)

**Where:** the kit pages call (`Prompts.kitPages`, at the roles, during the hunt; round 20). Today it says "exactly
these 6 items". It would say "pick 4 to 6 from this library; badges always". The art starts right after (`KitArtService.prepare`), so nothing new waits.

| Piece | Today | Proposed |
|---|---|---|
| Choosing types | Fixed 6 (`KitRecipe`, `Sanitizer.recipeOrdered`) | App gives a **shortlist** per known game (a table keyed by the `Suggestions` id, or by `GameMatch` for free-said games). Claude picks 4–6 from it and may swap in up to 2 other library types for the theme twist. Unknown games: Claude picks from the whole library with the rules below. |
| Rules in the prompt | "every page is used on purpose" | Same, stronger: each pick needs a **verb job** in a scene (wear, hang, pay, show, punch, hide, find, decode, stamp, tick, give). "Look at it" is not a job. A pick no role uses is dropped. |
| Layout variant | none | App picks (section 5); Claude may suggest. |
| Sanitizer | Orders the 6, fixes shapes | Badges first, 4–6 items, no two of a type, ≤ 7 printed pages, ≤ 2 non-sheet images per style. |
| Purpose | `purpose`: one sentence | Same field, plus a short **setup use** ("hide the clue cards", "hang the sign", "put the coins in the chest"). |
| Setup / clean-up goal rows (round 36/37, setup rows as goals) | `SetupCoverage` checks every page by recipe key `page:<recipe>` | Same check, keyed by item id. Each goal row ("Get the treasure ready") is spoken with its props and printables ("...hide the clue cards and put the gold coins in the chest"). Clean-up gets its matching line ("Put the coins back in the chest"). |
| The play guide (`kitScenes`) | Receives each page's id, lines and purpose | Same; it must use each page in a scene task. If one is unused: re-ask once, then the app's repair (as today). |

**Replays and saved games:**
- Saved art is keyed by item id (`img_<id>`, `cut_<id>_n`, `o...` for the other style), so new types fit the same folders.
- Add the new types to `KitRecipe` and make it decode **tolerantly** (an unknown name → nil, not a failed load), then bump
  the save schema to 4. Schema 3 games keep their 6 old types.
- Old saved games keep their old art, which already has the model's blank boxes in it. Options: leave them as they are
  (Haylee's earlier "no migration" rule for voice clips), or let the app find the empty white band in the old art and
  write the name/role text inside it with no outline of its own (no image calls). See question 4.
- Replays never make new images, so nothing changes for replay cost.

---

## 8. Questions for Haylee

1. **Badges in every kit, sign in most.** OK to drop the sign when there's no place (treasure hunt, spy mission, mail
   route)? Or always keep a sign ("Secret Agent HQ")?
2. **Shared picture sheets vs a picture per page.** Shared sheets are cheaper (7–9 images vs 13) but cards reuse the cut-out
   pictures. A picture per page costs about what it does today and looks more custom. Which way?
3. **Writing for 4–8 year olds.** Clue cards, logs and order slips have words. OK if they are picture-first (tick boxes
   next to pictures) with very few words, and Nutmeg reads a card out loud when a kid taps it?
4. **Old saved games.** Leave their badges and tickets as they are (double frame), or have the app fit its text into the
   model's old blank box (no new images)?
5. **Shortlist per game.** Do you want a fixed shortlist per suggested game (predictable, testable, like section 3), with
   Claude free only for games kids make up? Or let Claude choose every time?
