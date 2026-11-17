import Foundation
import Testing
@testable import NutmegCore

/// Round C1 (generate for 6; Haylee's answer 2: every playing role gets its OWN called-out task in every scene; round 29:
/// all their rows show at once). Pure rules plus the store's "no AI call on a count change".
@MainActor
struct RoundC1Tests {
    let roles = Fallback.airplane.plan.roles
    let kit = Fallback.airplane.kit

    // MARK: Schemas and prompts

    @Test func schemasAllowSixRolesAndRoleTaggedStepsWithNoOwner() throws {
        #expect(RoleID.allCases.map(\.rawValue) == ["R1", "R2", "R3", "R4", "R5", "R6"])
        #expect(Schemas.roleIDs == ["R1", "R2", "R3", "R4", "R5", "R6"])
        let json = String(decoding: try JSONSerialization.data(withJSONObject: Schemas.kitScenes(), options: [.sortedKeys]), as: UTF8.self)
        #expect(json.contains(#""enum":["R1","R2","R3","R4","R5","R6","solo"]"#))   // round 29: a task per role + solo
        #expect(!json.contains("\"owner\""))
        let plan = String(decoding: try JSONSerialization.data(withJSONObject: Schemas.plan(), options: [.sortedKeys]), as: UTF8.self)
        #expect(!plan.contains("\"count\""))
        // Strict objects: every task property is required (round 29: no pictures).
        let steps = (((Schemas.kitScenes()["properties"] as! [String: Any])["scenes"] as! [String: Any])["items"] as! [String: Any])
        let step = ((steps["properties"] as! [String: Any])["steps"] as! [String: Any])["items"] as! [String: Any]
        #expect(Set(step["required"] as! [String]) == ["role", "text", "short"])   // round 34: spoken + shown
    }

    @Test func promptsAskForSixRankedRolesAndATaskPerRole() {
        let ctx = AdventureContext(gameTitle: "Pirate Ship", plan: Fallback.airplane.plan, playerCount: 2)
        #expect(Prompts.plan(game: "Pirate Ship", ctx: ctx).contains("exactly 6 different roles, ranked"))
        for p in [Prompts.kitScenes(ctx: ctx, items: kit.items), Prompts.kit(ctx: ctx)] {
            // Round 29: 3 scenes, ONE task per role + a solo task, connected, never scripted.
            #expect(p.contains("exactly 3 scenes") && p.contains("ONE task for EACH role R1, R2, R3, R4, R5 and R6, plus one solo task"))
            #expect(p.contains("NEVER script lines") && p.contains("CONNECT"))
        }
        #expect(Prompts.system.contains("6 RANKED roles"))
        #expect(Realtime.instructions.contains("exactly 6 RANKED roles"))
        let setRoles = Realtime.json(["t": Realtime.tools])
        #expect(setRoles.contains("Exactly 6 ranked roles for this game"))
        #expect(ConfirmStep.confirmedOutput(playerCount: 3).contains("exactly 6 ranked roles"))
    }

    @Test func validateAsksForATaskForEveryRoleInEveryScene() {
        #expect(Validate.scenes(kit.scenes, roles: 6) == nil)
        var short = kit.scenes
        short[2].steps.removeAll { $0.role == .R5 }
        let p = Validate.scenes(short, roles: 6)
        #expect(p?.fatal == false && p?.message.contains("no task for R5") == true)
        #expect(Validate.scenes(short, roles: 0) == nil)   // older callers: no role check
        #expect(Validate.scenes(Array(kit.scenes.prefix(2)), roles: 6)?.message.contains("exactly 3 scenes") == true)
    }

