import Foundation
import Testing
@testable import NutmegCore

/// Round 35 prep: one playback path and one audio session for every Nutmeg sound, one voice config for both Realtime
/// sessions, and the cost flags (off by default).

private let appRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("PretendThat")

private func appSources() throws -> [(name: String, text: String)] {
    let files = FileManager.default.enumerator(at: appRoot, includingPropertiesForKeys: nil)?
        .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
    return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
}

// MARK: One playback path

/// Every Nutmeg sound plays through `NutmegSpeaker` (player → Varispeed 1.20 → mixer, `SpeakerGraph`). Nothing else in
/// the app may build an audio player graph, set the audio session category or use the system voice.
@Test func allNutmegPlaybackGoesThroughTheSpeaker() throws {
    let files = try appSources()
    #expect(files.count > 20)
    for f in files {
        // Never system TTS (Haylee's hard rule).
        #expect(!f.text.contains("AVSpeechSynthesizer"), "\(f.name)")
        #expect(!f.text.contains("AVSpeechUtterance"), "\(f.name)")
        #expect(!f.text.contains("NutmegVoice"), "\(f.name)")
        // One player graph: only the speaker makes player nodes.
        if f.name != "NutmegSpeaker.swift" {
            #expect(!f.text.contains("AVAudioPlayerNode("), "\(f.name)")
            #expect(!f.text.contains("SpeakerGraph.wire("), "\(f.name)")
            #expect(!f.text.contains("SpeakerGraph.makePitchUnit("), "\(f.name)")
        }
        // Engines: the speaker's (her voice) and the tap-fallback listener's (input only, never plays).
        if !["NutmegSpeaker.swift", "Listener.swift"].contains(f.name) {
            #expect(!f.text.contains("AVAudioEngine()"), "\(f.name)")
        }
        // One session setup: nobody sets the category by hand (NutmegAudioSession.apply does), never `.playback`.
        #expect(!f.text.contains("setCategory("), "\(f.name)")
        #expect(!f.text.contains(".spokenAudio"), "\(f.name)")
    }
    // The onboarding's voice is a thin wrapper over the speaker.
    let onboarding = try #require(files.first { $0.name == "AppModel+Onboarding.swift" })
    #expect(onboarding.text.contains("speaker.playClip("))
    #expect(onboarding.text.contains("startForClips("))
    // The speaker uses the shared session setup.
    let speaker = try #require(files.first { $0.name == "NutmegSpeaker.swift" })
    #expect(speaker.text.contains("NutmegAudioSession.nutmeg.apply()"))
}

/// The output-only start (onboarding before the Mic page) must never touch the input node, or iOS asks for the mic.
@Test func outputOnlyStartNeverTouchesTheInput() throws {
    let speaker = try #require(try appSources().first { $0.name == "NutmegSpeaker.swift" })
    // Every inputNode access in the speaker is behind the inputEnabled guard (or inside the input start).
    let lines = speaker.text.split(separator: "\n").map(String.init)
    for (i, l) in lines.enumerated() where l.contains(".inputNode") && !l.trimmingCharacters(in: .whitespaces).hasPrefix("///") {
        let window = lines[max(0, i - 3)...i].joined(separator: "\n")
        #expect(window.contains("inputEnabled") || window.contains("withInput"), "line \(i + 1): \(l)")
    }
}

@Test func theOneSessionIsTheGamesSession() {
    let s = NutmegAudioSession.nutmeg
    #expect(s.category == "playAndRecord")
    #expect(s.mode == "default")
    #expect(s.options == ["defaultToSpeaker", "allowBluetoothA2DP"])
    #expect(s.preferredSampleRate == 48_000)
}

// MARK: One voice config for both sessions

private func json(_ o: Any) -> String {
    String(decoding: try! JSONSerialization.data(withJSONObject: o, options: [.sortedKeys]), as: UTF8.self)
}

@Test func bothSessionsBuildTheirConfigFromOneVoiceConfig() throws {
    let instructions = Realtime.instructions
    let main = VoiceSessionPlan.conversation(.nutmeg, instructions: instructions)
    let lines = try #require(VoiceSessionPlan.lines(.nutmeg, instructions: instructions, model: Realtime.miniModel))
    // Identical session.update (voice, speed, format, instructions, tools): only the model differs.
    #expect(json(main.sessionUpdate) == json(lines.sessionUpdate))
    #expect(main.config == lines.config)
    #expect(main.model == "gpt-realtime-2.1" && lines.model == "gpt-realtime-2.1-mini")
    #expect(lines.url.absoluteString.hasSuffix("model=gpt-realtime-2.1-mini"))
    for plan in [main, lines] {
        let s = try #require(plan.sessionUpdate["session"] as? [String: Any])
        let out = try #require((s["audio"] as? [String: Any])?["output"] as? [String: Any])
        #expect(out["voice"] as? String == "coral")
        #expect((out["speed"] as? NSNumber)?.doubleValue == 1.0)   // Varispeed does the speed, never stacked
        let fmt = try #require(out["format"] as? [String: Any])
        #expect(fmt["type"] as? String == "audio/pcm" && fmt["rate"] as? Int == 24_000)
        #expect((s["instructions"] as? String)?.contains(Realtime.voiceStyle) == true)
        #expect(plan.playbackRate == 1.20)
        #expect(plan.config.method == .varispeed)
    }
    // Clip keys stay on one voice ID (bundled clips keep matching).
    #expect(main.voiceID == lines.voiceID)
}

