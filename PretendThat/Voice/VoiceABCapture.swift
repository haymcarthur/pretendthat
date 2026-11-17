#if DEBUG
import AVFoundation
import NutmegCore

/// Round 35 prep, voice A/B v2 (`-PTVoiceAB`, DEBUG only): records what Nutmeg's ONE speaker plays, one file pair per
/// line: the player's output (`NN-x.raw.caf`: the voice as the session sent it, 24 kHz, before Varispeed) and the
/// mixer's output (`NN-x.out.caf`: what goes to the speaker, hardware rate, after Varispeed 1.20). The pair measures
/// the heard rate (duration and pitch ratio out/raw) on the real app path. Taps only exist with the flag; nothing is
/// recorded in a normal run. (Not with `-PTTapOut`, which taps the same buses.)
final class ABCapture: @unchecked Sendable {
    static let shared = ABCapture()
    static var enabled: Bool { ProcessInfo.processInfo.arguments.contains("-PTVoiceAB") }

    private let lock = NSLock()
    private var raw: AVAudioFile?
    private var out: AVAudioFile?
    private var playFormat: AVAudioFormat?
    private var outFormat: AVAudioFormat?

    func install(_ engine: AVAudioEngine, player: AVAudioPlayerNode, playFormat: AVAudioFormat) {
        guard Self.enabled else { return }
        let outFmt = engine.mainMixerNode.outputFormat(forBus: 0)
        lock.withLock { self.playFormat = playFormat; self.outFormat = outFmt }
        player.installTap(onBus: 0, bufferSize: 2048, format: playFormat) { [weak self] b, _ in self?.write(b, raw: true) }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 2048, format: outFmt) { [weak self] b, _ in self?.write(b, raw: false) }
        rtLog("VOICEAB taps: raw \(playFormat.sampleRate) Hz, out \(outFmt.sampleRate) Hz × \(outFmt.channelCount)")
    }

    private func write(_ b: AVAudioPCMBuffer, raw isRaw: Bool) {
        lock.withLock { try? (isRaw ? raw : out)?.write(from: b) }
    }

    func begin(dir: URL, name: String) {
        lock.withLock {
            guard let pf = playFormat, let of = outFormat else { return }
            raw = try? AVAudioFile(forWriting: dir.appendingPathComponent("\(name).raw.caf"), settings: pf.settings)
            out = try? AVAudioFile(forWriting: dir.appendingPathComponent("\(name).out.caf"), settings: of.settings)
        }
    }

    func end() { lock.withLock { raw = nil; out = nil } }
}

extension AppModel {
    /// The A/B v2 lines: the kinds of scripted lines the mini model would say (`sayExactly`).
    static var voiceABLines: [(label: String, line: String)] {
        [
            ("Scene opening", "Pretend that the jungle pizza restaurant is opening for its very first night! The oven is hot and the "
                + "tables are set. Everyone, take your places and get ready for the first hungry customer!"),
            ("Prop line", PropLines.ask(item: "pot", becomes: "mixing bowl", reason: "The Pizza Chef stirs the sauce in it.", n: 1)),
            ("Task read-out", "Server, put the hot pizza on the tray and carry it to the Hungry Customer's table!"),
            ("Returning greeting", GameGreeting.short.first ?? "Hi again! What should we play today?"),
            ("Print step", HandOffLines.printReady),
            ("Replay Pick", ReplayLines.howMany),
            ("The End", HandOffLines.end()),
            ("Nothing heard", "Hmm, I didn't catch that. Hold the red button and tell me again!"),
        ]
    }

    /// `-PTLive -PTVoiceAB -PTMiniLines YES`: connects the real session (and the mini lines session), then says each A/B
    /// line on the full model and on the mini model through the app's own path (`realtime.say` → NutmegSpeaker),
    /// capturing raw + heard audio per line into Documents/voice-ab-v2/. Order alternates per line.
    func debugVoiceAB() async {
        guard let auth = realtimeAuth else { rtLog("VOICEAB: no voice auth"); return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("voice-ab-v2", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ok = await realtime.connect(auth: auth, config: voiceConfig, echoCancel: Self.echoCancel, instructions: Realtime.instructions)
        guard ok else { rtLog("VOICEAB: connect failed"); return }
        try? await Task.sleep(for: .seconds(2))
        guard realtime.linesOnMini else { rtLog("VOICEAB: the mini lines session isn't up (pass -PTMiniLines YES)"); return }
        var index: [String] = []
        for (i, item) in Self.voiceABLines.enumerated() {
            let n = String(format: "%02d", i + 1)
            let order: [Bool] = i % 2 == 0 ? [false, true] : [true, false]   // mini?
            for mini in order {
                let name = "\(n)-\(mini ? "mini" : "full")"
                realtime.debugLinesOnMain = !mini
                ABCapture.shared.begin(dir: dir, name: name)
                let t0 = Date()
                realtime.say(item.line, record: false)
                for _ in 0..<100 where !realtime.isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
                for _ in 0..<600 where realtime.isSpeaking || realtime.isBusy { try? await Task.sleep(for: .milliseconds(100)) }
                try? await Task.sleep(for: .seconds(1.0))   // the mixer tap lags the player; let the tail land
                ABCapture.shared.end()
                rtLog(String(format: "VOICEAB %@ done in %.1f s", name, Date().timeIntervalSince(t0)))
                try? await Task.sleep(for: .seconds(0.8))
            }
            index.append("\(n)\t\(item.label)\t\(item.line)")
        }
        realtime.debugLinesOnMain = false
        try? (index.joined(separator: "\n") + "\n").write(to: dir.appendingPathComponent("lines.tsv"), atomically: true, encoding: .utf8)
        rtLog("VOICEAB done: \(dir.path)")
        realtime.disconnect()
    }
}
#endif
