import Foundation
import QuartzCore

/// Round 31: the mic press timing (DEBUG log only, no audio and no words): touch-down → the listening look on screen,
/// and touch-down → the first captured audio buffer. Thread-safe (the audio tap reports from the audio thread).
enum MicTiming {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var touchAt: Date?
    nonisolated(unsafe) private static var touchHost: CFTimeInterval = 0
    nonisolated(unsafe) private static var visibleLogged = false
    nonisolated(unsafe) private static var audioLogged = false

    /// The touch event's own timestamp (DragGesture.Value.time), at the first gesture callback.
    static func touchDown(event: Date) {
        lock.withLock { touchAt = event; touchHost = CACurrentMediaTime(); visibleLogged = false; audioLogged = false }
        #if DEBUG
        rtLog(String(format: "MIC touch-down: gesture callback %.1f ms after the touch event", Date().timeIntervalSince(event) * 1000))
        #endif
    }

    /// The listening look was inserted into the view tree (onAppear), and again after the frame was committed.
    static func visible() {
        let start: Date? = lock.withLock { () -> Date? in
            guard let t = touchAt, !visibleLogged else { return nil }
            visibleLogged = true; return t
        }
        guard let start else { return }
        let inserted = Date().timeIntervalSince(start) * 1000
        DispatchQueue.main.async {
            let committed = Date().timeIntervalSince(start) * 1000
            rtLog(String(format: "MIC touch→visible: %.1f ms (view inserted), %.1f ms (frame committed)", inserted, committed))
        }
    }

    /// An audio buffer was captured for the kid's turn. `bufferHost` is when its first sample was captured
    /// (host seconds); a pre-roll buffer can start BEFORE the touch (negative).
    static func captured(bufferHost: CFTimeInterval?) {
        let (logged, host) = lock.withLock { () -> (Bool, CFTimeInterval) in
            let was = audioLogged; audioLogged = true; return (was, touchHost)
        }
        guard !logged, host > 0 else { return }
        let now = CACurrentMediaTime()
        let firstSample = bufferHost.map { ($0 - host) * 1000 }
        rtLog(String(format: "MIC touch→first captured audio: delivered +%.1f ms; its first sample at %@ ms",
                     (now - host) * 1000, firstSample.map { String(format: "%+.1f", $0) } ?? "?"))
    }
}
