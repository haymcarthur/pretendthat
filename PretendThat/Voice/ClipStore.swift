import AVFoundation
import Observation
import NutmegCore

/// Round D3b (design §D4): the current game's recorded Nutmeg lines, the speaker's clip source.
/// - First play: kept lines are encoded to AAC-LC (24 kHz mono, 32 kbps, ADTS .aac) and held for this game only. Save moves
///   them into the saved game; Leave / New game drops them with the rest of the unsaved game.
/// - Saved game (after Save, and every replay): a new line (live once) is added to the game folder at once.
/// - Bundled common lines (§D4.6: recorded once in development from her real Realtime voice) are the last stop.
/// Only her app lines are ever here (the session's recorder takes only tagged `sayExactly` responses); nothing about kids.
@MainActor
final class ClipStore: NutmegClipSource {
    enum Mode: Equatable { case off, firstPlay, saved(UUID) }
    private(set) var mode: Mode = .off
    private(set) var index = ClipIndex(commonKeys: ClipStore.bundledCommon)
    private let games: SavedGameStore
    /// First play: key → AAC data waiting for Save.
    private var pending: [String: Data] = [:]
    private var decoded: [String: [Float]] = [:]
    /// Voice pitch build: each clip's measured raw pitch (for its own shift toward the live voice), by key.
    private var pitches: [String: Double] = [:]
    private let voiceID = VoiceConfig.nutmeg.voiceID
    /// A kept line was stored (counts only).
    var onStored: ((SavedClip) -> Void)?

    init(games: SavedGameStore) { self.games = games }

    /// The bundled common lines that ship with the app (text → key).
    static let bundledCommon: [String: String] = {
        var out: [String: String] = [:]
        for line in CommonLines.all {
            let key = CommonLines.key(line)
            if Bundle.main.url(forResource: "common-\(key)", withExtension: "aac") != nil { out[line] = key }
        }
        return out
    }()

    /// Round 35 prep: a bundled common line as a clip with no game loaded (the onboarding), for the speaker's one
    /// playback path. nil when the line isn't bundled (she stays quiet; never TTS).
    static func bundledClip(for line: String) -> NutmegClip? {
        guard let key = bundledCommon[line],
              let url = Bundle.main.url(forResource: "common-\(key)", withExtension: "aac"),
              let samples = decode(url), !samples.isEmpty else { return nil }
        if bundledPitch[key] == nil { bundledPitch[key] = measuredPitch(key, samples) }
        return NutmegClip(key: key, text: line, samples: samples, common: true, pitchHz: bundledPitch[key])
    }

    /// The onboarding's bundled clips' pitches, measured once per launch (it plays them with no game loaded).
    @MainActor private static var bundledPitch: [String: Double] = [:]

    /// A clip's raw median pitch (a few ms), checked against the live band (`ClipPitch.keepRange`): logged when outside
    /// it. Clips all get the live processing; the pitch is for the check (and the log), never a per-clip shift.
    nonisolated static func measuredPitch(_ key: String, _ samples: [Float]) -> Double? {
        let hz = PitchTracker.medianHz(samples)
        let r = ClipPitch.keepRange
        if ClipPitch.check(hz, in: r) != .ok {
            rtLog(String(format: "CLIP pitch %@: %@ %.0f Hz raw (live band %.0f–%.0f)", ClipPitch.check(hz, in: r) == .outOfRange ? "OUT OF RANGE" : "unmeasured",
                         String(key.prefix(8)), hz ?? 0, r.lowerBound, r.upperBound))
        }
        return hz
    }

    // MARK: Modes

    func startFirstPlay() { mode = .firstPlay; pending = [:]; decoded = [:]; pitches = [:]; index = ClipIndex(commonKeys: Self.bundledCommon) }
    func load(_ game: SavedGame) {
        #if DEBUG
        // `-PTNoClips`: the D1 baseline (every replay line live, nothing recorded), for the cost comparison.
        if ProcessInfo.processInfo.arguments.contains("-PTNoClips") { reset(); rtLog("CLIPS off (-PTNoClips): D1 live-voice baseline"); return }
        #endif
        mode = .saved(game.id); pending = [:]; decoded = [:]; pitches = [:]
        index = ClipIndex(clips: game.clips, commonKeys: Self.bundledCommon)
        rtLog("CLIPS loaded: \(game.clips.count) recorded lines, \(Self.bundledCommon.count) bundled")
    }
    /// Leave / New game: an unsaved game's clips are thrown away.
    func reset() {
        if mode == .firstPlay && !pending.isEmpty { rtLog("CLIPS discarded with the unsaved game: \(pending.count)") }
        mode = .off; pending = [:]; decoded = [:]; pitches = [:]; index = ClipIndex(commonKeys: Self.bundledCommon)
    }

    /// Save at The End: the clips to write with the game.
    func pendingForSave() -> (clips: [SavedClip], data: [String: Data]) {
        (index.gameClips.filter { pending[$0.key] != nil }, pending)
    }
    func didSave(_ id: UUID) { mode = .saved(id); pending = [:] }

    // MARK: Lookup

    func has(_ line: String) -> Bool { mode != .off && index.has(line) }

