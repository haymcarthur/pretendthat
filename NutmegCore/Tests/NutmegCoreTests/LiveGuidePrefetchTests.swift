import Foundation
import Testing
@testable import NutmegCore

/// Guide prefetch live timing (LIVE_GUIDE=1 and a key via tools/with-keys.sh; real calls): the pages, the early play
/// guide (no props), then one weave call per prop, and the final guide after a skip. Prints timings and the steps that
/// use a prop only.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_GUIDE"] == "1"
               && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
func liveGuidePrefetchTimings() async throws {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let svc = PhaseService(llm: ClaudeClient(config: ClaudeConfig(mode: .direct(apiKey: key))))
    let names = [("Captain", "steer the ship"), ("Navigator", "read the map"), ("Parrot Keeper", "feed the parrot"),
                 ("Cook", "make pirate snacks"), ("Lookout", "spot the island"), ("Treasure Keeper", "guard the gold")]
    let drafts = names.map { Role(id: .R1, roleName: $0.0, emoji: "", symbol: "star", job: $0.1) }
    let plan = Sanitizer.clean(GamePlan(gameTitle: "Pirate Ship on the Moon", setting: "Pirate Ship on the Moon", roles: drafts, nutmegSays: ""), playerCount: 2)
    var ctx = AdventureContext(gameTitle: "Pirate Ship on the Moon", plan: plan, playerCount: 2)
    var t = Date()
    let items = try await svc.kitPages(ctx: ctx)
    print("LIVEGUIDE pages \(String(format: "%.1f", Date().timeIntervalSince(t))) s")
    t = Date()
    var kit = try await svc.earlyGuide(ctx: ctx, items: items)
    print("LIVEGUIDE early guide \(String(format: "%.1f", Date().timeIntervalSince(t))) s, \(kit.scenes.count) scenes, steps \(kit.scenes.map(\.steps.count)), gaps: \(Validate.scenes(kit.scenes, roles: 6)?.message ?? "none")")
    for (i, sc) in kit.scenes.enumerated() {
        print("LIVEGUIDE scene \(i + 1) \"\(sc.title)\": \(sc.nutmegSays)")
        for st in sc.steps { print("LIVEGUIDE   \(st.role.rawValue): [\(st.short ?? "-")] \(st.text)") }
    }
    let all = [Prop(id: "cardboard-box", householdItem: "Cardboard box", becomes: "the treasure chest", forRole: .all, safetyOK: true, libraryID: "cardboard-box"),
               Prop(id: "towel", householdItem: "Towel", becomes: "the pirate cape", forRole: .R1, safetyOK: true, libraryID: "towel"),
               Prop(id: "bowl", householdItem: "Bowl", becomes: "the captain's hat", forRole: .all, safetyOK: true, libraryID: "bowl")]
    var uses: [PropUse] = []
    for p in all {
        t = Date()
        let w = try await svc.weaveProps(scenes: kit.scenes, props: [p], taken: uses, ctx: ctx)
        let r = GuideWeave.apply(w, to: kit.scenes, props: [p], taken: uses)
        kit.scenes = r.scenes; uses += r.uses
        print("LIVEGUIDE weave \(p.id) \(String(format: "%.1f", Date().timeIntervalSince(t))) s, \(r.uses.count) step(s): "
              + r.uses.map { "s\($0.scene).\($0.step) \(kit.scenes[$0.scene].steps[$0.step].role.rawValue): \(kit.scenes[$0.scene].steps[$0.step].text)" }.joined(separator: " | "))
    }
    var props = Props(nutmegSays: "", props: all); props.props[2].skipped = true
    ctx.props = props
    let final = KitDraft.finalItems(items, props: props)
    let scenes = GuideWeave.finalize(kit.scenes, uses: uses, props: props, items: final)
    let safe = await svc.guideIsSafe(scenes)
    for u in uses { print("LIVEGUIDE final s\(u.scene).\(u.step) [\(scenes[u.scene].steps[u.step].picture.kind.rawValue):\(scenes[u.scene].steps[u.step].picture.id)] \(scenes[u.scene].steps[u.step].text)") }
    print("LIVEGUIDE safe \(safe)")
    for n in [2, 5] {
        let view = PlayCast.kit(Kit(nutmegSays: "", items: final, scenes: scenes), roles: plan.roles, players: n)
        let shown = view.scenes.flatMap(\.steps).filter { $0.picture.kind == .prop || $0.picture.id.hasPrefix("cutout:") && $0.text.contains("pretend") }
        print("LIVEGUIDE n=\(n) prop steps shown: \(shown.count): " + shown.map(\.text).joined(separator: " | "))
    }
}
