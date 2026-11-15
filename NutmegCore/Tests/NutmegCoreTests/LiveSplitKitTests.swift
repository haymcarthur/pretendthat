import Foundation
import Testing
@testable import NutmegCore

/// Round 20 live timing (LIVE_SPLIT=1 and a key via tools/with-keys.sh; costs real calls): the pages call, then the
/// play guide at medium and low effort, for one game. Prints timings only.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_SPLIT"] == "1"
               && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
func liveSplitKitTimings() async throws {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let llm = CountingLLM(ClaudeClient(config: ClaudeConfig(mode: .direct(apiKey: key))))
    let svc = PhaseService(llm: llm)
    let roles = [Role(id: .R1, roleName: "Head Baker", emoji: "", symbol: "star", job: "bakes"),
                 Role(id: .R2, roleName: "Space Server", emoji: "", symbol: "star", job: "serves")]
    let plan = GamePlan(gameTitle: "Bakery on the Moon", gameEmoji: "", setting: "Bakery on the Moon", roles: roles, nutmegSays: "")
    var ctx = AdventureContext(gameTitle: "Bakery on the Moon", plan: plan, playerCount: 2)
    var t = Date()
    let items = try await svc.kitPages(ctx: ctx)
    print("LIVE pages: \(String(format: "%.1f", Date().timeIntervalSince(t))) s, calls \(llm.calls)")
    ctx.props = Props(nutmegSays: "", props: [
        Prop(id: "bowl", householdItem: "Bowl", becomes: "the mixing bowl", forRole: .R1, safetyOK: true, libraryID: "bowl"),
        Prop(id: "tray", householdItem: "Tray", becomes: "the treat tray", forRole: .R2, safetyOK: true, libraryID: "tray"),
        Prop(id: "hat", householdItem: "Hat", becomes: "the baker hat", forRole: .R1, safetyOK: true, libraryID: "hat", skipped: true)])
    let final = KitDraft.finalItems(items, props: ctx.props)
    for effort in [Effort.medium, .low] {
        let before = llm.calls
        t = Date()
        let kit = try await svc.kitScenes(ctx: ctx, items: final, effort: effort)
        print("LIVE scenes \(effort.rawValue): \(String(format: "%.1f", Date().timeIntervalSince(t))) s, \(kit.scenes.count) scenes, calls \(llm.calls - before)")
        #expect(kit.scenes.count >= 4)
    }
}