/// The app's session code builds both sockets from `VoiceSessionPlan` (never its own session.update).
@Test func realtimeSessionUsesThePlanForBothSockets() throws {
    let rt = try #require(try appSources().first { $0.name == "RealtimeSession.swift" })
    #expect(rt.text.contains("VoiceSessionPlan.conversation("))
    #expect(rt.text.contains("VoiceSessionPlan.lines("))
    #expect(!rt.text.contains(".sessionUpdate(instructions:"))
    #expect(!rt.text.contains("lineSessionUpdate"))
}

// MARK: Flags (round 44: default ON; the old flags still turn them off)

@Test func costFlagsAreOnByDefaultAndTheFlagsStillTurnThemOff() {
    let d = UserDefaults(suiteName: "round35-\(UUID().uuidString)")!
    #expect(CostFlags.isOn(CostFlags.miniLinesKey, args: [], defaults: d))
    #expect(CostFlags.isOn(CostFlags.sonnetGuideKey, args: [], defaults: d))
    #expect(CostFlags.isOn(CostFlags.miniLinesKey, args: ["app", "-PTMiniLines"], defaults: d))
    #expect(CostFlags.isOn(CostFlags.miniLinesKey, args: ["app", "-PTMiniLines", "YES"], defaults: d))
    #expect(CostFlags.isOn(CostFlags.miniLinesKey, args: ["app", "-PTMiniLines", "-PTConsent"], defaults: d))
    #expect(!CostFlags.isOn(CostFlags.miniLinesKey, args: ["app", "-PTMiniLines", "NO"], defaults: d))
    #expect(!CostFlags.isOn(CostFlags.sonnetGuideKey, args: ["-PTSonnetGuide", "0"], defaults: d))
    d.set(false, forKey: CostFlags.sonnetGuideKey)   // a stored OFF still wins over the default
    #expect(!CostFlags.isOn(CostFlags.sonnetGuideKey, args: [], defaults: d))
    #expect(CostFlags.isOn(CostFlags.sonnetGuideKey, args: ["-PTSonnetGuide", "YES"], defaults: d))
    #expect(CostFlags.modelArgument("PTMiniLines", args: ["-PTMiniLines", "gpt-realtime-x"]) == "gpt-realtime-x")
    #expect(CostFlags.modelArgument("PTMiniLines", args: ["-PTMiniLines", "YES"]) == nil)
    // This test process passes neither flag: both on, the scripted lines use the mini model.
    #expect(Realtime.lineModel == Realtime.miniModel)
    #expect(VoiceSessionPlan.lines()?.model == Realtime.miniModel)
}

@Test func sonnetTakesOnlyTheGuideAndTheWeave() {
    let opus = "claude-opus-5-5"
    for call in ClaudeCall.allCases {
        let on = ClaudeRouting.flagged(call, base: opus, sonnetOn: true)
        #expect(on == ([.guide, .weave].contains(call) ? "claude-sonnet-5-5" : opus), "\(call)")
        #expect(ClaudeRouting.flagged(call, base: opus, sonnetOn: false) == opus)
    }
    #expect(ClaudeRouting.flagged(nil, base: opus, sonnetOn: true) == opus)
    #expect(ClaudeRouting.flagged(.kit, base: opus, sonnetOn: true) == opus)
    #expect(ClaudeRouting.flagged(.pages, base: opus, sonnetOn: true) == opus)
    // Round 44: ON by default: a guide call goes to Sonnet, an untagged call and the kit keep Opus.
    #expect(ClaudeRouting.$call.withValue(.guide) { ClaudeRouting.model(default: opus) } == "claude-sonnet-5-5")
    #expect(ClaudeRouting.$call.withValue(.weave) { ClaudeRouting.model(default: opus) } == "claude-sonnet-5-5")
    #expect(ClaudeRouting.$call.withValue(.kit) { ClaudeRouting.model(default: opus) } == opus)
    #expect(ClaudeRouting.model(default: opus) == opus)
}

@Test func secretRequestNamesTheSessionsModel() throws {
    let relay = RelayConfig(url: URL(string: "https://relay.example.dev")!, token: "tok")
    #expect(try bodyJSON(RealtimeSecret.request(relay: relay))["model"] as? String == "gpt-realtime-2.1")
    #expect(try bodyJSON(RealtimeSecret.request(relay: relay, model: Realtime.miniModel))["model"] as? String == "gpt-realtime-2.1-mini")
}

/// A flagged model the old relay refuses (400) falls back to Opus once, so the flag can't break a game.
@Test func refusedFlaggedModelFallsBackToOpus() async throws {
    final class Seq: HTTPTransport, @unchecked Sendable {
        private let lock = NSLock(); private(set) var models: [String] = []
        func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
            let m = (try? bodyJSON(request))?["model"] as? String ?? "?"
            let first = lock.withLock { models.append(m); return models.count == 1 }
            let status = first && m != "claude-opus-5-5" ? 400 : 200
            let body = status == 400 ? #"{"error":{"type":"model_not_allowed"}}"# : okTurn
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
    }
    // Round 44: the flag is on by default (this process): Sonnet is refused once, then the same call goes to Opus.
    let t = Seq()
    let c = ClaudeClient(config: .init(mode: .direct(apiKey: "k")), transport: t)
    _ = try await ClaudeRouting.$call.withValue(.guide) {
        try await c.structured(NutmegTurn.self, system: "s", user: "u", schema: JSONSchema(Schemas.turn()), effort: .low)
    }
    #expect(t.models == ["claude-sonnet-5-5", "claude-opus-5-5"])
}
