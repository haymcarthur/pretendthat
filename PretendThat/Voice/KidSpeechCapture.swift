import AVFoundation
import QuartzCore
import Speech
import NutmegCore

/// Round 31 (decisions/2026-11-16-on-device-speech.md, Haylee): the kid's push-to-talk audio is turned into words ON
/// THE iPAD (Apple Speech, `requiresOnDeviceRecognition = true`, en-US) and dropped at once. Nothing here sends audio
/// anywhere: the words go back to the caller, which scrubs names and sends TEXT.
/// - Pre-warmed: the shared engine's input tap feeds `push` for the whole game (the mic itself is the same one that
///   already ran under push-to-talk). While nobody holds the button, only the last few ~50 ms tap chunks are kept, in
///   memory, overwritten as they go, so the chunk the touch lands in isn't lost; they are never sent or stored.
/// - `begin(touchHost:)` on touch-down (from the touch view itself, before any other work): a new on-device request,
///   the chunks from just before the touch, then every chunk until `finish()`.
/// - `finish()` on release: ends the audio, waits for the final words (bounded), drops the request and the audio.
/// Thread-safe: `push` runs on the audio thread.
final class KidSpeechCapture: @unchecked Sendable {
    /// Chunks kept before a touch (≈ 4 × 50 ms), so the first syllable is caught.
    static let preRollChunks = 4
    /// Chunks that started up to this long before the touch are included (the one the touch lands in, plus slack for
    /// the touch → tap delivery).
    static let preRollSeconds = 0.15

