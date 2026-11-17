import AVFoundation
import Observation
import QuartzCore
import NutmegCore

/// Round D3a (design 2026-11-15-saved-games-replay-design.md §D4.4): Nutmeg's speaker, split out of `RealtimeSession`
/// with no behavior change. It owns PLAYING her voice; the session keeps the socket and the protocol and hands it audio.
/// - Engine: one AVAudioEngine, player node → pitch unit (Varispeed 1.20 by default, TimePitch or none for comparison)
///   → mixer, all at the 24 kHz mono play format (the Realtime output rate, so nothing is resampled before the mixer's
///   one conversion to the hardware rate). The mic shares the engine (push-to-talk), so `start` lets the session
///   install its tap on the input node.
/// - Lip sync: each buffer is analyzed as it is scheduled (`LipSyncAnalyzer`, 10 ms windows) and every window is
///   stamped with the moment it leaves the speaker (`SpeakerTimeline.place`); a 60 Hz main-actor clock feeds due
///   windows to `MouthShaper` and publishes `mouth` and `level`.
/// - Speaking state (`isSpeaking`, from `SpeakerTimeline`'s clock + tail) drives the poses, Doze, Repeat's busy state,
///   the cheers' wait, and the session's silence timer (`onFinishedSpeaking`).
/// - Barge-in: `cancel()` clears the player, the mouth and the clock at once (the session cancels the responses and
///   truncates her item at `heardMs`).
/// - App lines (`say`, round D3b): CLIP FIRST. A recorded clip of the line (the game's, or a bundled common line) plays
///   through the same `schedule` path in ~100 ms chunks, so it gets the same Varispeed 1.20 (the clip is stored before
///   Varispeed, so the pitch unit applies it exactly once), the same lip sync and the same barge-in `cancel()`. With no
///   clip, the line goes to the live voice (the session's `sayExactly`, recorded when asked). Offline on a replay
///   with no clip, the caller pauses on the line (the Wi-Fi note). Never the system voice.
/// - Pitch raise (voice pitch build, Haylee 2026-11-17): live audio goes through a streaming Signalsmith Stretch shifter
///   (+2 semitones, formants not preserved, `VoiceConfig.pitchShift`) BEFORE the player, so `queueMouth` and the
///   timeline see exactly what is heard. The shifter holds back ~60 ms (heard) at a line's start; `endOfLine()` (the
///   session's audio done, or the idle check when the queue runs dry) plays the rest; `cancel()` resets it so a cut
///   line never leaks into the next. Clips (raw coral takes stored before the shift) get exactly the same +2
///   (`ClipPitch.plan`, voice clips match 2026-11-17): no per-clip shift, outlier takes are re-recorded. 0 = no processing.
/// - Memory: the last app line she was given (Repeat's fallback, round 17).
/// The speaker itself stores nothing: buffers are played and dropped (the session's recorder keeps app lines only).
@Observable @MainActor
final class NutmegSpeaker {
    /// 0…1 loudness of her voice (the mouth envelope, coarsely updated).
    private(set) var level: Float = 0
    /// The mouth shape to show right now, in sync with what the speaker is playing.
    private(set) var mouth: MouthShape = .closed
    private(set) var isSpeaking = false
    /// The last app line she was given to say (round 17's Repeat fallback when there's no chat line).
    private var memory = LastLineMemory()
    var lastAppLine: String? { memory.line }
    func remember(_ line: String) { memory.remember(line) }

    /// Her audio is playing or still queued for the mouth (a kid turn stops it: `SpeechStop.kidTurnStops`).
    var hasAudioQueued: Bool { isSpeaking || !mouthQueue.isEmpty }
    /// The engine is running (audio arriving without it is dropped).
    var isRunning: Bool { engine != nil }
    /// The input node of the shared engine (DEBUG log only). nil on an output-only engine (never created there).
    var inputNode: AVAudioInputNode? { inputEnabled ? engine?.inputNode : nil }
    /// Round 35 prep: the engine was started WITH the mic's input node. The output-only start (onboarding clips before
    /// the Mic page) never touches `inputNode`, so iOS never asks for the microphone there.
    private(set) var inputEnabled = false

