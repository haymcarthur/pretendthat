import AVFoundation

/// The writing moment's soft crayon scribble (round 5): a tiny bundled loop (tools/make_scribble.py, filtered noise
/// bursts), quiet, and ducked further under Nutmeg's voice. It plays through the app's current audio session (the
/// Realtime conversation's when live), so it never reconfigures audio.
@MainActor
final class ScribbleSound {
    private var player: AVAudioPlayer?
    private var fade: Task<Void, Never>?
    static let volume: Float = 0.16, ducked: Float = 0.05

    func setPlaying(_ on: Bool, ducked: Bool) {
        if on {
            if player == nil, let url = Bundle.main.url(forResource: "scribble", withExtension: "wav") {
                player = try? AVAudioPlayer(contentsOf: url)
                player?.numberOfLoops = -1
                player?.volume = 0
                player?.prepareToPlay()
            }
            fade?.cancel()
            guard let player else { return }
            if !player.isPlaying { player.currentTime = Double.random(in: 0..<player.duration); player.play() }
            player.setVolume(ducked ? Self.ducked : Self.volume, fadeDuration: 0.15)
        } else if let player, player.isPlaying {
            player.setVolume(0, fadeDuration: 0.2)
            fade?.cancel()
            fade = Task { @MainActor [weak player] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled else { return }
                player?.stop()
            }
        }
    }
}
