import Foundation
import Testing
@testable import NutmegCore

// 2026-11-18 (decisions/2026-11-18-small-fixes.md): the Claude cost meter prices each call at its own model's rate.
// It used to price every call at Opus rates, so the Sonnet guide and weaves read double.
@Suite struct ClaudePricesTests {
    @Test func opusAndSonnetHaveTheirOwnPrices() {
        #expect(ClaudePrices.perMillion(model: "claude-opus-5-5") == (4, 20))
        #expect(ClaudePrices.perMillion(model: "claude-sonnet-5-5") == (2, 10))
        #expect(ClaudePrices.perMillion(model: "claude-sonnet-5-5-20261101") == (2, 10))   // a dated id
        #expect(ClaudePrices.perMillion(model: ClaudeRouting.sonnet) == ClaudePrices.sonnet55)
    }

    @Test func anUnknownModelIsMeteredHighNeverLow() {
        #expect(ClaudePrices.perMillion(model: "claude-haiku-5-5") == ClaudePrices.unknownModelFallback)
        #expect(ClaudePrices.perMillion(model: "") == ClaudePrices.opus55)
    }

    @Test func centsFollowTheModel() {
        // The pet hotel game's play guide (Sonnet, low): 8,118 in / 2,519 out ≈ 4.1¢ (was 8.3¢ at Opus rates).
        #expect(abs(ClaudePrices.cents(input: 8_118, output: 2_519, model: "claude-sonnet-5-5") - 4.1426) < 0.001)
        #expect(abs(ClaudePrices.cents(input: 8_118, output: 2_519, model: "claude-opus-5-5") - 8.2852) < 0.001)
        // Its kit pages (Opus): 5,219 / 740 ≈ 3.6¢.
        #expect(abs(ClaudePrices.cents(input: 5_219, output: 740, model: "claude-opus-5-5") - 3.5676) < 0.001)
        let calls = [ClaudeUsageMeter.Call(input: 5_219, output: 740, model: "claude-opus-5-5"),
                     ClaudeUsageMeter.Call(input: 8_118, output: 2_519, model: "claude-sonnet-5-5")]
        #expect(abs(ClaudeUsageMeter.cents(calls) - (3.5676 + 4.1426)) < 0.001)
    }

    @Test func theClientRecordsTheModelThatAnswered() async throws {
        // Unique token counts so a parallel test's calls on the shared meter can't be mistaken for this one.
        let body = #"{"model":"claude-sonnet-5-5","stop_reason":"end_turn","usage":{"input_tokens":918273,"output_tokens":645},"content":[{"type":"text","text":"{\"nutmegSays\":\"Hi\",\"choices\":[],\"understood\":true}"}]}"#
        let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(body: body))
        _ = try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
        let call = try #require(ClaudeUsageMeter.shared.calls.last { $0.input == 918_273 })
        #expect(call.model == "claude-sonnet-5-5" && call.output == 645)
        #expect(abs(call.cents - (918_273 * 2.0 + 645 * 10.0) / 10_000) < 0.0001)
        // No model in the response: the model asked for (here the configured Opus).
        let noModel = #"{"stop_reason":"end_turn","usage":{"input_tokens":918274,"output_tokens":1},"content":[{"type":"text","text":"{\"nutmegSays\":\"Hi\",\"choices\":[],\"understood\":true}"}]}"#
        let c2 = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: FakeTransport(body: noModel))
        _ = try await c2.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
        #expect(ClaudeUsageMeter.shared.calls.last { $0.input == 918_274 }?.model == "claude-opus-5-5")
    }
}
