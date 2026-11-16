import Foundation
import Testing
@testable import NutmegCore

/// Round 20 (Haylee): full color, or color them yourself? Asked right after the confirm step's yes, before the roles.
/// The choice lives in the store (one source of truth) and decides every kit image prompt.
@MainActor struct Round20ColorTests {
    private func confirmed(_ store: AdventureStore, count: Int = 2) async {
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Bakery on the Moon"))
        _ = await store.apply(.setPlayerCount(count))
    }

    @Test func yesAsksTheColorQuestionThenTheRolesStart() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        #expect(store.printStyle == nil && store.currentPrintStyle == .colorIn)
        let yes = await store.confirmYes()
        #expect(store.planningStep == .color)
        #expect(yes.contains("say exactly this and nothing else") && yes.contains(ColorChoice.question))
        #expect(!yes.contains("start_planning"))                       // one reply: just the question
        // The roles can't start before the color answer.
        let early = await store.apply(.setRoles([.init(roleName: "Baker", job: "")]))
        #expect(early.contains("Not yet") && store.plan == nil && store.planningStep == .color)
        let chosen = await store.apply(.setPrintStyle(.fullColor))
        #expect(store.printStyle == .fullColor && store.currentPrintStyle == .fullColor && store.planningStep == .roles)
        #expect(chosen.contains("full color") && chosen.contains("start_planning") && chosen.contains("exactly 6 ranked roles"))
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: "bakes"), .init(roleName: "Customer", job: "buys")]))
        #expect(store.planningStep == .props && store.printStyle == .fullColor)
        store.newGame()
        #expect(store.printStyle == nil)
    }

    @Test func aCorrectionKeepsTheColorAndSkipsTheQuestionAfterTheNewYes() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        _ = await store.confirmYes(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: ""), .init(roleName: "Customer", job: "")]))
        _ = await store.apply(.setTheme("Bakery Under the Sea"))         // back to the recap
        #expect(store.planningStep == .confirm && store.printStyle == .colorIn)
        let yes = await store.apply(.confirmPlan)
        #expect(store.planningStep == .roles && yes.contains("start_planning") && !yes.contains(ColorChoice.question))
    }

    @Test func aColorSaidEarlyIsKeptAndChangesLaterAreCorrections() async {
        let store = AdventureStore(service: nil)
        await confirmed(store)
        let early = await store.apply(.setPrintStyle(.fullColor))       // "yes, and in full color!"
        #expect(early.contains("don't ask about color again") && store.planningStep == .confirm)
        _ = await store.confirmYes()
        #expect(store.planningStep == .roles)                            // the question is skipped
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: ""), .init(roleName: "Customer", job: "")]))
        let change = await store.apply(.setPrintStyle(.colorIn))         // mid-hunt change of mind
        #expect(store.printStyle == .colorIn && change.contains("pages you color yourself") && store.planningStep == .props)
    }

    @Test func aColorChangeAtThePrintStepRedrawsThePagesAndPlayKeepsThem() async {
        let store = AdventureStore(service: nil)
        await confirmed(store, count: 1)
        _ = await store.confirmYes(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles([.init(roleName: "Baker", job: "")]))
        await store.makeKit()
        #expect(store.phase == .kitReady)
        let n = store.kitRestyles
        let same = await store.apply(.setPrintStyle(.colorIn))
        #expect(same.contains("Already") && store.kitRestyles == n)
        let out = await store.apply(.setPrintStyle(.fullColor))
        #expect(store.kitRestyles == n + 1 && out.contains("Say nothing") && store.nutmegLine == ColorChoice.restyleLine(.fullColor))
        store.beginPlay()
        let late = await store.apply(.setPrintStyle(.colorIn))
        #expect(late.contains("New game") && store.printStyle == .fullColor)
    }

    @Test func toolsInstructionsAndTurnCheck() {
        #expect(PlanningCall.decode(name: "set_print_style", arguments: #"{"style":"full_color"}"#) == .setPrintStyle(.fullColor))
        #expect(PlanningCall.decode(name: "set_print_style", arguments: #"{"style":"color_myself"}"#) == .setPrintStyle(.colorIn))
        #expect(PlanningCall.decode(name: "set_print_style", arguments: #"{"style":"rainbow"}"#) == nil)
        let tool = Realtime.tools.first { $0["name"] as? String == "set_print_style" }
        #expect(tool != nil && Realtime.json(tool!).contains("color_myself"))
        #expect(Realtime.kidTurnTools(step: .color, huntActive: false)?.first == "set_print_style")
        #expect(Realtime.huntTools.contains("set_print_style"))
        #expect(Realtime.instructions.contains(ColorChoice.question) && Realtime.instructions.contains("3c. COLOR"))
        #expect(Realtime.outputSuffix(name: "set_print_style", output: "x", spokeFirst: false) == "")
        #expect(PlanningStep.color > .confirm && PlanningStep.color < .roles)
        #expect(TurnCheck.nudge(for: ColorChoice.question, step: .color) == nil)
        #expect(TurnCheck.nudge(for: "Ooh, so fun!", step: .color) != nil)
        #expect(ColorChoice.yesTapNote().contains("No tools") && ColorChoice.yesTapNote().contains(ColorChoice.question))
        #expect(ColorChoice.tapNote(.fullColor, playerCount: 3).contains("don't call set_print_style"))
        #expect(PrintStyle.fullColor.label == "Full color" && PrintStyle.colorIn.label == "I'll color them")
    }

    @Test func promptBuilderFollowsTheChoice() {
        let kit = Fallback.airplane.kit
        for item in kit.items where item.recipe != .cutouts {
            let line = KitArtPrompt.prompt(for: item, gameTitle: "Sky Bakery", style: .colorIn)
            #expect(line.hasPrefix("Coloring-page line art") && line.contains("Black and white only") && line.contains("easy for a 5-year-old to color."))
            let color = KitArtPrompt.prompt(for: item, gameTitle: "Sky Bakery", style: .fullColor)
            #expect(color.contains("Full-color, kid-friendly cartoon illustration") && color.contains("bright cheerful colors"))
            for banned in ["Coloring-page", "line art", "Black and white", "no shading", "no gray fills", "to color"] {
                #expect(!color.contains(banned), "\(item.title): \(banned)")
            }
            // Safety stays on every prompt; the item's own words and layout rules stay too.
            #expect(color.hasSuffix(ImageSafety.suffix) && line.hasSuffix(ImageSafety.suffix))
            #expect(color.contains("Sky Bakery") && color.contains(item.title))
            #expect(color.replacingOccurrences(of: KitArtPrompt.style(.fullColor, cutout: false), with: "")
                        .replacingOccurrences(of: "Printable full-color art", with: "")
                    == line.replacingOccurrences(of: KitArtPrompt.style(.colorIn, cutout: false), with: "")
                        .replacingOccurrences(of: "Coloring-page line art", with: ""))
        }
        // The default is the coloring page, word for word as before round 20.
        let item = kit.items[0]
        #expect(KitArtPrompt.prompt(for: item, gameTitle: "X") == KitArtPrompt.prompt(for: item, gameTitle: "X", style: .colorIn))
        let cut = KitArtPrompt.cutoutPrompt("a cupcake", gameTitle: "Sky Bakery", style: .fullColor)
        #expect(cut.contains("a cupcake") && cut.contains("cut out") && !cut.contains("Black and white") && cut.hasSuffix(ImageSafety.suffix))
        #expect(KitArtPrompt.cutoutPrompt("a cupcake", gameTitle: "Sky Bakery").contains("easy for a 5-year-old to color and cut out."))
    }

    /// Round 20 (Haylee: "Allow pretend swords"): pretend swords pass; knives, guns and real blades stay blocked.
    @Test func pretendSwordsAreAllowed() {
        #expect(Realtime.safetyRules.contains("PRETEND SWORDS ARE OK") && Realtime.safetyRules.contains("Knives stay off-limits"))
        #expect(Prompts.system.contains("Pretend swords are fine") && Prompts.system.contains("never a real"))
        #expect(ImageSafety.suffix.contains("no knives") && ImageSafety.suffix.contains("pretend toy sword is fine"))
        #expect(PropLibrary.looksUnsafe("kitchen knife") && !PropLibrary.contains("knife"))
    }
}

/// Round 20 (seen live: a bakery's "the oven" prop was blocked and she steered away mid-hunt): pretend ovens and stoves
/// in tool fields and generated kit text are fine; kid-typed text stays strict.
struct Round20PretendWordsTests {
    @Test func pretendOvenIsFineButKidTextStaysStrict() async {
        #expect(Sanitizer.kidSafety("the moon oven", pretend: true) == nil)
        #expect(Sanitizer.kidSafety(["Bake the cookies in the oven", "a toy stove"], pretend: true) == nil)
        #expect(Sanitizer.kidSafety("let's cook on the stove")?.category == .dangerous)          // kid text
        #expect(Sanitizer.kidSafety("the oven", pretend: true) == nil && Sanitizer.kidSafety("the oven") != nil)
        #expect(Sanitizer.kidSafety("play with matches", pretend: true)?.category == .dangerous)  // still strict
        #expect(Sanitizer.kidSafety("a knife", pretend: true)?.category == .violence)
        let check = KidSafetyCheck(moderator: nil)
        #expect(await check.check(["the big oven"], pretend: true) == nil)
        #expect(await check.check(["the big oven"]) != nil)
    }
}