    /// She started speaking (the first buffer of a line).
    @ObservationIgnored var onStartedSpeaking: (@MainActor () -> Void)?
    /// Her audio really ended (the tail passed with nothing new queued).
    @ObservationIgnored var onFinishedSpeaking: (@MainActor () -> Void)?
    /// A buffer was scheduled: the host time its first sample is heard (the latency trace).
    @ObservationIgnored var onScheduled: (@MainActor (Double) -> Void)?

    /// Where her live app lines go (the Realtime session's `sayExactly`).
    @ObservationIgnored weak var live: (any NutmegLiveVoice)?
    /// Round D3b: the game's recorded clips (`ClipStore`) and the bundled common lines.
    @ObservationIgnored var clips: (any NutmegClipSource)?
    /// Round D3b: the app keeps the engine running between sessions (a replay plays clips offline, and a dropped
    /// session must not silence them). `stop()` from the session then only releases the mic tap.
    @ObservationIgnored var holdEngine = false
    /// A clip is playing (the pseudo-response a barge-in stops like live audio).
    private(set) var clipPlaying = false
    @ObservationIgnored private var clipEnd: Task<Void, Never>?

    @ObservationIgnored private var engine: AVAudioEngine?
    @ObservationIgnored private var player = AVAudioPlayerNode()
    @ObservationIgnored private var pitchUnit: AVAudioUnit?
    @ObservationIgnored private var shape = VoiceShape()
    @ObservationIgnored private var timeline = SpeakerTimeline(sampleRate: Realtime.sampleRate)
    @ObservationIgnored private var peak: Float = 0
    @ObservationIgnored private var configObserver: NSObjectProtocol?
    @ObservationIgnored private var routeObserver: NSObjectProtocol?
    @ObservationIgnored private var tailTask: Task<Void, Never>?
    @ObservationIgnored private var analyzer = LipSyncAnalyzer(sampleRate: Realtime.sampleRate)
    @ObservationIgnored private var shaper = MouthShaper()
    /// Analysis windows waiting for their moment (CACurrentMediaTime seconds), in order.
    @ObservationIgnored private var mouthQueue: [(time: Double, features: MouthFeatures)] = []
    @ObservationIgnored private var mouthClock: Task<Void, Never>?
    @ObservationIgnored private let playFormat = AVAudioFormat(standardFormatWithSampleRate: Realtime.sampleRate, channels: 1)!
    /// The live voice's streaming pitch shifter (nil when the shift is 0).
    @ObservationIgnored private var liveShifter: VoicePitchShifter?
    /// Flushes the live shifter when no audio came and the queue is about to run dry (a missed audio-done).
    @ObservationIgnored private var idleFlush: Task<Void, Never>?
    /// A clip still being shifted and fed to the player (cancelled by a barge-in).
    @ObservationIgnored private var clipFeed: Task<Void, Never>?

    /// Playback rate of the queued audio (Varispeed plays it faster), for timing when she stops talking.
    private var playbackRate: Double { shape.method == .varispeed ? shape.rate : 1 }

    init() {
        #if DEBUG
        shape.shift = Self.debugShift(shape.shift)
        #endif
        timeline.playbackRate = playbackRate
        makeLiveShifter()
    }

    #if DEBUG
    /// `-PTPitchShift N`: the live raise in semitones for this run (0 = today's voice, no processing; before/after captures).
    static func debugShift(_ shift: PitchShift) -> PitchShift {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PTPitchShift"), i + 1 < args.count, let st = Double(args[i + 1]) else { return shift }
        return PitchShift(semitones: st, preserveFormants: shift.preserveFormants)
    }
    #endif

    private func makeLiveShifter() {
        liveShifter = shape.shift.isOn
            ? VoicePitchShifter(semitones: shape.shift.semitones, formantSemitones: shape.shift.liveFormantSemitones, playbackRate: playbackRate)
            : nil
    }

    // MARK: App lines

