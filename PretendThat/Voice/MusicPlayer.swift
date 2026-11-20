import AVFoundation
import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md): the one scene's background music. Each music
/// family is three segments (a calm loop, a tense loop, a win ending; 2026-11-21: plus calm2, a second calm loop that
/// takes turns with calm at each loop end, scheduled on the device clock) plus ONE shared event chime, bundled under
/// Resources/Music/ (see its README.md). Calm and tense loop seamlessly and crossfade at event boundaries; the music
/// ducks about −12 dB under Nutmeg's voice and the chime (`MusicMix`).
///
/// The same approach as the writing moment's scribble (`ScribbleSound`): plain `AVAudioPlayer`s that play through the
/// app's CURRENT audio session. It never configures or activates the session, never touches Nutmeg's speaker engine
/// (`NutmegSpeaker` / `SpeakerGraph`) and never touches the microphone input, so it can't fight her voice or undo the
/// voice-stall fixes (decisions/2026-11-20-voice-stall-fix.md).
///
/// Missing files are fine: a segment with no file is silent (the scene clock and the events still run). Today the
/// folder holds tiny PLACEHOLDER tones (tools/make_placeholder_music.py) until the real AI-made music is bundled.
@MainActor
final class MusicPlayer {
    private(set) var family: MusicFamily?
    private var players: [BeatMusic: AVAudioPlayer] = [:]
    private var chime: AVAudioPlayer?
    /// The segment that should be playing (silent when none is).
    private(set) var segment: BeatMusic = .silent
    private var ducked = false
    /// 2026-11-21 (Haylee): the music pill's off switch. The loops keep running silently (so turning it back on picks
    /// up the right segment in place); the chime is a separate player and still plays.
    private var muted = false
    private var paused = false
    /// The segment's player was sounding when ⏸ Pause came (a win ending that already finished isn't replayed).
    private var wasPlaying = false
    private var stopTasks: [BeatMusic: Task<Void, Never>] = [:]
    /// 2026-11-21 (Haylee): calm + calm2 take turns (`CalmLoop`). `players[.calm]` is always the calm loop sounding
    /// now; `calmPlayers` holds both in file order (empty or one: a plain looping calm, as before).
    private var calmPlayers: [AVAudioPlayer] = []
    private var calmLoop = CalmLoop(count: 1)
    /// Device time (`deviceCurrentTime`) when the calm loop sounding now ends, when known.
    private var calmEnd: TimeInterval?
    /// The next calm loop is scheduled to start at this device time (`play(atTime:)`).
    private var calmQueuedAt: TimeInterval?
    /// Not before this device time does a calm loop that isn't playing count as stopped by the system (a fresh
    /// `play(atTime:)` takes a moment to report it's playing).
    private var calmSettlesAt: TimeInterval = 0
    /// The calm loops alternate (calm2 is bundled).
    private var calmChain: Bool { calmPlayers.count == 2 }
    /// How far ahead a (re)started calm loop is scheduled, so its start time is known exactly.
    private static let calmLead: TimeInterval = 0.05

    /// At least one segment of this family is bundled.
    var hasMusic: Bool { !players.isEmpty }

    /// The family's segments, ready to play (each one that exists in the bundle).
    func prepare(_ family: MusicFamily) {
        guard self.family != family || players.isEmpty else { return }
        stop()
        self.family = family
        players = [:]
        calmPlayers = []
        for seg in [BeatMusic.calm, .tense, .win] {
            guard let url = Self.url(MusicMix.file(family, seg)), let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.numberOfLoops = MusicMix.loops(seg) ? -1 : 0
            p.volume = 0
            p.prepareToPlay()
            players[seg] = p
        }
        // 2026-11-21: with calm2 bundled, the two calm loops each play once through and hand over at the loop end.
        if let a = players[.calm], let url = Self.url(MusicMix.calm2(family)), let b = try? AVAudioPlayer(contentsOf: url) {
            a.numberOfLoops = 0
            b.numberOfLoops = 0
            b.volume = 0
            b.prepareToPlay()
            calmPlayers = [a, b]
        } else if let a = players[.calm] {
            calmPlayers = [a]
        }
        calmLoop = CalmLoop(count: calmPlayers.count)
        if chime == nil, let url = Self.url(MusicMix.chime) {
            chime = try? AVAudioPlayer(contentsOf: url)
            chime?.prepareToPlay()
        }
        rtLog("music: \(family.rawValue) (\(players.count) of 3 segments\(calmChain ? " + calm2" : "")\(chime == nil ? ", no chime" : "")\(players.isEmpty ? ": silent" : ""))")
    }

