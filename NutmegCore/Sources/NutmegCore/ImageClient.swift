import Foundation

/// OpenAI Images API client for kit artwork.
/// Verified 2026-11-13 against developers.openai.com image-generation guide: POST /v1/images/generations,
/// response data[0].b64_json, portrait 1024x1536. The guide's code examples use `gpt-image-2.5-flare`
/// (captions mention 2.6 Flare); `gpt-image-2` is the earlier, widely reported ID. We try them in order.
public final class ImageClient: Sendable {
    public enum Mode: Sendable { case direct(apiKey: String), relay(url: URL, token: String) }
    public static let models = ["gpt-image-2.5-flare", "gpt-image-2"]

    let mode: Mode
    let transport: HTTPTransport
    public init(mode: Mode, transport: HTTPTransport = URLSessionTransport()) { self.mode = mode; self.transport = transport }

    public static func from(info: [String: Any]) -> ImageClient? {
        func value(_ k: String) -> String? {
            guard let s = (info[k] as? String)?.trimmingCharacters(in: .whitespaces), !s.isEmpty, !s.hasPrefix("$(") else { return nil }
            return s
        }
        if let host = value("RELAY_HOST"), let token = value("RELAY_TOKEN"), let url = URL(string: host.hasPrefix("http") ? host : "https://\(host)") {
            return ImageClient(mode: .relay(url: url, token: token))
        }
        if let key = value("OPENAI_API_KEY") { return ImageClient(mode: .direct(apiKey: key)) }
        return nil
    }

    func request(prompt: String, size: String, model: String) throws -> URLRequest {
        var req: URLRequest
        switch mode {
        case .direct(let key):
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .relay(let url, let token):
            req = URLRequest(url: url.appendingPathComponent("v1/images/generations"))
            req.setValue(token, forHTTPHeaderField: "x-nutmeg-token")
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 120
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        let body: [String: Any] = ["model": model, "prompt": prompt, "size": size, "n": 1, "quality": "medium", "output_format": "png"]
        req.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        return req
    }

    /// Returns PNG data. Falls through the model list on 400/404 (unknown model).
    public func generate(prompt: String, size: String) async throws -> Data {
        var lastError: Error = ClaudeError.transport
        for model in Self.models {
            let (data, http) = try await transport.send(try request(prompt: prompt, size: size, model: model))
            if http.statusCode == 400 || http.statusCode == 404 { lastError = ClaudeError.http(http.statusCode); continue }
            guard (200..<300).contains(http.statusCode) else { throw ClaudeError.http(http.statusCode) }
            guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let b64 = ((obj["data"] as? [[String: Any]])?.first?["b64_json"]) as? String,
                  let png = Data(base64Encoded: b64) else { throw ClaudeError.decoding("no b64_json") }
            return png
        }
        throw lastError
    }
}
