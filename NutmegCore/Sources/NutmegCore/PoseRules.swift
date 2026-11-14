import Foundation

/// Nutmeg's body poses and when she uses them (decision mascot-nutmeg.md, 2026-11-13 update).
/// IDLE is the resting default (also for listening and talking). Wave, point and celebrate are brief gestures:
/// pop in, hold, pop back to the base pose. Sit is only the step-back nap. clipboardBoth (round 3): the clipboard held
/// in front with both hands while she says she's making the kit and while it generates. Round 5: the WRITING moment
/// (every planning beat and the kit) also rests in clipboardBoth; the old coloring body is retired.
public enum PoseName: String, CaseIterable, Sendable {
    case idle, wave, point, celebrate, sit, coloring, clipboardBoth
}

public enum NutmegGesture: String, Sendable { case wave, point, celebrate
    public var pose: PoseName { PoseName(rawValue: rawValue)! }
}

public enum PoseRules {
    /// Minimum time between two body swaps, so she never flickers.
    public static let minSwapInterval: TimeInterval = 1.5
    /// How long a gesture is held before popping back.
    public static func hold(_ g: NutmegGesture) -> TimeInterval {
        switch g { case .wave: 1.6; case .point: 2.0; case .celebrate: 1.2 }
    }

    /// The resting pose for what's happening (never a gesture).
    public static func base(napping: Bool, coloring: Bool, clipboard: Bool = false) -> PoseName {
        if napping { return .sit }
        if coloring || clipboard { return .clipboardBoth }   // round 5: writing = clipboardBoth + crayon top + focus face
        return .idle
    }

    /// Kit step (round 3, Haylee): from "Let me make your coloring pages!" (finish_planning → makingKit) until the
    /// WHOLE kit is final she holds the clipboard in front with both hands (whole pose, pop swap; thinking/happy faces
    /// and blinks ride on top). She pops back to idle when she looks up for the paper reveal. The swap throttle
    /// (`minSwapInterval`) keeps the pose on screen at least that long even when the kit is instant.
    public static func holdsClipboard(phase: Phase, kitBeat: PTStageDirector.KitBeat) -> Bool {
        (phase == .makingKit || phase == .kitReady) && kitBeat == .coloring
    }

    /// Delay before a swap requested at `now` may happen, given the last swap time.
    public static func delay(lastSwap: Date?, now: Date) -> TimeInterval {
        guard let lastSwap else { return 0 }
        return max(0, minSwapInterval - now.timeIntervalSince(lastSwap))
    }

    /// Gestures only play over the idle rest pose (not while napping or coloring).
    public static func allowsGesture(over base: PoseName) -> Bool { base == .idle }
}

extension PoseRules {
    /// The WRITING moment (Haylee, round 5; replaces the coloring approach): EVERY time she plans (roles after the
    /// player count, each next prop, the kit) she writes on the clipboard for a short beat: clipboardBoth, focus face,
    /// a close shot of her head and the clipboard top (hands out of frame), the crayon's top end wiggling above the
    /// clipboard edge, a soft scribble sound. Everything else (including the start of the conversation) rests in idle.
    public static func isWriting(phase: Phase, planningBeat: Bool, kitWriting: Bool) -> Bool {
        if planningBeat { return true }
        switch phase {
        case .makingKit, .kitReady: return kitWriting
        default: return false
        }
    }
    /// Shortest writing beats (seconds): a planning beat never feels like a flicker; the kit writes a little longer.
    public static let minPlanningBeat: TimeInterval = 1.8, minKitWriting: TimeInterval = 3.2
}

/// Resting motion (motion-and-surface.md) as plain numbers, so it can be checked: subtle breathing and a blink at a
/// pseudo-random moment in every 5.5 s window.
public enum IdleMotion {
    static func noise(_ n: Double, _ salt: Double) -> Double {
        abs((sin(n * 12.9898 + salt * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1))
    }
    /// Body breathing scale (1 ± 1.2%).
    public static func breathe(_ t: Double, napping: Bool = false, reduced: Bool = false) -> Double {
        1 + 0.012 * sin(t * 2 * .pi / (napping ? 4.5 : 3.5)) * (reduced ? 0.5 : 1)
    }
    /// Eyes closed right now (a 130 ms blink once per 5.5 s window).
    public static func blink(_ t: Double) -> Bool {
        let c = floor(t / 5.5)
        return abs(t - c * 5.5 - (0.5 + noise(c, 1) * 4.5)) < 0.065
    }
}
