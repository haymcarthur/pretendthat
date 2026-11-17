import Foundation

/// A JSON-schema dictionary that can cross concurrency boundaries (it is built once and never mutated).
public struct JSONSchema: @unchecked Sendable {
    public let value: [String: Any]
    public init(_ value: [String: Any]) { self.value = value }
}

public enum Effort: String, Sendable { case low, medium }

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

    func makeRequest(system: String, user: String, schema: JSONSchema, effort: Effort) throws -> URLRequest {
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
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 90  // live kit calls took 15–25 s; leave room for a slow day
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        req.setValue(Self.fallbackBeta, forHTTPHeaderField: "anthropic-beta")
        // No temperature (400 on 2026-10-21), no thinking config (Opus 5.5 is adaptive), no prefill.
        let body: [String: Any] = [
            "model": config.model,
            "max_tokens": 16000,
            "system": system,
            "messages": [["role": "user", "content": user]],
            "output_config": ["effort": effort.rawValue, "format": ["type": "json_schema", "schema": schema.value]],
            "fallbacks": "default"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    public func structured<T: Decodable & Sendable>(_ type: T.Type, system: String, user: String, schema: JSONSchema, effort: Effort) async throws -> T {
        let req = try makeRequest(system: system, user: user, schema: schema, effort: effort)
        AICallLog.record(.claude)   // round D1: counted (numbers only) so a replay can be shown to make no content calls
        let data: Data, http: HTTPURLResponse
        do { (data, http) = try await transport.send(req) } catch let e as ClaudeError { throw e } catch { throw ClaudeError.transport }
        guard (200..<300).contains(http.statusCode) else { throw ClaudeError.http(http.statusCode) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw ClaudeError.decoding("response not JSON") }
        switch obj["stop_reason"] as? String {
        case "refusal": throw ClaudeError.refusal
        case "max_tokens": throw ClaudeError.truncated
        default: break
        }
        // Round C1: token usage is metered (in memory only, no content) so the cost per game can be measured.
        if let u = obj["usage"] as? [String: Any] {
            ClaudeUsageMeter.shared.record(input: u["input_tokens"] as? Int ?? 0, output: u["output_tokens"] as? Int ?? 0)
            #if DEBUG   // cost v2 (2026-11-16): cache counts and effort too (numbers only, never content)
            NSLog("[CLAUDE] usage detail: effort=%@ cache_read=%d cache_write=%d model=%@", effort.rawValue,
                  u["cache_read_input_tokens"] as? Int ?? 0, u["cache_creation_input_tokens"] as? Int ?? 0, obj["model"] as? String ?? "?")
            #endif
        }
        // After a server-side fallback, content can hold fallback/thinking blocks; the answer is the last text block.
        let blocks = obj["content"] as? [[String: Any]] ?? []
        guard let text = blocks.last(where: { $0["type"] as? String == "text" })?["text"] as? String else {
            throw ClaudeError.decoding("no text block")
        }
        do { return try JSONDecoder().decode(T.self, from: Data(text.utf8)) }
        catch { throw ClaudeError.decoding(String(describing: error)) }
    }
}

/// Round C1: Claude token counts per call (numbers only), for measuring the cost per game. Debug builds log each call.
public final class ClaudeUsageMeter: @unchecked Sendable {
    public static let shared = ClaudeUsageMeter()
    public struct Call: Equatable, Sendable { public let input: Int, output: Int }
    private let lock = NSLock()
    private var log: [Call] = []
    /// Opus 5.5 list prices, dollars per 1M tokens (input, output).
    public static let pricePerMillion = (input: 4.0, output: 20.0)
    public func record(input: Int, output: Int) {
        lock.withLock { log.append(Call(input: input, output: output)) }
        #if DEBUG
        NSLog("[CLAUDE] usage: %d in, %d out (%.2f cents)", input, output, Self.cents(input: input, output: output))
        #endif
    }
    public var calls: [Call] { lock.withLock { log } }
    public func reset() { lock.withLock { log = [] } }
    public static func cents(input: Int, output: Int) -> Double {
        (Double(input) * pricePerMillion.input + Double(output) * pricePerMillion.output) / 10_000
    }
}
