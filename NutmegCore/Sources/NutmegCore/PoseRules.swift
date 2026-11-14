import Foundation

/// Nutmeg's body poses and when she uses them (decision mascot-nutmeg.md, 2026-11-13 update).
/// IDLE is the resting default (also for listening and talking). Wave, point and celebrate are brief gestures:
/// pop in, hold, pop back to the base pose. Sit is only the step-back nap; coloring only while generating.
public enum PoseName: String, CaseIterable, Sendable {
    case idle, wave, point, celebrate, sit, coloring
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
    public static func base(napping: Bool, coloring: Bool) -> PoseName {
        if napping { return .sit }
        if coloring { return .coloring }
        return .idle
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
    /// The coloring pose appears ONLY during a planning beat or while the kit is being made (planning-beats.md,
    /// no-text-overlays.md). Everything else (including the start of the conversation) rests in idle.
    public static func isColoring(phase: Phase, planningBeat: Bool, kitBeat: PTStageDirector.KitBeat) -> Bool {
        if planningBeat { return true }
        switch phase {
        case .makingKit, .kitReady: return kitBeat == .coloring
        default: return false
        }
    }
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
