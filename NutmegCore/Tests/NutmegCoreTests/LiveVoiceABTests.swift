import Foundation
import Testing
@testable import NutmegCore

/// Cost v3 (2026-11-16): the same fixed app lines (`sayExactly`) on the full Realtime model (the app's own session:
/// instructions + tools, coral, server speed 1.0) and on the mini model in a separate fixed-lines session
/// (round 35 prep: `VoiceSessionPlan.lines`, the same session.update as the conversation). Saves raw PCM16 24 kHz per line (Varispeed 1.20 is applied afterwards, exactly as
/// the app's pitch unit does: resampling), the transcript, the latency (response.create sent → first audio delta) and
/// the token counts. LIVE_VOICE_AB=1 with OPENAI_API_KEY; real calls. Output: $PT_AB_OUT (default /tmp/pt-cost3/voice).
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_VOICE_AB"] == "1"
               && ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty == false))
func liveVoiceAB() async throws {
    let env = ProcessInfo.processInfo.environment
    let key = env["OPENAI_API_KEY"]!
    let out = URL(fileURLWithPath: env["PT_AB_OUT"] ?? "/tmp/pt-cost3/voice")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let lines = ABLines.all
    var report: [String] = []
    let rounds = Int(env["PT_AB_ROUNDS"] ?? "1") ?? 1
    // Round 35 prep: both sessions from the one plan (identical session.update; only the model differs).
    let full = VoiceSessionPlan.conversation(), mini = VoiceSessionPlan.lines(model: Realtime.miniModel)!
    for (label, model, session) in [("full", full.model, full.sessionUpdate), ("mini", mini.model, mini.sessionUpdate)] {
        for round in 1...rounds {
            let ws = ABSocket(model: model, key: key)
            ws.send(session)
            guard await ws.waitReady() else { report.append("\(label): session not ready \(ws.error ?? "-")"); continue }
            for (i, line) in lines.enumerated() {
                let r = await ws.say(line)
                let n = String(format: "%02d", i + 1)
                if round == 1 { try r.pcm.write(to: out.appendingPathComponent("\(n)-\(label).pcm")) }
                let secs = Double(r.pcm.count) / 2 / 24_000
                let exact = ABLines.norm(r.transcript) == ABLines.norm(line)
                report.append("\(label) r\(round) \(n): first-audio \(String(format: "%.2f", r.firstAudio)) s, done \(String(format: "%.2f", r.done)) s, "
                              + "audio \(String(format: "%.1f", secs)) s (\(String(format: "%.1f", secs / 1.2)) s at 1.20), exact=\(exact), usage \(r.usage)"
                              + (exact ? "" : " | SAID: \(r.transcript)"))
            }
            ws.close()
        }
    }
    try (report.joined(separator: "\n") + "\n").write(to: out.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
    for l in report { print("VOICEAB \(l)") }
}

enum ABLines {
    static let all: [String] = [
        // 1. a scene opening (setup + each role's task + the first-scene how-to), the longest kind of line
        "Pretend that the jungle pizza restaurant is opening for its very first night! Pizza Chef, stir the sauce in the mixing bowl, then spread it on the pizza. Hungry Customer, read the menu and tell the Server what you want. Server, write the order on a ticket and carry it to the Pizza Chef! "
            + HandOffLines.nextSceneHowTo,
        // 2. a row's task read-out
        "Server, put the hot pizza on the tray and carry it to the Hungry Customer's table!",
        // 3. the print line
        HandOffLines.printReady,
        // 4. a kit progress line
        "I'm making your name badges!",
        // 5. a replay hunt line
        "No problem, we'll pretend!",
        // 6. the replay's Pick question
        ReplayLines.howMany,
        // 7. The End
        HandOffLines.end(),
        // 8. the nothing-heard line (round 31)
        "Hmm, I didn't catch that. Hold the red button and tell me again!",
    ]
    static func norm(_ s: String) -> String {
        s.lowercased().unicodeScalars.filter { CharacterSet.letters.contains($0) || $0 == " " }.map(String.init).joined()
            .split(separator: " ").joined(separator: " ")
    }
}

final class ABSocket: @unchecked Sendable {
    struct Result { var pcm = Data(); var transcript = ""; var firstAudio = 0.0; var done = 0.0; var usage = "" }
    private let task: URLSessionWebSocketTask
    private let lock = NSLock()
    private var buffer: [String] = []
    private var waiters: [CheckedContinuation<String?, Never>] = []
    private(set) var error: String?
    init(model: String, key: String) {
        var req = URLRequest(url: Realtime.url(model: model))
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        task = URLSession.shared.webSocketTask(with: req)
        task.maximumMessageSize = 16 * 1024 * 1024
        task.resume()
        pump()
    }
    func send(_ obj: [String: Any]) { task.send(.string(Realtime.json(obj))) { _ in } }
    func close() { task.cancel(with: .normalClosure, reason: nil) }
    private func pump() {
        task.receive { [weak self] r in
            guard let self else { return }
            switch r {
            case .success(let m):
                var text: String?
                if case .string(let s) = m { text = s } else if case .data(let d) = m { text = String(data: d, encoding: .utf8) }
                if let text { self.deliver(text) }
                self.pump()
            case .failure(let e):
                self.lock.withLock { self.error = e.localizedDescription }
                self.deliver(nil)
            }
        }
    }
    private func deliver(_ t: String?) {
        let w: CheckedContinuation<String?, Never>? = lock.withLock {
            if !waiters.isEmpty { return waiters.removeFirst() }
            if let t { buffer.append(t) }
            return nil
        }
        w?.resume(returning: t)
    }
    func next() async -> String? {
        await withCheckedContinuation { c in
            let t: String?? = lock.withLock {
                if !buffer.isEmpty { return .some(buffer.removeFirst()) }
                if error != nil { return .some(nil) }
                waiters.append(c); return nil
            }
            if let t { c.resume(returning: t) }
        }
    }
    func waitReady() async -> Bool {
        while let t = await next() {
            switch Realtime.parse(t) {
            case .sessionReady: return true
            case .error(let m): lock.withLock { error = m }; return false
            default: continue
            }
        }
        return false
    }
    func say(_ line: String) async -> Result {
        var r = Result()
        let t0 = Date()
        send(Realtime.sayExactly(line))
        while let t = await next() {
            switch Realtime.parse(t) {
            case .audioDelta(let d):
                if r.pcm.isEmpty { r.firstAudio = Date().timeIntervalSince(t0) }
                r.pcm.append(d)
            case .transcriptDone(let s): r.transcript = s
            case .responseDone:
                r.done = Date().timeIntervalSince(t0)
                r.usage = RealtimeUsage.parse(t)?.line ?? "-"
                return r
            case .error(let m): r.transcript = "ERROR \(m)"; return r
            default: continue
            }
        }
        return r
    }
}

/// Round 35 prep: negative controls for the A/B v2 voice check. The same 3 lines in OTHER voices (and coral) on the
/// full model, raw PCM16 24 kHz, so the measurement can show it tells coral from a wrong voice.
/// LIVE_VOICE_CONTROLS=1 with OPENAI_API_KEY; real calls (12 short responses). Output: $PT_AB_OUT.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_VOICE_CONTROLS"] == "1"
               && ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty == false))
func liveVoiceControls() async throws {
    let env = ProcessInfo.processInfo.environment
    let out = URL(fileURLWithPath: env["PT_AB_OUT"] ?? "/tmp/pt-voice-controls")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let lines = [ABLines.all[1], ABLines.all[6], ABLines.all[7]]
    for voice in ["coral", "marin", "shimmer", "sage"] {
        var c = VoiceConfig.nutmeg; c.voice = voice
        let plan = VoiceSessionPlan.conversation(c)
        let ws = ABSocket(model: plan.model, key: env["OPENAI_API_KEY"]!)
        ws.send(plan.sessionUpdate)
        guard await ws.waitReady() else { print("CONTROL \(voice): not ready \(ws.error ?? "-")"); continue }
        for (i, line) in lines.enumerated() {
            let r = await ws.say(line)
            try r.pcm.write(to: out.appendingPathComponent("\(voice)-\(i + 1).pcm"))
        }
        ws.close()
    }
}
