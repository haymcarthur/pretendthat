import Foundation

/// A JSON-schema dictionary that can cross concurrency boundaries (it is built once and never mutated).
public struct JSONSchema: @unchecked Sendable {
    public let value: [String: Any]
    public init(_ value: [String: Any]) { self.value = value }
}

public enum Effort: String, Sendable { case low, medium }

/// Cost v3 (2026-11-16): which Claude call this is, so a DEBUG experiment can route chosen calls to a cheaper model
/// and the usage log can say which call spent what (numbers only). Release builds always use `ClaudeConfig.model`.
public enum ClaudeCall: String, Sendable, CaseIterable {
    case ideas, plan, props, kit, pages, guide, weave, turn, help
}

public enum ClaudeRouting {
    /// Set by PhaseService around each call.
    @TaskLocal public static var call: ClaudeCall?
    #if DEBUG
    /// DEBUG only: `-PTClaudeModels "guide=claude-sonnet-5-5,weave=claude-haiku-5-5"` (launch argument) or the
    /// `PT_CLAUDE_MODELS` environment variable (live tests). `all=<model>` routes every call. Personal keys only:
    /// the relay's allow-list (relay/src/index.ts CLAUDE_MODELS) only has claude-opus-5-5.
    public static let overrides: [ClaudeCall: String] = {
        let a = ProcessInfo.processInfo.arguments
        var spec = ProcessInfo.processInfo.environment["PT_CLAUDE_MODELS"] ?? ""
        if let i = a.firstIndex(of: "-PTClaudeModels"), i + 1 < a.count { spec = a[i + 1] }
        return parse(spec)
    }()
    #endif
    public static func parse(_ spec: String) -> [ClaudeCall: String] {
        var out: [ClaudeCall: String] = [:]
        for part in spec.split(separator: ",") {
            let kv = part.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2, !kv[1].isEmpty else { continue }
            if kv[0] == "all" { ClaudeCall.allCases.forEach { out[$0] = kv[1] } }
            else if let c = ClaudeCall(rawValue: kv[0]) { out[c] = kv[1] }
        }
        return out
    }
    /// The model for the current call: a DEBUG override, else round 35's Sonnet flag (guide + weave, default ON since round 44),
    /// else the configured model (Opus 5.5).
    public static func model(default base: String) -> String {
        #if DEBUG
        if let c = call, let m = overrides[c] { return m }
        #endif
        return flagged(call, base: base, sonnetOn: CostFlags.sonnetGuide)
    }
    /// Haiku 5.5 has no server-side refusal fallback (claude-api skill, 2026-11-03), so the fallback beta is left off.
    public static func supportsFallbacks(_ model: String) -> Bool { !model.contains("haiku") }
}

public enum ClaudeError: Error, Equatable {
    case refusal, truncated, http(Int), decoding(String), transport, notConfigured
}

/// Sends one HTTP request. Injectable so tests never touch the network.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionTransport: HTTPTransport {
    let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }
    public func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.transport }
        return (data, http)
    }
}

public struct ClaudeConfig: Sendable {
    public enum Mode: Sendable { case direct(apiKey: String), relay(url: URL, token: String) }
    public var mode: Mode
    public var model = "claude-opus-5-5"
    public init(mode: Mode) { self.mode = mode }

    /// Reads Info.plist values (Relay.xcconfig, overridden by the optional Secrets.xcconfig). A personal
    /// ANTHROPIC_API_KEY wins (dev mode); otherwise the shared relay; otherwise nil (bundled fallback adventure).
    public static func from(info: [String: Any]) -> ClaudeConfig? {
        if let key = InfoValue.string(info, "ANTHROPIC_API_KEY") { return ClaudeConfig(mode: .direct(apiKey: key)) }
        if let relay = RelayConfig.from(info: info) { return ClaudeConfig(mode: .relay(url: relay.url, token: relay.token)) }
        return nil
    }
    public static func fromBundle(_ bundle: Bundle = .main) -> ClaudeConfig? { from(info: bundle.infoDictionary ?? [:]) }
}

/// Anything that can return a schema-shaped answer. ClaudeClient conforms; tests use fakes.
public protocol LLM: Sendable {
    func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T
}

/// Raw-HTTPS Claude Messages API client with structured outputs.
/// Headers verified against the claude-api skill on 2026-11-13: anthropic-version 2026-10-21,
/// anthropic-beta server-side-fallback-2026-07-01 with body `fallbacks: "default"`.
public final class ClaudeClient: LLM {
    public static let apiVersion = "2026-10-21"
    public static let fallbackBeta = "server-side-fallback-2026-07-01"
    let config: ClaudeConfig
    let transport: HTTPTransport

    public init(config: ClaudeConfig, transport: HTTPTransport = URLSessionTransport()) {
        self.config = config; self.transport = transport
    }

