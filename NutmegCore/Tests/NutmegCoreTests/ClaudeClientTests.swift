import Foundation
import Testing
@testable import NutmegCore

final class FakeTransport: HTTPTransport, @unchecked Sendable {
    let status: Int; let body: String
    private let lock = NSLock(); private var _last: URLRequest?
    var last: URLRequest? { lock.withLock { _last } }
    init(status: Int = 200, body: String) { self.status = status; self.body = body }
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        lock.withLock { _last = request }
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

let okTurn = #"{"stop_reason":"end_turn","content":[{"type":"thinking","thinking":""},{"type":"text","text":"{\"nutmegSays\":\"Hi\",\"choices\":[],\"understood\":true}"}]}"#

func bodyJSON(_ r: URLRequest?) throws -> [String: Any] {
    let data = try #require(r?.httpBody)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}

@Test func buildsRequestWithStructuredOutput() async throws {
    let t = FakeTransport(body: okTurn)
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "test-key")), transport: t)
    _ = try await c.structured(NutmegTurn.self, system: "sys", user: "hi", schema: JSONSchema(Schemas.turn()), effort: .low)
    let r = try #require(t.last)
    #expect(r.url?.absoluteString == "https://api.anthropic.com/v1/messages")
    #expect(r.value(forHTTPHeaderField: "anthropic-version") == "2026-10-21")
    #expect(r.value(forHTTPHeaderField: "anthropic-beta") == "server-side-fallback-2026-07-01")
    #expect(r.value(forHTTPHeaderField: "x-api-key") == "test-key")
    let b = try bodyJSON(r)
    #expect(b["model"] as? String == "claude-opus-5-5")
    #expect(b["fallbacks"] as? String == "default")
    #expect(b["temperature"] == nil && b["thinking"] == nil)
    let oc = try #require(b["output_config"] as? [String: Any])
    #expect(oc["effort"] as? String == "low")
    #expect((oc["format"] as? [String: Any])?["type"] as? String == "json_schema")
}

@Test func relayModeUsesTokenNotKey() async throws {
    let t = FakeTransport(body: okTurn)
    let c = ClaudeClient(config: .init(mode: .relay(url: URL(string: "https://relay.example.dev")!, token: "tok")), transport: t)
    _ = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .medium)
    let r = try #require(t.last)
    #expect(r.url?.absoluteString == "https://relay.example.dev/v1/messages")
    #expect(r.value(forHTTPHeaderField: "x-nutmeg-token") == "tok")
    #expect(r.value(forHTTPHeaderField: "x-api-key") == nil)
}

@Test func decodesTextBlockJSON() async throws {
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(body: okTurn))
    let turn = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
    #expect(turn.nutmegSays == "Hi")
}

@Test func refusalThrows() async {
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(body: #"{"stop_reason":"refusal","content":[]}"#))
    await #expect(throws: ClaudeError.refusal) {
        _ = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
    }
}

@Test func maxTokensThrowsTruncated() async {
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(body: #"{"stop_reason":"max_tokens","content":[{"type":"text","text":"{"}]}"#))
    await #expect(throws: ClaudeError.truncated) {
        _ = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
    }
}

@Test func http500Throws() async {
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(status: 500, body: "{}"))
    await #expect(throws: ClaudeError.http(500)) {
        _ = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
    }
}

@Test func configFromInfoDictionary() {
    #expect(ClaudeConfig.from(info: ["ANTHROPIC_API_KEY": ""]) == nil)
    #expect(ClaudeConfig.from(info: ["ANTHROPIC_API_KEY": "$(ANTHROPIC_API_KEY)"]) == nil)
    if case .direct(let k)? = ClaudeConfig.from(info: ["ANTHROPIC_API_KEY": "abc"])?.mode { #expect(k == "abc") } else { Issue.record("expected direct") }
    if case .relay(let u, _)? = ClaudeConfig.from(info: ["ANTHROPIC_API_KEY": "abc", "RELAY_HOST": "r.example.dev", "RELAY_TOKEN": "t"])?.mode {
        #expect(u.absoluteString == "https://r.example.dev")
    } else { Issue.record("expected relay") }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]?.isEmpty == false))
func liveSmoke() async throws {
    let key = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"]!
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: key)))
    let t = try await c.structured(NutmegTurn.self, system: "You are Nutmeg, a cheerful mouse. Reply briefly.", user: "Say hi to a kid.", schema: JSONSchema(Schemas.turn()), effort: .low)
    print("LIVE nutmegSays:", t.nutmegSays)
    #expect(!t.nutmegSays.isEmpty)
}
