import Foundation
import Testing
@testable import NutmegCore

/// Round 25 (Haylee): no printer question / Draw it!, the play checklist bug (a scene titled "x", props in none of the
/// steps, ONE scene so a replay at 2 kids never reached the second role), The End's Play step goes back to the checklist.
@MainActor struct Round25Tests {

    // MARK: The magic bakery guide, as it was saved (round 24 Draw it! path)

    static let roles: [Role] = RoleCast.rank([("Head Baker", "mix the magic batter"), ("Oven Watcher", "watch the oven"),
        ("Recipe Reader", "read the recipe"), ("Decorator", "decorate the cakes"), ("Delivery Helper", "deliver the treats"),
        ("Shop Greeter", "greet the customers")].map { Role(id: .R1, roleName: $0.0, emoji: "", symbol: "star", job: $0.1) })
    static let props: [Prop] = [
        Prop(id: "bowl", householdItem: "Bowl", becomes: "mixing bowl", forRole: .R1, safetyOK: true, libraryID: "bowl", skipped: false),
        Prop(id: "flashlight", householdItem: "Flashlight", becomes: "big stirrer", forRole: .R2, safetyOK: true, libraryID: "flashlight", skipped: false),
        Prop(id: "tray", householdItem: "Tray", becomes: "display tray", forRole: .all, safetyOK: true, libraryID: "tray", skipped: false),
    ]
    static var bakeryScene: Scene {
        Scene(id: "s1", owner: .all, title: "x", picture: .kit("sign"),
              nutmegSays: "Pretend that the bakery doors just opened for a magic morning!", steps: [
                Step(picture: .kit("badge:R1"), text: "Head Baker, put on your star badge!", role: .R1),
                Step(picture: .kit("badge:R2"), text: "Oven Watcher, wear your yellow star badge!", role: .R2),
                Step(picture: .kit("menu"), text: "Recipe Reader, hold up the cake menu!", role: .R3),
                Step(picture: .action("point"), text: "Decorator, set out the cakes!", role: .R4),
                Step(picture: .kit("money"), text: "Delivery Helper, stack the bakery money!", role: .R5),
                Step(picture: .action("wave"), text: "Shop Greeter, wave hello at the door!", role: .R6),
                Step(picture: .action("clap"), text: "Everyone, clap because the bakery is open!"),
                Step(picture: .action("cheer"), text: "Everyone, shout hooray for magic baking!"),
              ])
    }
    static var bakeryGame: SavedGame {
        SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Magic Bakery", roles: roles,
                  props: props.map(SavedProp.init), kit: Kit(nutmegSays: "", items: Fallback.airplane.kit.items, scenes: [bakeryScene]),
                  printStyle: .colorIn, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
    }

    /// Every visible step's text for N kids.
    func visibleTexts(_ kit: Kit, players n: Int) -> [String] {
        PlayCast.kit(kit, roles: Self.roles, players: n).scenes.flatMap { $0.steps.map(\.text) }
    }

    // MARK: Titles

    @Test(arguments: ["x", "", "  ", "X", "xx", "Title", "Scene 3", "scene", "...", "TBD", "n/a", "untitled"])
    func placeholderTitlesAreCaught(_ t: String) {
        #expect(GuideRepair.isPlaceholderTitle(t))
    }

    @Test(arguments: ["The Bakery Opens", "Cake Rush!", "Big Finish", "Sail Away"])
    func realTitlesPass(_ t: String) {
        #expect(!GuideRepair.isPlaceholderTitle(t))
    }

    @Test func validateFlagsAPlaceholderTitle() {
        let six = (0..<6).map { i -> Scene in var s = Self.bakeryScene; s.id = "s\(i)"; s.title = "Real Title \(i)"; return s }
        #expect(Validate.scenes(six, roles: 6) == nil)
        var bad = six; bad[2].title = "x"
        #expect(Validate.scenes(bad, roles: 6)?.message.contains("no real title") == true)
    }

    // MARK: The repair (no AI call)

