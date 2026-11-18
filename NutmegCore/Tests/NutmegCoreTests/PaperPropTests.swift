import Testing
@testable import NutmegCore

/// 2026-11-17 (live test game): the household prop "Paper" became the "recipe sheet", a printed thing. Plain paper is
/// never a prop, and recipes / printout sheets are printed things; a bedsheet stays a fine prop.
@MainActor struct PaperPropTests {
    @Test func plainPaperIsOffTheListForGood() {
        #expect(!PropLibrary.contains("paper") && !PropLibrary.ids.contains("paper"))
        #expect(PropLibrary.name("paper") == "Paper" && PropLibrary.hasArt("paper"))   // an older saved game still shows it
        #expect(!Realtime.tools.description.contains("\"paper\""))
        #expect(PropLibrary.tagsFor("Paper") == nil && PropLibrary.tagsFor("newspaper") == nil)
        #expect(PropLibrary.uses["paper"] == nil)
        // The things made OF paper stay: plate, bag, towel tube.
        for id in ["paper-plate", "paper-bag", "paper-towel-tube", "sheet"] { #expect(PropLibrary.contains(id), "\(id)") }
    }

    @Test func plainPaperIsNeverAPropByName() {
        for item in ["Paper", "paper", "a sheet of paper", "Sheets of paper", "Cardstock", "printer paper", "Construction paper",
                     "newspaper", "blank white paper", "a piece of paper"] {
            #expect(PropLibrary.isPlainPaper(item), "\(item)")
            #expect(!PropFit.fits(itemID: item, becomes: "the fan"), "\(item)")
        }
        for item in ["Paper plate", "Paper bag", "Paper towel tube", "Bedsheet", "Sheet", "sheet", "Baking sheet", "Pillowcase"] {
            #expect(!PropLibrary.isPlainPaper(item), "\(item)")
        }
    }

    @Test func recipesAndPrintoutSheetsArePrinted() {
        for use in ["the recipe sheet", "the recipe", "the recipes", "a recipe sheet", "the score sheet", "the worksheet",
                    "the coloring sheet", "the sticker sheets", "a sheet of paper", "the order sheet"] {
            #expect(PrintedProps.clash(use) != nil, "\(use)")
        }
        // Cloth sheets, baking sheets and real books stay allowed.
        for use in ["the sheet", "the bed sheet", "the ghost sheet", "the pirate sail", "the baking sheet", "the recipe book",
                    "the tablecloth", "the blanket fort"] {
            #expect(PrintedProps.clash(use) == nil, "\(use)")
        }
        #expect(PropFit.fits(itemID: "sheet", becomes: "the pirate sail"))
        #expect(!PropFit.fits(itemID: "sticky-notes", becomes: "the recipe sheet"))
    }

    @Test func claudesListSwapsOutPaper() {
        let bad = Props(nutmegSays: "", props: [
            Prop(id: "paper", householdItem: "Paper", becomes: "the recipe sheet", forRole: .all, safetyOK: true, libraryID: "paper"),
            Prop(id: "bowl", householdItem: "Bowl", becomes: "the mixing bowl", forRole: .all, safetyOK: true, libraryID: "bowl"),
        ])
        #expect(Validate.props(bad) != nil)
        let fixed = PropFit.repair(bad)
        #expect(fixed.props.allSatisfy { $0.libraryID != "paper" && PrintedProps.clash($0.becomes) == nil })
    }
}
