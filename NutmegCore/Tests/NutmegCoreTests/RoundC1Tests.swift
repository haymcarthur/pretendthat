import Foundation
import Testing
@testable import NutmegCore

/// Round C1 (generate for 6; Haylee's answer 2: every playing role gets its OWN called-out steps in every scene, and
/// the hand-offs rotate through all the playing roles). Pure rules plus the store's "no AI call on a count change".
@MainActor
struct RoundC1Tests {
    let roles = Fallback.airplane.plan.roles
    let kit = Fallback.airplane.kit

    // MARK: Schemas and prompts

    @Test func schemasAllowSixRolesAndRoleTaggedStepsWithNoOwner() throws {
        #expect(RoleID.allCases.map(\.rawValue) == ["R1", "R2", "R3", "R4", "R5", "R6"])
        #expect(Schemas.roleIDs == ["R1", "R2", "R3", "R4", "R5", "R6"])
        let json = String(decoding: try JSONSerialization.data(withJSONObject: Schemas.kitScenes(), options: [.sortedKeys]), as: UTF8.self)
        #expect(json.contains(#""enum":["R1","R2","R3","R4","R5","R6","all"]"#))
        #expect(!json.contains("\"owner\""))                       // the app rotates the hand-offs
        #expect(json.contains("badge:R1..R6"))
        #expect(PictureResolver.kitIDs.contains("badge:R6"))
        let plan = String(decoding: try JSONSerialization.data(withJSONObject: Schemas.plan(), options: [.sortedKeys]), as: UTF8.self)
        #expect(!plan.contains("\"count\""))
        // Strict objects: every step property is required.
        let steps = (((Schemas.kitScenes()["properties"] as! [String: Any])["scenes"] as! [String: Any])["items"] as! [String: Any])
        let step = ((steps["properties"] as! [String: Any])["steps"] as! [String: Any])["items"] as! [String: Any]
        #expect(Set(step["required"] as! [String]) == ["picture", "role", "text"])
    }

    @Test func promptsAskForSixRankedRolesAndAStepPerRole() {
        let ctx = AdventureContext(gameTitle: "Pirate Ship", plan: Fallback.airplane.plan, playerCount: 2)
        #expect(Prompts.plan(game: "Pirate Ship", ctx: ctx).contains("exactly 6 different roles, ranked"))
        for p in [Prompts.kitScenes(ctx: ctx, items: kit.items), Prompts.kit(ctx: ctx)] {
            #expect(p.contains("exactly 6 scenes") && p.contains("ONE step for EACH role R1, R2, R3, R4, R5 and R6"))
            #expect(p.contains("2 steps for everyone"))
        }
        #expect(Prompts.system.contains("6 RANKED roles"))
        #expect(Realtime.instructions.contains("exactly 6 RANKED roles"))
        let setRoles = Realtime.json(["t": Realtime.tools])
        #expect(setRoles.contains("Exactly 6 ranked roles for this game"))
        #expect(ConfirmStep.confirmedOutput(playerCount: 3).contains("exactly 6 ranked roles"))
    }

    @Test func validateAsksForAStepForEveryRoleInEveryScene() {
        #expect(Validate.scenes(kit.scenes, roles: 6) == nil)
        var short = kit.scenes
        short[2].steps.removeAll { $0.role == .R5 }
        let p = Validate.scenes(short, roles: 6)
        #expect(p?.fatal == false && p?.message.contains("no step for R5") == true)
        #expect(Validate.scenes(short, roles: 0) == nil)   // older callers: no role check
    }