    func clip(for line: String) -> NutmegClip? {
        guard mode != .off, let hit = index.hit(for: line) else { return nil }
        switch hit {
        case .game(let c):
            if let s = decoded[c.key] { return NutmegClip(key: c.key, text: line, samples: s, pitchHz: pitches[c.key] ?? pitch(c.key, s)) }
            let url: URL?
            if let d = pending[c.key] { url = Self.tempFile(d, key: c.key) }
            else if case .saved(let id) = mode { url = games.clipURL(c, in: id) }
            else { url = nil }
            guard let url, let s = Self.decode(url) else { rtLog("CLIP decode failed"); return nil }
            if pending[c.key] != nil { try? FileManager.default.removeItem(at: url) }
            decoded[c.key] = s
            return NutmegClip(key: c.key, text: line, samples: s, pitchHz: pitch(c.key, s))
        case .common(let key):
            if let s = decoded[key] { return NutmegClip(key: key, text: line, samples: s, common: true, pitchHz: pitch(key, s)) }
            guard let url = Bundle.main.url(forResource: "common-\(key)", withExtension: "aac"), let s = Self.decode(url) else { return nil }
            decoded[key] = s
            return NutmegClip(key: key, text: line, samples: s, common: true, pitchHz: pitch(key, s))
        }
    }

    private func pitch(_ key: String, _ samples: [Float]) -> Double? {
        if let hz = pitches[key] { return hz }
        let hz = Self.measuredPitch(key, samples)
        pitches[key] = hz
        return hz
    }

    // MARK: Recording

    /// A line the recorder kept: encoded off the main actor, then held (first play) or added to the saved game.
    func store(_ line: RecordedLine, roles: [Role]) {
        guard mode != .off else { return }
        let key = ClipKey.make(line: line.request.line, voiceID: voiceID)
        guard index.hit(for: line.request.line).map({ if case .game = $0 { return false } else { return true } }) ?? true else { return }
        let pcm = line.pcm16
        let clip = SavedClip(key: key, text: line.request.line, kind: line.request.kind.rawValue, role: line.request.role,
                             duration: line.duration, file: SavedGame.clipFile(key))
        Task { @MainActor in
            // Measured and encoded off the main actor. Voice clips match: a take outside the live band isn't kept (a
            // replay says the line live again and keeps that take if it's in range): re-recorded, never pitch-corrected.
            guard let (data, hz) = await Task.detached(priority: .utility, operation: { () -> (Data?, Double?)? in
                let hz = Self.measuredPitch(key, ClipAudio.floats(pcm))
                guard ClipPitch.keeps(hz) else { return (nil, hz) }
                guard let d = Self.encodeAAC(pcm) else { return nil }
                return (d, hz)
            }).value else {
                rtLog("CLIP encode failed"); return
            }
            guard let data else { rtLog(String(format: "CLIP not kept: take outside the live band (%.0f Hz raw)", hz ?? 0)); return }
            guard self.mode != .off else { return }
            switch self.mode {
            case .firstPlay: self.pending[key] = data
            case .saved(let id): guard self.games.addClip(clip, data: data, to: id) else { return }
            case .off: return
            }
            self.index.add(clip)
            self.decoded[key] = ClipAudio.floats(pcm)
            if let hz { self.pitches[key] = hz }
            rtLog(String(format: "CLIP stored (%@, %.1f s, %d KB AAC)%@", clip.kind, clip.duration, data.count / 1024,
                         self.mode == .firstPlay ? " for this game" : " in the saved game"))
            self.onStored?(clip)
        }
    }

    // MARK: AAC (AAC-LC 24 kHz mono 32 kbps, ADTS .aac: no 32 KB container header per clip)

    /// The AAC encoder's delay at the start of an ADTS stream (no edit list to trim it).
    nonisolated static let primingFrames = 2112

    nonisolated static func encodeAAC(_ pcm16: Data) -> Data? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("clip-\(UUID().uuidString).aac")
        defer { try? FileManager.default.removeItem(at: url) }
        let settings: [String: Any] = [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: Realtime.sampleRate,
                                       AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 32_000]
        let samples = ClipAudio.floats(pcm16)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Realtime.sampleRate, channels: 1),
              let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        samples.withUnsafeBufferPointer { buf.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        buf.frameLength = AVAudioFrameCount(samples.count)
        do {
            var file: AVAudioFile? = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
            try file?.write(from: buf)
            file = nil   // closes the file
            return try Data(contentsOf: url)
        } catch {
            rtLog("CLIP AAC encode error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Decodes a clip to float PCM at 24 kHz mono, the encoder's priming trimmed (ADTS has no edit list).
    nonisolated static func decode(_ url: URL) -> [Float]? {
        guard let file = try? AVAudioFile(forReading: url),
              let buf = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              (try? file.read(into: buf)) != nil, let ch = buf.floatChannelData?[0] else { return nil }
        let n = Int(buf.frameLength)
        let skip = url.pathExtension == "aac" ? min(primingFrames, n) : 0
        if file.processingFormat.sampleRate == Realtime.sampleRate { return Array(UnsafeBufferPointer(start: ch + skip, count: n - skip)) }
        // A different rate (never written by this app): resample to 24 kHz.
        guard let out = AVAudioFormat(standardFormatWithSampleRate: Realtime.sampleRate, channels: 1),
              let conv = AVAudioConverter(from: file.processingFormat, to: out),
              let dst = AVAudioPCMBuffer(pcmFormat: out, frameCapacity: AVAudioFrameCount(Double(n) * Realtime.sampleRate / file.processingFormat.sampleRate) + 1024)
        else { return nil }
        var fed = false
        _ = conv.convert(to: dst, error: nil) { _, status in
            if fed { status.pointee = .endOfStream; return nil }
            fed = true; status.pointee = .haveData; return buf
        }
        return Array(UnsafeBufferPointer(start: dst.floatChannelData![0], count: Int(dst.frameLength)))
    }

    private static func tempFile(_ data: Data, key: String) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("pending-\(key).aac")
        return (try? data.write(to: url)) != nil ? url : nil
    }
}
