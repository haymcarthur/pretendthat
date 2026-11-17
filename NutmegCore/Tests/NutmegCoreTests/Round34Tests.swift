import Foundation
import Testing
@testable import NutmegCore

/// Round 34 (Haylee): replay prop lines are the first play's lines (never "do you still have"), no repeated "Next,";
/// tasks are short on screen with the specifics spoken (`short` + `say`); the scene opens with the setup and a cue;
/// the whole row plays its role's spoken task; the speech model download states; a one-sentence returning greeting.
@MainActor struct Round34Tests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }

    func prop(_ id: String, _ item: String, _ becomes: String, reason: String? = nil, skipped: Bool = false) -> Prop {
        Prop(id: id, householdItem: item, becomes: becomes, forRole: .all, safetyOK: true, libraryID: id, alternates: [],
             skipped: skipped, reason: reason)
    }

    // MARK: 1. Prop lines

    @Test func propLinesNeverSayNextOrStillHaveAndRotate() {
        var seen = Set<String>()
        for n in 1...6 {
            let line = PropLines.ask(item: "Chair", becomes: "the plane seats", reason: nil, n: n)
            #expect(!line.contains("Next,") && !line.lowercased().contains("still have"), "\(line)")
            #expect(line.contains("chair") && line.contains("plane seats"), "\(line)")
            seen.insert(String(line.prefix(12)))
        }
        #expect(seen.count >= 4)   // several phrasings, not one template
        let first = PropLines.ask(item: "Pot", becomes: "the captain's hat", reason: "A pot is round like a hat!", n: 1)
        #expect(first == "First, can you find a pot? It'll be the captain's hat! A pot is round like a hat! " + PropLines.howTo)
        #expect(PropLines.ask(item: "Tray", becomes: "the snack cart", reason: nil, n: 3).contains("pretend that"))   // round 13
        #expect(PropLines.ask(item: "Books", becomes: "the display stand", reason: nil, n: 4)
                == "Ooh, some books would make a great display stand! Can you find some?")
    }

    @Test func theLeadSaysTheAnswerBeforeIt() {
        let ps = [prop("pot", "Pot", "the hat"), prop("chair", "Chair", "the seats", skipped: true), prop("tray", "Tray", "the cart")]
        #expect(PropLines.line(for: ps, index: 0)?.hasPrefix("First,") == true)
        #expect(PropLines.line(for: ps, index: 1)?.hasPrefix(PropLines.cheer(n: 2) + " ") == true)
        #expect(PropLines.line(for: ps, index: 2)?.hasPrefix("No problem, we'll pretend the seats!") == true)
        #expect(PropLines.line(for: ps, index: 5) == nil)
    }

    /// The heart of item 1: a first play's prop lines (written by the app when it says them) and a replay of the saved
    /// game with the same answers are the SAME words, so the clip key (normalized words) matches.
    @Test func aReplayReusesTheFirstPlaysPropLinesWordForWord() async {
        let store = AdventureStore(service: nil)
        store.appSaysPropLines = true
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane"))
        _ = await store.apply(.setPlayerCount(2))
        _ = await store.apply(.setRoles([PlanningCall.RoleDraft(roleName: "Captain", job: "fly"), PlanningCall.RoleDraft(roleName: "Passenger", job: "ride")]))
        var firstPlay: [String] = []
        let picks: [(String, String)] = [("pot", "the captain's hat"), ("chair", "the plane seats"), ("tray", "the snack cart"), ("blanket", "the cloud")]
        for (k, pick) in picks.enumerated() {
            let out = await store.apply(.showNextProp(PlanningCall.PropDraft(itemID: pick.0, becomes: pick.1, forRole: "Captain", alternates: [], reason: "")))
            if k == 0 {
                #expect(store.pendingPropLine == nil)   // the first line follows the roles line
                firstPlay.append(store.firstPropAppLine ?? "")
            } else {
                let line = store.takePendingPropLine()
                #expect(line != nil && out.contains("Say NOTHING") && out.contains(line ?? "#"), "\(out)")
                firstPlay.append(line ?? "")
            }
            let id = store.currentPropID ?? ""
            if k == 1 { _ = await store.apply(.skipProp(id)) } else { _ = await store.apply(.markFound(id)) }
        }
        #expect(firstPlay.allSatisfy { !$0.isEmpty && !$0.contains("Next,") })
        // Save → replay with the same answers.
        let saved = (store.props?.props ?? []).map(SavedProp.init)
        let replayList = saved.map(\.replayProp)
        var replay: [String] = []
        var answered = replayList
        for k in replayList.indices {
            replay.append(PropLines.line(for: answered, index: k) ?? "")
            if k == 1 { answered[k].skipped = true }
        }
        #expect(replay.map(ClipText.normalize) == firstPlay.map(ClipText.normalize))
        #expect(replay.map { ClipKey.make(line: $0, voiceID: "coral") } == firstPlay.map { ClipKey.make(line: $0, voiceID: "coral") })
    }

    @Test func theReplayStoreSaysTheSameLinesThroughItsHunt() async {
        let store = AdventureStore(service: nil)
        let g = RoundD1Fixtures.game()
        store.loadReplay(g)
        store.replayPick(2)
        let list = g.props.map(\.replayProp)
        #expect(store.takeReplayFollowUp() == PropLines.line(for: list, index: 0))   // its own line, after the count
        store.replayHunt(found: true)
        #expect(store.nutmegLine == PropLines.line(for: list, index: 1))
        #expect(!store.nutmegLine.contains("still have") && !store.nutmegLine.hasPrefix("Next"))
    }

    @Test func withoutTheFlagTheModelStillSaysThem() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane"))
        _ = await store.apply(.setPlayerCount(1))
        _ = await store.apply(.setRoles([PlanningCall.RoleDraft(roleName: "Captain", job: "fly")]))
        _ = await store.apply(.showNextProp(PlanningCall.PropDraft(itemID: "pot", becomes: "the hat", forRole: "Captain", alternates: [], reason: "")))
        _ = await store.apply(.markFound(store.currentPropID ?? ""))
        let out = await store.apply(.showNextProp(PlanningCall.PropDraft(itemID: "chair", becomes: "the seat", forRole: "Captain", alternates: [], reason: "")))
        #expect(store.pendingPropLine == nil && !out.contains("Say NOTHING") && !out.contains("Next,"))
    }

    // MARK: 4. short + say

    @Test func theGuideSchemaHasShortAndSay() throws {
        let def = (KitScenesSix.schema()["$defs"] as? [String: Any])?["scene"] as? [String: Any]
        let r1 = (def?["properties"] as? [String: Any])?["R1"] as? [String: Any]
        #expect(Set((r1?["required"] as? [String]) ?? []) == ["short", "say"])
        let keys = RoleID.allCases.map(\.rawValue) + ["solo"]
        let sc = #"{"title":"Liftoff","nutmegSays":"Pretend that we fly!","# + keys.map {
            #""\#($0)":{"short":"Get the plane ready","say":"\#($0) helper, get the plane ready! You could wave the map."}"#
        }.joined(separator: ",") + "}"
        let json = #"{"nutmegSays":"","scene1":\#(sc),"scene2":\#(sc),"scene3":\#(sc)}"#
        let six = try JSONDecoder().decode(KitScenesSix.self, from: Data(json.utf8))
        #expect(six.scenes.count == 3 && six.scenes[0].steps.count == 7)
        #expect(six.scenes[0].steps[0].short == "Get the plane ready" && six.scenes[0].steps[0].say.hasSuffix("wave the map."))
        // A plain string (an older answer) is the spoken text.
        let old = #"{"title":"T","nutmegSays":"Pretend that!","# + keys.map { #""\#($0)":"Captain, fly the plane now please""# }.joined(separator: ",") + "}"
        let six2 = try JSONDecoder().decode(KitScenesSix.self, from: Data(#"{"scene1":\#(old)}"#.utf8))
        #expect(six2.scenes[0].steps[0].short == nil && six2.scenes[0].steps[0].text.hasPrefix("Captain"))
        #expect(Prompts.sceneRules.contains("3 to 7 words") && Prompts.sceneRules.contains("1 or 2 concrete example ideas"))
    }

    @Test func theRepairEnforcesTheShortLength() {
        let say = "Pet Trainer, it's time to get the pet ready to go home! You could write its name on the Pet Visit Pass and hand over the leash."
        let pet = [Role(id: .R1, roleName: "Pet Trainer", emoji: "", symbol: "", job: "train")]
        #expect(TaskShort.derive(from: say, roles: pet) == "Get the pet ready to go home")
        #expect(TaskShort.clean("Pet Trainer, feed the puppy.", say: say, roles: pet) == "Feed the puppy")
        #expect(TaskShort.clean("Brush and feed and walk the dog and then give it a bath right now", say: say, roles: pet).split(separator: " ").count <= TaskShort.maxWords)
        #expect(TaskShort.clean("", say: say, roles: pet) == "Get the pet ready to go home")
        #expect(TaskShort.clean("Go", say: say, roles: pet) == "Get the pet ready to go home")
        #expect(TaskShort.clean("Say \"hi\" to everyone", say: say, roles: pet).contains("\"") == false)
        for st in GuideRepair.repair(a.kit.scenes, roles: roles, props: a.props.props, title: "Airplane", items: a.kit.items).flatMap(\.steps) {
            let n = st.short?.split(separator: " ").count ?? 0
            #expect(n >= TaskShort.minWords && n <= TaskShort.maxWords, "\(st.short ?? "nil")")
        }
    }

    @Test func realPropsAreCheckedInBothTexts() {
        let sc = Scene(id: "s", owner: .all, title: "Ring", picture: .point, nutmegSays: "Pretend that!", steps: [
            Step(picture: .point, text: "Captain, ring the bell and greet the Passenger!", role: .R1, short: "Ring the bell"),
        ])
        let out = GuideRepair.repair([sc, sc, sc], roles: roles, props: [], title: "Airplane", items: a.kit.items)
        #expect(out[0].steps[0].text.contains("pretend bell") && out[0].steps[0].short == "Ring the pretend bell")
        // Idempotent.
        #expect(GuideRepair.repair(out, roles: roles, props: [], title: "Airplane", items: a.kit.items) == out)
    }

    @Test func aSkippedPropBecomesPretendInBothTexts() {
        var sc = a.kit.scenes[0]
        sc.steps[0] = Step(picture: .prop("pot"), text: "Captain, wear the captain's hat and wave!", role: .R1, short: "Wear the captain's hat")
        let uses = [PropUse(propID: "pot", scene: 0, step: 0, libraryID: "pot", item: "Pot", becomes: "the captain's hat")]
        let props = Props(nutmegSays: "", props: [prop("pot", "Pot", "the captain's hat", skipped: true)])
        let out = GuideWeave.finalize([sc], uses: uses, props: props, items: a.kit.items)
        #expect(out[0].steps[0].text.contains("pretend captain's hat") && out[0].steps[0].short == "Wear the pretend captain's hat")
    }

    @Test func rowsShowTheShortAndSpeakTheSay() {
        let view = PlayCast.kit(a.kit, roles: roles, players: 3)
        for row in view.scenes[0].steps {
            #expect(row.short != nil && !(row.short ?? "").contains(","))
            #expect(PlayCast.names(row.text, roles[row.role.role!.index].roleName))   // the spoken text names its role
        }
        // A 2-kid game unnames away roles in the short text too.
        let sc = Scene(id: "s", owner: .all, title: "T", picture: .point, nutmegSays: "Pretend that!", steps: [
            Step(picture: .point, text: "Captain, help the Snack Chef!", role: .R1, short: "Help the Snack Chef")])
        #expect(PlayCast.rows(sc, roles: roles, players: 2)[0].short == "Help a friend")
    }

    // MARK: Scene opening: the setup + the cue

    @Test func theSceneOpensWithTheSetupAndTheCueOnly() {
        let view = PlayCast.kit(a.kit, roles: roles, players: 6)
        let open = HandOffLines.sceneOpen(view.scenes[1])
        #expect(open == view.scenes[1].nutmegSays + " " + HandOffLines.taskCue)
        let first = HandOffLines.sceneOpen(view.scenes[0], first: true)
        #expect(first.contains(HandOffLines.taskCue) && first.hasSuffix(HandOffLines.nextSceneHowTo))
        // Measured in words (~2.5 words a second before Varispeed): the old 6-role read-out vs the new opening.
        let old = PlayCast.sceneSpeech(view.scenes[1]).split(separator: " ").count
        let new = open.split(separator: " ").count
        #expect(new * 3 < old, "old \(old) words, new \(new)")
    }

    // MARK: 5. The whole row is the tap target

    @Test func aRowTapPlaysThatRolesSay() {
        let rows = PlayCast.kit(a.kit, roles: roles, players: 3).playScenes[0].steps
        for i in rows.indices { #expect(SceneRowTap.line(rows: rows, index: i) == HandOffLines.task(rows[i])) }
        #expect(SceneRowTap.line(rows: rows, index: 7) == nil)
        #expect(SceneRowTap.accessibilityLabel(roleName: "Pet Trainer") == "Hear the Pet Trainer's job")
        // Voice "what do I do, Flight Attendant?" → that row.
        #expect(SceneRowTap.row(named: "Flight Attendant", rows: rows, roles: roles) == 2)
        #expect(SceneRowTap.row(named: "the passenger", rows: rows, roles: roles) == 1)
        #expect(SceneRowTap.row(named: "Snack Chef", rows: rows, roles: roles) == nil)   // not playing at 3
        #expect(PlanningCall.decode(name: "read_job", arguments: #"{"role":"Captain"}"#) == .readJob("Captain"))
    }

    @Test func voiceReadJobPointsAtTheRow() async {
        let store = await storeAtFirstScene(players: 3)
        store.nextScene()   // round 36: past the story (no rows) to the setup scene
        let second = store.plan?.roles[1].roleName ?? "#"
        let out = await store.apply(.readJob(second))
        // Round 37: a role may have several setup rows; the voice points at that role's first row.
        let firstRow = store.kit?.scenes[1].steps.firstIndex { $0.role == SceneOwner(.R2) }
        #expect(out.contains("Say nothing") && store.lastReadJobRow == firstRow)
        let none = await store.apply(.readJob("Zebra Wrangler"))
        #expect(none.contains("tap your own row"))
    }

    // MARK: 3. Speech model download

    @Test func speechModelStatesFlow() {
        var s = SpeechModelState.unknown
        s = s.next(.status(.supported)); #expect(s == .needsDownload && s.canStart)
        s = s.next(.started); #expect(s.progress == 0)
        s = s.next(.progress(0.42)); #expect(s.progress == 0.42 && s.copy.body.hasPrefix("42%"))
        s = s.next(.error); #expect(s == .failed && s.canStart && s.copy.button == SpeechModelCopy.retryButton)
        s = s.next(.status(.supported)); #expect(s == .failed)   // a failure stays visible until retried
        s = s.next(.started).next(.finished); #expect(s.isReady && s.next(.error) == .installed)
        #expect(SpeechModelState.unknown.next(.osTooOld) == .notSupportedHere)
        #expect(SpeechModelState.notSupportedHere.copy.body.contains("Settings"))
        #expect(SpeechModelState.unknown.next(.status(.installed)) == .installed)
        #expect(SpeechModelState.unknown.next(.status(.unsupported)) == .unsupportedLanguage)
        #expect(SpeechModelCopy.body.contains("one time") && SpeechModelCopy.body.contains("about a minute on Wi-Fi") || SpeechModelCopy.body.contains("About a minute on Wi-Fi"))
    }

    // MARK: 6. The returning greeting

    @Test func theReturningGreetingIsOneShortSentenceWithTheQuestion() {
        for line in GameGreeting.short {
            #expect(line.split(separator: " ").count <= 8 && line.hasSuffix("?") && line.contains("What should we play"))
            #expect(!line.contains("Nutmeg") && !line.contains("I'm"))
            #expect(CommonLines.all.contains(line))   // bundled clips
        }
        let note = GameGreeting.kickOffNote(ideas: "a bakery or a pirate ship", returning: true)
        #expect(note.contains("\"Maybe a bakery or a pirate ship?\"") && note.contains("do NOT greet"))
    }
}

/// A small saved game for the replay store tests (the bundled airplane game, saved).
enum RoundD1Fixtures {
    static func game() -> SavedGame {
        let a = Fallback.airplane
        return SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane", roles: a.plan.roles,
                         props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: .colorIn, art: [], voiceID: VoiceConfig.nutmeg.voiceID)
    }
}
