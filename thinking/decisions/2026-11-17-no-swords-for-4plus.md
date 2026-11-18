# No pretend swords, so the app rates 4+

- **Date:** 2026-11-17
- **Decision:** Take pretend swords out of the app completely (Nutmeg's lines, prop ideas, printables). Answer "None" for Guns or Other Weapons in the App Store age rating.
- **Why:** With pretend swords allowed (round 20), the honest answer was "Infrequent" weapons, and Apple calculated 9+. A 9+ badge on an app for ages 4–8 blocks parents who limit Screen Time to 4+ apps. Every other age-rating answer was None/No.
- **Replaces:** the round 20 "pretend swords are fine" rule.
- **Must ship in the first App Store build** (the rating describes that build).
- **Who decided:** Haylee.

## What changed (the build, 2026-11-17)

- **Claude prompt** (`Prompts.swift`) and **voice rules** (`RealtimeProtocol.swift` `safetyRules`): no swords or weapons of any kind, not even pretend or toy ones. Knights get shields, helmets, capes and crowns; pirates get spyglasses, maps, treasure chests and ships. A kid asking for a sword is "not an alarm": Nutmeg keeps their game and offers a non-weapon prop ("a shiny shield", "a paper towel tube telescope") without repeating the weapon word.
- **Kid-safety filter** (`KidSafety.swift`): new soft category `pretendWeapon` (sword, lightsaber, cutlass, saber, spear, bow and arrow, crossbow, slingshot, cannon, cannonball, catapult, blaster, toy/water/squirt gun, nerf). Checked only on pretend text (tool fields, generated kit text, prop reasons), so a game title, prop, kit line or printable can never carry one; a tool call with one gets a gentle note ("keep the SAME game, call again without the weapon"). Kid text saying "sword" is NOT blocked: it goes on to Nutmeg, whose rules do the gentle swap. "Real sword", "sharp sword", knives, guns, bombs stay hard violence blocks as before. "Swordfish", "saber tooth tiger", "the arrow" stay fine. Claude's regenerate note now says "no swords, not even toy ones".
- **Images** (`ImageSafety.suffix`): "no swords, no weapons of any kind (not even toy ones)"; page prompts add "pirate ships have no cannons; knights hold shields, never swords".
- **Props** (`PropFit.swift`): any "becomes" that names a weapon never fits (rule "weapon"), for every item; "sword", "lightsaber" and "cannonball" left the shape rules. `GuideRepair` no longer lists "sword" as a step object.
- **Tests:** `NoSwordsTests` (prompts and image suffix have no sword allowance, kid "sword" passes but pretend text is caught, the swap line is gentle and never says the word, no item ever becomes a weapon, nothing bundled or suggested names one). 655 NutmegCore tests pass.
- Not changed: `design/printables-ai-test/*.json` (old approved test recipes, not shipped) still say "a toy sword is fine".
