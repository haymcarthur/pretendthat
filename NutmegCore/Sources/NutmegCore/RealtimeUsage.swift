import Foundation

/// Round 20 (cost): the token COUNTS from a Realtime `response.done` (`response.usage`), for measuring how much of each
/// response's input hit OpenAI's prompt cache. Never any content: only numbers.
public struct RealtimeUsage: Equatable, Sendable {
    public var input = 0, cached = 0, cachedText = 0, cachedAudio = 0, textIn = 0, audioIn = 0, output = 0
    /// Round D3b: output token split (audio out is the costly part of an app line).
    public var outAudio = 0, outText = 0
    public var outOfBand = false
    public init() {}

    /// Parses a `response.done` event's usage; nil for any other event or one without usage.
    public static func parse(_ text: String) -> RealtimeUsage? {
        guard text.contains("\"response.done\""),
              let obj = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any],
              let response = obj["response"] as? [String: Any],
              let usage = response["usage"] as? [String: Any] else { return nil }
        func int(_ d: [String: Any]?, _ k: String) -> Int { (d?[k] as? NSNumber)?.intValue ?? 0 }
        var u = RealtimeUsage()
        let inDetails = usage["input_token_details"] as? [String: Any]
        let cachedDetails = inDetails?["cached_tokens_details"] as? [String: Any]
        u.input = int(usage, "input_tokens"); u.output = int(usage, "output_tokens")
        u.cached = int(inDetails, "cached_tokens")
        u.cachedText = int(cachedDetails, "text_tokens"); u.cachedAudio = int(cachedDetails, "audio_tokens")
        u.textIn = int(inDetails, "text_tokens"); u.audioIn = int(inDetails, "audio_tokens")
        let outDetails = usage["output_token_details"] as? [String: Any]
        u.outAudio = int(outDetails, "audio_tokens"); u.outText = int(outDetails, "text_tokens")
        u.outOfBand = (response["conversation_id"] as? String) == nil && (response["conversation"] as? String) == "none"
        return u
    }

    /// One log line of counts.
    public var line: String {
        "in \(input) (text \(textIn), audio \(audioIn)), cached \(cached) (text \(cachedText), audio \(cachedAudio)), out \(output)"
    }
}

/// Running totals for a session (counts only).
public struct RealtimeUsageTotals: Equatable, Sendable {
    public var responses = 0, input = 0, cached = 0, output = 0
    /// Round D3b: audio output tokens and text / audio input tokens (the replay cost check).
    public var outAudio = 0, textIn = 0, audioIn = 0
    public init() {}
    public mutating func add(_ u: RealtimeUsage) {
        responses += 1; input += u.input; cached += u.cached; output += u.output
        outAudio += u.outAudio; textIn += u.textIn; audioIn += u.audioIn
    }
    /// List-price dollars for these counts (gpt-realtime: text in $4, cached $0.40, audio in $32, audio out $64,
    /// text out $16 per 1M tokens). An estimate for the live checks, not billing.
    public var dollars: Double {
        let uncached = Double(max(0, input - cached))
        let textOut = Double(max(0, output - outAudio))
        return (uncached * 4 + Double(cached) * 0.4 + Double(outAudio) * 64 + textOut * 16) / 1_000_000
    }
    public var cachedShare: Double { input == 0 ? 0 : Double(cached) / Double(input) }
}
