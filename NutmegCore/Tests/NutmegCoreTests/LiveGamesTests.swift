import Foundation
import Testing
@testable import NutmegCore

/// Live any-game check (M4). Runs only with LIVE_GAMES=1 and a key (tools/with-keys.sh). Costs real API calls.
/// For each game: ideas → plan → props → kit on the raw client, then asserts the model already met every limit
/// (the Sanitizer would change nothing). Writes each result to /tmp/nutmeg-kits/<game>.json.
struct LiveCase: Sendable, CustomStringConvertible {
    let game: String; let players: Int; let director: Bool
    var description: String { "\(game) (\(director ? "director" : "\(players)p"))" }
}

let liveEnabled = ProcessInfo.processInfo.environment["LIVE_GAMES"] == "1"
    && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false

let liveCases: [LiveCase] = {
    let all = [LiveCase(game: "restaurant", players: 2, director: false),
               LiveCase(game: "vet clinic", players: 3, director: false),
               LiveCase(game: "underwater bakery", players: 2, director: false),
               LiveCase(game: "hotel", players: 1, director: false),
               LiveCase(game: "space station", players: 5, director: true),
               LiveCase(game: "grocery store", players: 4, director: false)]
    guard let only = ProcessInfo.processInfo.environment["LIVE_ONLY"] else { return all }
    return all.filter { only.split(separator: ",").contains(Substring($0.game)) }
}()

struct LiveProblems { var list: [String] = []; mutating func check(_ ok: Bool, _ msg: String) { if !ok { list.append(msg) } } }

func tokenProblems(_ text: String, count: Int) -> Bool {
    let used = PlayerToken.allCases.filter { text.contains($0.placeholder) }
    return used.allSatisfy { $0.index < count }
}

@Test(.enabled(if: liveEnabled), .timeLimit(.minutes(5)), arguments: liveCases)
func liveGame(_ c: LiveCase) async throws {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let llm = ClaudeClient(config: .init(mode: .direct(apiKey: key)))
    let count = c.director ? 4 : c.players
    var p = LiveProblems()
    let started = Date()

    let ideas = try await llm.structured(GameIdeas.self, system: Prompts.system, user: Prompts.ideas(kidSaid: "I want to play \(c.game)"), schema: JSONSchema(Schemas.gameIdeas()), effort: .medium)
    p.check(ideas.ideas.count == 3, "ideas=\(ideas.ideas.count)")

    var ctx = AdventureContext(gameTitle: c.game, playerCount: c.players, directorMode: c.director)
    let plan = try await llm.structured(GamePlan.self, system: Prompts.system, user: Prompts.plan(game: c.game, ctx: ctx), schema: JSONSchema(Schemas.plan()), effort: .medium)
    p.check(plan == Sanitizer.clean(plan, playerCount: count), "plan needed sanitizing: roles=\(plan.roles.map { "\($0.player.rawValue):\($0.symbol)" })")
    p.check(plan.roles.count == count, "roles=\(plan.roles.count) want \(count)")
    ctx.plan = plan

    let props = try await llm.structured(Props.self, system: Prompts.system, user: Prompts.props(ctx: ctx), schema: JSONSchema(Schemas.props()), effort: .medium)
    p.check((3...5).contains(props.props.count), "props=\(props.props.count)")
    p.check(props.props.allSatisfy(\.safetyOK), "unsafe props: \(props.props.filter { !$0.safetyOK }.map(\.householdItem))")
    p.check(props.props.allSatisfy { ($0.forRole.token?.index ?? 0) < count }, "prop forRole beyond players")
    let words = { (s: String) in s.split(separator: " ").count }
    p.check(props.props.allSatisfy { words($0.householdItem) <= 4 && words($0.becomes) <= 5 }, "long prop text: \(props.props.map { "\($0.householdItem) → \($0.becomes)" })")
    ctx.props = props

    let kit = try await llm.structured(Kit.self, system: Prompts.system, user: Prompts.kit(ctx: ctx), schema: JSONSchema(Schemas.kit()), effort: .medium)
    p.check(kit == Sanitizer.clean(kit, playerCount: count), "kit needed sanitizing: symbols=\(kit.items.map(\.symbol)) copies=\(kit.items.map(\.copies)) owners=\(kit.scenes.map(\.owner.rawValue))")
    p.check((2...4).contains(kit.items.count), "items=\(kit.items.count)")
    p.check((4...6).contains(kit.scenes.count), "scenes=\(kit.scenes.count)")
    p.check(kit.scenes.allSatisfy { (3...5).contains($0.steps.count) }, "steps=\(kit.scenes.map(\.steps.count))")
    let pages = KitLayout.pages(for: kit, players: Array(PlayerToken.allCases.prefix(count)), directorMode: c.director)
    p.check(pages.count <= KitLayout.maxPages, "pages=\(pages.count)")
    let allText = [plan.nutmegSays, props.nutmegSays, kit.nutmegSays] + kit.scenes.map(\.nutmegSays) + kit.items.flatMap(\.lines)
    p.check(allText.allSatisfy { tokenProblems($0, count: count) }, "token beyond player count")

    let secs = Int(Date().timeIntervalSince(started))
    let out: [String: Any] = ["case": c.description, "seconds": secs, "problems": p.list,
        "ideas": try JSONSerialization.jsonObject(with: JSONEncoder().encode(ideas)),
        "plan": try JSONSerialization.jsonObject(with: JSONEncoder().encode(plan)),
        "props": try JSONSerialization.jsonObject(with: JSONEncoder().encode(props)),
        "kit": try JSONSerialization.jsonObject(with: JSONEncoder().encode(kit))]
    let dir = URL(fileURLWithPath: "/tmp/nutmeg-kits"); try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys]).write(to: dir.appendingPathComponent("\(c.game.replacingOccurrences(of: " ", with: "-")).json"))
    print("LIVE \(c): \(secs)s, pages=\(pages.count), problems=\(p.list)")
    #expect(p.list.isEmpty, "\(c): \(p.list)")
}