    /// One of her fixed app lines (round D3b, §D4.4): a clip first when the game (or the bundle) has one; else the live
    /// voice, recorded when `record` (her app lines are; a safety steer isn't). Returns how it was said; on
    /// `.waitForNetwork` nothing was said and the caller pauses on the line (Haylee's answer 1).
    @discardableResult
    func say(_ line: String, thinking: Bool = false, echo: Bool = false, record: Bool = true, replay: Bool = false) -> LineRoute {
        let clip = clips?.clip(for: line)
        let route = LineRoute.choose(hasClip: clip != nil, live: live?.canSpeakLive ?? false, replay: replay, recordable: record)
        switch route {
        case .clip: playClip(clip!, echo: echo)
        case .live(let rec): live?.say(line, thinking: thinking, echo: echo, record: rec)
        case .waitForNetwork, .unavailable: break
        }
        return route
    }

    // MARK: Engine

    /// The voice shape for the next `start` (pitch method, cents, Varispeed rate).
    func configure(_ shape: VoiceShape) {
        var shape = shape
        #if DEBUG
        shape.shift = Self.debugShift(shape.shift)
        #endif
        let changed = shape != self.shape
        self.shape = shape
        timeline.playbackRate = playbackRate
        if changed { makeLiveShifter() }
        rtLog("speaker: pitch shift \(shape.shift)")
    }

    /// Round D3b: the engine for clips with no live session (a replay starting or offline). Same output chain.
    /// Round 35 prep: also the onboarding's clips (one playback path for every Nutmeg sound). Until the microphone is
    /// allowed the engine starts OUTPUT-ONLY (same session, same graph, never touches the input node, so nothing asks
    /// for the mic before the Mic page); the live session's `start` adds the input later.
    func startForClips() {
        guard engine == nil else { ensureRunning(); return }
        var withInput = AVAudioApplication.shared.recordPermission == .granted
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTClipsOutputOnly") { withInput = false }   // test the hand-over
        #endif
        do { try start(echoCancel: false, withInput: withInput) { _ in } ; rtLog("speaker: engine started for clips\(withInput ? "" : " (output only)")") }
        catch { rtLog("speaker: clip engine failed: \(error.localizedDescription)") }
    }

