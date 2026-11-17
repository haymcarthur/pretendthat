import Foundation
import Testing
@testable import NutmegCore

/// Cost v3 (2026-11-16): the DEBUG Claude routing spec and the fixed-lines session shape.
@Test func claudeRoutingParsesSpecs() {
    let one = ClaudeRouting.parse("guide=claude-sonnet-5-5, weave=claude-haiku-5-5,bogus=x,help=")
    #expect(one == [.guide: "claude-sonnet-5-5", .weave: "claude-haiku-5-5"])
    let all = ClaudeRouting.parse("all=claude-sonnet-5-5")
    #expect(all.count == ClaudeCall.allCases.count)
    #expect(ClaudeRouting.parse("").isEmpty)
    #expect(ClaudeRouting.supportsFallbacks("claude-sonnet-5-5"))
    #expect(!ClaudeRouting.supportsFallbacks("claude-haiku-5-5"))
    // No override outside a tagged call: the configured model.
    #expect(ClaudeRouting.model(default: "claude-opus-5-5") == "claude-opus-5-5")
}

@Test func lineSessionKeepsTheVoiceAndDropsTools() throws {
    let e = VoiceConfig.nutmeg.lineSessionUpdate()
    let s = try #require(e["session"] as? [String: Any])
    #expect((s["tools"] as? [Any])?.isEmpty == true)
    #expect(s["tool_choice"] as? String == "none")
    let out = try #require(((s["audio"] as? [String: Any])?["output"]) as? [String: Any])
    #expect(out["voice"] as? String == "coral")
    #expect((s["instructions"] as? String)?.contains(Realtime.voiceStyle) == true)
    #expect(Realtime.lineModel == nil)   // off unless -PTMiniLines is passed
}
