import Foundation

/// The shared stateless relay (relay/, a Cloudflare Worker) that holds the API keys, so a fresh clone works without
/// its own. Filled from the committed Relay.xcconfig through Info.plist. Personal keys in Secrets.xcconfig win (dev mode).
public struct RelayConfig: Sendable, Equatable {
    /// Every relay request carries the app token in this header.
    public static let tokenHeader = "X-PT-Token"
    public let url: URL
    public let token: String
    public init(url: URL, token: String) { self.url = url; self.token = token }

    /// RELAY_HOST has no scheme (xcconfig treats `//` as a comment); the app adds https://. The committed placeholder
    /// (`pretendthat-relay.<subdomain>.workers.dev`) counts as not set, so an undeployed relay is never called.
    public static func from(info: [String: Any]) -> RelayConfig? {
        guard let host = InfoValue.string(info, "RELAY_HOST"), let token = InfoValue.string(info, "RELAY_TOKEN"),
              !host.contains("<"), !host.contains(">"), !host.contains(" "),
              let url = URL(string: host.hasPrefix("http") ? host : "https://\(host)"), url.host != nil else { return nil }
        return RelayConfig(url: url, token: token)
    }
}

/// Reads one Info.plist build setting. Empty values and unexpanded `$(NAME)` placeholders count as not set.
enum InfoValue {
    static func string(_ info: [String: Any], _ key: String) -> String? {
        guard let s = (info[key] as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty, !s.hasPrefix("$(") else { return nil }
        return s
    }
}

/// How the Realtime socket authenticates. A personal OPENAI_API_KEY connects directly (dev mode). Otherwise the
/// relay mints a short-lived ephemeral client secret per connect, so the long-lived key never reaches the iPad.
public enum RealtimeAuth: Sendable, Equatable {
    case direct(apiKey: String)
    case relay(RelayConfig)

    public static func from(info: [String: Any]) -> RealtimeAuth? {
        if let key = InfoValue.string(info, "OPENAI_API_KEY") { return .direct(apiKey: key) }
        if let relay = RelayConfig.from(info: info) { return .relay(relay) }
        return nil
    }

    /// The Bearer value for one WebSocket connect. Relay mode fetches a fresh secret every time (each first connect,
    /// pre-connect, silent reconnect and voice audition), since a secret is only good for starting a session.
    public func bearer(transport: HTTPTransport = URLSessionTransport()) async throws -> String {
        switch self {
        case .direct(let key): return key
        case .relay(let relay):
            let (data, http) = try await transport.send(RealtimeSecret.request(relay: relay))
            return try RealtimeSecret.decode(data: data, status: http.statusCode)
        }
    }
}

/// POST {relay}/v1/realtime/client_secrets → `{"value": "ek_…", "expires_at": …}` (the relay calls OpenAI's GA
/// `POST /v1/realtime/client_secrets` with the app's model and returns only the secret).
public enum RealtimeSecret {
    public static func request(relay: RelayConfig) -> URLRequest {
        var req = URLRequest(url: relay.url.appendingPathComponent("v1/realtime/client_secrets"))
        req.httpMethod = "POST"
        req.timeoutInterval = 15
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.setValue(relay.token, forHTTPHeaderField: RelayConfig.tokenHeader)
        req.httpBody = Data(#"{"model":"\#(Realtime.model)"}"#.utf8)
        return req
    }

    public static func decode(data: Data, status: Int) throws -> String {
        guard (200..<300).contains(status) else { throw ClaudeError.http(status) }
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = obj["value"] as? String, !value.isEmpty else { throw ClaudeError.decoding("no client secret") }
        return value
    }
}
