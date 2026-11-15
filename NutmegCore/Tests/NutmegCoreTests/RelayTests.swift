import Foundation
import Testing
@testable import NutmegCore

private var relayInfo: [String: Any] { ["RELAY_HOST": "pretendthat-relay.test.workers.dev", "RELAY_TOKEN": "tok"] }

@Test func relayConfigFromInfo() throws {
    let r = try #require(RelayConfig.from(info: relayInfo))
    #expect(r.url.absoluteString == "https://pretendthat-relay.test.workers.dev")
    #expect(r.token == "tok")
    #expect(RelayConfig.from(info: ["RELAY_HOST": "https://r.example.dev", "RELAY_TOKEN": "t"])?.url.absoluteString == "https://r.example.dev")
}

@Test func relayConfigIgnoresPlaceholdersAndBlanks() {
    // The committed Relay.xcconfig placeholder before deploy: never called.
    #expect(RelayConfig.from(info: ["RELAY_HOST": "pretendthat-relay.<subdomain>.workers.dev", "RELAY_TOKEN": "t"]) == nil)
    #expect(RelayConfig.from(info: ["RELAY_HOST": "", "RELAY_TOKEN": "t"]) == nil)
    #expect(RelayConfig.from(info: ["RELAY_HOST": "r.example.dev", "RELAY_TOKEN": ""]) == nil)
    #expect(RelayConfig.from(info: ["RELAY_HOST": "$(RELAY_HOST)", "RELAY_TOKEN": "$(RELAY_TOKEN)"]) == nil)
    #expect(RelayConfig.from(info: [:]) == nil)
}

@Test func freshCloneUsesRelayForEverything() {
    // No Secrets.xcconfig: the keys expand to nothing, so Claude, images and Realtime all go through the relay.
    var info = relayInfo
    info["ANTHROPIC_API_KEY"] = ""; info["OPENAI_API_KEY"] = ""
    if case .relay? = ClaudeConfig.from(info: info)?.mode {} else { Issue.record("Claude should use the relay") }
    if case .relay? = ImageClient.from(info: info)?.mode {} else { Issue.record("images should use the relay") }
    #expect(RealtimeAuth.from(info: info) == .relay(RelayConfig(url: URL(string: "https://pretendthat-relay.test.workers.dev")!, token: "tok")))
}

@Test func personalKeysWinOverRelay() {
    var info = relayInfo
    info["ANTHROPIC_API_KEY"] = "a"; info["OPENAI_API_KEY"] = "o"
    if case .direct(let k)? = ClaudeConfig.from(info: info)?.mode { #expect(k == "a") } else { Issue.record("expected direct") }
    if case .direct(let k)? = ImageClient.from(info: info)?.mode { #expect(k == "o") } else { Issue.record("expected direct") }
    #expect(RealtimeAuth.from(info: info) == .direct(apiKey: "o"))
    #expect(RealtimeAuth.from(info: [:]) == nil)
}

@Test func imageRelayRequestSendsAppToken() async throws {
    let png = Data([0x89, 0x50])
    let t = FakeTransport(body: #"{"data":[{"b64_json":"\#(png.base64EncodedString())"}]}"#)
    let c = ImageClient(mode: .relay(url: URL(string: "https://relay.example.dev")!, token: "tok"), transport: t)
    _ = try await c.generate(prompt: "x", size: "1024x1024")
    let r = try #require(t.last)
    #expect(r.url?.absoluteString == "https://relay.example.dev/v1/images/generations")
    #expect(r.value(forHTTPHeaderField: "X-PT-Token") == "tok")
    #expect(r.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(try bodyJSON(r)["n"] as? Int == 1)
}

@Test func ephemeralSecretRequestShape() throws {
    let r = RealtimeSecret.request(relay: RelayConfig(url: URL(string: "https://relay.example.dev")!, token: "tok"))
    #expect(r.httpMethod == "POST")
    #expect(r.url?.absoluteString == "https://relay.example.dev/v1/realtime/client_secrets")
    #expect(r.value(forHTTPHeaderField: "X-PT-Token") == "tok")
    #expect(r.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(try bodyJSON(r)["model"] as? String == Realtime.model)
}

@Test func ephemeralSecretDecoding() throws {
    #expect(try RealtimeSecret.decode(data: Data(#"{"value":"ek_abc","expires_at":1763200000,"model":"gpt-realtime-2.1"}"#.utf8), status: 200) == "ek_abc")
    #expect(throws: ClaudeError.http(429)) { try RealtimeSecret.decode(data: Data(#"{"error":{"type":"rate_limited"}}"#.utf8), status: 429) }
    #expect(throws: ClaudeError.http(401)) { try RealtimeSecret.decode(data: Data("{}".utf8), status: 401) }
    #expect(throws: ClaudeError.self) { try RealtimeSecret.decode(data: Data(#"{"value":""}"#.utf8), status: 200) }
    #expect(throws: ClaudeError.self) { try RealtimeSecret.decode(data: Data("not json".utf8), status: 200) }
}

@Test func bearerFetchesAFreshSecretPerConnect() async throws {
    let t = FakeTransport(body: #"{"value":"ek_1","expires_at":1}"#)
    let auth = RealtimeAuth.relay(RelayConfig(url: URL(string: "https://relay.example.dev")!, token: "tok"))
    #expect(try await auth.bearer(transport: t) == "ek_1")
    #expect(try await auth.bearer(transport: t) == "ek_1")
    #expect(t.count == 2)
    #expect(try await RealtimeAuth.direct(apiKey: "sk").bearer(transport: t) == "sk")
    #expect(t.count == 2)
}
