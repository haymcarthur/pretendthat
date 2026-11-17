import Foundation
#if os(iOS)
@preconcurrency import AVFAudio
#endif

// Round 35 prep (2026-11-16, Haylee's overnight plan step 2): one audio session for every Nutmeg sound, one voice
// config for both Realtime sessions, and the two cost cuts (mini voice for scripted lines, Sonnet for the guide and
// the weave) behind flags that are OFF until Haylee approves by ear.

// MARK: - The one audio session

/// The audio session Nutmeg ALWAYS plays through: the game's `.playAndRecord` / `.default` /
/// `[.defaultToSpeaker, .allowBluetoothA2DP]` with a 48 kHz preference (round 25). Before round 35 the onboarding used
/// `.playback` / `.spokenAudio` on its own engine, which an iPad routes through different speaker processing, so she
/// sounded different there (research/2026-11-16-onboarding-voice-investigation.md). `NutmegSpeaker.start`, the
/// output-only clip start (onboarding, before the mic is allowed) and the tap-fallback listener all call `apply()`.
/// Activating this category does not ask for the microphone: only starting the engine's INPUT does, and the
/// output-only start never touches `inputNode`.
public struct NutmegAudioSession: Equatable, Sendable {
    public let category: String
    public let mode: String
    public let options: [String]
    public let preferredSampleRate: Double

    public static let nutmeg = NutmegAudioSession(category: "playAndRecord", mode: "default",
                                                  options: ["defaultToSpeaker", "allowBluetoothA2DP"], preferredSampleRate: 48_000)

    #if os(iOS)
    public var avCategory: AVAudioSession.Category { .playAndRecord }
    public var avMode: AVAudioSession.Mode { .default }
    public var avOptions: AVAudioSession.CategoryOptions { [.defaultToSpeaker, .allowBluetoothA2DP] }

    /// Sets the category, the 48 kHz preference (before activating, so the input starting later doesn't renegotiate
    /// the hardware rate) and activates.
    @MainActor public func apply() throws {
        let s = AVAudioSession.sharedInstance()
        if s.category != avCategory || s.mode != avMode || s.categoryOptions != avOptions {
            try s.setCategory(avCategory, mode: avMode, options: avOptions)
        }
        try? s.setPreferredSampleRate(preferredSampleRate)
        try s.setActive(true)
    }

    /// The current session matches this setup (DEBUG log / the VOICEFMT line).
    @MainActor public var isCurrent: Bool {
        let s = AVAudioSession.sharedInstance()
        return s.category == avCategory && s.mode == avMode && s.categoryOptions == avOptions
    }
    #endif
}

// MARK: - Flags (default OFF)

/// Round 35 prep: the cost cuts are built but OFF until Haylee approves (the mini voice by ear, A/B v2 in
/// design/voice-ab-v2/). Each is a UserDefaults bool; a launch argument sets it for one run in any build:
/// `-PTMiniLines YES` (or bare `-PTMiniLines`; `NO` turns it off) and `-PTSonnetGuide YES`.
/// On a device: Xcode scheme → Run → Arguments, or `UserDefaults.standard.set(true, forKey: …)` in a debug menu later.
public enum CostFlags {
    /// Scripted app lines (`sayExactly`) on the mini Realtime model, in a second session with the SAME voice config.
    public static let miniLinesKey = "PTMiniLines"
    /// The play guide and the per-prop weave on Sonnet 5.5 (the kit pages stay on Opus 5.5).
    public static let sonnetGuideKey = "PTSonnetGuide"

    public static var miniLines: Bool { isOn(miniLinesKey) }
    public static var sonnetGuide: Bool { isOn(sonnetGuideKey) }

    /// `-<key>` alone or with any value but NO/0/false/off → on; else the UserDefaults bool (off when unset).
    public static func isOn(_ key: String, args: [String] = ProcessInfo.processInfo.arguments,
                            defaults: UserDefaults = .standard) -> Bool {
        if let i = args.firstIndex(of: "-" + key) {
            guard i + 1 < args.count, !args[i + 1].hasPrefix("-") else { return true }
            return !["no", "0", "false", "off"].contains(args[i + 1].lowercased())
        }
        return defaults.bool(forKey: key)
    }