    /// "Music/space-adventure/calm.m4a" in the app bundle (the Music folder is a folder reference, so it keeps its
    /// sub-folders).
    static func url(_ path: String?) -> URL? {
        guard let path else { return nil }
        let ns = path as NSString
        let name = (ns.lastPathComponent as NSString).deletingPathExtension
        return Bundle.main.url(forResource: name, withExtension: ns.pathExtension, subdirectory: ns.deletingLastPathComponent)
    }

    /// The level for the playing segment now (ducked under her voice or the chime).
    private var level: Float { MusicMix.gain(speaking: ducked, chime: false, muted: muted) }

    /// Music off / on (a short ramp).
    func setMuted(_ on: Bool) {
        guard on != muted else { return }
        muted = on
        if !paused { players[segment]?.setVolume(level, fadeDuration: MusicMix.duckRamp); syncQueuedCalm() }
    }

    /// Switches to `seg` with a crossfade (the win ending starts from its beginning; a loop keeps its place).
    func play(_ seg: BeatMusic) {
        guard !paused else { return }
        if seg == segment {
            if seg == .calm && calmChain { tendCalm(); return }
            // Review: a loop the system stopped (an audio interruption, a session change by the voice) comes back on the
            // next tick. Only loops: the win ending plays once.
            if MusicMix.loops(seg), let p = players[seg], !p.isPlaying { p.play(); p.setVolume(level, fadeDuration: MusicMix.duckRamp) }
            return
        }
        let old = segment
        segment = seg
        if old == .calm { cancelQueuedCalm() }   // the calm loop sounding now fades; nothing takes over after it
        if let o = players[old] { fadeOut(o, key: old) }
        guard let p = players[seg] else { return }
        stopTasks[seg]?.cancel(); stopTasks[seg] = nil
        if seg == .win { p.currentTime = 0 }
        if seg == .calm && calmChain {
            if !p.isPlaying { p.volume = 0; startCalm(p) }
            p.setVolume(level, fadeDuration: MusicMix.crossfade)
            tendCalm()
            return
        }
        if !p.isPlaying { p.volume = 0; p.play() }
        p.setVolume(level, fadeDuration: MusicMix.crossfade)
    }

    // MARK: calm → calm2 → calm… (2026-11-21, Haylee)

    /// Starts (or restarts, from where it is) the calm loop `p` on the device clock, so its end time is exact.
    private func startCalm(_ p: AVAudioPlayer) {
        let start = p.deviceCurrentTime + Self.calmLead
        calmEnd = CalmLoop.endTime(startedAt: start, duration: p.duration, position: p.currentTime)
        calmSettlesAt = start + 0.25
        _ = p.play(atTime: start)
    }

