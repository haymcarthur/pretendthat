import SwiftUI
import QuartzCore
import NutmegCore

// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md; build: decisions/2026-11-21-round-one-scene-build.md):
// the setup checklist (▶ Let's play! lights up when every card is done), ONE ~10 minute scene with music where Nutmeg
// calls out events at set moments (the pure timeline is NutmegCore's `BeatRun` + `BeatClock`), then the clean-up
// checklist (▶ The End lights up when everything is checked). During the scene the only buttons are the small ✕ and
// ⏸ Pause. The microphone stays off for the whole Play phase (`PlayMic`).

extension AppModel {
    // MARK: The setup / clean-up big button

    /// ▶ Let's play! (setup) / ▶ The End (clean-up). 2026-11-21 (Haylee): never grey. Pressed before everything is
    /// checked, the rows still unchecked are ticked one by one (a brief visual check-off), then it goes on.
    func tapOneSceneButton() {
        guard let kind = store.oneSceneChecklist, !oneSceneFinishing, case .scene(let i) = store.phase else { return }
        userAction(.nextScene)
        stopChecklistReading()
        let left = store.uncheckedRows
        rtLog("one scene: \(kind == .setup ? "Let's play!" : "The End") (tap\(left.isEmpty ? "" : ", checks the \(left.count) left"))")
        guard !left.isEmpty else { store.nextScene(); return }
        oneSceneFinishing = true
        Task { @MainActor [weak self] in
            // Review: always cleared, even when the game was left mid check-off (else the button stayed dead).
            defer { self?.oneSceneFinishing = false }
            for k in left {
                guard let self, case .scene(i) = self.store.phase else { return }
                if !self.store.isChecked(k) { _ = self.store.toggleCheck(k) }
                try? await Task.sleep(for: .milliseconds(140))
            }
            try? await Task.sleep(for: .milliseconds(350))   // the last check lands before the scene changes
            guard let self, case .scene(i) = self.store.phase else { return }
            self.store.nextScene()
        }
    }

    // MARK: The scene clock

    /// 1× normally; `-PTFastScene` (DEBUG) runs the whole 10 minute scene in about a minute.
    static var beatSpeed: Double {
        #if DEBUG
        if DemoDriver.fastScene { return BeatClock.fastSpeed }
        #endif
        return 1
    }

    /// The phase changed: the one scene opened (its clock starts; a resumed scene opens paused) or closed (it stops).
    func beatPhaseChanged() {
        if store.currentBeatScene != nil {
            if beatTask == nil { startBeatScene() }
        } else if beatTask != nil || beatRun != nil {
            endBeatScene()
        }
    }

    /// Starts the scene from `store.beatTime` (0 for a new scene; a relaunch resume restores it and opens paused, so
    /// the family starts it again when they're ready).
    func startBeatScene() {
        guard let b = store.currentBeatScene?.beats else { return }
        var run = BeatRun(events: b.events)
        let at = max(0, store.beatTime)
        if at > 0 { run.restore(elapsed: at) }
        beatRun = run
        beatClock = BeatClock(elapsed: at, speed: Self.beatSpeed)
        beatSavedAt = CACurrentMediaTime()
        music.prepare(b.music)
        music.setMuted(!musicOn)
        if at > 0 {
            scenePaused = true
        } else {
            scenePaused = false
            beatClock.start(now: CACurrentMediaTime())
        }
        rtLog("one scene: start at \(Int(at)) s, \(b.events.count) events, music \(b.music.rawValue)\(Self.beatSpeed > 1 ? " (fast clock)" : "")\(at > 0 ? ", paused (resumed)" : "")")
        publishBeat(run, at: at)
        updateIdleTimer()   // review: the screen stays awake while the scene runs (no auto-lock mid-scene)
        beatTask?.cancel()
        beatTask = Task { @MainActor [weak self] in
            while let self, !Task.isCancelled {
                self.beatTick()
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    /// The scene closed (clean-up opened, the game was left): the clock, her pending lines and the music stop.
    func endBeatScene() {
        beatTask?.cancel(); beatTask = nil
        beatLineTask?.cancel(); beatLineTask = nil
        beatRun = nil
        music.stop()
        scenePaused = false
        beatDisplay = .playing
        beatProgress = 0
        beatFiredEvents = 0
        updateIdleTimer()
    }

    /// One tick (4 a second): the cues that are due fire, the music follows the beat, the screen follows the clock.
    func beatTick() {
        guard store.currentBeatScene != nil, var run = beatRun else { return }
        let now = CACurrentMediaTime()
        if !scenePaused {
            let t = beatClock.elapsed(now: now)
            store.beatTime = t
            let due = run.due(at: t)
            beatRun = run
            for cue in due {
                fireBeat(cue, run: run)
                if store.currentBeatScene == nil { return }   // the clean-up opened
            }
            music.play(run.music(at: t))
            publishBeat(run, at: t)
            if now - beatSavedAt > 5 { beatSavedAt = now; saveResumePoint() }   // a relaunch resumes about here
        }
        music.setDucked(isSpeaking || now < beatChimeUntil)
    }

    /// The screen's numbers, set only when they change (so the stage doesn't redraw 4 times a second for nothing).
    private func publishBeat(_ run: BeatRun, at t: TimeInterval) {
        let d = run.display(at: t)
        if d != beatDisplay { beatDisplay = d }
        let p = (run.progress(at: t) * 300).rounded() / 300
        if p != beatProgress { beatProgress = p }
        let f = run.firedEvents(at: t)
        if f != beatFiredEvents { beatFiredEvents = f }
    }

    private func fireBeat(_ cue: BeatCue, run: BeatRun) {
        guard let b = store.currentBeatScene?.beats else { return }
        switch cue.kind {
        case .opener:
            sayBeat(b.opener, after: 0.4)
        case .event(let i):
            guard run.events.indices.contains(i) else { return }
            // The chime first (the music ducks around it), then her line (Haylee: kids learn the cue).
            music.playChime()
            // Review: ducked until her line can start (a live line takes a moment), so the music doesn't swell between.
            beatChimeUntil = CACurrentMediaTime() + 2.5
            rtLog("one scene: event \(i + 1)/\(run.events.count) (\(run.events[i].mood.rawValue), \(run.events[i].roles.map(\.rawValue).joined(separator: "+")))")
            sayBeat(run.events[i].line, after: 0.9)
        case .calmAgain(let i):
            guard run.events.indices.contains(i), let line = run.events[i].calmAgain else { return }
            sayBeat(line, after: 0.3, waitForQuiet: true)
        case .finale:
            rtLog("one scene: finale")
            gesture(.celebrate)
            celebrations += 1
            beatConfetti += 1
            sayBeat(b.finale, after: 0.6)
        case .cleanup:
            rtLog("one scene: the clean-up opens")
            stopChecklistReading()
            store.nextScene()
        }
    }

    /// Says one of the scene's lines (after a moment, and after anything she's still saying when asked), unless the
    /// scene was paused or left meanwhile. A newer line replaces one still waiting.
    private func sayBeat(_ line: String, after delay: Double = 0, waitForQuiet: Bool = false) {
        let phase = store.phase
        beatLineTask?.cancel()
        beatLineTask = Task { @MainActor [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            if waitForQuiet {
                var waited = 0
                while let s = self, s.isSpeaking, waited < 80, !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100)); waited += 1
                }
            }
            guard let self, !Task.isCancelled, !self.scenePaused, self.store.phase == phase else { return }
            self.speak(line)
        }
    }

    // MARK: Hear again, End scene, music on/off (2026-11-21, Haylee)

    /// The line on the card up now (the event's, or the calm-again's), if any.
    var beatCardLine: String? {
        guard let events = store.currentBeatScene?.beats?.events else { return nil }
        switch beatDisplay {
        case .event(let i): return events.indices.contains(i) ? events[i].line : nil
        case .calmAgain(let i): return events.indices.contains(i) ? events[i].calmAgain : nil
        case .playing, .finale: return nil
        }
    }

    /// 🔊 on the event / calm-again card: the same line again, so it plays this game's take (no new call). Nothing
    /// while she's already talking.
    func hearBeatAgain() {
        guard !scenePaused, !isSpeaking, let line = beatCardLine else { return }
        rtLog("one scene: hear again")
        speak(line)
    }

    /// "End scene" (the grown-up or the kids are done early): straight to the finale (celebrate, the win music), then
    /// the clean-up 20 s later, the same as the scheduled finale. The scene time jumps to the finale's, so a relaunch
    /// lands there too.
    func endSceneEarly() {
        let now = CACurrentMediaTime()
        // Review: at or past the finale it does nothing (it used to cut off her finale line).
        guard store.currentBeatScene != nil, var run = beatRun, beatClock.elapsed(now: now) < run.finaleAt else { return }
        let t = run.endEarly(at: beatClock.elapsed(now: now))
        beatRun = run
        beatLineTask?.cancel(); beatLineTask = nil
        userAction(.pauseScene)   // her current line stops (the finale line follows)
        beatClock = BeatClock(elapsed: t, speed: Self.beatSpeed)
        store.beatTime = t
        if scenePaused { scenePaused = false; music.resume() }
        beatClock.start(now: now)
        saveResumePoint()
        updateIdleTimer()
        rtLog("one scene: End scene (jumps to the finale at \(Int(t)) s)")
        beatTick()
    }

    /// The music pill's toggle: the background music off or on (her voice and the chime still play). A per-device
    /// choice, so the rest of this game, a resume and the next game keep it (not kid data).
    func toggleMusic() {
        musicOn.toggle()
        UserDefaults.standard.set(musicOn, forKey: MusicMix.musicOnKey)
        music.setMuted(!musicOn)
        rtLog("one scene: music \(musicOn ? "on" : "off")")
    }

    // MARK: Pause (Haylee: kids may want to pause; nothing to confirm a task)

    /// ⏸ Pause: the music, the scene clock and her speech stop; the "Paused" card shows with a big ▶ Resume.
    func pauseScene() {
        guard store.currentBeatScene != nil, !scenePaused else { return }
        let now = CACurrentMediaTime()
        beatClock.pause(now: now)
        store.beatTime = beatClock.elapsed(now: now)
        scenePaused = true
        beatLineTask?.cancel(); beatLineTask = nil
        userAction(.pauseScene)
        music.pause()
        saveResumePoint()
        updateIdleTimer()
        rtLog("one scene: paused at \(Int(store.beatTime)) s")
    }

    /// ▶ Resume: the scene goes on where it was (a line cut off by the pause isn't said again).
    func resumeScene() {
        guard store.currentBeatScene != nil, scenePaused else { return }
        scenePaused = false
        beatClock.start(now: CACurrentMediaTime())
        music.resume()
        updateIdleTimer()
        rtLog("one scene: resumed at \(Int(store.beatTime)) s")
    }

    // MARK: What the stage shows

    /// The event's or the calm-again card is up (Nutmeg moves aside for it; otherwise she's centered, whole body).
    var beatCardUp: Bool {
        guard store.currentBeatScene != nil, !scenePaused else { return false }
        switch beatDisplay {
        case .event, .calmAgain: return true
        case .playing, .finale: return false
        }
    }

    /// The music pill's tense look (between a tense event and its calm-again line).
    var beatTense: Bool {
        guard let run = beatRun, !scenePaused else { return false }
        return run.music(at: store.beatTime) == .tense
    }

    /// Her face follows the beat (Haylee): calm play = happy, gently bobbing to the music; a calm event = talking with
    /// perked ears; a tense event = alarmed (ooh + perked ears until the art exists); calm-again = phew (happy until
    /// the art exists); the finale = yay with the celebrate pose. Paused: plain happy, still.
    var beatState: NutmegState? {
        guard let scene = store.currentBeatScene else { return nil }
        if scenePaused { return .idle }
        switch beatDisplay {
        case .playing: return .grooving
        case .event(let i):
            let events = scene.beats?.events ?? []
            return events.indices.contains(i) && events[i].isTense ? .alarmed : .calling
        case .calmAgain: return .relieved
        case .finale: return .excited
        }
    }

    #if DEBUG
    /// Demo targets (`-PTDemo onePlaying | oneEvent | oneTense | oneCalmAgain | oneFinale | onePaused`): jump the scene
    /// to a moment (every cue before it counts as fired, so nothing is said for the jump).
    func debugJumpScene(to t: TimeInterval, paused: Bool = false) {
        guard store.currentBeatScene != nil, var run = beatRun else { return }
        run.restore(elapsed: t)
        beatRun = run
        beatClock = BeatClock(elapsed: t, speed: Self.beatSpeed)
        store.beatTime = t
        if paused {
            scenePaused = true
            music.pause()
        } else {
            beatClock.start(now: CACurrentMediaTime())
            music.play(run.music(at: t))
        }
        publishBeat(run, at: t)
        if case .finale = run.display(at: t) { gesture(.celebrate); beatConfetti += 1 }
    }
    #endif
}