    /// Starts the audio session and the engine. `installInput` is the mic's tap on the shared engine's input node.
    /// `withInput: false` (clips before the mic is allowed): the same session and output chain, no input node.
    func start(echoCancel: Bool, withInput: Bool = true, installInput: (AVAudioInputNode) -> Void) throws {
        if let engine {
            // Round D3b: the engine is already running (clips on a replay): the session only adds its mic tap, so a
            // clip playing while the voice connects isn't cut.
            if inputEnabled {
                engine.inputNode.removeTap(onBus: 0)
                installInput(engine.inputNode)
                ensureRunning()
                return
            }
            guard withInput else { ensureRunning(); return }
            // Round 35 prep: an output-only engine (onboarding) gets the input by starting over with it (same session).
            let hold = holdEngine
            shutdown()
            holdEngine = hold
            rtLog("speaker: output-only engine restarted with the mic input")
        }
        // Round 35 prep: the ONE session setup (playAndRecord / default / speaker + A2DP, 48 kHz preferred before
        // activating, so the input starting doesn't renegotiate the hardware rate).
        try NutmegAudioSession.nutmeg.apply()
        let session = AVAudioSession.sharedInstance()

        let engine = AVAudioEngine()
        player = AVAudioPlayerNode()
        pitchUnit = makePitchUnit()
        engine.attach(player)
        if let pitchUnit { engine.attach(pitchUnit) }
        if withInput {
            let input = engine.inputNode   // withInput: the mic's node (an output-only start never creates it)
            // Echo cancellation is off (round 20: fixed default): voice processing also degrades the output path. The
            // mic gate keeps Nutmeg from hearing herself either way.
            if echoCancel { try? input.setVoiceProcessingEnabled(true) }
            wireOutput(engine)
            installInput(input)
        } else {
            wireOutput(engine)
        }
        inputEnabled = withInput
        engine.mainMixerNode.outputVolume = 1   // unity gain: PCM16 → float is already within ±1, no clipping
        #if DEBUG
        rtLog("AUDIOFMT session \(session.category.rawValue)/\(session.mode.rawValue) \(session.sampleRate) Hz (shared setup: \(NutmegAudioSession.nutmeg.isCurrent)); output hw \(engine.outputNode.outputFormat(forBus: 0).sampleRate), output in \(engine.outputNode.inputFormat(forBus: 0).sampleRate), mixer out \(engine.mainMixerNode.outputFormat(forBus: 0).sampleRate), input \(withInput ? "on" : "off (output only)")")
        Self.installOutputTaps(engine, player: player, playFormat: playFormat)
        ABCapture.shared.install(engine, player: player, playFormat: playFormat)
        #endif
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
                self.ensureRunning()
                self.player.play()
                #if DEBUG
                self.logFormats("after configuration change")
                #endif
            }
        }
        // Voice rate: a route change (headphones, AirPlay, Bluetooth) can change the output rate without a configuration
        // change on this engine; re-link mixer → output at the new hardware rate.
        routeObserver = NotificationCenter.default.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.relinkOutput("route change") }
        }
    }

    /// Re-links mixer → output when the hardware rate no longer matches the link (logged). Stops and restarts the engine
    /// around the re-link; the player's queue is kept (it's called with nothing queued, or on a route change).
    private func relinkOutput(_ moment: String) {
        guard let engine, let m = SpeakerGraph.linkMismatch(engine) else { return }
        let running = engine.isRunning
        if running { engine.pause() }
        SpeakerGraph.wire(engine, player: player, pitchUnit: pitchUnit)
        if running { try? engine.start(); player.play() }
        rtLog(String(format: "VOICEFMT relinked (%@): link %.0f → hardware %.0f (she'd have been heard at ×%.3f)",
                     moment, m.link, m.hardware, shape.rate * m.link / m.hardware))
    }

    /// Stops the engine (and the mic tap on it) and silences her. Round D3b: while the app holds the engine (a replay),
    /// the session's stop only releases the mic tap; `shutdown()` stops it for good.
    func stop() {
        if holdEngine, let engine {
            if inputEnabled { engine.inputNode.removeTap(onBus: 0) }
            return
        }
        shutdown()
    }

    func shutdown() {
        holdEngine = false
        if let configObserver { NotificationCenter.default.removeObserver(configObserver) }
        configObserver = nil
        if let routeObserver { NotificationCenter.default.removeObserver(routeObserver) }
        routeObserver = nil
        if let engine {
            if inputEnabled { engine.inputNode.removeTap(onBus: 0) }
            player.stop()
            engine.stop()
        }
        engine = nil
        inputEnabled = false
        silence()
    }

    #if DEBUG
    /// Voice-rate check: the session and hardware rates against the mixer → output link she's played through. If the
    /// hardware rate moved after the graph was wired, she's heard at 1.20 × link/hardware instead of 1.20.
    func logFormats(_ moment: String) {
        guard let engine else { return }
        let s = AVAudioSession.sharedInstance()
        let hw = engine.outputNode.outputFormat(forBus: 0).sampleRate, link = engine.outputNode.inputFormat(forBus: 0).sampleRate
        let inputRate = inputEnabled ? engine.inputNode.outputFormat(forBus: 0).sampleRate : 0
        let vp = inputEnabled && engine.inputNode.isVoiceProcessingEnabled
        rtLog(String(format: "VOICEFMT %@: session %@/%@ %.0f, output hw %.0f, mixer→output link %.0f, mixer out %.0f, input %.0f, vp %@ → heard ×%.3f",
                     moment, s.category.rawValue, s.mode.rawValue, s.sampleRate, hw, link, engine.mainMixerNode.outputFormat(forBus: 0).sampleRate,
                     inputRate, vp ? "on" : "off", shape.rate * (hw > 0 ? link / hw : 1)))
    }

    /// Round 25 (voice check): `-PTTapOut` writes what goes INTO the pitch unit (tmp/voice-in.caf, 24 kHz) and what the
    /// mixer sends to the speaker (tmp/voice-out.caf, hardware rate), to measure the effective rate and pitch.
    nonisolated static func installOutputTaps(_ engine: AVAudioEngine, player: AVAudioPlayerNode, playFormat: AVAudioFormat) {
        guard ProcessInfo.processInfo.arguments.contains("-PTTapOut") else { return }
        let dir = FileManager.default.temporaryDirectory
        let outFmt = engine.mainMixerNode.outputFormat(forBus: 0)
        let inFile = try? AVAudioFile(forWriting: dir.appendingPathComponent("voice-in.caf"), settings: playFormat.settings)
        let outFile = try? AVAudioFile(forWriting: dir.appendingPathComponent("voice-out.caf"), settings: outFmt.settings)
        player.installTap(onBus: 0, bufferSize: 4096, format: playFormat) { b, _ in try? inFile?.write(from: b) }
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4096, format: outFmt) { b, _ in try? outFile?.write(from: b) }
        rtLog("TAPOUT in=\(playFormat.sampleRate) out=\(outFmt.sampleRate) → \(dir.path)")
    }
    #endif

    /// Round 25: the pitch unit and the wiring live in `SpeakerGraph` (NutmegCore), locked by `SpeakerGraphTests`.
    private func makePitchUnit() -> AVAudioUnit? {
        SpeakerGraph.makePitchUnit(VoiceConfig(method: shape.method, rate: shape.rate, cents: shape.cents))
    }

    /// player → [pitch unit] → mixer at 24 kHz; mixer → output at the HARDWARE rate (round 25: the implicit link was
    /// 44.1 kHz on a 48 kHz session, so she was heard at ≈1.10 instead of 1.20).
    private func wireOutput(_ engine: AVAudioEngine) {
        SpeakerGraph.wire(engine, player: player, pitchUnit: pitchUnit)
    }

    /// Voice processing / route changes can stop the engine; restart it before scheduling audio.
    private func ensureRunning() {
        guard let engine, !engine.isRunning else { return }
        do { try engine.start(); rtLog("engine restarted") } catch { rtLog("engine restart failed: \(error.localizedDescription)") }
    }

    // MARK: Playback

    /// Live audio: one Realtime PCM16 24 kHz delta.
    func play(_ pcm16: Data) {
        ensureRunning()
        guard let liveShifter else {
            guard let buffer = SpeakerGraph.pcm16Buffer(pcm16) else { return }
            schedule(buffer)
            return
        }
        let shifted = liveShifter.process(ClipAudio.floats(pcm16))
        if !shifted.isEmpty { for b in SpeakerGraph.clipBuffers(shifted) { schedule(b) } }
        armIdleFlush()
    }

    /// The end of a live line (the session's response audio done): the shifter's held-back audio plays now.
    func endOfLine() {
        idleFlush?.cancel(); idleFlush = nil
        guard let liveShifter, !liveShifter.isIdle else { return }
        let tail = liveShifter.finish()
        guard !tail.isEmpty else { return }
        ensureRunning()
        for b in SpeakerGraph.clipBuffers(tail) { schedule(b) }
    }

    /// A safety net for a missed audio-done: when no new audio arrives before the queue runs dry, flush the line.
    /// (A flush mid-line only happens if the network stalls longer than what's queued, when she'd pause anyway.)
    private func armIdleFlush() {
        idleFlush?.cancel()
        let wait = max(0.15, timeline.speakingUntil.timeIntervalSinceNow - 0.03)
        idleFlush = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, let s = self.liveShifter, !s.isIdle else { return }
            rtLog("speaker: pitch shifter flushed by the idle check")
            self.endOfLine()
        }
    }

    /// The one playback path (live deltas now, recorded clips in D3b): speaking state, lip sync, the end check.
    private func schedule(_ buffer: AVAudioPCMBuffer) {
        // Track when the queued audio will end from the clock, not completion callbacks (an engine
        // reconfiguration can drop scheduled buffers without calling them back).
        // Voice rate: a line starting with nothing queued re-checks the mixer → output link against the hardware rate
        // (the mic's input, a route or a session change can move the hardware rate after the graph was wired).
        if !isSpeaking { relinkOutput("line start") }
        if timeline.willSchedule(frames: Int(buffer.frameLength), now: Date()) {
            isSpeaking = true; peak = 0; onStartedSpeaking?(); rtLog("speaking")
            #if DEBUG
            logFormats("speaking")
            #endif
        }
        queueMouth(buffer)
        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
        scheduleEndCheck()
    }

    /// Barge-in: the player is cleared and she stops at once (mouth closed, clock reset). A clip is just stopped (the
    /// stored clip is unchanged).
    func cancel() {
        let t0 = CACurrentMediaTime()
        let wasClip = clipPlaying
        resetShifters()   // nothing of the cut line is held back for the next one
        player.stop(); player.play()
        silence()
        if wasClip {
            let latency = AVAudioSession.sharedInstance().outputLatency + AVAudioSession.sharedInstance().ioBufferDuration
            rtLog(String(format: "CLIP cut: player cleared in %.1f ms (+ %.0f ms output latency)", (CACurrentMediaTime() - t0) * 1000, latency * 1000))
        }
    }

    // MARK: Clips (round D3b, §D4.4)

    /// A recorded line: float PCM 24 kHz (before Varispeed) fed in ~100 ms chunks into the ONE `schedule` path, so the
    /// pitch unit, lip sync, speaking state, end check and barge-in are exactly the live voice's.
    func playClip(_ clip: NutmegClip, echo: Bool) {
        if engine == nil { startForClips() }
        guard engine != nil, !clip.samples.isEmpty else { return }
        ensureRunning()
        live?.clipStarted(clip.text, echo: echo)
        clipPlaying = true
        // Voice clips match: a clip is a raw coral take like a live line, so it gets exactly the live processing.
        let plan = ClipPitch.plan(shape.shift)
        rtLog(String(format: "CLIP play %@ (%.1f s%@), pitch %.0f Hz raw → shift %+.2f st (same as live)", String(clip.key.prefix(8)),
                     Double(clip.samples.count) / Realtime.sampleRate, echo ? ", repeat" : "", clip.pitchHz ?? 0, plan.semitones))
        clipFeed?.cancel(); clipFeed = nil
        if plan.isOn {
            // The live shift (stored before Varispeed and before the raise): the first ~0.3 s now, the rest a chunk at
            // a time so a long scene line never blocks the main actor (the shifter runs hundreds of times real time).
            let shifter = VoicePitchShifter(plan, playbackRate: playbackRate)
            let chunks = ClipAudio.chunks(count: clip.samples.count)
            let first = min(3, chunks.count)
            for r in chunks[..<first] { scheduleSamples(shifter.process(Array(clip.samples[r]))) }
            let samples = clip.samples
            clipFeed = Task { [weak self] in
                for r in chunks[first...] {
                    await Task.yield()
                    guard let self, !Task.isCancelled else { return }
                    self.scheduleSamples(shifter.process(Array(samples[r])))
                }
                guard let self, !Task.isCancelled else { return }
                self.scheduleSamples(shifter.finish())
            }
        } else {
            for buf in SpeakerGraph.clipBuffers(clip.samples) { schedule(buf) }
        }
        clipEnd?.cancel()
        clipEnd = Task { [weak self] in
            while let self, self.isSpeaking, !Task.isCancelled { try? await Task.sleep(for: .milliseconds(50)) }
            self?.clipPlaying = false
        }
    }

    private func scheduleSamples(_ samples: [Float]) {
        guard !samples.isEmpty else { return }
        for b in SpeakerGraph.clipBuffers(samples) { schedule(b) }
    }

    private func resetShifters() {
        idleFlush?.cancel(); idleFlush = nil
        clipFeed?.cancel(); clipFeed = nil
        liveShifter?.reset()
    }

    /// Where a new conversation item's audio starts, in player samples.
    func itemStart() -> Double { timeline.itemStart(playerSample: playerSample()) }

    /// How much of the item starting at `itemStart` was actually heard, in ms (the truncate point).
    func heardMs(itemStart: Double) -> Int { timeline.heardMs(itemStart: itemStart, playerSample: playerSample()) }

    private func playerSample() -> Double? {
        if let render = player.lastRenderTime, render.isHostTimeValid, let pt = player.playerTime(forNodeTime: render) {
            return Double(pt.sampleTime)
        }
        return nil
    }

    private func silence() {
        resetShifters()
        clipEnd?.cancel(); clipPlaying = false
        timeline.clear(); tailTask?.cancel()
        isSpeaking = false; level = 0
        resetMouth()
    }

    private func scheduleEndCheck() {
        tailTask?.cancel()
        let wait = timeline.endCheckDelay()   // short tail so room echo dies before the mic reopens
        tailTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(wait))
            guard let self, !Task.isCancelled, self.timeline.hasFinished() else { return }
            self.timeline.finish()
            self.isSpeaking = false
            rtLog("done speaking, peak mouth level \(String(format: "%.2f", self.peak))")
            self.level = 0
            self.mouthQueue = []
            self.onFinishedSpeaking?()
        }
    }

    // MARK: Lip sync

    /// Analyzes a buffer as it is scheduled and stamps each window with when it will be heard.
    private func queueMouth(_ buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let frames = Int(buffer.frameLength)
        let audio = AVAudioSession.sharedInstance()
        let latency = audio.outputLatency + audio.ioBufferDuration
        // Where the player is now (source samples) and the host time of that sample.
        var now: (sample: Double, hostTime: Double)?
        if let render = player.lastRenderTime, render.isHostTimeValid, let pt = player.playerTime(forNodeTime: render) {
            now = (Double(pt.sampleTime), AVAudioTime.seconds(forHostTime: render.hostTime))
        }
        let base = timeline.place(frames: frames, player: now, hostNow: CACurrentMediaTime(), latency: latency)
        onScheduled?(base)   // when the first sample actually leaves the speaker
        let rate = playbackRate
        let features = analyzer.analyze(Array(UnsafeBufferPointer(start: data, count: frames)))
        mouthQueue.append(contentsOf: features.map { (base + $0.offset / rate, $0) })
        startMouthClock()
    }

    private func startMouthClock() {
        guard mouthClock == nil else { return }
        mouthClock = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard let self, self.tickMouth() else { break }
            }
            self?.mouthClock = nil
        }
    }

    /// Feeds due windows to the shaper; returns false once the voice has ended and the mouth is closed.
    private func tickMouth() -> Bool {
        let now = CACurrentMediaTime()
        var fed = false
        while let first = mouthQueue.first, first.time <= now {
            mouthQueue.removeFirst()
            shaper.step(first.features, at: first.time)
            fed = true
        }
        if !fed && mouthQueue.isEmpty {
            // Nothing playing: decay toward closed (silence windows).
            shaper.step(MouthFeatures(offset: 0, rms: 0, bright: 0, low: 0), at: now)
        }
        if mouth != shaper.shape { mouth = shaper.shape }
        let e = (shaper.envelope * 20).rounded() / 20
        if abs(e - level) >= 0.05 || (e == 0 && level != 0) { level = e; peak = max(peak, e) }
        return !(mouthQueue.isEmpty && shaper.shape == .closed && shaper.envelope < 0.01)
    }

    private func resetMouth() {
        mouthClock?.cancel(); mouthClock = nil
        mouthQueue = []
        analyzer.reset(); shaper.reset()
        mouth = .closed
    }
}

