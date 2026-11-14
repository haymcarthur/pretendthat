import AVFoundation
import Observation
import NutmegCore

/// Hands-free voice conversation with Nutmeg over OpenAI's Realtime API (decisions D1, D2, D7).
/// WebSocket (URLSessionWebSocketTask) + AVAudioEngine, no third-party code.
/// - Mic: input node with voice processing (echo cancellation) → 24 kHz PCM16 mono → `input_audio_buffer.append`.
///   The mic is NOT sent while Nutmeg's audio plays (plus a short tail), so she never hears herself. Server VAD
///   decides when the kid has finished talking.
/// - Speaker: PCM16 deltas (24 kHz float, same rate as the Realtime output, so nothing is resampled before the
///   mixer's one high-quality conversion to the hardware rate) → player node → pitch unit (Varispeed by default,
///   TimePitch or none for comparison) → mixer, with an RMS tap for the mouth.
/// - Voice-processing IO (echo cancellation) is OFF by default: on iOS it runs on the whole IO unit, so it also
///   processes (and dulls/ducks) the OUTPUT. The mic is gated while Nutmeg talks, so she never hears herself anyway.
/// Nothing is recorded or stored: audio buffers are sent and dropped.
@Observable @MainActor
final class RealtimeSession {
    enum Status: Equatable { case idle, connecting, live, failed(String) }

    private(set) var status: Status = .idle
    /// 0…1 loudness of Nutmeg's voice (drives her mouth).
    private(set) var level: Float = 0
    private(set) var isSpeaking = false
    /// Server VAD heard the kid start talking (ears perk).
    private(set) var kidIsTalking = false
    var isMuted = false { didSet { updateGate() } }
    /// Planning is over: stop sending the mic (kids tap from here on, D3), keep the voice for Nutmeg's lines.
    var micWanted = true { didSet { updateGate() } }
    private(set) var lastError: String?

    /// Live transcript for the chat panel: in memory only, cleared when a new conversation starts (PretendThat
    /// stores nothing). Lives on this @Observable, @MainActor session, the same instance the panel reads.
    private(set) var chat = RealtimeTranscript()
    var transcript: [RealtimeTranscript.Line] { chat.lines }

    /// Function call handler: returns the output for the model and whether Nutmeg should answer afterwards.
    @ObservationIgnored var onCall: (@MainActor (String, String) async -> (output: String, respond: Bool))?

    @ObservationIgnored private var socket: RealtimeSocket?
    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player = AVAudioPlayerNode()
    @ObservationIgnored private var pitchUnit: AVAudioUnit?
    @ObservationIgnored private var shape = VoiceShape()
    /// Playback rate of the queued audio (Varispeed plays it faster), for timing when she stops talking.
    private var playbackRate: Double { shape.method == .varispeed ? shape.rate : 1 }
    @ObservationIgnored private let mic = MicPump()
    @ObservationIgnored private var speakingUntil = Date.distantPast
    @ObservationIgnored private var peak: Float = 0
    @ObservationIgnored private var configObserver: NSObjectProtocol?
    @ObservationIgnored private var tailTask: Task<Void, Never>?
    @ObservationIgnored private var pendingOutputs: [(String, String)] = []
    @ObservationIgnored private var wantsResponse = false
    @ObservationIgnored private var responseActive = false
    @ObservationIgnored private var receiveTask: Task<Void, Never>?
    @ObservationIgnored private let playFormat = AVAudioFormat(standardFormatWithSampleRate: Realtime.sampleRate, channels: 1)!

    var isLive: Bool { status == .live }

    // MARK: Lifecycle