    @Test func sanitizerKeepsOneStepPerRoleAndTwoForEveryone() {
        var s = kit.scenes[0]
        s.steps += [Step(picture: .point, text: "Captain, again", role: .R1), Step(picture: .point, text: "All three", role: .all)]
        let clean = Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: [s])).scenes[0]
        #expect(clean.steps.count == 8)
        #expect(clean.steps.filter { $0.role == .R1 }.map(\.text) == ["Captain, hold the steering wheel"])
        #expect(clean.steps.filter { $0.role == .all }.count == 2)
        #expect(clean.owner == .all)
        // Older JSON (no role on steps) still decodes: everyone's steps, no owner needed.
        let old = try? JSONDecoder().decode(Scene.self, from: Data(#"{"id":"a","title":"T","nutmegSays":"Pretend that!","steps":[{"text":"Wave"}]}"#.utf8))
        #expect(old?.steps.first?.role == .all && old?.owner == .all)
    }

    // MARK: Per-role coverage at every count

    @Test func everyPlayingRoleHasItsOwnCalledOutStepInEveryScene() {
        for n in 1...6 {
            let view = PlayCast.kit(kit, roles: roles, players: n)
            for scene in view.scenes {
                let tagged = scene.steps.compactMap(\.role.role)
                #expect(Set(tagged) == Set(RoleID.allCases.prefix(n)), "n=\(n) \(scene.title)")
                #expect(tagged.count == n)                                  // exactly one each
                for step in scene.steps { if let r = step.role.role {
                    #expect(PlayCast.names(step.text, roles[r.index].roleName), "\(step.text)")
                } }
                #expect((3...PlayCast.maxVisibleSteps).contains(scene.steps.count), "n=\(n): \(scene.steps.count) steps")
                // Nothing on screen names a role that isn't playing.
                for away in roles.dropFirst(n) {
                    let texts = [scene.title, scene.nutmegSays] + scene.steps.map(\.text)
                    #expect(!texts.contains { PlayCast.names($0, away.roleName) }, "n=\(n) names \(away.roleName)")
                }
            }
        }
    }

    @Test func groupStepsFillTheRoomAndTheFinaleIsKept() {
        let s = kit.scenes[0]
        #expect(PlayCast.visibleSteps(s, roles: roles, players: 1).map(\.role) == [.R1, .all, .all])
        #expect(PlayCast.visibleSteps(s, roles: roles, players: 4).count == 6)
        let five = PlayCast.visibleSteps(s, roles: roles, players: 5)
        #expect(five.count == 6 && five.last?.text == "Say: Welcome aboard!")   // the last group step stays
        #expect(PlayCast.visibleSteps(s, roles: roles, players: 6).allSatisfy { $0.role != .all })
    }

    @Test func aMissingRoleStepIsWrittenFromTheJobAndUncalledStepsGetTheTitle() {
        var s = kit.scenes[0]
        s.steps.removeAll { $0.role == .R3 }
        s.steps[0].text = "Hold the steering wheel"   // R1's step forgot to call the Captain
        let v = PlayCast.visibleSteps(s, roles: roles, players: 3)
        #expect(v.first?.text == "Captain, hold the steering wheel")
        #expect(v.contains { $0.role == .R3 && $0.text == "Co-Pilot, read the map and help the captain!" })
    }

    @Test func linesNamingAnAbsentRoleAreRewritten() {
        let r = roles
        #expect(PlayCast.unname("Captain, give the map to the Weather Watcher", roles: r, players: 2) == "Captain, give the map to a friend")
        #expect(PlayCast.unname("The Snack Chef's tray is ready!", roles: r, players: 4) == "A friend's tray is ready!")
        #expect(PlayCast.unname("Co-Pilot, wave", roles: r, players: 3) == "Co-Pilot, wave")          // playing: unchanged
        #expect(PlayCast.sceneLine("Pretend that it's stormy! Weather Watcher, look out!", roles: r, players: 2) == "Pretend that it's stormy!")
        #expect(!PlayCast.names("Co-Pilot, wave", "Pilot"))
    }

    // MARK: Hand-off rotation

    @Test func handoffsRotateSoEveryKidGetsATurn() {
        for n in 1...6 {
            let owners = (0..<6).map { PlayCast.owner(scene: $0, players: n) }
            #expect(Set(owners) == Set(RoleID.allCases.prefix(n)))    // 6 scenes: every playing kid holds the iPad
            #expect(owners.first == .R1)
            #expect(owners.allSatisfy { $0.rank <= n })
        }
        #expect((0..<6).map { PlayCast.owner(scene: $0, players: 2) } == [.R1, .R2, .R1, .R2, .R1, .R2])
    }

    @Test func storeHandsOffToEachPlayingRoleInTurn() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setPlayerCount(3)); _ = await store.confirmWithPrinter(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles(roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        _ = await store.apply(.finishPlanning)
        for _ in 0..<100 where store.phase != .kitReady { try? await Task.sleep(for: .milliseconds(10)) }
        store.autoCheckStep = .zero; store.autoCheckHold = .zero
        store.beginPlay()
        var lines: [String] = []
        for i in 0..<6 {
            #expect(store.phase == .handoff(sceneIndex: i))
            lines.append(store.nutmegLine)
            _ = await store.apply(.confirmHandoff)
            #expect(store.phase == .scene(i))
            await store.sceneDone()
        }
        #expect(store.phase == .end)
        let who = ["Captain", "Flight Attendant", "Co-Pilot", "Captain", "Flight Attendant", "Co-Pilot"]
        for (line, role) in zip(lines, who) { #expect(line.contains("Pass the iPad to the \(role), then tap I'm the \(role)!"), "\(line)") }
    }

    // MARK: Roles in the voice path

    @Test func setRolesRanksSixAndAnnouncesOnlyThePlayingOnes() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmWithPrinter(); _ = await store.apply(.setPrintStyle(.colorIn))
        let out = await store.apply(.setRoles(["Captain", "Navigator", "Parrot Keeper", "Cook", "Lookout", "Treasure Keeper"].map { .init(roleName: $0, job: "") }))
        #expect(store.plan?.roles.count == 6 && store.playingRoles.map(\.roleName) == ["Captain", "Navigator"])
        #expect(out.contains("2 kids are playing: announce ONLY Captain, Navigator"))
        #expect(out.contains("We need a Captain and a Navigator!"))
        #expect(out.contains("6. Treasure Keeper"))
        let one = AdventureStore.rolesSetOutput(store.plan!.roles, players: 1)
        #expect(one.contains("announce ONLY the Captain") && !one.contains("Navigator ("))
    }

    // MARK: No AI call on a count change

    @Test func countChangeAfterTheRolesMakesNoAICall() async {
        let llm = FakeLLM()
        let store = AdventureStore(service: PhaseService(llm: llm))
        store.beginConversation()
        _ = await store.apply(.setGame("Airplane")); _ = await store.apply(.setTheme("Airplane to the Beach"))
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmWithPrinter(); _ = await store.apply(.setPrintStyle(.colorIn))
        _ = await store.apply(.setRoles(roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        for _ in 0..<300 where store.draftItems == nil { try? await Task.sleep(for: .milliseconds(10)) }
        let gen = store.draftGeneration, calls = llm.calls
        // During the hunt: the roles, props and the pages being written all stay.
        let hunt = await store.apply(.setPlayerCount(5))
        #expect(hunt.contains("Nothing is remade") && hunt.contains("Five friends! Our crew is a Captain, a Flight Attendant, a Co-Pilot, a Passenger and a Snack Chef!"))
        #expect(store.playerCount == 5 && store.plan?.roles.count == 6 && store.planningStep == .props)
        #expect(store.draftGeneration == gen && llm.calls == calls)
        _ = await store.apply(.finishPlanning)
        for _ in 0..<300 where store.phase != .kitReady || store.guidePending { try? await Task.sleep(for: .milliseconds(10)) }
        let afterKit = llm.calls
        let full = store.fullKit
        // At Paper: any count, still no call; the checklists and badges follow.
        for n in [1, 6, 3] {
            _ = await store.apply(.setPlayerCount(n))
            #expect(store.playerCount == n && store.phase == .kitReady && store.fullKit == full)
            #expect(store.kit?.scenes.allSatisfy { $0.steps.compactMap(\.role.role).count == n } == true)
            let badges = KitLayout.pages(for: store.kit!, roles: store.plan!.roles, playerCount: n).filter { $0.item.recipe == .badges }
            #expect(badges.flatMap(\.slots).count == n)
        }
        #expect(llm.calls == afterKit)
        // During play she points to Pick; at Pick the change works and Play starts over for the new crew.
        store.beginPlay()
        let inPlay = await store.apply(.setPlayerCount(2))
        #expect(inPlay.contains("tap Pick") && store.playerCount == 3)
        #expect(store.goTo(.game))
        _ = await store.apply(.setPlayerCount(2))
        #expect(store.playerCount == 2)
        #expect(store.goTo(.play) && store.phase == .handoff(sceneIndex: 0))
        #expect(llm.calls == afterKit)
    }

    @Test func drawItCountsFollowTheCurrentCount() {
        let g = DrawIt.fallback(playerCount: 1)
        let badges = g.pieces.first { $0.kind == .badges }!
        #expect(DrawIt.countLine(badges, players: 4) == "Make four, one for each friend.")
        #expect(DrawIt.countLine(badges, players: 1) == "Make one for you.")
        #expect(DrawIt.line(g, 0, players: 5).contains("Make five, one for each friend."))
        // The guide's inputs don't depend on the count, so a count change never rewrites it.
        let a = KitDraft.inputs(title: "X", playerCount: 2, plan: Fallback.airplane.plan, printStyle: .colorIn, step: .props)
        let b = KitDraft.inputs(title: "X", playerCount: 5, plan: Fallback.airplane.plan, printStyle: .colorIn, step: .props)
        #expect(a == b && a != nil)
    }

    // MARK: The 6-up badge sheet

    @Test func badgeSheetIsOneJobSlicedIntoSixPortraitBadges() {
        let items = kit.items
        let jobs = KitArtPlan.jobs(items: items, title: "Airplane", style: .colorIn, settled: [], roles: roles)
        let badge = items.first { $0.recipe == .badges }!
        let sheet = jobs.filter { $0.key == KitArtPlan.sheetKey(badge.id) }
        #expect(sheet.count == 1 && sheet[0].size == "1024x1536" && sheet[0].count == 6)
        #expect(!jobs.contains { $0.key == badge.id })
        for r in roles { #expect(sheet[0].prompt.contains(r.roleName)) }
        #expect(sheet[0].prompt.contains("3 columns and 2 rows") && sheet[0].prompt.contains(ImageSafety.suffix))
        #expect(KitArtPlan.keys(items: items, roles: roles).contains(KitArtPlan.sheetKey(badge.id)))
        // The sheet failed (or didn't slice into 6): the one shared badge image instead.
        let failed: Set<String> = [KitArtPlan.sheetFailedKey(badge.id)]
        let fb = KitArtPlan.jobs(items: items, title: "Airplane", style: .colorIn, settled: failed, roles: roles)
        #expect(fb.contains { $0.key == badge.id } && !fb.contains { $0.key == KitArtPlan.sheetKey(badge.id) })
        #expect(KitArtPlan.keys(items: items, roles: roles, settled: failed).contains(badge.id))
        // No roles known: the old shared badge.
        #expect(KitArtPlan.jobs(items: items, title: "Airplane", style: .colorIn, settled: []).contains { $0.key == badge.id })
    }

    @Test func badgeSheetSlicesKeepThePortraitShape() {
        // A 300×600 sheet with 6 ink badges (each 70×220) centered in a 3×2 grid.
        let w = 300, h = 600
        var gray = [UInt8](repeating: 255, count: w * h)
        for r in 0..<2 { for c in 0..<3 {
            let cx = c * 100 + 50, cy = r * 300 + 150
            for y in (cy - 110)..<(cy + 110) { for x in (cx - 35)..<(cx + 35) { gray[y * w + x] = 0 } }
        } }
        let cells = BadgeSheet.cells(gray: gray, width: w, height: h)
        #expect(cells.count == 6)
        for (k, cell) in cells.enumerated() {
            #expect(cell.height > cell.width * 2, "cell \(k) is portrait: \(cell)")
            #expect(cell.x <= (k % 3) * 100 + 15 && cell.x + cell.width >= (k % 3) * 100 + 85)   // the whole badge
            #expect(cell.y < (k / 3) * 300 + 41)
        }
        // The cut-out sheet is unchanged (square cells).
        let squares = CutoutSheet.cells(gray: gray, width: w, height: h, count: 6)
        #expect(squares.allSatisfy { $0.width == $0.height })
    }

    @Test func sixRoleColorsAllReadWithWhite() {
        #expect(BrandPalette.players.count == 6 && BrandPalette.playerShades.count == 6)
        for c in BrandPalette.players { #expect(BrandPalette.contrast(BrandPalette.white, c) >= 3) }
    }

    @Test func countChangeLines() {
        #expect(PlayCast.countChangeLine(roles: roles, players: 1) == "Just you! You'll be the Captain!")
        #expect(PlayCast.countChangeLine(roles: roles, players: 2) == "Two friends! Our crew is a Captain and a Flight Attendant!")
        #expect(PlayCast.crewList(Array(roles.prefix(3))) == "a Captain, a Flight Attendant and a Co-Pilot")
    }
}