    @Test func sanitizerKeepsOneTaskPerRoleAndOneSolo() {
        var s = kit.scenes[0]
        s.steps += [Step(picture: .point, text: "Captain, again", role: .R1), Step(picture: .point, text: "All three", role: .all),
                    Step(picture: .point, text: "Captain, solo again", role: .solo)]
        let clean = Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: [s])).scenes[0]
        #expect(clean.steps.count == 7)
        #expect(clean.steps.filter { $0.role == .R1 }.map(\.text) == [kit.scenes[0].steps[0].text])
        #expect(clean.steps.filter { $0.role == .solo }.count == 1 && clean.steps.filter { $0.role == .all }.isEmpty)
        #expect(clean.owner == .all)
        #expect(Sanitizer.clean(Kit(nutmegSays: "", items: [], scenes: kit.scenes + kit.scenes)).scenes.count == 3)
        // Older JSON (no role on steps) still decodes: everyone's steps, no owner needed.
        let old = try? JSONDecoder().decode(Scene.self, from: Data(#"{"id":"a","title":"T","nutmegSays":"Pretend that!","steps":[{"text":"Wave"}]}"#.utf8))
        #expect(old?.steps.first?.role == .all && old?.owner == .all)
    }

    // MARK: Per-role coverage at every count (round 29: one row per playing role, all at once)

    @Test func everyPlayingRoleHasItsOwnCalledOutRowInEveryScene() {
        for n in 1...6 {
            let view = PlayCast.kit(kit, roles: roles, players: n)
            #expect(view.scenes.count == kit.scenes.count, "n=\(n)")
            for (i, scene) in view.scenes.enumerated() {
                #expect(scene.steps.map(\.role) == Array(RoleID.allCases.prefix(n)).map { SceneOwner($0) })
                for step in scene.steps { #expect(PlayCast.names(step.text, roles[step.role.role!.index].roleName), "\(step.text)") }
                #expect(PretendLine.has(scene.nutmegSays))
                if n == 1 { #expect(scene.steps[0].text == kit.scenes[i].steps.first { $0.role == .solo }!.text) }
                for away in roles.dropFirst(n) {
                    // (Round 29: a solo task may speak of pretend passengers, so one kid's row is left out of this check.)
                    let texts = [scene.title, scene.nutmegSays] + (n == 1 ? [] : scene.steps.map(\.text))
                    #expect(!texts.contains { PlayCast.names($0, away.roleName) }, "n=\(n) names \(away.roleName)")
                }
            }
        }
    }

    @Test func aMissingRoleTaskIsWrittenFromTheJobAndUncalledTasksGetTheTitle() {
        var s = kit.scenes[0]
        s.steps.removeAll { $0.role == .R3 }
        s.steps[0].text = "Hold the steering wheel"   // R1's task forgot to call the Captain
        let v = PlayCast.rows(s, roles: roles, players: 3)
        #expect(v.first?.text == "Captain, hold the steering wheel")
        #expect(v.filter { $0.role == .R3 }.map(\.text) == ["Flight Attendant, check tickets and bring snacks!"])
        // No solo task: one kid gets R1's.
        s.steps.removeAll { $0.role == .solo }
        #expect(PlayCast.rows(s, roles: roles, players: 1).map(\.text) == ["Captain, hold the steering wheel"])
    }

    @Test func linesNamingAnAbsentRoleAreRewritten() {
        let r = roles
        #expect(PlayCast.unname("Captain, give the map to the VIP Passenger", roles: r, players: 2) == "Captain, give the map to a friend")
        #expect(PlayCast.unname("The Snack Chef's tray is ready!", roles: r, players: 4) == "A friend's tray is ready!")
        #expect(PlayCast.unname("Co-Pilot, wave", roles: r, players: 4) == "Co-Pilot, wave")          // playing: unchanged
        #expect(PlayCast.sceneLine("Pretend that it's stormy! Snack Chef, look out!", roles: r, players: 2) == "Pretend that it's stormy!")
        #expect(!PlayCast.names("Co-Pilot, wave", "Pilot"))
    }

    // MARK: Roles in the voice path

    @Test func setRolesRanksSixAndAnnouncesOnlyThePlayingOnes() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
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
        _ = await store.apply(.setPlayerCount(2)); _ = await store.confirmYes()
        _ = await store.apply(.setRoles(roles.map { .init(roleName: $0.roleName, job: $0.job) }))
        for _ in 0..<300 where store.draftItems == nil { try? await Task.sleep(for: .milliseconds(10)) }
        let gen = store.draftGeneration, calls = llm.calls
        // During the hunt: the roles, props and the pages being written all stay.
        let hunt = await store.apply(.setPlayerCount(5))
        #expect(hunt.contains("Nothing is remade") && hunt.contains("Five friends! Our crew is a Captain, a Passenger, a Flight Attendant, a Co-Pilot and a Snack Chef!"))
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
            #expect(store.kit?.scenes.count == store.fullKit?.scenes.count)   // round 29: the same 3 scenes
            #expect(store.kit?.scenes.allSatisfy { $0.steps.count == n } == true)   // a row per playing role
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
        #expect(store.goTo(.play) && store.phase == .scene(0))
        #expect(llm.calls == afterKit)
    }

    @Test func kitInputsDontDependOnTheCount() {
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
        #expect(PlayCast.countChangeLine(roles: roles, players: 2) == "Two friends! Our crew is a Captain and a Passenger!")
        #expect(PlayCast.crewList(Array(roles.prefix(3))) == "a Captain, a Passenger and a Flight Attendant")
    }
}