    /// Connects, configures the session and starts the audio. Returns false (with `status = .failed`) on any problem.
    func connect(apiKey: String, voice: String, shape: VoiceShape, speed: Double, echoCancel: Bool = false) async -> Bool {
        disconnect()
        chat.clear()
        status = .connecting
        lastError = nil
        guard await AVAudioApplication.requestRecordPermission() else {
            return fail("Microphone permission is off")
        }
        var req = URLRequest(url: Realtime.url())
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let socket = RealtimeSocket(request: req)
        self.socket = socket
        socket.send(Realtime.sessionUpdate(voice: voice, speed: Realtime.apiSpeed(method: shape.method, requested: speed)))

        // Wait for session.updated (or an error) before starting the audio.
        let ready = await withTaskGroup(of: Bool.self) { group in
            group.addTask { await socket.waitForReady() }
            group.addTask { try? await Task.sleep(for: .seconds(8)); return false }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
        guard ready else { return fail(socket.firstError ?? "Couldn't reach OpenAI Realtime") }

        self.shape = shape
        do { try startAudio(echoCancel: echoCancel) } catch { return fail("Audio: \(error.localizedDescription)") }
        status = .live
        #if DEBUG
        rtLog("live; voice processing: \(engine?.inputNode.isVoiceProcessingEnabled ?? false) input: \(engine?.inputNode.outputFormat(forBus: 0).description ?? "-")")
        #endif
        receiveTask = Task { [weak self] in
            for await text in socket.messages { await self?.handle(Realtime.parse(text)) }
            await self?.socketClosed()
        }
        updateGate()
        return true
    }

    func disconnect() {
        receiveTask?.cancel(); receiveTask = nil
        socket?.close(); socket = nil
        mic.stop()
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        if let engine {
            engine.inputNode.removeTap(onBus: 0)
            engine.mainMixerNode.removeTap(onBus: 0)
            player.stop()
            engine.stop()
        }
        engine = nil
        speakingUntil = .distantPast; tailTask?.cancel(); pendingOutputs = []; wantsResponse = false; responseActive = false
        isSpeaking = false; kidIsTalking = false; level = 0
        if status != .idle, case .failed = status {} else { status = .idle }
    }

    /// Nutmeg speaks first (greeting) without waiting for the kid.
    func kickOff() {
        guard let socket, isLive else { return }
        socket.send(Realtime.userText("(The kids just opened the app and can hear you now. Say hi in your own words and find out what they feel like playing.)"))
        requestResponse()
    }

    /// Typed turn (keyboard fallback, simulator, demo safety).
    func sendText(_ text: String) {
        guard let socket, isLive else { return }
        socket.send(Realtime.userText(text))
        chat.kidTyped(text)
        requestResponse()
    }

    /// Speak a fixed line in Nutmeg's Realtime voice (kit ready, scene lines) without adding it to the chat.
    /// Only one in-conversation response may run at a time; ask again after the current one finishes.
    private func requestResponse() {
        if responseActive { wantsResponse = true; return }
        responseActive = true
        socket?.send(Realtime.responseCreate)
    }

    func say(_ line: String) {
        guard let socket, isLive, !line.isEmpty else { return }
        socket.send(Realtime.sayExactly(line))
    }

    /// Applies pitch changes right away (a method change takes effect on the next conversation).
    func setShape(_ s: VoiceShape) {
        let methodChanged = s.method != shape.method
        shape = s
        if methodChanged { return }
        if let tp = pitchUnit as? AVAudioUnitTimePitch { tp.pitch = Float(s.cents) }
        if let vs = pitchUnit as? AVAudioUnitVarispeed { vs.rate = Float(s.rate) }
    }

    /// Grown-ups voice audition: a short session with `voice` that plays the fixed sample line through the same
    /// audio path and pitch settings, then hangs up. (The Realtime voice can't change inside a session.)
    func audition(apiKey: String, voice: String, shape: VoiceShape, speed: Double) async {
        guard status != .live, status != .connecting else { return }
        micWanted = false
        guard await connect(apiKey: apiKey, voice: voice, shape: shape, speed: speed) else { return }
        socket?.send(Realtime.sayExactly(Realtime.auditionLine))
        for _ in 0..<80 where !isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
        for _ in 0..<300 where isSpeaking { try? await Task.sleep(for: .milliseconds(100)) }
        disconnect()
        micWanted = true
    }

    private func fail(_ reason: String) -> Bool {
        rtLog("failed: \(reason)")
        disconnect()
        lastError = reason
        status = .failed(reason)
        return false
    }

    private func socketClosed() {
        guard status == .live else { return }
        let reason = socket?.firstError ?? "Connection closed"
        _ = fail(reason)
    }

    // MARK: Audio

    private func makePitchUnit() -> AVAudioUnit? {
        switch shape.method {
        case .off: return nil
        case .varispeed: let u = AVAudioUnitVarispeed(); u.rate = Float(shape.rate); return u
        case .timePitch: let u = AVAudioUnitTimePitch(); u.pitch = Float(shape.cents); u.rate = 1; return u
        }
    }

    /// player → [pitch unit] → mixer, all at the 24 kHz mono play format.
    private func wireOutput(_ engine: AVAudioEngine) {
        if let pitchUnit {
            engine.connect(player, to: pitchUnit, format: playFormat)
            engine.connect(pitchUnit, to: engine.mainMixerNode, format: playFormat)
        } else {
            engine.connect(player, to: engine.mainMixerNode, format: playFormat)
        }
    }

    private func startAudio(echoCancel: Bool) throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothA2DP])
        try session.setActive(true)

        let engine = AVAudioEngine()
        let input = engine.inputNode
        // Echo cancellation is optional (Grown-ups): voice processing also degrades the output path. The mic gate
        // below keeps Nutmeg from hearing herself either way.
        if echoCancel { try? input.setVoiceProcessingEnabled(true) }
        player = AVAudioPlayerNode()
        pitchUnit = makePitchUnit()
        engine.attach(player)
        if let pitchUnit { engine.attach(pitchUnit) }
        wireOutput(engine)
        engine.mainMixerNode.outputVolume = 1   // unity gain: PCM16 → float is already within ±1, no clipping
        installLevelTap(engine)

        let inFormat = input.outputFormat(forBus: 0)
        if inFormat.sampleRate > 0 && inFormat.channelCount > 0 {
            mic.configure(from: inFormat, socket: socket)
            Self.installMicTap(on: input, format: inFormat, pump: mic)
        }
        engine.prepare()
        try engine.start()
        player.play()
        self.engine = engine
        configObserver = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            Task { @MainActor in
                rtLog("engine configuration changed")
                guard let self, let engine = self.engine else { return }
                // Re-wire the output chain at our format; a reconfiguration can leave it disconnected.
                self.wireOutput(engine)
                self.installLevelTap(engine)
                self.ensureRunning()
                self.player.play()
            }
        }
    }

    private func updateGate() {
        mic.open = isLive && !isMuted && micWanted && !isSpeaking
    }

    private func update(rms: Float) {
        guard isSpeaking else { if level != 0 { level = 0 }; return }
        let target = min(1, rms * 7)
        level = target > level ? target : level + (target - level) * 0.2
        peak = max(peak, level)
    }

    private func installLevelTap(_ engine: AVAudioEngine) {
        engine.mainMixerNode.removeTap(onBus: 0)
        Self.installLevelTap(on: engine.mainMixerNode) { [weak self] rms in Task { @MainActor in self?.update(rms: rms) } }
    }

    /// Voice processing / route changes can stop the engine; restart it before scheduling audio.
    private func ensureRunning() {
        guard let engine, !engine.isRunning else { return }
        do { try engine.start(); rtLog("engine restarted") } catch { rtLog("engine restart failed: \(error.localizedDescription)") }
    }

    private func play(_ pcm16: Data) {
        ensureRunning()
        guard let buffer = Self.floatBuffer(pcm16, format: playFormat) else { return }
        if !isSpeaking { isSpeaking = true; peak = 0; updateGate(); rtLog("speaking") }
        // Track when the queued audio will end from the clock, not completion callbacks (an engine
        // reconfiguration can drop scheduled buffers without calling them back).
        let now = Date()
        speakingUntil = max(now, speakingUntil).addingTimeInterval(Double(buffer.frameLength) / Realtime.sampleRate / playbackRate)
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
        scheduleEndCheck()
    }

    private func scheduleEndCheck() {
        tailTask?.cancel()
        let wait = speakingUntil.timeIntervalSinceNow + 0.45   // short tail so room echo dies before the mic reopens
        tailTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0.05, wait)))
            guard let self, !Task.isCancelled, Date() >= self.speakingUntil.addingTimeInterval(0.4) else { return }
            self.isSpeaking = false
            rtLog("done speaking, peak mouth level \(String(format: "%.2f", self.peak))")
            self.level = 0
            self.updateGate()
        }
    }

    // MARK: Events

    private func handle(_ event: Realtime.Event) async {
        #if DEBUG   // event kinds only (no audio, no transcripts): live-test diagnostics in the simulator console
        switch event {
        case .audioDelta, .transcriptDelta, .other: break
        case .functionCall(let name, _, _): rtLog("call \(name)")
        case .transcriptDone: rtLog("said a line")
        default: rtLog("\(event)")
        }
        #endif
        switch event {
        case .audioDelta(let data): play(data)
        case .transcriptDelta, .transcriptDone, .kidTranscript:
            // Out-of-band lines (sayExactly: kit ready, scene lines) also stream here; they're Nutmeg's words too.
            chat.apply(event)
        case .speechStarted: kidIsTalking = true
        case .speechStopped: kidIsTalking = false
        case .functionCall(let name, let callID, let args):
            let result = await onCall?(name, args) ?? (output: "ok", respond: true)
            pendingOutputs.append((callID, result.output))
            if result.respond { wantsResponse = true }
        case .responseCreated:
            responseActive = true
        case .responseDone:
            responseActive = false
            if !pendingOutputs.isEmpty, let socket {
                for (id, out) in pendingOutputs { socket.send(Realtime.functionOutput(callID: id, output: out)) }
                pendingOutputs = []
            }
            if wantsResponse { wantsResponse = false; requestResponse() }
        case .error(let message):
            lastError = message
        default: break
        }
    }

    // MARK: Off-main helpers

    nonisolated private static func floatBuffer(_ data: Data, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = data.count / 2
        guard frames > 0, let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)),
              let out = buf.floatChannelData?[0] else { return nil }
        data.withUnsafeBytes { raw in
            let src = raw.bindMemory(to: Int16.self)
            for i in 0..<frames { out[i] = Float(Int16(littleEndian: src[i])) / 32768 }
        }
        buf.frameLength = AVAudioFrameCount(frames)
        return buf
    }

    nonisolated private static func installLevelTap(on node: AVAudioNode, report: @escaping @Sendable (Float) -> Void) {
        node.installTap(onBus: 0, bufferSize: 1024, format: nil) { buffer, _ in
            guard let data = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength)
            guard n > 0 else { return }
            var sum: Float = 0
            for i in 0..<n { sum += data[i] * data[i] }
            report((sum / Float(n)).squareRoot())
        }
    }

    nonisolated private static func installMicTap(on input: AVAudioInputNode, format: AVAudioFormat, pump: MicPump) {
        input.installTap(onBus: 0, bufferSize: 2400, format: format) { buffer, _ in pump.push(buffer) }
    }
}

