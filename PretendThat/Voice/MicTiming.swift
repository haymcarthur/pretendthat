import Foundation
import QuartzCore

/// Round 31: the mic press timing (DEBUG log only, no audio and no words): touch-down → the listening look on screen,
/// and touch-down → the first captured audio buffer. Thread-safe (the audio tap reports from the audio thread).
enum MicTiming {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var touchHost: CFTimeInterval = 0
    nonisolated(unsafe) private static var visibleLogged = false
    nonisolated(unsafe) private static var audioLogged = false

    /// The touch event's own timestamp (DragGesture.Value.time: the UITouch timestamp, seconds of system uptime, on the
    /// same clock as CACurrentMediaTime), at the first gesture callback.
    static func touchDown(event: Date) { touchDown(host: event.timeIntervalSinceReferenceDate) }
    /// Round 31: the UITouch timestamp itself (system uptime seconds = CACurrentMediaTime's clock).
    static func touchDown(host eventHost: Double) {
        let now = CACurrentMediaTime()
        let t0 = (now - eventHost >= 0 && now - eventHost < 2) ? eventHost : now
        lock.withLock { touchHost = t0; visibleLogged = false; audioLogged = false }
        rtLog(String(format: "MIC touch-down: gesture callback %.1f ms after the touch event", (now - t0) * 1000))
    }

    /// The listening look was inserted into the view tree (onAppear), and again after the frame was committed.
    static func visible() {
        let start: CFTimeInterval? = lock.withLock { () -> CFTimeInterval? in
            guard touchHost > 0, !visibleLogged else { return nil }
            visibleLogged = true; return touchHost
        }
        guard let start else { return }
        let inserted = (CACurrentMediaTime() - start) * 1000
        // The next display refresh after the insert: when that frame is on screen.
        MainActor.assumeIsolated {
            NextFrame.after { shown in
                rtLog(String(format: "MIC touch→visible: %.1f ms (view inserted), %.1f ms (next frame on screen)", inserted, (shown - start) * 1000))
            }
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

/// One display-link tick: calls back at the next display refresh with its target time (round 31: the mic press work
/// waits for the frame that shows the listening look; also the press timing log).
@MainActor final class NextFrame: NSObject {
    private var link: CADisplayLink?
    private var done: ((Double) -> Void)?
    private static var live: [NextFrame] = []
    static func after(_ done: @escaping (Double) -> Void) {
        let f = NextFrame(); f.done = done
        f.link = CADisplayLink(target: f, selector: #selector(tick(_:)))
        f.link?.add(to: .main, forMode: .common)
        live.append(f)
        // No refresh comes when nothing is on a display (a headless simulator, a covered screen): never wait > 1 frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(17)) { f.fire(CACurrentMediaTime()) }
    }
    @objc private func tick(_ link: CADisplayLink) { fire(link.targetTimestamp) }
    private func fire(_ time: Double) {
        link?.invalidate(); link = nil
        guard let done else { return }
        self.done = nil
        done(time)
        NextFrame.live.removeAll { $0 === self }
    }
}
