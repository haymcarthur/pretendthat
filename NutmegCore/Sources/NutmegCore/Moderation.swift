import Foundation

/// Round 19: OpenAI's Moderation API (`POST /v1/moderations`, model `omni-moderation-latest`) as the second check on kid
/// text and generated text. Personal keys call OpenAI directly; the shared relay has its own `/v1/moderations` route
/// (token check, rate limit, the model forced). FAIL SAFE: any error answers `.unavailable`, and the caller keeps going
/// on the local filter. Nothing is stored or logged.
public protocol Moderating: Sendable {
    func check(_ texts: [String]) async -> ModerationResult
}

public enum ModerationResult: Equatable, Sendable {
    case clear, flagged(categories: [String]), unavailable
    public var isFlagged: Bool { if case .flagged = self { return true }; return false }
}

public final class ModerationClient: Moderating, @unchecked Sendable {
    public static let model = "omni-moderation-latest"
    public enum Mode: Sendable { case direct(apiKey: String), relay(url: URL, token: String) }
    let mode: Mode
    let transport: HTTPTransport
    public init(mode: Mode, transport: HTTPTransport = URLSessionTransport()) { self.mode = mode; self.transport = transport }

    /// A personal OPENAI_API_KEY wins (dev mode); otherwise the shared relay; otherwise nil (local filter only).
    public static func from(info: [String: Any]) -> ModerationClient? {
        if let key = InfoValue.string(info, "OPENAI_API_KEY") { return ModerationClient(mode: .direct(apiKey: key)) }
        if let relay = RelayConfig.from(info: info) { return ModerationClient(mode: .relay(url: relay.url, token: relay.token)) }
        return nil
    }

    func request(_ texts: [String]) throws -> URLRequest {
        var req: URLRequest
        switch mode {
        case .direct(let key):
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/moderations")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .relay(let url, let token):
            req = URLRequest(url: url.appendingPathComponent("v1/moderations"))
            req.setValue(token, forHTTPHeaderField: RelayConfig.tokenHeader)
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 4   // a slow answer counts as unavailable (fail safe to the local filter)
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["model": Self.model, "input": texts], options: [.sortedKeys])
        return req
    }

    public func check(_ texts: [String]) async -> ModerationResult {
        let input = texts.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !input.isEmpty else { return .clear }
        do {
            let (data, http) = try await transport.send(try request(Array(input.prefix(32))))
            return Self.decode(data: data, status: http.statusCode)
        } catch {
            return .unavailable
        }
    }

    /// `{"results": [{"flagged": true, "categories": {"violence": true, ...}}]}`. Anything else is `.unavailable`.
    public static func decode(data: Data, status: Int) -> ModerationResult {
        guard (200..<300).contains(status),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = obj["results"] as? [[String: Any]], !results.isEmpty else { return .unavailable }
        var cats: [String] = []
        var flagged = false
        for r in results where (r["flagged"] as? Bool) == true {
            flagged = true
            cats += ((r["categories"] as? [String: Any]) ?? [:]).compactMap { ($0.value as? Bool) == true ? $0.key : nil }
        }
        return flagged ? .flagged(categories: Array(Set(cats)).sorted()) : .clear
    }
}

/// The local filter first (instant, works offline), then moderation (fails safe to the local result).
public struct KidSafetyCheck: Sendable {
    public let moderator: Moderating?
    public init(moderator: Moderating?) { self.moderator = moderator }

    /// nil = fine to use. A moderation flag maps to a steer category (self-harm → get a grown-up).
    /// `pretend`: the text names pretend things in the game (tool fields, generated kit text), so a pretend oven or
    /// stove is fine (round 20: a bakery's "the oven" prop was blocked); kid-typed text stays strict.
    public func check(_ texts: [String], pretend: Bool = false) async -> Sanitizer.SafetyVerdict? {
        if let v = Sanitizer.kidSafety(texts, pretend: pretend) { return v }
        guard let moderator else { return nil }
        switch await moderator.check(texts) {
        case .flagged(let cats):
            if cats.contains(where: { $0.hasPrefix("self-harm") }) { return .init(.needsGrownUp) }
            if cats.contains(where: { $0.hasPrefix("sexual") }) { return .init(.sexual) }
            if cats.contains(where: { $0.hasPrefix("hate") || $0.hasPrefix("harassment") }) { return .init(.hate) }
            if cats.contains(where: { $0.hasPrefix("illicit") }) { return .init(.drugs) }
            return .init(.violence)
        case .clear, .unavailable:
            return nil
        }
    }
}
