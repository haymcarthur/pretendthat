import AVFoundation
import NutmegCore

/// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md): the one scene's background music. Each music
/// family is three segments (a calm loop, a tense loop, a win ending) plus ONE shared event chime, bundled under
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
    private var paused = false
    /// The segment's player was sounding when ⏸ Pause came (a win ending that already finished isn't replayed).
    private var wasPlaying = false
    private var stopTasks: [BeatMusic: Task<Void, Never>] = [:]

    /// At least one segment of this family is bundled.
    var hasMusic: Bool { !players.isEmpty }

    /// The family's segments, ready to play (each one that exists in the bundle).
    func prepare(_ family: MusicFamily) {
        guard self.family != family || players.isEmpty else { return }
        stop()
        self.family = family
        players = [:]
        for seg in [BeatMusic.calm, .tense, .win] {
            guard let url = Self.url(MusicMix.file(family, seg)), let p = try? AVAudioPlayer(contentsOf: url) else { continue }
            p.numberOfLoops = MusicMix.loops(seg) ? -1 : 0
            p.volume = 0
            p.prepareToPlay()
            players[seg] = p
        }
        if chime == nil, let url = Self.url(MusicMix.chime) {
            chime = try? AVAudioPlayer(contentsOf: url)
            chime?.prepareToPlay()
        }
        rtLog("music: \(family.rawValue) (\(players.count) of 3 segments\(chime == nil ? ", no chime" : "")\(players.isEmpty ? ": silent" : ""))")
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
    private var level: Float { MusicMix.gain(speaking: ducked, chime: false) }

    /// Switches to `seg` with a crossfade (the win ending starts from its beginning; a loop keeps its place).
    func play(_ seg: BeatMusic) {
        guard !paused else { return }
        if seg == segment {
            // Review: a loop the system stopped (an audio interruption, a session change by the voice) comes back on the
            // next tick. Only loops: the win ending plays once.
            if MusicMix.loops(seg), let p = players[seg], !p.isPlaying { p.play(); p.setVolume(level, fadeDuration: MusicMix.duckRamp) }
            return
        }
        let old = segment
        segment = seg
        if let o = players[old] { fadeOut(o, key: old) }
        guard let p = players[seg] else { return }
        stopTasks[seg]?.cancel(); stopTasks[seg] = nil
        if seg == .win { p.currentTime = 0 }
        if !p.isPlaying { p.volume = 0; p.play() }
        p.setVolume(level, fadeDuration: MusicMix.crossfade)
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
        if !paused { players[segment]?.setVolume(level, fadeDuration: MusicMix.duckRamp) }
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
        paused = true
        wasPlaying = players[segment]?.isPlaying ?? false
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
        p.play()
        p.setVolume(level, fadeDuration: MusicMix.duckRamp)
    }

    /// The scene ended (or the game was left): silence, ready for the next scene.
    func stop() {
        for t in stopTasks.values { t.cancel() }
        stopTasks = [:]
        for p in players.values { p.stop(); p.currentTime = 0 }
        chime?.stop()
        segment = .silent
        paused = false
        ducked = false
    }
}