    /// Called on every tick while calm sounds: hands over to the next loop once its start time has passed, restarts a
    /// loop the system stopped, and keeps the next loop scheduled for the exact moment the current one ends.
    private func tendCalm() {
        guard calmChain, segment == .calm, !paused, let cur = players[.calm] else { return }
        let now = cur.deviceCurrentTime
        if let at = calmQueuedAt {
            if now < at - 0.3 {
                // The switch is a while away: fall through (restart a stopped loop, keep the queue).
            } else if now < at {
                return   // the switch is a moment away: leave both players alone
            } else {
                // The next loop took over exactly at `at`.
                let next = calmPlayers[calmLoop.next]
                calmLoop.advance()
                players[.calm] = next
                calmEnd = CalmLoop.endTime(startedAt: at, duration: next.duration, position: 0)
                calmSettlesAt = at + 0.25
                calmQueuedAt = nil
                if cur.isPlaying { cur.stop() }   // it has reached its end (only its silent tail could be left)
                cur.currentTime = 0               // ready for its next turn
            }
        }
        guard let live = players[.calm] else { return }
        if !live.isPlaying && now > calmSettlesAt {
            // An audio interruption (or a session change by the voice) stopped it: it comes back where it was.
            cancelQueuedCalm()
            if live.duration - live.currentTime < 0.05 { live.currentTime = 0 }
            startCalm(live)
            live.setVolume(level, fadeDuration: MusicMix.duckRamp)
        }
        if calmQueuedAt == nil, let end = calmEnd {
            let next = calmPlayers[calmLoop.next]
            next.stop()
            next.currentTime = 0
            next.volume = level
            next.prepareToPlay()
            if next.play(atTime: end) { calmQueuedAt = end }
        }
    }

    /// The scheduled next calm loop is called off (calm fades, ⏸ Pause, a restart, the scene ends).
    private func cancelQueuedCalm() {
        guard calmChain else { return }
        if calmQueuedAt != nil {
            let next = calmPlayers[calmLoop.next]
            next.stop()
            next.currentTime = 0
            next.volume = 0
        }
        calmQueuedAt = nil
    }

    /// The scheduled next calm loop starts at the level the music has now (ducked, muted or full).
    private func syncQueuedCalm() {
        guard calmChain, calmQueuedAt != nil, segment == .calm else { return }
        calmPlayers[calmLoop.next].volume = level
    }

    private func fadeOut(_ p: AVAudioPlayer, key: BeatMusic) {
        p.setVolume(0, fadeDuration: MusicMix.crossfade)
        stopTasks[key]?.cancel()
        stopTasks[key] = Task { @MainActor [weak self, weak p] in
            try? await Task.sleep(for: .seconds(MusicMix.crossfade + 0.1))
            guard !Task.isCancelled, let self, self.segment != key else { return }
            p?.pause()
        }
    }

    /// Ducks (her voice, the chime) or comes back up, on a short ramp.
    func setDucked(_ on: Bool) {
        guard on != ducked else { return }
        ducked = on
        if !paused { players[segment]?.setVolume(level, fadeDuration: MusicMix.duckRamp); syncQueuedCalm() }
    }

    /// The shared event chime (the music is ducked around it by the caller).
    func playChime() {
        guard !paused, let c = chime else { return }
        c.currentTime = 0
        c.volume = 0.8
        c.play()
    }

    /// ⏸ Pause: everything stops where it is.
    func pause() {
        if segment == .calm { tendCalm() }   // a hand-over that just happened is counted first
        paused = true
        wasPlaying = players[segment]?.isPlaying ?? false
        cancelQueuedCalm()   // the next calm loop is scheduled again on ▶ Resume
        calmEnd = nil
        for t in stopTasks.values { t.cancel() }
        stopTasks = [:]
        for p in players.values where p.isPlaying { p.pause() }
        chime?.stop()
    }

    /// ▶ Resume: the segment that was playing goes on.
    func resume() {
        guard paused else { return }
        paused = false
        guard let p = players[segment], wasPlaying || MusicMix.loops(segment) else { return }
        p.volume = 0
        if segment == .calm && calmChain {
            startCalm(p)
            p.setVolume(level, fadeDuration: MusicMix.duckRamp)
            tendCalm()
            return
        }
        p.play()
        p.setVolume(level, fadeDuration: MusicMix.duckRamp)
    }

    /// The scene ended (or the game was left): silence, ready for the next scene.
    func stop() {
        for t in stopTasks.values { t.cancel() }
        stopTasks = [:]
        for p in players.values { p.stop(); p.currentTime = 0 }
        for p in calmPlayers { p.stop(); p.currentTime = 0; p.volume = 0 }
        // The next scene starts with calm again.
        calmQueuedAt = nil
        calmEnd = nil
        calmLoop.reset()
        if let a = calmPlayers.first { players[.calm] = a }
        chime?.stop()
        segment = .silent
        paused = false
        ducked = false
    }
}