/// The live source of her app lines: the Realtime session's out-of-band `sayExactly` (round 13: one voice for every line).
@MainActor protocol NutmegLiveVoice: AnyObject {
    /// The live voice can say a line now (connected, not in the background).
    var canSpeakLive: Bool { get }
    /// `record` (round D3b): capture this line's audio; kept with the game only if it passes the transcript gate.
    func say(_ line: String, thinking: Bool, echo: Bool, record: Bool)
    /// A clip of `text` started playing (her chat bubble unless it's a Repeat; nothing in the conversation to truncate).
    func clipStarted(_ text: String, echo: Bool)
}

/// One recorded app line, float PCM 24 kHz mono, stored BEFORE Varispeed so it plays through the same pitch unit and
/// sounds exactly like her live voice (§D4.2, §D4.4).
struct NutmegClip: Sendable {
    let key: String
    let text: String
    let samples: [Float]
    /// A bundled common line (not this game's).
    var common = false
    /// Its measured raw median pitch (`PitchTracker`), logged only (clips get the live processing; nil = unmeasured).
    var pitchHz: Double?
}

/// The game's clips (`ClipStore`). `clip(for:)` is nil for a line she has never said.
@MainActor protocol NutmegClipSource: AnyObject {
    func clip(for line: String) -> NutmegClip?
}

/// Playing a clip through the speaker's one `schedule` path (~100 ms chunks), as a pseudo-response the round 19 stop
/// rules cancel like live audio.
@MainActor protocol NutmegClipPlayback: AnyObject {
    func playClip(_ clip: NutmegClip, echo: Bool)
}

extension NutmegSpeaker: NutmegClipPlayback {}