    /// The value after `-<key>` when it names a model (`-PTMiniLines gpt-realtime-…`), for experiments.
    public static func modelArgument(_ key: String, args: [String] = ProcessInfo.processInfo.arguments) -> String? {
        guard let i = args.firstIndex(of: "-" + key), i + 1 < args.count else { return nil }
        let v = args[i + 1]
        return v.hasPrefix("gpt-") || v.hasPrefix("claude-") ? v : nil
    }
}

// MARK: - One voice config for both Realtime sessions

/// Round 35 prep (Haylee's hard rule: "Nutmeg's voice never changes"). The conversation session and the scripted-lines
/// session are BOTH built here from the same `VoiceConfig` and the same instructions: the session.update payloads are
/// identical (voice coral, server speed 1.0, PCM16 24 kHz out, the same instructions with `Realtime.voiceStyle`, the
/// same tools); only the model in the URL differs. Both sessions' audio plays through the one `NutmegSpeaker`
/// (Varispeed 1.20). `VoiceSessionPlanTests` fails if they ever differ.
public struct VoiceSessionPlan: Sendable {
    public enum Kind: String, Sendable { case conversation, lines }
    public let kind: Kind
    public let model: String
    public let config: VoiceConfig
    public let instructions: String

    public static func conversation(_ config: VoiceConfig = .nutmeg, instructions: String = Realtime.instructions) -> VoiceSessionPlan {
        VoiceSessionPlan(kind: .conversation, model: Realtime.model, config: config, instructions: instructions)
    }
    /// The scripted-lines session: nil while the mini flag is off.
    public static func lines(_ config: VoiceConfig = .nutmeg, instructions: String = Realtime.instructions,
                             model: String? = Realtime.lineModel) -> VoiceSessionPlan? {
        guard let model else { return nil }
        return VoiceSessionPlan(kind: .lines, model: model, config: config, instructions: instructions)
    }

    /// The session.update both sessions send (the same builder, the same config).
    public var sessionUpdate: [String: Any] { config.sessionUpdate(instructions: instructions) }
    public var url: URL { Realtime.url(model: model) }
    /// Heard rate on the device (both sessions play through the speaker's Varispeed).
    public var playbackRate: Double { config.playbackRate }
    /// Clip keys stay on the conversation voice ID for now (bundled clips keep matching); see the round 35 prep decision.
    public var voiceID: String { config.voiceID }
}

extension Realtime {
    /// The mini Realtime model for scripted lines (cost v3; behind `CostFlags.miniLines`).
    public static let miniModel = "gpt-realtime-2.1-mini"

    /// What the server confirmed in session.updated: model, voice, speed, output format and the instructions' length
    /// (numbers and settings only, no content). The A/B v2 run logs it for both sessions: proof both are coral.
    public static func sessionEcho(_ text: String) -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let s = obj["session"] as? [String: Any] else { return "?" }
        let out = (s["audio"] as? [String: Any])?["output"] as? [String: Any] ?? [:]
        let fmt = out["format"] as? [String: Any] ?? [:]
        return "model \(s["model"] as? String ?? "?"), voice \(out["voice"] as? String ?? "?"), speed \(out["speed"].map { "\($0)" } ?? "?"), "
            + "format \(fmt["type"] as? String ?? "?")@\(fmt["rate"].map { "\($0)" } ?? "?"), instructions \((s["instructions"] as? String)?.count ?? 0) chars, "
            + "tools \((s["tools"] as? [Any])?.count ?? 0)"
    }
}

// MARK: - Sonnet for the guide and the weave

extension ClaudeRouting {
    public static let sonnet = "claude-sonnet-5-5"
    /// The calls Sonnet takes when `CostFlags.sonnetGuide` is on. The kit pages (and every other call) stay on Opus.
    public static let sonnetCalls: Set<ClaudeCall> = [.guide, .weave]
    /// The flag's routing, pure (tests): Sonnet for the guide and the weave when on, else the configured model.
    public static func flagged(_ call: ClaudeCall?, base: String, sonnetOn: Bool) -> String {
        guard sonnetOn, let call, sonnetCalls.contains(call) else { return base }
        return sonnet
    }
}