    private let lock = NSLock()
    private var ring: [(buffer: AVAudioPCMBuffer, host: Double)] = []
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var words = ""
    private var final = false
    private var failed: Error?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var fileOverride: [AVAudioPCMBuffer]?
    private var debugWords: String? = KidSpeechCapture.standInWords
    #if DEBUG
    /// `-PTStandInWords "..."`: every hold returns these words (simulator press checks: its speech model can't load).
    static let standInWords: String? = {
        let a = ProcessInfo.processInfo.arguments
        return a.firstIndex(of: "-PTStandInWords").flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil }
    }()
    #else
    static let standInWords: String? = nil
    #endif
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    /// A recognition error that says on-device speech can't run here (the app falls back to typing).
    var onUnavailable: (@Sendable () -> Void)?

    var isCapturing: Bool { lock.withLock { request != nil || turnAppend != nil } }

    /// Round 34: iPadOS 26's SpeechAnalyzer turn (the in-app downloaded model), used when SFSpeechRecognizer can't
    /// recognize on the device but the model the app downloaded is installed (`SpeechModelInstaller`).
    nonisolated(unsafe) static var useAnalyzer = false
    private var turnAppend: (@Sendable (AVAudioPCMBuffer) -> Void)?
    private var turnFinish: (@Sendable () async -> String)?
    private var turnCancel: (@Sendable () -> Void)?

    /// Audio thread: one tap chunk. Captured for the turn while a request is open, else kept briefly for the pre-roll.
    func push(_ buffer: AVAudioPCMBuffer, host: Double?) {
        let h = host ?? CACurrentMediaTime()
        if let f = lock.withLock({ fileOverride == nil ? turnAppend : nil }) { f(buffer); MicTiming.captured(bufferHost: h); return }
        let req: SFSpeechAudioBufferRecognitionRequest? = lock.withLock {
            if let request { return fileOverride == nil ? request : nil }
            guard let copy = buffer.copy() as? AVAudioPCMBuffer else { return nil }
            ring.append((copy, h))
            if ring.count > Self.preRollChunks { ring.removeFirst(ring.count - Self.preRollChunks) }
            return nil
        }
        if let req { req.append(buffer); MicTiming.captured(bufferHost: h) }
    }

    /// Touch-down: start a fresh on-device request with the chunks from just before the touch.
    func begin(touchHost: Double) {
        if Self.useAnalyzer, #available(iOS 26, *) { beginAnalyzer(touchHost: touchHost); return }
        guard let recognizer else { onUnavailable?(); return }
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.requiresOnDeviceRecognition = true   // never Apple's servers, never anyone's
        req.shouldReportPartialResults = true
        req.taskHint = .dictation
        req.addsPunctuation = true
        let (pre, file): ([(buffer: AVAudioPCMBuffer, host: Double)], [AVAudioPCMBuffer]?) = lock.withLock {
            task?.cancel(); task = nil
            request = req; words = ""; final = false; failed = nil
            let pre = ring.filter { $0.host >= touchHost - Self.preRollSeconds }
            ring = []
            return (pre, fileOverride)
        }
        if let file {
            for b in file { req.append(b) }   // DEBUG: a recorded phrase stands in for the mic
        } else {
            for p in pre { req.append(p.buffer) }
            if let first = pre.first { MicTiming.captured(bufferHost: first.host) }   // the pre-roll chunk the touch landed in
        }
        #if DEBUG
        if lock.withLock({ debugWords }) != nil { return }   // `#heard`: no recognizer for this hold
        #endif
        // Starting the recognition task talks to the speech service (tens of ms): off the main thread, so the press
        // frame and the stop of her voice never wait for it. Audio appended meanwhile queues in the request.
        let box = UncheckedSendable(req)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let t = recognizer.recognitionTask(with: box.value) { [weak self] result, error in
                self?.update(text: result?.bestTranscription.formattedString, isFinal: result?.isFinal ?? false, error: error)
            }
            self?.lock.withLock { if self?.request === box.value { self?.task = t } else { t.cancel() } }
        }
    }

    /// Round 34: the same turn through SpeechAnalyzer (pre-roll included), on the iPad only.
    @available(iOS 26, *)
    private func beginAnalyzer(touchHost: Double) {
        let turn = AnalyzerTurn()
        let (pre, file): ([(buffer: AVAudioPCMBuffer, host: Double)], [AVAudioPCMBuffer]?) = lock.withLock {
            turnCancel?()
            task?.cancel(); task = nil; request = nil
            turnAppend = { turn.append($0) }; turnFinish = { await turn.finish() }; turnCancel = { turn.cancel() }
            words = ""; final = false; failed = nil
            let pre = ring.filter { $0.host >= touchHost - Self.preRollSeconds }
            ring = []
            return (pre, fileOverride)
        }
        if let file { for b in file { turn.append(b) } } else { for p in pre { turn.append(p.buffer) } }
        rtLog("speech: analyzer turn (in-app model)")
    }

    private func update(text: String?, isFinal: Bool, error: Error?) {
        var unavailable = false
        let wake: [CheckedContinuation<Void, Never>] = lock.withLock {
            if let text { words = text }
            if let error { failed = error; unavailable = Self.meansUnavailable(error) }
            guard isFinal || error != nil else { return [] }
            final = true
            let w = waiters; waiters = []; return w
        }
        wake.forEach { $0.resume() }
        if let error {
            let e = error as NSError
            rtLog("speech: recognition ended with \(e.domain) \(e.code)\(unavailable ? " (on-device unavailable)" : "")")
        }
        if unavailable { onUnavailable?() }
    }

    /// Release: end the audio, wait for the final words (at most `timeout`), then drop the request and every buffer.
    /// Returns "" when nothing was heard.
    func finish(timeout: Duration = .milliseconds(1500)) async -> String {
        #if DEBUG
        if let words = lock.withLock({ debugWords }) {
            // DEBUG `#heard`: the simulator can't run the on-device model, so a live check may stand in for the
            // recognizer's OUTPUT (the rest of the pipeline is the real one). The audio is dropped as usual.
            cancel(); lock.withLock { debugWords = Self.standInWords }
            return words
        }
        #endif
        if let fin = lock.withLock({ turnFinish }) {
            // Round 34: the SpeechAnalyzer turn, bounded like the older path.
            let words: String = await withTaskGroup(of: String?.self) { group in
                group.addTask { await fin() }
                group.addTask { try? await Task.sleep(for: timeout + .milliseconds(500)); return nil }
                let first = await group.next() ?? nil
                group.cancelAll()
                return first ?? ""
            }
            let cancel: (@Sendable () -> Void)? = lock.withLock {
                let c = turnCancel
                turnAppend = nil; turnFinish = nil; turnCancel = nil; ring = []
                return c
            }
            if words.isEmpty { cancel?() }
            return words
        }
        guard let req = lock.withLock({ request }) else { return "" }
        req.endAudio()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in await self?.waitFinal() }
            group.addTask { try? await Task.sleep(for: timeout) }
            await group.next()
            group.cancelAll()
        }
        let (text, waiting): (String, [CheckedContinuation<Void, Never>]) = lock.withLock {
            let t = words
            task?.cancel(); task = nil; request = nil; words = ""; ring = []
            let w = waiters; waiters = []; return (t, w)
        }
        waiting.forEach { $0.resume() }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func waitFinal() async {
        await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
            let done = lock.withLock { () -> Bool in
                if final || request == nil { return true }
                waiters.append(c); return false
            }
            if done { c.resume() }
        }
    }

    /// A tap-length hold, the kit being made, leaving: drop everything, no words.
    func cancel() {
        let w: [CheckedContinuation<Void, Never>] = lock.withLock {
            task?.cancel(); task = nil; request?.endAudio(); request = nil; words = ""; ring = []
            turnCancel?(); turnAppend = nil; turnFinish = nil; turnCancel = nil
            let w = waiters; waiters = []; return w
        }
        w.forEach { $0.resume() }
    }

    /// The engine stopped (background, leaving): no pre-roll is kept.
    func clearPreRoll() { lock.withLock { ring = [] } }

    /// kAFAssistantErrorDomain 1700s / "on-device" errors: the speech asset is missing or on-device isn't supported.
    static func meansUnavailable(_ error: Error) -> Bool {
        let e = error as NSError
        let text = e.localizedDescription.lowercased()
        return text.contains("on-device") || text.contains("on device") || text.contains("not available")
            || text.contains("asset") || (e.domain == "kAFAssistantErrorDomain" && [1700, 1101, 1107].contains(e.code))
            // "Failed to initialize recognizer": the on-device model couldn't load (seen in the simulator, whose
            // speech asset is incomplete although supportsOnDeviceRecognition says true).
            || (e.domain == "kLSRErrorDomain" && e.code == 300)
    }

    #if DEBUG
    /// Live checks (`#heard <words>`): the next finished hold returns these words instead of the recognizer's.
    func debugUseWords(_ words: String?) { lock.withLock { debugWords = words } }
    /// Live checks (`#speak <file>`): the next turn's audio comes from this file instead of the mic (same recognizer,
    /// same on-device request, same everything after). nil = back to the mic.
    func debugUseFile(_ url: URL?) {
        guard let url else { lock.withLock { fileOverride = nil }; return }
        let buffers = Self.read(url)
        rtLog("speech (DEBUG): \(buffers.count) buffers from \(url.lastPathComponent) stand in for the mic")
        lock.withLock { fileOverride = buffers }
    }
    static var onDeviceSupported: Bool {
        SFSpeechRecognizer(locale: Locale(identifier: "en-US"))?.supportsOnDeviceRecognition ?? false
    }
    static func read(_ url: URL) -> [AVAudioPCMBuffer] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        var out: [AVAudioPCMBuffer] = []
        while file.framePosition < file.length {
            guard let b = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: 4800),
                  (try? file.read(into: b)) != nil, b.frameLength > 0 else { break }
            out.append(b)
        }
        return out
    }
    #endif
}