/// Converts mic buffers to 24 kHz mono PCM16 and sends them while the gate is open. Runs on the audio thread.
final class MicPump: @unchecked Sendable {
    private let lock = NSLock()
    private var _open = false
    private var converter: AVAudioConverter?
    private weak var socket: RealtimeSocket?
    private let outFormat = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Realtime.sampleRate, channels: 1, interleaved: true)!

    var open: Bool {
        get { lock.withLock { _open } }
        set { lock.withLock { _open = newValue } }
    }

    func configure(from format: AVAudioFormat, socket: RealtimeSocket?) {
        lock.withLock {
            converter = AVAudioConverter(from: format, to: outFormat)
            self.socket = socket
        }
    }

    func stop() { lock.withLock { _open = false; converter = nil; socket = nil } }

    func push(_ buffer: AVAudioPCMBuffer) {
        let (isOpen, converter, socket) = lock.withLock { (_open, self.converter, self.socket) }
        guard isOpen, let converter, let socket else { return }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 64)
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, out.frameLength > 0, let ch = out.int16ChannelData?[0] else { return }
        let data = Data(bytes: ch, count: Int(out.frameLength) * 2)
        socket.send(Realtime.appendAudio(data))
    }
}

/// Thin thread-safe wrapper around URLSessionWebSocketTask: JSON out, text messages in as an AsyncStream.
final class RealtimeSocket: @unchecked Sendable {
    private let task: URLSessionWebSocketTask
    private let lock = NSLock()
    private var _ready = false
    private var _firstError: String?
    private var readyWaiters: [CheckedContinuation<Bool, Never>] = []
    let messages: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation

