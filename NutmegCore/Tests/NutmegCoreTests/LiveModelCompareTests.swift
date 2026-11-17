import Foundation
import Testing
@testable import NutmegCore

/// Cost v3 (2026-11-16): the same 3 game setups through the voice path's Claude calls (kit pages, early play guide, a
/// weave per prop, the final guide) plus the tap path's plan and a help call, on the model named by PT_CLAUDE_MODELS
/// (e.g. "all=claude-haiku-5-5"; empty = Opus). LIVE_COMPARE=1 and keys via tools/with-keys.sh; real calls.
/// Writes every raw answer and a summary to $PT_COMPARE_OUT/<label>/ (numbers and generated game text only; no kid data).
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_COMPARE"] == "1"
               && ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
func liveModelCompare() async throws {
    let env = ProcessInfo.processInfo.environment
    let key = env["ANTHROPIC_API_KEY"]!
    let label = env["PT_COMPARE_LABEL"] ?? "opus"
    let root = URL(fileURLWithPath: env["PT_COMPARE_OUT"] ?? "/tmp/pt-cost3/claude").appendingPathComponent(label)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    let rec = CompareTransport()
    let moderator = (env["OPENAI_API_KEY"]?.isEmpty == false) ? ModerationClient(mode: .direct(apiKey: env["OPENAI_API_KEY"]!)) : nil
    let svc = PhaseService(llm: ClaudeClient(config: ClaudeConfig(mode: .direct(apiKey: key)), transport: rec), moderator: moderator)

    struct Setup { let id, title: String; let players: Int; let roles: [(String, String)]; let props: [Prop]; let skip: String? }
    func prop(_ id: String, _ item: String, _ becomes: String) -> Prop {
        Prop(id: id, householdItem: item, becomes: becomes, forRole: .all, safetyOK: true, libraryID: id)
    }
    let setups = [
        Setup(id: "A-pizza-jungle-3", title: "Pizza Restaurant in the Jungle", players: 3,
              roles: [("Pizza Chef", "make the jungle pizzas"), ("Hungry Customer", "order and eat pizza"), ("Server", "take orders and bring pizza"),
                      ("Cashier", "take the money"), ("Delivery Driver", "deliver pizzas through the jungle"), ("Monkey Helper", "find toppings")],
              props: [prop("bowl", "Bowl", "the mixing bowl"), prop("tray", "Tray", "the pizza tray"), prop("apron", "Apron", "the chef's apron"),
                      prop("paper-plate", "Paper plate", "the pizza"), prop("wooden-spoon", "Wooden spoon", "the sauce spoon")], skip: nil),
        Setup(id: "B-dragon-petshop-5", title: "Pet Shop for Dragons", players: 5,
              roles: [("Shopkeeper", "run the dragon pet shop"), ("Dragon Buyer", "choose a baby dragon to take home"), ("Dragon Vet", "check the dragons are healthy"),
                      ("Dragon Feeder", "feed the baby dragons"), ("Egg Keeper", "keep the dragon eggs warm"), ("Shop Helper", "clean the cages")],
              props: [prop("cardboard-box", "Cardboard box", "the dragon nest"), prop("towel", "Towel", "the dragon blanket"),
                      prop("egg-carton", "Egg carton", "the dragon egg tray"), prop("flashlight", "Flashlight", "the vet's light"),
                      prop("basket", "Basket", "the dragon carrier")], skip: "flashlight"),
        Setup(id: "C-robot-station-2", title: "Space Station with Robots", players: 2,
              roles: [("Station Captain", "run the space station"), ("Robot Visitor", "visit the station and get fixed"), ("Robot Mechanic", "fix the robots"),
                      ("Radio Operator", "talk to Earth"), ("Space Cook", "make space food"), ("Spacewalker", "fix the outside of the station")],
              props: [prop("colander", "Colander", "the space helmet"), prop("paper-towel-tube", "Paper towel tube", "the telescope"),
                      prop("toy-keys", "Toy keys", "the robot tools"), prop("pillowcase", "Pillowcase", "the moon rock bag")], skip: nil),
    ]

    var summary: [String] = []
    func save(_ name: String, _ text: String) { try? text.write(to: root.appendingPathComponent(name), atomically: true, encoding: .utf8) }
    func usage(_ calls: [CompareTransport.Call]) -> String {
        let i = calls.map(\.input).reduce(0, +), o = calls.map(\.output).reduce(0, +), cr = calls.map(\.cacheRead).reduce(0, +)
        return "calls=\(calls.count) in=\(i) cacheRead=\(cr) out=\(o) model=\(Set(calls.map(\.model)).sorted().joined(separator: "/")) secs=\(String(format: "%.1f", calls.map(\.seconds).reduce(0, +)))"
    }

    for s in setups {
        let drafts = s.roles.map { Role(id: .R1, roleName: $0.0, emoji: "", symbol: "star", job: $0.1) }
        let plan = Sanitizer.clean(GamePlan(gameTitle: s.title, setting: s.title, roles: drafts, nutmegSays: ""), playerCount: s.players)
        var ctx = AdventureContext(gameTitle: s.title, plan: plan, playerCount: s.players)

        // Tap path: the plan (roles) for the same game.
        rec.take()
        do {
            let p = try await svc.plan(game: s.title, ctx: AdventureContext(gameTitle: s.title, playerCount: s.players))
            summary.append("\(s.id) plan: \(usage(rec.take())) roles: " + p.roles.map { "\($0.id.rawValue) \($0.roleName)" }.joined(separator: ", "))
        } catch { summary.append("\(s.id) plan: FAILED \(error) \(usage(rec.take()))") }
        save("\(s.id)-1-plan.json", rec.rawLog())

        rec.take(); rec.clearRaw()
        let items: [KitItem]
        do { items = try await svc.kitPages(ctx: ctx) } catch { summary.append("\(s.id) pages: FAILED \(error) \(usage(rec.take()))"); continue }
        summary.append("\(s.id) pages: \(usage(rec.take())) items: " + items.map { "\($0.recipe?.rawValue ?? "-"):\($0.title)" }.joined(separator: " | "))
        save("\(s.id)-2-pages.json", rec.rawLog()); rec.clearRaw()

        var kit: Kit
        do { kit = try await svc.earlyGuide(ctx: ctx, items: items) } catch { summary.append("\(s.id) guide: FAILED \(error) \(usage(rec.take()))"); continue }
        summary.append("\(s.id) guide: \(usage(rec.take())) scenes=\(kit.scenes.count) gaps=\(Validate.scenes(kit.scenes, roles: 6)?.message ?? "none")")
        save("\(s.id)-3-guide.json", rec.rawLog()); rec.clearRaw()

        var uses: [PropUse] = []
        var weaveLines: [String] = []
        for p in s.props {
            do {
                let w = try await svc.weaveProps(scenes: kit.scenes, props: [p], taken: uses, ctx: ctx)
                let r = GuideWeave.apply(w, to: kit.scenes, props: [p], taken: uses)
                kit.scenes = r.scenes; uses += r.uses
                weaveLines.append("\(p.id): returned \(w.uses.count), kept \(r.uses.count): " + r.uses.map { kit.scenes[$0.scene].steps[$0.step].text }.joined(separator: " | "))
            } catch { weaveLines.append("\(p.id): FAILED \(error)") }
        }
        summary.append("\(s.id) weave: \(usage(rec.take()))")
        save("\(s.id)-4-weave.json", rec.rawLog()); rec.clearRaw()

        var props = Props(nutmegSays: "", props: s.props)
        if let sk = s.skip, let i = props.props.firstIndex(where: { $0.id == sk }) { props.props[i].skipped = true }
        ctx.props = props
        let final = KitDraft.finalItems(items, props: props)
        let allowed = GuideRepair.allowedWords(props: props.props, items: final)
        // Checks on the model's own text (before the app's repairs).
        let raw = kit.scenes
        let steps = raw.flatMap(\.steps)
        let missing = steps.flatMap { GuideRepair.missingObjects($0.text, allowed: allowed, roles: plan.roles) }
        let scripted = steps.filter { GuideRepair.hasScriptedLine($0.text) }.count
        let threePart = steps.filter { t in
            let x = t.text.lowercased()
            return x.components(separatedBy: ", then ").count + x.components(separatedBy: " and then ").count - 2 >= 2
                || x.components(separatedBy: ",").count >= 4
        }.count
        let longTasks = steps.filter { $0.text.split(separator: " ").count > 26 }.count
        let pretend = raw.filter { $0.nutmegSays.lowercased().hasPrefix("pretend that") }.count
        let solo = raw.filter { $0.steps.contains { $0.role == .solo } }.count
        let scenes = GuideWeave.finalize(raw, uses: uses, props: props, items: final)
        let repaired = GuideRepair.repair(scenes, roles: plan.roles, props: props.props, title: s.title, items: final)
        let safe = await svc.guideIsSafe(repaired)
        summary.append("\(s.id) checks: steps=\(steps.count) solo-scenes=\(solo)/\(raw.count) missingObjects=\(missing.count) \(missing) scripted=\(scripted) 3+parts~\(threePart) over26words=\(longTasks) pretendThat=\(pretend)/\(raw.count) safe=\(safe) propUses=\(uses.count)")

        let roleList: String = plan.roles.map { (r: Role) -> String in "\(r.id.rawValue) \(r.roleName)" }.joined(separator: ", ")
        let pageList: String = items.map { (i: KitItem) -> String in "\(i.recipe?.rawValue ?? "-"): \(i.title)" }.joined(separator: " | ")
        let weaveList: String = weaveLines.map { (l: String) -> String in "- " + l }.joined(separator: "\n")
        var readable = "# \(s.title), \(s.players) players (label \(label))\n\nRoles: \(roleList)\n\nPages: \(pageList)\n\nWeaves:\n\(weaveList)\n\n"
        for v in [s.players] {
            let view = PlayCast.kit(Kit(nutmegSays: "", items: final, scenes: repaired), roles: plan.roles, players: v)
            for sc in view.scenes {
                readable += "## \(sc.title)\n\(sc.nutmegSays)\n" + PlayCast.rows(sc, roles: plan.roles, players: v).map { "- \($0.text)" }.joined(separator: "\n") + "\n\n"
            }
        }
        readable += "## Raw guide (all 6 roles + solo, after weave, before repair)\n"
        for sc in raw { readable += "### \(sc.title)\n\(sc.nutmegSays)\n" + sc.steps.map { "- \($0.role.rawValue): \($0.text)" }.joined(separator: "\n") + "\n" }
        save("\(s.id)-guide.md", readable)

        // A help call (tap path's "help" on scene 1).
        do {
            let h = try await svc.help(scene: repaired[0], ctx: ctx)
            summary.append("\(s.id) help: \(usage(rec.take())) says: \(h.nutmegSays)")
        } catch { summary.append("\(s.id) help: FAILED \(error) \(usage(rec.take()))") }
        save("\(s.id)-5-help.json", rec.rawLog()); rec.clearRaw()
    }
    save("summary.txt", summary.joined(separator: "\n") + "\n")
    for l in summary { print("COMPARE \(label) \(l)") }
}

