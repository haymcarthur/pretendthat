import Foundation
import Testing
@testable import NutmegCore

/// Round C1 cost measurement (before: the HEAD version of this test measured 7.2–7.6 cents) (LIVE_COST=1 + a key via tools/with-keys.sh; real calls): the kit pages and the play
/// guide for one game at N players, with the token usage of every call.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_COST"] == "1"
               && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
func liveCostPerGame() async throws {
  for players in [2, 5, 2, 5] {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let svc = PhaseService(llm: ClaudeClient(config: ClaudeConfig(mode: .direct(apiKey: key))))
    let names = [("Captain", "steer the ship"), ("Navigator", "read the map"), ("Parrot Keeper", "feed the parrot"),
                 ("Cook", "make pirate snacks"), ("Lookout", "spot the island"), ("Treasure Keeper", "guard the gold")]
    // Round C1: always 6 ranked roles; the count only says how many play.
    let drafts = names.map { Role(id: .R1, roleName: $0.0, emoji: "", symbol: "star", job: $0.1) }
    let plan = Sanitizer.clean(GamePlan(gameTitle: "Pirate Ship on the Moon", setting: "Pirate Ship on the Moon", roles: drafts, nutmegSays: ""), playerCount: players)
    var ctx = AdventureContext(gameTitle: "Pirate Ship on the Moon", plan: plan, playerCount: players)
    ClaudeUsageMeter.shared.reset()
    let items = try await svc.kitPages(ctx: ctx)
    let pages = ClaudeUsageMeter.shared.calls
    ctx.props = Props(nutmegSays: "", props: [
        Prop(id: "box", householdItem: "Cardboard box", becomes: "the treasure chest", forRole: .all, safetyOK: true, libraryID: "box"),
        Prop(id: "towel", householdItem: "Towel", becomes: "the pirate cape", forRole: .all, safetyOK: true, libraryID: "towel"),
        Prop(id: "bowl", householdItem: "Bowl", becomes: "the captain's hat", forRole: .all, safetyOK: true, libraryID: "bowl", skipped: true)])
    let kit = try await svc.kitScenes(ctx: ctx, items: KitDraft.finalItems(items, props: ctx.props))
    let all = ClaudeUsageMeter.shared.calls
    let scenes = Array(all.dropFirst(pages.count))
    func sum(_ c: [ClaudeUsageMeter.Call]) -> (Int, Int, Double) {
        let i = c.map(\.input).reduce(0, +), o = c.map(\.output).reduce(0, +); return (i, o, ClaudeUsageMeter.cents(input: i, output: o))
    }
    let p = sum(pages), s = sum(scenes), t = sum(all)
    print("LIVECOST players=\(players) pages calls=\(pages.count) in=\(p.0) out=\(p.1) cents=\(String(format: "%.2f", p.2)) | scenes calls=\(scenes.count) in=\(s.0) out=\(s.1) cents=\(String(format: "%.2f", s.2)) | total cents=\(String(format: "%.2f", t.2)) | \(kit.scenes.count) scenes, steps \(kit.scenes.map(\.steps.count)), role gaps: \(Validate.scenes(kit.scenes, roles: 6)?.message ?? "none")")
    let view = PlayCast.kit(kit, roles: plan.roles, players: players)
    for s in view.scenes { print("LIVEVIEW n=\(players) [\(s.owner.rawValue)] \(s.title): " + s.steps.map { "\($0.role.rawValue): \($0.text)" }.joined(separator: " | ")) }
}
}
