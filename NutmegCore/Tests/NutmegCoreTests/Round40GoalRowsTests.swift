import Foundation
import Testing
@testable import NutmegCore

/// Round 40 (Haylee, decisions/2026-11-17-setup-rows-as-goals.md): setup and clean-up rows are goals in the game's world
/// (2 to 6 words), about one per role (solo 3 at most, 2 players 2 each at most); Nutmeg's spoken line for each row gives
/// the specifics, and every household prop and printed page is named in some row's specifics.
@MainActor struct Round40GoalRowsTests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }
    var props: [Prop] { a.props.props }
    func view(_ k: Kit, _ n: Int, _ ps: [Prop]? = nil) -> [Scene] { PlayCast.kit(k, roles: roles, players: n, props: ps ?? props).scenes }
    var allItems: [CoverItem] { Bookends.coverItems(items: a.kit.items, props: props) }

    func checkGoalRows(_ sc: Scene, _ n: Int, _ tag: String) {
        for st in sc.steps {
            let short = st.short ?? ""
            let w = short.split(separator: " ").count
            #expect(w >= Bookends.minGoalWords && w <= Bookends.maxGoalWords, "\(tag) n=\(n) goal '\(short)'")
            // The spoken line starts with the role, then the goal, then the specifics.
            #expect(st.text.lowercased().contains(short.lowercased() + " by "), "\(tag) n=\(n) \(st.text)")
        }
    }

    @Test func theDemoGameHasGoalRows() {
        #expect(a.kit.setup?.goals?.count == 6 && a.kit.cleanup?.goals?.count == 6)
        let v = view(a.kit, 2)
        #expect(v[1].steps.first?.short == "Get the cockpit ready")
        #expect(v[1].steps.first?.text.hasPrefix("Captain, get the cockpit ready by hanging the Sky Airlines Gate 3 sign") == true)
    }

    @Test func rowCountsAreAboutOneGoalPerRole() {
        for n in 1...6 {
            let v = view(a.kit, n)
            for sc in [v[1], v.last!] {
                let perRole = Dictionary(grouping: sc.steps, by: \.role).mapValues(\.count)
                #expect(perRole.values.allSatisfy { $0 <= Bookends.goalRowsPerRole(players: n) }, "n=\(n) \(perRole)")
                #expect(perRole.count == n, "n=\(n): every playing kid has a goal")
                if n >= 3 { #expect(sc.steps.count == n) }
                if n == 1 { #expect((1...3).contains(sc.steps.count)) }
                if n == 2 { #expect((2...4).contains(sc.steps.count)) }
                checkGoalRows(sc, n, sc.arc == .setup ? "setup" : "clean-up")
            }
        }
    }

    /// Haylee's standing rule, in code: every household prop AND every printed page is named in a row's spoken
    /// specifics (the badges by the opening line), at every count, in both scenes.
    @Test func everyPropAndPageIsNamedInTheSetupAndTheCleanUp() {
        for n in 1...6 {
            let v = view(a.kit, n)
            #expect(SetupCoverage.setupMissing(v, items: allItems).isEmpty, "n=\(n) \(SetupCoverage.setupMissing(v, items: allItems))")
            #expect(SetupCoverage.cleanupMissing(v, items: allItems).isEmpty, "n=\(n) \(SetupCoverage.cleanupMissing(v, items: allItems))")
            #expect(SetupCoverage.missing(v, items: allItems, roles: roles).isEmpty)
        }
    }

    @Test func aTwoPlayerGameMentionsItsProps() {
        let v = view(a.kit, 2)
        for it in allItems where it.prop != nil {
            #expect(v[1].steps.contains { Bookends.mentions($0.text, it) }, "setup misses \(it.id)")
            #expect(v.last!.steps.contains { Bookends.mentions($0.text, it) }, "clean-up misses \(it.id)")
        }
    }

    @Test func aSwappedPropIsNamedAsTheNewItemAndASkippedOneIsLeftOut() {
        var ps = props
        ps[1].householdItem = "Paper plate"   // the steering wheel is now a paper plate
        ps[3].skipped = true                   // no backpack: a printed suitcase cut-out instead
        let v = view(a.kit, 2, ps)
        let items = Bookends.coverItems(items: a.kit.items, props: ps)
        #expect(!items.contains { $0.id == "prop:backpack" })
        #expect(SetupCoverage.setupMissing(v, items: items).isEmpty && SetupCoverage.cleanupMissing(v, items: items).isEmpty)
        #expect(v.last!.steps.contains { $0.text.contains("paper plate") }, "\(v.last!.steps.map(\.text))")
    }

    @Test func theBadgesAreInBothOpeningLines() {
        #expect(view(a.kit, 1)[1].nutmegSays.hasSuffix("Put on your badge first!"))
        #expect(view(a.kit, 1).last!.nutmegSays.hasSuffix("Take off your badge first!"))
        #expect(view(a.kit, 3).last!.nutmegSays.hasSuffix("Everyone, take off your badge first!"))
    }

    /// Replay parity: the rows are a pure function of the saved kit, so a saved game says the same words again.
    @Test func aSavedGameKeepsItsGoalsAndSaysTheSameWords() throws {
        let data = try JSONEncoder().encode(a.kit)
        let back = try JSONDecoder().decode(Kit.self, from: data)
        #expect(back.setup?.goals == a.kit.setup?.goals)
        for n in 1...6 { #expect(view(back, n) == view(a.kit, n)) }
    }

    /// A game saved before round 40 (no goals) still composes its round-37 rows, exactly as it did (no migration).
    @Test func anOlderSavedGameReplaysItsOldRows() throws {
        var old = a.kit
        old.setup?.goals = nil; old.cleanup?.goals = nil
        let json = String(decoding: try JSONEncoder().encode(old), as: UTF8.self)
        #expect(!json.contains("\"goals\""))
        let back = try JSONDecoder().decode(Kit.self, from: Data(json.utf8))
        #expect(back.setup?.goals == nil)
        let v = view(back, 1)
        #expect(v[1].steps.allSatisfy { ($0.short ?? "").split(separator: " ").count <= Bookends.maxRowShortWords })
        #expect(v[1].steps.contains { $0.short == "Hang up the gate sign" || ($0.short ?? "").contains("sign") })
        // The app's repair leaves an older game's rows alone (it never adds goals).
        let r = Bookends.repair(back, props: props, roles: roles, title: "Sky Airlines")
        #expect(r.kit.setup?.goals == nil && r.kit.cleanup?.goals == nil)
    }

    @Test func missingGoalsAreWrittenByTheAppForANewGame() {
        var k = a.kit
        k.setup?.goals = ["R1": "Get the cockpit ready", "R2": "x"]   // R2 too short, R3…R6 missing
        k.cleanup?.goals = [:]
        let r = Bookends.repair(k, props: props, roles: roles, title: "Sky Airlines")
        #expect(r.kit.setup?.goal(.R1) == "Get the cockpit ready")
        #expect(RoleID.allCases.allSatisfy { Bookends.isValidGoal(r.kit.setup?.goal($0)) && Bookends.isValidGoal(r.kit.cleanup?.goal($0)) })
        #expect(r.repaired.contains("setup goal R2") && r.repaired.contains("clean-up goal R6"))
        #expect(Bookends.repair(r.kit, props: props, roles: roles, title: "Sky Airlines").repaired.isEmpty)   // idempotent
        // A brand-new kit with no arc yet gets goal rows (`ensure`).
        let fresh = Bookends.ensure(Kit(nutmegSays: "", items: a.kit.items, scenes: a.kit.scenes))
        #expect(fresh.setup?.goals != nil && fresh.cleanup?.goals != nil)
    }

    @Test func theGuideAnswerCarriesTheGoals() throws {
        let schema = KitScenesSix.schema()
        let defs = schema["$defs"] as? [String: Any]
        let bookend = defs?["bookend"] as? [String: Any]
        let bp = bookend?["properties"] as? [String: Any]
        #expect(bp?["goals"] != nil)
        let job = (defs?["job"] as? [String: Any])?["properties"] as? [String: Any]
        #expect(job?["setupShort"] == nil && job?["setupSay"] != nil)
        let goals = #"{"R1":"Get the pet room ready","R2":"Open the front desk","R3":"Fill the water bowls","R4":"Tidy the waiting room","R5":"Stock the medicine shelf","R6":"Greet the pets"}"#
        let json = #"{"nutmegSays":"Hi","story":"A story. Another one.","setupScene":{"title":"Opening Time","nutmegSays":"Pretend that the clinic opens soon!","goals":"# + goals + #"},"cleanupScene":{"title":"Closing Time","nutmegSays":"Pretend that the clinic is closing!"},"pageJobs":{"sign":{"role":"R1","setupSay":"hang the Pet Clinic sign by the door","cleanupSay":"take down the Pet Clinic sign"}}}"#
        let k = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        #expect(k.setup?.goal(.R1) == "Get the pet room ready")
        #expect(k.cleanup?.goals == [:])   // a new answer is always goal rows (the app fills the missing ones)
        #expect(k.setup?.job("page:sign")?.short == "" && k.setup?.job("page:sign")?.say == "hang the Pet Clinic sign by the door")
        #expect(k.safetyTexts.contains("Open the front desk"))
        #expect(Prompts.bookendRules.contains("GOAL"))
    }

    @Test func jobsBecomeIngPhrases() {
        #expect(Gerund.ing("hang") == "hanging" && Gerund.ing("set") == "setting" && Gerund.ing("put") == "putting")
        #expect(Gerund.ing("line") == "lining" && Gerund.ing("tie") == "tying" && Gerund.ing("stack") == "stacking")
        #expect(Gerund.ing("keep") == "keeping" && Gerund.ing("open") == "opening" && Gerund.ing("wrap") == "wrapping")
        #expect(Gerund.ing("seat") == "seating" && Gerund.ing("fly") == "flying" && Gerund.ing("fix") == "fixing")
        #expect(Gerund.phrase("write your name on a pass and keep it ready") == "writing your name on a pass and keeping it ready")
        #expect(Gerund.phrase("line up the cups and plates") == "lining up the cups and plates")
        #expect(Gerund.phrase("the sign goes up") == nil)
        #expect(Bookends.goalLine(goal: "Get the pet room ready", says: ["hang up the sign", "set up the pet bed"])
                == "get the pet room ready by hanging up the sign and setting up the pet bed")
        // A job that doesn't start with a verb the app knows: the specifics become their own sentence.
        #expect(Bookends.goalLine(goal: "Get the pet room ready", says: ["the sign goes up", "set up the pet bed"])
                == "get the pet room ready! The sign goes up, then set up the pet bed")
    }

    /// The live 2-player game (round 40): the AI gave the first role 5 items, one 16-second line. A row with more than 3
    /// items now splits while its role has room; the new row takes a free role's goal (never a duplicate label).
    @Test func aLongRowSplitsIntoAFewGoalRows() {
        var k = a.kit
        let jobs = k.setup!.jobs.map { var j = $0; j.role = j.item == "page:menu" ? .R2 : .R1; return j }
        k.setup?.jobs = jobs
        for n in [1, 2] {
            let v = view(k, n)
            let setup = v[1]
            let items = Bookends.setupItems(items: k.items, props: props)
            var jobs: [String: ItemJob] = [:]
            for it in items { jobs[it.id] = k.setup?.job(it.id) }
            let plan = Bookends.goalAssignment(items: items, jobs: jobs, roles: roles, players: n)
            #expect(plan.allSatisfy { $0.items.count <= Bookends.maxItemsPerGoalRow }, "n=\(n) \(plan.map(\.items))")
            #expect(Set(plan.flatMap(\.items)) == Set(items.map(\.id)) && plan.flatMap(\.items).count == items.count)
            let labels = setup.steps.compactMap(\.short)
            #expect(Set(labels).count == labels.count, "n=\(n) duplicate goal \(labels)")
            let perRole = Dictionary(grouping: setup.steps, by: \.role).mapValues(\.count)
            #expect(perRole.values.allSatisfy { $0 <= Bookends.goalRowsPerRole(players: n) }, "n=\(n) \(perRole)")
            #expect(SetupCoverage.setupMissing(v, items: Bookends.coverItems(items: k.items, props: props)).isEmpty)
        }
        let two = view(k, 2)[1].steps
        #expect(two.filter { $0.role == SceneOwner(.R1) }.count == 2, "\(two.map(\.text))")
    }

    @Test func secondActionsAfterAndBecomeIngToo() {
        #expect(Gerund.phrase("count the Paw Bucks and stack them up") == "counting the Paw Bucks and stacking them up")
        #expect(Gerund.phrase("sit the patient pet by the desk") == "sitting the patient pet by the desk")
        #expect(Gerund.phrase("put the cups and stack by the sink") == "putting the cups and stack by the sink")
    }

    @Test func goalsAreTwoToSixWords() {
        #expect(Bookends.isValidGoal("Get the pet room ready"))
        #expect(!Bookends.isValidGoal("Ready"))
        #expect(!Bookends.isValidGoal("Get the whole big pet room all ready now"))
        #expect(!Bookends.isValidGoal("Say \"hi\" to pets"))
    }

    @Test func theContentReportShowsTheGoals() {
        let text = ContentReport.bookendText(a.kit.setup!)
        #expect(text.contains("R1 goal: Get the cockpit ready"))
    }
}