/// Sends through URLSession and keeps each response's usage numbers and answer text (the generated game JSON).
final class CompareTransport: HTTPTransport, @unchecked Sendable {
    struct Call { let input, output, cacheRead: Int; let model: String; let seconds: Double }
    private let lock = NSLock()
    private var calls: [Call] = []
    private var raw: [String] = []
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let t = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.transport }
        let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
        let u = obj["usage"] as? [String: Any] ?? [:]
        let text = (obj["content"] as? [[String: Any]] ?? []).last { $0["type"] as? String == "text" }?["text"] as? String
        lock.withLock {
            calls.append(Call(input: u["input_tokens"] as? Int ?? 0, output: u["output_tokens"] as? Int ?? 0,
                              cacheRead: u["cache_read_input_tokens"] as? Int ?? 0, model: obj["model"] as? String ?? "http \(http.statusCode)",
                              seconds: Date().timeIntervalSince(t)))
            raw.append(text ?? "{\"error\": \"http \(http.statusCode)\", \"stop_reason\": \"\(obj["stop_reason"] as? String ?? "-")\", \"body\": \(String(data: data, encoding: .utf8).map { "\"" + $0.prefix(300).replacingOccurrences(of: "\"", with: "'") + "\"" } ?? "null")}")
        }
        return (data, http)
    }
    func take() -> [Call] { lock.withLock { defer { calls = [] }; return calls } }
    func rawLog() -> String { lock.withLock { "[\n" + raw.joined(separator: ",\n") + "\n]\n" } }
    func clearRaw() { lock.withLock { raw = [] } }
}
