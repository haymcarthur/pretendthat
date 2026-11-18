import Foundation
import Testing
@testable import NutmegCore

/// 2026-11-17 (Haylee, 4+ age rating): no swords or weapons of any kind, not even pretend or toy ones. Replaces
/// round 20's "pretend swords are fine". A kid SAYING "sword" is a gentle swap to a non-weapon prop, never an alarm.
struct NoSwordsTests {
    static let swordAllowances = ["swords are fine", "sword is fine", "swords are ok", "pretend swords", "as your sword",
                                  "sword cut-out", "sword prop", "toy sword is fine"]

    @Test func promptsNoLongerAllowPretendSwords() {
        for (name, text) in [("claude", Prompts.system), ("realtime", Realtime.safetyRules), ("realtime full", Realtime.instructions)] {
            let low = text.lowercased()
            for a in Self.swordAllowances { #expect(!low.contains(a), "\(name): \(a)") }
            #expect(low.contains("not even pretend"), "\(name) states the no-weapons rule")
            #expect(low.contains("shield"), "\(name) offers a shield instead")
            #expect(low.contains("spyglass"), "\(name) offers a spyglass instead")
        }
        // A kid asking is a gentle swap, not the steer-away to a different game.
        #expect(Realtime.safetyRules.contains("NOT an alarm"))
        #expect(Prompts.system.contains("that's no alarm"))
    }

    @Test func imageSuffixForbidsEveryWeaponEvenToys() {
        let s = ImageSafety.suffix.lowercased()
        #expect(!s.contains("is fine"))
        #expect(s.contains("no swords"))
        #expect(s.contains("no weapons of any kind"))
        #expect(s.contains("not even toy ones"))
        #expect(KitPagePrompt.safe.hasPrefix(ImageSafety.suffix))
        #expect(KitPagePrompt.safe.contains("no cannons"))
    }

    @Test func aKidSayingSwordIsNotBlockedButPretendTextIs() {
        // Kid text goes on to Nutmeg (her rules swap it gently): no block, no scary steer.
        for kid in ["pirates with swords", "knight with a sword", "a toy sword", "I want a lightsaber", "can we have cannons"] {
            #expect(Sanitizer.kidSafety(kid) == nil, "\(kid)")
            // The same words as a game title, prop or kit line can never be used.
            #expect(Sanitizer.kidSafety(kid, pretend: true)?.category == .pretendWeapon, "\(kid)")
        }
        // Real or sharp swords are still violence everywhere.
        #expect(Sanitizer.kidSafety("a real sword to cut")?.category == .violence)
        #expect(Sanitizer.kidSafety("a sharp sword", pretend: true)?.category == .violence)
        // Look-alikes stay fine.
        for ok in ["a swordfish in the ocean", "a saber tooth tiger", "tap the arrow", "take a bow", "a shiny shield",
                   "a paper towel tube telescope", "the treasure map"] {
            #expect(Sanitizer.kidSafety(ok, pretend: true) == nil, "\(ok)")
            #expect(!Sanitizer.namesWeapon(ok), "\(ok)")
        }
    }

    @Test func theWeaponSwapIsGentleAndNeverSaysTheWord() {
        let line = SafetySteer.line(for: .init(.pretendWeapon), ideas: [Suggestion("zoo", "a zoo")])
        #expect(line == SafetySteer.weaponLine)
        #expect(line.contains("shield"))
        #expect(!line.contains("different adventure"))   // the game goes on
        #expect(!Sanitizer.namesWeapon(line))
        #expect(Sanitizer.kidSafety(line, pretend: true) == nil)
        let note = SafetySteer.toolNote(.init(.pretendWeapon), ideas: [Suggestion("zoo", "a zoo")])
        #expect(note.contains("SAME game"))
        #expect(note.contains(SafetySteer.weaponLine))
        #expect(!note.contains("different adventure"))
    }

    @Test func propFitNeverMakesAWeapon() {
        for item in PropLibrary.ids {
            for use in ["the sword", "the pirate sword", "the knight's sword", "the lightsaber", "the cannon", "the spear",
                        "the bow and arrow", "the toy gun"] {
                #expect(!PropFit.fits(itemID: item, becomes: use), "\(item) → \(use)")
            }
        }
        #expect(PropFit.check(itemID: "paper-towel-tube", becomes: "the sword").rule == "weapon")
        #expect(PropFit.check(itemID: "paper-towel-tube", becomes: "the spyglass").ok)
        let fb = PropFit.fallback(becomes: "the sword")
        #expect(!Sanitizer.namesWeapon(fb.becomes))
        // No library use, no shortlist use and no curated reason names a weapon.
        for (id, uses) in PropLibrary.uses {
            for u in uses { #expect(!Sanitizer.namesWeapon(u.becomes) && !Sanitizer.namesWeapon(u.reason), "\(id): \(u.becomes)") }
        }
        for t in PropNeeds.profiles { for u in t.uses { #expect(!Sanitizer.namesWeapon(u), "\(u)") } }
    }

    @Test func nothingTheAppSuggestsOrBundlesNamesAWeapon() {
        for s in Suggestions.games + Suggestions.twists { #expect(Sanitizer.kidSafety(s.text, pretend: true) == nil, "\(s.text)") }
        let a = Fallback.airplane
        #expect(Sanitizer.kidSafety(a.kit.safetyTexts + a.plan.safetyTexts + a.props.safetyTexts, pretend: true) == nil)
        for line in [HandOffLines.printReady, HandOffLines.nextSceneHowTo, HandOffLines.end(), TurnCheck.silenceLine]
            + PretendLine.openers + KitProgress.allLines {
            #expect(!Sanitizer.namesWeapon(line), "\(line)")
        }
    }
}