    @Test func theBakeryGuideIsRepaired() {
        let fixed = GuideRepair.repair([Self.bakeryScene], roles: Self.roles, props: Self.props, title: "Magic Bakery")
        #expect(fixed.count >= GuideRepair.minScenes)
        #expect(fixed.allSatisfy { !GuideRepair.isPlaceholderTitle($0.title) })
        #expect(Set(fixed.map(\.title)).count == fixed.count)
        #expect(fixed.allSatisfy { PretendLine.has($0.nutmegSays) })
        // Every scene still has a step for each of the 6 roles plus group steps (round C1 shape).
        for s in fixed { #expect(RoleID.allCases.allSatisfy { r in s.steps.contains { $0.role.role == r } }) }
        // Every prop is in the steps, for every count (R1 always plays).
        let kit = Kit(nutmegSays: "", items: [], scenes: fixed)
        for n in 1...6 {
            let texts = visibleTexts(kit, players: n).joined(separator: " | ").lowercased()
            for p in Self.props { #expect(texts.contains(p.becomes), "N=\(n) misses \(p.becomes)") }
        }
        // Idempotent: a good guide comes back unchanged.
        #expect(GuideRepair.repair(fixed, roles: Self.roles, props: Self.props, title: "Magic Bakery") == fixed)
    }

    @Test func aGoodGuideIsLeftAlone() {
        var scenes = (0..<6).map { i -> Scene in var s = Self.bakeryScene; s.id = "s\(i)"; s.title = "Scene Idea \(["A", "B", "C", "D", "E", "F"][i])"; return s }
        scenes[0].steps[0].text = "Head Baker, stir the mixing bowl!"; scenes[0].steps[0].picture = .prop("bowl")
        scenes[1].steps[1].text = "Oven Watcher, wave the big stirrer!"; scenes[1].steps[1].picture = .prop("flashlight")
        scenes[2].steps[6].text = "Everyone, fill the display tray!"; scenes[2].steps[6].picture = .prop("tray")
        #expect(GuideRepair.repair(scenes, roles: Self.roles, props: Self.props, title: "Magic Bakery") == scenes)
    }

    @Test func aSkippedPropIsWovenInAsPretend() {
        var props = Self.props; props[0].skipped = true
        let fixed = GuideRepair.repair([Self.bakeryScene], roles: Self.roles, props: props, title: "Magic Bakery")
        let texts = fixed.flatMap { $0.steps.map(\.text) }
        #expect(texts.contains { $0.contains("pretend mixing bowl") })
    }

    @Test func aNewGameWithAOneSceneXGuideIsRepaired() async {
        // The AI's guide came back as ONE scene titled "x" (the round 24 failure shape) on the after-hunt path.
        var kit = Fallback.airplane.kit
        var s = Fixture.scene("s0", steps: 4); s.title = "x"
        kit.scenes = [s]
        let llm = FakeLLM(); llm.responses["Kit"] = kit
        let store = AdventureStore(service: PhaseService(llm: llm))
        await store.start(); await store.chooseGame("Airplane")
        store.setPlayerCount(2)
        await store.confirmPlayers(); await store.confirmRoles(); await store.confirmProps()
        let full = try! #require(store.fullKit)
        #expect(full.scenes.count >= GuideRepair.minScenes)
        #expect(full.scenes.allSatisfy { !GuideRepair.isPlaceholderTitle($0.title) })
        let texts = store.kit!.scenes.flatMap { $0.steps.map(\.text) }.joined(separator: " ").lowercased()
        for p in store.props?.props ?? [] {
            #expect(texts.contains(KitDraft.cutoutLabel(becomes: p.becomes).lowercased()) || texts.contains(p.householdItem.lowercased()))
        }
    }

    // MARK: 3b: a replay at 1 → 2 → 3 (Haylee: the second player got no checklist)

    /// Plays the replay through; returns each scene's (holder, visible step roles).
    func playThrough(_ store: AdventureStore) async -> [(owner: RoleID?, roles: [SceneOwner])] {
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        var seen: [(RoleID?, [SceneOwner])] = []
        store.replayPickDone(); store.replayPropsDone(); store.replayPaper(.skip)
        for _ in 0..<20 where store.phase != .end {
            if case .handoff(let i) = store.phase, let o = store.kit?.scenes[i].owner.role { store.badgeTapped(o) }
            guard case .scene(let i) = store.phase, let sc = store.kit?.scenes[i] else { break }
            seen.append((sc.owner.role, sc.steps.map(\.role)))
            await store.sceneDone()
        }
        return seen
    }

    @Test func aReplayAtOneThenTwoThenThreeRotatesThroughEveryPlayingRole() async {
        let store = AdventureStore(service: nil)
        for n in [1, 2, 3] {
            store.loadReplay(Self.bakeryGame)
            store.replayPick(n)
            let scenes = await playThrough(store)
            #expect(store.phase == .end)
            #expect(scenes.count >= GuideRepair.minScenes)
            let playing = Array(RoleID.allCases.prefix(n))
            // Hand-offs rotate R1, R2, …, RN: every playing role holds the iPad, nobody else does.
            #expect(scenes.map(\.owner) == scenes.indices.map { Optional(playing[$0 % n]) }, "N=\(n)")
            #expect(Set(scenes.compactMap(\.owner)) == Set(playing))
            for s in scenes {
                // One step per playing role, called out; nothing for a role that isn't playing.
                let roleSteps = s.roles.compactMap(\.role)
                #expect(roleSteps.sorted { $0.rank < $1.rank } == playing, "N=\(n): \(roleSteps)")
            }
        }
        // And the count change in the middle of one replay (1 → 2 at Pick) needs no reload.
        store.loadReplay(Self.bakeryGame)
        store.replayPick(1); store.replayPick(2)
        let scenes = await playThrough(store)
        #expect(Set(scenes.compactMap(\.owner)) == [.R1, .R2])
    }

    @Test func theReplayChecklistHasRealTitlesAndUsesTheProps() {
        let store = AdventureStore(service: nil)
        store.loadReplay(Self.bakeryGame)
        store.replayPick(1)
        let kit = store.kit!
        #expect(kit.scenes.allSatisfy { !GuideRepair.isPlaceholderTitle($0.title) })
        let texts = kit.scenes.flatMap { $0.steps.map(\.text) }.joined(separator: " ").lowercased()
        for p in Self.props { #expect(texts.contains(p.becomes)) }
        // A prop they don't have now: its woven step says "pretend".
        store.replayProp("bowl", have: false)
        #expect(store.kit!.scenes.flatMap { $0.steps.map(\.text) }.contains { $0.contains("pretend mixing bowl") })
    }

    // MARK: 4: The End → the Play step goes back to the checklist

    @Test func theEndsPlayStepGoesBackToTheChecklist() async {
        let store = AdventureStore(service: nil)
        store.loadReplay(Self.bakeryGame)
        store.replayPick(2)
        _ = await playThrough(store)
        #expect(store.phase == .end && store.playFinished && store.canGoTo(.play))
        #expect(store.nutmegLine.contains(HandOffLines.endBackHint))
        let last = store.kit!.scenes.count - 1
        #expect(store.goTo(.play) && store.phase == .scene(last))
        #expect(store.checkedSteps.isEmpty)   // the checkmarks from before Done! (none were tapped), restored exactly
        #expect(store.nutmegLine == HandOffLines.backToChecklist)
        // Voice: "go back to the checklist" = go_to_step play.
        await store.sceneDone()
        #expect(store.phase == .end)
        let out = await store.apply(.goToStep(.play))
        #expect(store.phase == .scene(last) && out.contains(HandOffLines.backToChecklist))
    }

    // MARK: 1: no printer question, no Draw it!

    @Test func thereIsNoPrinterStepOrDrawTool() async {
        #expect(!PlanningStep.allCases.map { "\($0)" }.contains("printer"))
        let names = Set(Realtime.tools.compactMap { $0["name"] as? String })
        #expect(!names.contains("set_printer") && !names.contains("draw_step"))
        #expect(!Realtime.instructions.contains("Draw it") && !Realtime.instructions.contains("printer question"))
        #expect(!SavedGame.allowedKeys.contains("drawGuide") && !SavedGame.allowedKeys.contains("hasPrinter"))
        // The confirm yes goes straight to the color question (the round 20 flow).
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Bakery")); _ = await store.apply(.setTheme("Magic Bakery"))
        _ = await store.apply(.setPlayerCount(2))
        let out = await store.confirmYes()
        #expect(store.planningStep == .color && out.contains(ColorChoice.question))
    }

    @Test func printIsTheStepNameAgainWithAPrinterIcon() {
        #expect(JourneyStep.print.label == "Print")
        #expect(BackNav.symbol(.print) == "printer.fill" && BackNav.overlay(.print) == nil)
        #expect(BackNav.toolSteps["paper"] == .print && BackNav.toolSteps["print"] == .print)
    }

    @Test func anOldDrawItSaveStillDecodes() throws {
        // Test saves from round 24 carry hasPrinter / drawGuide / printables keys: they're ignored.
        var json = try JSONSerialization.jsonObject(with: SavedGame.encoder().encode(Self.bakeryGame)) as! [String: Any]
        json["hasPrinter"] = false; json["drawGuide"] = ["nutmegSays": "x", "pieces": []]; json["printablesMade"] = false
        let g = try SavedGame.decode(JSONSerialization.data(withJSONObject: json))
        #expect(g.title == "Magic Bakery")
    }
}