    func makeRequest(system: String, user: String, schema: JSONSchema, effort: Effort, model forced: String? = nil) throws -> URLRequest {
        let base: URL
        var req: URLRequest
        switch config.mode {
        case .direct(let key):
            base = URL(string: "https://api.anthropic.com")!
            req = URLRequest(url: base.appendingPathComponent("v1/messages"))
            req.setValue(key, forHTTPHeaderField: "x-api-key")
        case .relay(let url, let token):
            req = URLRequest(url: url.appendingPathComponent("v1/messages"))
            req.setValue(token, forHTTPHeaderField: RelayConfig.tokenHeader)
            ShowTicket.attach(to: &req)   // round 38: this new show's relay ticket (server-side show counts)
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 90  // live kit calls took 15–25 s; leave room for a slow day
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        let model = forced ?? ClaudeRouting.model(default: config.model)
        let fallbacks = ClaudeRouting.supportsFallbacks(model)
        if fallbacks { req.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta") }
        // No temperature (400 on 2026-10-21), no thinking config (Opus 5.5 is adaptive), no prefill.
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": ["effort": effort.rawValue, "format": ["type": "json_schema", "schema": schema.value]]
        ]
        if fallbacks { body["fallbacks"] = "default" }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    public func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        let req = try makeRequest(system: system, user: user, schema: schema, effort: effort)
        AICallLog.record(.claude)   // round D1: counted (numbers only) so a replay can be shown to make no content calls
        var data: Data, http: HTTPURLResponse
        do { (data, http) = try await transport.send(req) } catch let e as ClaudeError { throw e } catch { throw ClaudeError.transport }
        // Round 35 prep: a flagged model the relay doesn't allow yet (400 model_not_allowed before Haylee redeploys)
        // falls back to the configured model once, so turning the flag on can never break a game.
        let routed = ClaudeRouting.model(default: config.model)
        var asked = routed
        if http.statusCode == 400, routed != config.model {
            asked = config.model
            NSLog("[CLAUDE] %@ refused (400): retrying on %@", routed, config.model)
            let retry = try makeRequest(system: system, user: user, schema: schema, effort: effort, model: config.model)
            do { (data, http) = try await transport.send(retry) } catch let e as ClaudeError { throw e } catch { throw ClaudeError.transport }
        }
        guard (200..<300).contains(http.statusCode) else { throw ClaudeError.http(http.statusCode) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ClaudeError.decoding("response not JSON") }
        switch obj["stop_reason"] as? String {
        case "refusal": throw ClaudeError.refusal
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        // Round C1: token usage is metered (in memory only, no content) so the cost per game can be measured.
        if let u = obj["usage"] as? [String: Any] {
            // 2026-11-18: priced by the model that answered (the response's `model`, else the one asked for).
            ClaudeUsageMeter.shared.record(input: u["input_tokens"] as? Int ?? 0, output: u["output_tokens"] as? Int ?? 0,
                                           model: obj["model"] as? String ?? asked)
            #if DEBUG   // cost v2 (2026-11-16): cache counts and effort too (numbers only, never content)
            NSLog("[CLAUDE] usage detail: call=%@ effort=%@ cache_read=%d cache_write=%d model=%@", ClaudeRouting.call?.rawValue ?? "?", effort.rawValue,
                  u["cache_read_input_tokens"] as? Int ?? 0, u["cache_creation_input_tokens"] as? Int ?? 0, obj["model"] as? String ?? "?")
            #endif
        }
        // After a server-side fallback, content can hold fallback/thinking blocks; the answer is the last text block.
        let blocks = obj["content"] as? [[String: Any]] ?? []
        guard let text = blocks.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw ClaudeError.decoding("no text block")
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTLogGuide"), ClaudeRouting.call == .guide { NSLog("[CLAUDE] guide answer: %@", String(text.prefix(1500))) }
        #endif
        do { return try JSONDecoder().decode(T.self, from: Data(text.utf8)) }
        catch { throw ClaudeError.decoding(String(describing: error)) }
    }
}

/// Claude list prices, dollars per 1M tokens (input, output), per model. From the repo's cost research
/// (thinking/research/2026-11-18-cost-per-game.md, the claude-api skill's 2026-11-03 table): Opus 5.5 $4 / $20,
/// Sonnet 5.5 $2 / $10. Until 2026-11-18 the meter priced every call at Opus rates, so Sonnet calls (the guide and the
/// weaves) read double (~10¢ a game too high).
public enum ClaudePrices {
    public static let opus55 = (input: 4.0, output: 20.0)
    public static let sonnet55 = (input: 2.0, output: 10.0)
    /// NOT a researched price: any other model (Haiku included; its price isn't in the repo's research) is metered at
    /// Opus rates, so the meter can only read high, never low.
    public static let unknownModelFallback = opus55
    /// The price for a model id ("claude-sonnet-5-5", or a dated / suffixed form of it).
    public static func perMillion(model: String) -> (input: Double, output: Double) {
        let m = model.lowercased()
        if m.hasPrefix("claude-opus-5-5") { return opus55 }
        if m.hasPrefix("claude-sonnet-5-5") { return sonnet55 }
        return unknownModelFallback
    }
    public static func cents(input: Int, output: Int, model: String) -> Double {
        let p = perMillion(model: model)
        return (Double(input) * p.input + Double(output) * p.output) / 10_000
    }
}

/// Round C1: Claude token counts per call (numbers only), for measuring the cost per game. Debug builds log each call.
public final class ClaudeUsageMeter: @unchecked Sendable {
    public static let shared = ClaudeUsageMeter()
    public struct Call: Equatable, Sendable {
        public let input: Int, output: Int
        /// The model that answered (prices differ: `ClaudePrices`).
        public let model: String
        public init(input: Int, output: Int, model: String) {
            self.input = input; self.output = output; self.model = model
        }
        /// This call's cost at its own model's price.
        public var cents: Double { ClaudePrices.cents(input: input, output: output, model: model) }
    }
    private let lock = NSLock()
    private var log: [Call] = []
    public func record(input: Int, output: Int, model: String) {
        let call = Call(input: input, output: output, model: model)
        lock.withLock { log.append(call) }
        #if DEBUG
        NSLog("[CLAUDE] usage: %d in, %d out (%.2f cents, %@)", input, output, call.cents, model)
        #endif
    }
    public var calls: [Call] { lock.withLock { log } }
    public func reset() { lock.withLock { log = [] } }
    /// The calls' total cost, each at its own model's price.
    public static func cents(_ calls: [Call]) -> Double { calls.map(\.cents).reduce(0, +) }
}
