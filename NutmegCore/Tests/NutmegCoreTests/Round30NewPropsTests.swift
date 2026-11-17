import Testing
@testable import NutmegCore

/// Round 30 (Haylee): 30 new household props (set 2), tagged by shape/function with plausible pretend uses.
struct Round30NewPropsTests {
    static let newIDs = ["paper", "paper-towel-tube", "paper-bag", "egg-carton", "crayons", "tape", "paper-plate",
                         "plastic-container", "measuring-cup", "colander", "baking-sheet", "wooden-spoon", "apron", "oven-mitt",
                         "ball", "scarf", "sunglasses", "sneakers", "headband", "sock", "mittens", "umbrella", "pillowcase",
                         "toy-keys", "wagon", "jump-rope", "hula-hoop", "sidewalk-chalk", "plastic-cups", "sticky-notes"]

    @Test func allThirtyAreInTheLibraryWithTagsUsesAndArtNames() {
        #expect(Self.newIDs.count == 30)
        #expect(PropLibrary.ids.count == 60 && Set(PropLibrary.ids).count == 60)
        for id in Self.newIDs {
            #expect(PropLibrary.contains(id), "\(id) missing")
            #expect(PropLibrary.tags[id] != nil, "\(id) has no tags")
            #expect((PropLibrary.uses[id] ?? []).count >= 2, "\(id) needs 2+ curated uses")
            #expect(PropLibrary.asset(id) == "prop-\(id)")
            #expect(PictureResolver.allIDs.contains(id))
        }
    }

    @Test func everyCuratedUseFitsItsItemAndIsKidSafe() {
        for (id, uses) in PropLibrary.uses {
            for u in uses {
                #expect(PropFit.fits(itemID: id, becomes: u.becomes), "\(id) as \(u.becomes)")
                #expect(Sanitizer.kidSafety(u.becomes + " " + u.reason, pretend: true) == nil, "\(id): \(u.reason)")
            }
        }
    }

    @Test func thePairingsHaylee() {
        let good: [(String, String)] = [
            ("paper", "the fan"), ("paper", "the snowballs"),   // round 42: never a map, letter or ticket (printed)
            ("paper-towel-tube", "the telescope"), ("paper-towel-tube", "the microphone"), ("paper-towel-tube", "the magic wand"),
            ("colander", "the knight's helmet"), ("baking-sheet", "the steering wheel"), ("baking-sheet", "the tray"),
            ("baking-sheet", "the shield"), ("umbrella", "the cane"), ("umbrella", "the magic wand"),
            ("pillowcase", "the sack"), ("pillowcase", "the cape"), ("pillowcase", "the treasure bag"),
            ("wagon", "the car"), ("wagon", "the train"), ("wagon", "the delivery cart"),
            ("hula-hoop", "the steering wheel"), ("hula-hoop", "the pond"), ("headband", "the crown"),
            ("sticky-notes", "the leaves"), ("jump-rope", "the finish line"), ("plastic-cups", "the drums"),
        ]
        for (id, use) in good { #expect(PropFit.fits(itemID: id, becomes: use), "\(id) should fit \(use)") }
        let bad: [(String, String)] = [
            ("ball", "the pirate map"), ("sunglasses", "the boat"), ("umbrella", "the tent"), ("crayons", "the helmet"),
            ("sock", "the steering wheel"), ("toy-keys", "the telescope"), ("tape", "the cape"), ("hula-hoop", "the counter"),
            ("plate", "the pond"),
        ]
        for (id, use) in bad { #expect(!PropFit.fits(itemID: id, becomes: use), "\(id) should not fit \(use)") }
    }

    @Test func craftItemsAndKitchenThingsPassTheSafetyCheck() {
        for id in Self.newIDs {
            let name = PropLibrary.name(id) ?? id
            #expect(Sanitizer.kidSafety("Can you find the \(name.lowercased())?") == nil, "\(name)")
            #expect(!name.lowercased().contains("cut") && !name.lowercased().contains("scissor"))
        }
    }

    @Test func aMissingNewPropBecomesPretendInATaskAndAFoundOneStays() {
        let wagon = Prop(id: "wagon", householdItem: "Wagon", becomes: "the delivery cart", forRole: .all, safetyOK: true, libraryID: "wagon")
        let allowed = GuideRepair.allowedWords(props: [wagon], items: [])
        #expect(GuideRepair.missingObjects("Pull the wagon to the shop!", allowed: allowed, roles: []).isEmpty)
        #expect(GuideRepair.missingObjects("Jump through the hoop!", allowed: allowed, roles: []) == ["hoop"])
    }

    @Test func fallbackCanReachTheNewItems() {
        #expect(PropFit.candidates(for: "the telescope").contains("paper-towel-tube"))
        #expect(PropFit.candidates(for: "the space helmet").contains("colander"))
        #expect(PropFit.reason(itemID: "baking-sheet", becomes: "the race car wheel").contains("two hands"))
    }
}
