import Foundation

/// Round 20 (Haylee, cost): the kit art quality, ONE constant to flip ("low", "medium" or "high").
public enum ImageQuality {
    public static let kit = "low"   // round 20: low kept lines crisp and colorable (/tmp/pt-round20/quality/compare.png)
}

/// OpenAI Images API client for kit artwork. POST /v1/images/generations (and, printables draw-once 2026-11-17,
/// POST /v1/images/edits for the color pages), response data[0].b64_json.
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
            ShowTicket.attach(to: &req)   // round 38: this new show's relay ticket (server-side show counts)
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

    /// Printables draw-once (2026-11-17): the image EDIT request (POST /v1/images/edits, multipart): ONE page image
    /// plus the prompt, with the same model, size, quality, format and moderation as a drawn page. `input_fidelity` is
    /// never sent (gpt-image-2.6-flare rejects it). The relay forwards it with the same auth, limits and show ticket.
    func editRequest(image: Data, prompt: String, size: String, model: String, quality: String = "medium",
                     boundary: String = "pt-" + UUID().uuidString) -> URLRequest {
        var req: URLRequest
        switch mode {
        case .direct(let key):
            req = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
            req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .relay(let url, let token):
            req = URLRequest(url: url.appendingPathComponent("v1/images/edits"))
            req.setValue(token, forHTTPHeaderField: RelayConfig.tokenHeader)
            ShowTicket.attach(to: &req)
        }
        req.httpMethod = "POST"
        req.timeoutInterval = 150
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "content-type")
        var body = Data()
        func field(_ name: String, _ value: String) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        for (k, v) in [("model", model), ("prompt", prompt), ("size", size), ("n", "1"), ("quality", quality),
                       ("output_format", "png"), ("moderation", "auto")] { field(k, v) }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"page.png\"\r\nContent-Type: image/png\r\n\r\n".utf8))
        body.append(image)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        req.httpBody = body
        return req
    }

    /// Returns PNG data. Throws fast once the account is known to be unusable this run (no retries per item).
    public func generate(prompt: String, size: String, quality: String = "medium", background: String? = nil) async throws -> Data {
        try await send { model in try self.request(prompt: prompt, size: size, model: model, quality: quality, background: background) }
    }

    /// Printables draw-once: the color page from the coloring page (`image`, PNG) with the edit endpoint. PNG data back.
    public func edit(image: Data, prompt: String, size: String, quality: String = "medium") async throws -> Data {
        try await send(edit: true) { model in self.editRequest(image: image, prompt: prompt, size: size, model: model, quality: quality) }
    }

    /// One image call through the model fall-through, the unusable-account stop and the usage log.
    private func send(edit: Bool = false, _ make: (String) throws -> URLRequest) async throws -> Data {
        if let reason = unavailableReason { throw ClaudeError.decoding("images unavailable: \(reason)") }
        let candidates = lock.withLock { working.map { [$0] } } ?? Self.models
        var lastError: Error = ClaudeError.transport
        for model in candidates {
            AICallLog.record(.image)   // round D1: counted (numbers only)
            ImageUsageLog.started()    // round 27: timing for the per-minute peak (numbers only)
            let (data, http) = try await transport.send(try make(model))
            let err = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? [String: Any]
            let code = err?["code"] as? String ?? "", message = (err?["message"] as? String ?? "").lowercased()
            let verification = message.contains("verif")
            if http.statusCode == 429 { ImageUsageLog.rateLimited() }
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
            if let u = obj["usage"] as? [String: Any] {   // round 27: cost measurement (token counts only)
                let d = u["input_tokens_details"] as? [String: Any]
                ImageUsageLog.usage(input: u["input_tokens"] as? Int ?? 0, output: u["output_tokens"] as? Int ?? 0,
                                    imageInput: d?["image_tokens"] as? Int ?? 0)
                #if DEBUG   // cost v2 (2026-11-16): one count line per image (model, size, quality; numbers only)
                NSLog("[IMAGE] usage%@: model=%@ in=%d (text %d, image %d) out=%d", edit ? " (edit)" : "", model,
                      u["input_tokens"] as? Int ?? 0, d?["text_tokens"] as? Int ?? 0, d?["image_tokens"] as? Int ?? 0,
                      u["output_tokens"] as? Int ?? 0)
                #endif
            }
            lock.withLock { working = model }
            return png
        }
        throw lastError
    }
}

/// Printables draw-once: the app's image calls behind the `PageImaging` seam (tests use a fake).
extension ImageClient: PageImaging {
    public func generate(prompt: String, size: String, quality: String) async throws -> Data {
        try await generate(prompt: prompt, size: size, quality: quality, background: nil)
    }
}
