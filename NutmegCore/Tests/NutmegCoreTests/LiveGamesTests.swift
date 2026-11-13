import Foundation
import Testing
@testable import NutmegCore

/// Live any-game check (M4). Runs only with LIVE_GAMES=1 and a key (tools/with-keys.sh). Costs real API calls.
/// For each game: ideas → plan → props → kit on the raw client, then asserts the model already met every limit
/// (the Sanitizer would change nothing). Writes each result to /tmp/nutmeg-kits/<game>.json.
struct LiveCase: Sendable, CustomStringConvertible {
    let game: String; let players: Int
    var description: String { "\(game) (\(players)p)" }
}

let liveEnabled = ProcessInfo.processInfo.environment["LIVE_GAMES"] == "1"
    && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false

let liveCases: [LiveCase] = {
    let all = [LiveCase(game: "restaurant", players: 2),
               LiveCase(game: "vet clinic", players: 3),
               LiveCase(game: "underwater bakery", players: 2),
               LiveCase(game: "hotel", players: 1),
               LiveCase(game: "space station", players: 5),
               LiveCase(game: "grocery store", players: 4)]
    guard let only = ProcessInfo.processInfo.environment["LIVE_ONLY"] else { return all }
    return all.filter { only.split(separator: ",").contains(Substring($0.game)) }
}()

/// Wraps the real client and counts calls, so the PhaseService path shows how often a corrective retry ran.
final class CountingLLM: LLM, @unchecked Sendable {
    let inner: LLM; private let lock = NSLock(); private var n = 0
    var calls: Int { lock.withLock { n } }
    init(_ inner: LLM) { self.inner = inner }
    func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        lock.withLock { n += 1 }
        return try await inner.structured(type, system: system, user: user, schema: schema, effort: effort)
    }
}

struct LiveProblems { var list: [String] = []; mutating func check(_ ok: Bool, _ msg: String) { if !ok { list.append(msg) } } }

/// No names and no name placeholders anywhere (roles-not-names.md).
func hasNamePlaceholder(_ text: String) -> Bool { text.contains("{P") || text.contains("{R") }

@Test(.enabled(if: liveEnabled), .timeLimit(.minutes(5)), arguments: liveCases)
func liveGame(_ c: LiveCase) async throws {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let llm = ClaudeClient(config: .init(mode: .direct(apiKey: key)))
    let count = min(4, c.players)
    var p = LiveProblems()
    let started = Date()

    let ideas = try await llm.structured(GameIdeas.self, system: Prompts.system, user: Prompts.ideas(kidSaid: "I want to play \(c.game)"), schema: JSONSchema(Schemas.gameIdeas()), effort: .medium)
    p.check(ideas.ideas.count == 3, "ideas=\(ideas.ideas.count)")

    var ctx = AdventureContext(gameTitle: c.game, playerCount: c.players)
    let plan = try await llm.structured(GamePlan.self, system: Prompts.system, user: Prompts.plan(game: c.game, ctx: ctx), schema: JSONSchema(Schemas.plan()), effort: .medium)
    // Unknown symbols becoming "star" is by design, so only role/token problems count here.
    var symbolFree = plan; symbolFree.roles = symbolFree.roles.map { var r = $0; r.symbol = PrintSymbols.safe(r.symbol); return r }
    p.check(symbolFree == Sanitizer.clean(plan, playerCount: c.players), "plan roles needed sanitizing: \(plan.roles.map { "\($0.id.rawValue) \($0.roleName) x\($0.count)" })")
    let swapped = plan.roles.map(\.symbol).filter { PrintSymbols.safe($0) != $0 }
    if !swapped.isEmpty { print("NOTE \(c): symbols shown as star: \(swapped)") }
    p.check(plan.roles.count == count, "roles=\(plan.roles.count) want \(count)")
    ctx.plan = plan

    let props = try await llm.structured(Props.self, system: Prompts.system, user: Prompts.props(ctx: ctx), schema: JSONSchema(Schemas.props()), effort: .medium)
    p.check((3...5).contains(props.props.count), "props=\(props.props.count)")
    p.check(props.props.allSatisfy(\.safetyOK), "unsafe props: \(props.props.filter { !$0.safetyOK }.map(\.householdItem))")
    p.check(props.props.allSatisfy { ($0.forRole.role?.index ?? 0) < count }, "prop forRole beyond players")
    let words = { (s: String) in s.split(separator: " ").count }
    p.check(props.props.allSatisfy { words($0.householdItem) <= 4 && words($0.becomes) <= 5 }, "long prop text: \(props.props.map { "\($0.householdItem) → \($0.becomes)" })")
    ctx.props = props

    // The kit goes through PhaseService (sanitize + one corrective retry), as in the app.
    let counting = CountingLLM(llm)
    let kit = try await PhaseService(llm: counting).kit(ctx: ctx)
    let kitCalls = counting.calls
    p.check(Validate.kit(kit) == nil, "kit still short after retry: \(Validate.kit(kit)?.message ?? "")")
    p.check(kit.items.map(\.recipe) == KitRecipe.allCases.map { Optional($0) }, "recipe=\(kit.items.map { $0.recipe?.rawValue ?? "-" })")
    p.check((4...6).contains(kit.scenes.count), "scenes=\(kit.scenes.count)")
    p.check(kit.scenes.allSatisfy { (3...5).contains($0.steps.count) }, "steps=\(kit.scenes.map(\.steps.count))")
    let pages = KitLayout.pages(for: kit, roles: plan.roles, playerCount: c.players)
    p.check(pages.count <= KitLayout.maxPages, "pages=\(pages.count)")
    let allText = [plan.nutmegSays, props.nutmegSays, kit.nutmegSays] + kit.scenes.map(\.nutmegSays) + kit.items.flatMap(\.lines)
    p.check(!allText.contains(where: hasNamePlaceholder), "name placeholder in output")

    let secs = Int(Date().timeIntervalSince(started))
    let out: [String: Any] = ["case": c.description, "seconds": secs, "kitCalls": kitCalls, "problems": p.list,
        "ideas": try JSONSerialization.jsonObject(with: JSONEncoder().encode(ideas)),
        "plan": try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)),
        "props": try JSONSerialization.jsonObject(with: JSONEncoder().encode(props)),
        "kit": try JSONSerialization.jsonObject(with: JSONEncoder().encode(kit))]
    let dir = URL(fileURLWithPath: "/tmp/nutmeg-kits"); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]).write(to: dir.appendingPathComponent("\(c.game.replacingOccurrences(of: " ", with: "-")).json"))
    print("LIVE \(c): \(secs)s, kitCalls=\(kitCalls), pages=\(pages.count), problems=\(p.list)")
    #expect(p.list.isEmpty, "\(c): \(p.list)")
}
