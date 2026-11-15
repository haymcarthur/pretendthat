import Foundation

/// OpenAI Images API client for kit artwork. POST /v1/images/generations, response data[0].b64_json.
/// Model IDs checked live 2026-11-13: gpt-image-2.6-flare generates successfully (about 6 s per image at
/// quality medium) and is pinned first. The older IDs stay as fall-throughs, used only when OpenAI says the
/// model itself is unknown. The first model that works is remembered for the run.
public final class ImageClient: @unchecked Sendable {
    public enum Mode: Sendable { case direct(apiKey: String), relay(url: URL, token: String) }
    public static let models = ["gpt-image-2.6-flare", "gpt-image-2.5-flare", "gpt-image-2"]
    private let lock = NSLock()
    private var working: String?
    /// Why images are off for this run (bad key, unverified org, no credits). Nil while they may work.
    private var _unavailable: String?
    public var unavailableReason: String? { lock.withLock { _unavailable } }
    /// The model ID that last produced an image this run.
    public var workingModel: String? { lock.withLock { working } }

    let mode: Mode
    let transport: HTTPTransport
    public init(mode: Mode, transport: HTTPTransport = URLSessionTransport()) { self.mode = mode; self.transport = transport }

    /// A personal OPENAI_API_KEY wins (dev mode); otherwise the shared relay; otherwise nil (bundled art).
    public static func from(info: [String: Any]) -> ImageClient? {
        if let key = InfoValue.string(info, "OPENAI_API_KEY") { return ImageClient(mode: .direct(apiKey: key)) }
        if let relay = RelayConfig.from(info: info) { return ImageClient(mode: .relay(url: relay.url, token: relay.token)) }
        return nil
    }

    func request(prompt: String, size: String, model: String, quality: String = "medium", background: String? = nil) throws -> URLRequest {
        var req: URLRequest
        switch mode {
        case .direct(let key):
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .relay(let url, let token):
            req = URLRequest(url: url.appendingPathComponent("v1/images/generations"))
            req.setValue(token, forHTTPHeaderField: RelayConfig.tokenHeader)
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        var body: [String: Any] = ["model": model, "prompt": prompt, "size": size, "n": 1, "quality": quality, "output_format": "png",
                                   // Round 19: OpenAI's own image moderation stays on its standard setting.
                                   "moderation": "auto"]
        if let background { body["background"] = background }
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    /// Returns PNG data. Throws fast once the account is known to be unusable this run (no retries per item).
    public func generate(prompt: String, size: String, quality: String = "medium", background: String? = nil) async throws -> Data {
        if let reason = unavailableReason { throw ClaudeError.decoding("images unavailable: \(reason)") }
        let candidates = lock.withLock { working.map { [$0] } } ?? Self.models
        var lastError: Error = ClaudeError.transport
        for model in candidates {
            let (data, http) = try await transport.send(try request(prompt: prompt, size: size, model: model, quality: quality, background: background))
            let err = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let code = err?["code"] as? String ?? "", message = (err?["message"] as? String ?? "").lowercased()
            let verification = message.contains("verif")
            if !verification && (http.statusCode == 404 || (http.statusCode == 400 && (code == "model_not_found" || message.contains("model")))) {
                lastError = ClaudeError.http(http.statusCode); continue
            }
            if verification || [401, 403].contains(http.statusCode) || (http.statusCode == 429 && code.contains("credit") || code == "insufficient_quota" || code == "billing_hard_limit_reached") {
                let reason = message.contains("verif") ? "organization not verified" : http.statusCode == 429 || code.contains("quota") ? "no OpenAI credits" : "key rejected (\(http.statusCode))"
                lock.withLock { _unavailable = reason }
                throw ClaudeError.http(http.statusCode)
            }
            guard (200..<300).contains(http.statusCode) else { throw ClaudeError.http(http.statusCode) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let b64 = ((obj["data"] as? [[String: Any]])?.first?["b64_json"]) as? String,
                  let png = Data(base64Encoded: b64) else { throw ClaudeError.decoding("no b64_json") }
            lock.withLock { working = model }
            return png
        }
        throw lastError
    }
}