    var firstError: String? { lock.withLock { _firstError } }

    init(request: URLRequest) {
        task = URLSession.shared.webSocketTask(with: request)
        task.maximumMessageSize = 16 * 1024 * 1024
        (messages, continuation) = AsyncStream.makeStream(of: String.self, bufferingPolicy: .unbounded)
        task.resume()
        receive()
    }

    func send(_ obj: [String: Any]) {
        task.send(.string(Realtime.json(obj))) { [weak self] error in
            if let error { self?.noteError(error.localizedDescription) }
        }
    }

    func close() {
        task.cancel(with: .normalClosure, reason: nil)
        continuation.finish()
        resolveReady(false)
    }

    func waitForReady() async -> Bool {
        await withCheckedContinuation { c in
            let state: Bool? = lock.withLock {
                if _ready { return true }
                if _firstError != nil { return false }
                readyWaiters.append(c); return nil
            }
            if let state { c.resume(returning: state) }
        }
    }

    private func receive() {
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                var text: String?
                switch message {
                case .string(let s): text = s
                case .data(let d): text = String(data: d, encoding: .utf8)
                @unknown default: break
                }
                if let text {
                    let event = Realtime.parse(text)
                    if event == .sessionReady { self.resolveReady(true) }
                    if case .error(let m) = event, !self.isReady { self.noteError(m) }
                    self.continuation.yield(text)
                }
                self.receive()
            case .failure(let error):
                self.noteError(error.localizedDescription)
                self.continuation.finish()
            }
        }
    }

    private var isReady: Bool { lock.withLock { _ready } }

    private func noteError(_ m: String) {
        lock.withLock { if _firstError == nil { _firstError = m } }
        resolveReady(false)
    }

    private func resolveReady(_ ok: Bool) {
        let waiters: [CheckedContinuation<Bool, Never>] = lock.withLock {
            if ok { _ready = true }
            let w = readyWaiters; readyWaiters = []; return w
        }
        waiters.forEach { $0.resume(returning: ok) }
    }
}

/// DEBUG-only diagnostics (event kinds and errors; never audio or transcripts).
func rtLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    NSLog("[RT] %@", message())
    #endif
}

/// Nutmeg's on-device pitch shaping (D7, revised in conversation-voice.md).
struct VoiceShape: Equatable {
    var method: Realtime.PitchMethod = Realtime.defaultPitchMethod
    var cents: Double = Realtime.defaultPitchCents
    var rate: Double = Realtime.defaultVarispeedRate
}
