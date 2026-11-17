import Foundation
import Testing
@testable import NutmegCore

/// Round 29 (Haylee, ensemble scenes): everyone plays each scene at once. The guide is 3 scenes with ONE bigger,
/// interactive task per ranked role plus a solo task; a scene card shows a row per playing role (no hand-offs, no
/// checkboxes); tasks never script lines and name only real things; saved games keep the new shape.
@MainActor struct Round29Tests {
    let a = Fallback.airplane
    var roles: [Role] { a.plan.roles }

    // MARK: The visible rows per count (1–6), no AI call

    @Test func theRowsAreOnePerPlayingRoleInRankOrderAndSoloIsOneRow() {
        let scene = a.kit.scenes[1]
        for n in 1...6 {
            let rows = PlayCast.rows(scene, roles: roles, players: n)
            #expect(rows.count == n)
            #expect(rows.map(\.role) == RoleID.allCases.prefix(n).map { SceneOwner($0) })
            for r in rows { #expect(PlayCast.names(r.text, roles[r.role.role!.index].roleName), "\(r.text)") }
        }
        // One kid: the scene's solo task (a bigger version of R1's), shown as R1's row.
        let solo = PlayCast.rows(scene, roles: roles, players: 1)
        #expect(solo.map(\.text) == [scene.steps.first { $0.role == .solo }!.text] && solo[0].role == .R1)
        #expect(solo[0].text != scene.steps[0].text)
        // Out-of-range counts clamp.
        #expect(PlayCast.rows(scene, roles: roles, players: 0).count == 1 && PlayCast.rows(scene, roles: roles, players: 9).count == 6)
    }

    @Test func interactingTasksSurviveACountWhereTheOtherRoleIsAway() {
        // A task naming a role that isn't playing turns it into "a friend" (the interaction stays doable).
        let sc = Scene(id: "s", owner: .all, title: "Busy", picture: .point, nutmegSays: "Pretend that it's busy!", steps: [
            Step(picture: .point, text: "Captain, ask the Snack Chef for a cookie and hand it to the Passenger.", role: .R1),
            Step(picture: .point, text: "Passenger, order from the Snack Menu and pay with Sky Dollars.", role: .R2),
        ])
        let two = PlayCast.rows(sc, roles: roles, players: 2)
        #expect(two[0].text == "Captain, ask a friend for a cookie and hand it to the Passenger.")
        #expect(PlayCast.rows(sc, roles: roles, players: 5)[0].text == sc.steps[0].text)
    }

    @Test func theSceneSpeechIsTheSetupThenEveryRowInOrder() {
        let view = PlayCast.kit(a.kit, roles: roles, players: 3)
        let line = HandOffLines.sceneOpen(view.scenes[0])
        #expect(line.hasPrefix(view.scenes[0].nutmegSays))
        var at = line.startIndex
        for row in view.scenes[0].steps {   // each task, by role name, in rank order
            let r = line.range(of: row.text, range: at..<line.endIndex)
            #expect(r != nil, "\(row.text)")
            at = r?.upperBound ?? at
        }
        // Six tasks still fit one recorded clip (about 2.5 words a second before Varispeed).
        let six = HandOffLines.sceneOpen(PlayCast.kit(a.kit, roles: roles, players: 6).scenes[0], first: true)
        #expect(Double(six.split(separator: " ").count) / 2.5 < ClipRecorder.maxSeconds)
    }

    // MARK: The schema and prompt

    @Test func theGuideIsThreeScenesOfSixTasksAndASolo() {
        #expect(KitScenesSix.count == 3 && GuideRepair.minScenes == 3 && Sanitizer.Limits.scenesMax == 3)
        #expect(KitScenesSix.taskKeys.map(\.key) == ["R1", "R2", "R3", "R4", "R5", "R6", "solo"])
        let rules = Prompts.sceneRules
        #expect(rules.contains("1 to 3 minutes") && rules.contains("at most two parts") && rules.contains("CONNECT"))
        #expect(rules.contains("no quotes, no \"Say:\"") && rules.contains("solo task is for ONE kid"))
        #expect(rules.contains("ONLY REAL PROPS"))
        let six = KitScenesSix(nutmegSays: "", scenes: a.kit.scenes)
        #expect(six.safetyTexts.contains(a.kit.scenes[0].steps.first { $0.role == .solo }!.text))   // the solo task is screened
    }

    @Test func theWeavePromptCoversTheSoloTaskAndForbidsLines() {
        let props = [Prop(id: "pot", householdItem: "Pot", becomes: "the big oven", forRole: .all, safetyOK: true, libraryID: "pot")]
        let p = GuideWeave.prompt(scenes: a.kit.scenes, props: props, taken: [], roles: roles, players: 3)
        #expect(p.contains("[solo: one kid alone as R1]") && p.contains("plus the solo task") && p.contains("no quotes"))
        #expect(GuideWeave.maxUsesPerProp == 3)
    }

    // MARK: GuideRepair: scripted lines, real props, short guides, the props

    @Test(arguments: [
        (#"Waiter, greet the guests and say "Welcome to the café!""#, "Waiter, greet the guests!"),
        (#"Waiter, say “Welcome!” and seat the guests."#, "Waiter, seat the guests."),
        (#"Customer, ask "Can I have pancakes?""#, "Customer, ask it in your own words!"),
        ("Captain, say: Welcome aboard, everyone!", "Captain, say it in your own words!"),
        (#"Cashier, hold up the "Open" sign."#, "Cashier, hold up the Open sign."),
        ("Customer, order from the menu and pay with money.", "Customer, order from the menu and pay with money."),
        ("Customer's turn: order from the menu.", "Customer's turn: order from the menu."),
    ])
    func scriptedLinesAreTakenOut(_ input: String, _ want: String) {
        let out = GuideRepair.unscripted(input)
        #expect(out == want)
        #expect(!GuideRepair.hasScriptedLine(out))
        #expect(GuideRepair.unscripted(out) == out)   // idempotent
    }

    @Test func repairFixesAGuideWithLinesMissingObjectsAndAMissingProp() {
        var scenes = a.kit.scenes
        scenes[1].steps[1].text = #"Passenger, ring the bell and say "All aboard!""#
        scenes[2].title = "x"
        let props = a.props.props + [Prop(id: "pot", householdItem: "Pot", becomes: "Cloud maker", forRole: .R4, safetyOK: true, libraryID: "pot")]
        let fixed = GuideRepair.repair(scenes, roles: roles, props: props, title: "Airplane", items: a.kit.items)
        #expect(fixed[1].steps[1].text == "Passenger, ring the pretend bell!")
        #expect(!GuideRepair.isPlaceholderTitle(fixed[2].title))
        // The missing prop goes to the only R1 task with no prop yet (R1 always plays).
        #expect(fixed[0].steps[0].picture == .prop("pot") && fixed[0].steps[0].text.contains("cloud maker"))
        #expect(GuideRepair.repair(fixed, roles: roles, props: props, title: "Airplane", items: a.kit.items) == fixed)   // idempotent
    }

    @Test func aMissingPropGoesIntoR1sTaskAndThatScenesSoloTask() {
        let plain = Scene(id: "x", owner: .all, title: "Fun Time", picture: .point, nutmegSays: "Pretend that the plane is ready!",
                          steps: [Step(picture: .point, text: "Captain, wave to the passengers", role: .R1)]
                            + roles.dropFirst().map(PlayCast.filler) + [Step(picture: .point, text: "Captain, check every seat", role: .solo)])
        let pot = Prop(id: "pot", householdItem: "Pot", becomes: "Cloud maker", forRole: .R4, safetyOK: true, libraryID: "pot")
        let fixed = GuideRepair.repair([plain], roles: roles, props: [pot], title: "Airplane", items: a.kit.items)
        #expect(fixed[0].steps[0].text == "Captain, wave to the passengers with the cloud maker!")
        #expect(fixed[0].steps[6].text == "Captain, check every seat with the cloud maker!" && fixed[0].steps[6].picture == .prop("pot"))
    }

    @Test func aShortGuideIsPaddedToThreeScenesWithATaskPerRoleAndASolo() {
        let fixed = GuideRepair.repair([a.kit.scenes[0]], roles: roles, props: a.props.props, title: "Airplane", items: a.kit.items)
        #expect(fixed.count == 3)
        for s in fixed.dropFirst() {
            #expect(s.steps.map(\.role) == RoleID.allCases.map { SceneOwner($0) } + [.solo])
            #expect(PretendLine.has(s.nutmegSays))
        }
        #expect(Validate.scenes(fixed, roles: 6) == nil)
    }

    // MARK: The store: no hand-off, no checkboxes; a count change makes no call

    @Test func aCountChangeAtPaperChangesTheRowsWithNoCall() async {
        let llm = FakeLLM()
        let store = await storeWithKit(owners: [], players: 2, llm: llm)
        let calls = llm.calls
        for n in [1, 6, 4] {
            store.changePlayerCount(n)
            #expect(store.kit?.scenes.allSatisfy { $0.steps.count == n } == true)
        }
        #expect(llm.calls == calls)
        store.beginPlay()
        #expect(store.phase == .scene(0) && store.nutmegLine == HandOffLines.sceneOpen(store.kit!.scenes[0], first: true))
        #expect(store.sceneLine(1) == HandOffLines.sceneOpen(store.kit!.scenes[1]))   // Repeat re-reads the whole scene
    }

    @Test func thereAreNoHandOffOrChecklistTools() {
        let names = Set(Realtime.tools.compactMap { $0["name"] as? String })
        #expect(names.contains("next_scene") && !names.contains("confirm_handoff") && !names.contains("finish_scene"))
        #expect(Realtime.instructions.contains("call next_scene") && !Realtime.instructions.contains("finish_scene"))
        #expect(BackNav.playNote.contains("next_scene"))
        #expect(!UserAction.allCases.map(\.rawValue).contains("handoff") && UserAction.nextScene.stopsSpeech && UserAction.readTask.stopsSpeech)
        #expect(!CommonLines.all.contains { $0.contains("checklist") })
    }

    // MARK: Saved games keep the new shape, and replays play the same scenes

    @Test func aSavedGameRoundTripsTheEnsembleGuideAndReplaysTheSameScenes() throws {
        let g = SavedGame(createdAt: Date(timeIntervalSince1970: 1_800_000_000), title: "Airplane", roles: roles,
                          props: a.props.props.map(SavedProp.init), kit: a.kit, printStyle: .fullColor, art: [],
                          voiceID: VoiceConfig.nutmeg.voiceID)
        let back = try SavedGame.decode(SavedGame.encoder().encode(g))
        #expect(back == g && back.schemaVersion == 2)
        #expect(back.kit.scenes.allSatisfy { $0.steps.map(\.role) == RoleID.allCases.map { SceneOwner($0) } + [.solo] })
        // A replay at 4: the same 3 scenes, 4 rows each; the plate skipped makes its tasks (solo too) say "pretend".
        let store = AdventureStore(service: nil)
        store.loadReplay(back)
        store.replayPick(4)
        #expect(store.kit?.scenes.count == 3 && store.kit?.scenes.allSatisfy { $0.steps.count == 4 } == true)
        #expect(store.kit?.scenes.map(\.title) == a.kit.scenes.map(\.title))
        while store.replayHuntActive {
            let id = store.replayCurrentProp!.id
            store.replayHunt(found: id != "plate")
            if id == "plate", store.replayCurrentProp?.id == "plate" { store.replayHunt(found: false) }
        }
        let s2 = store.fullKit!.scenes[1]
        #expect(s2.steps[0].text.contains("pretend steering wheel") && s2.steps[6].text.contains("pretend steering wheel"), "\(s2.steps.map(\.text))")
        store.beginPlay()
        var seen: [Phase] = []
        while store.phase != .end && seen.count < 5 { seen.append(store.phase); store.nextScene() }
        #expect(seen == [.scene(0), .scene(1), .scene(2)])
    }

    // MARK: The character picture (cropped from the color badge slice)

    @Test func theCharacterCropIsTheArtBetweenTheTwoBlankBanners() {
        let w = 100, h = 150
        var gray = [UInt8](repeating: 255, count: w * h)
        func fill(_ rows: Range<Int>, _ v: UInt8) { for y in rows { for x in 0..<w { gray[y * w + x] = v } } }
        fill(0..<6, 40); fill(36..<115, 120); fill(141..<150, 40)   // frame, the character, frame; banners stay white
        let r = BadgeCharacter.rect(gray: gray, width: w, height: h)
        #expect(r.y == 36 && r.y + r.height == 114 && r.x == 11 && r.width == 78)
        // No banners found (a plain picture): the prompt's layout.
        let plain = BadgeCharacter.rect(gray: [UInt8](repeating: 90, count: w * h), width: w, height: h)
        #expect(plain.y == 39 && plain.y + plain.height == 120)
    }
}
