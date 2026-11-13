import SwiftUI

import NutmegCore

/// What Nutmeg is doing right now (app state). Napping is the step-back screen; oops is an error;
/// coloring is the kit/checklist wait (D6).
enum NutmegState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, talking, excited, oops, napping, coloring
    var id: String { rawValue }

    /// Face and ears per state. The BODY pose is separate (decision mascot-nutmeg.md): idle is the resting default
    /// (also while listening and talking); wave/point/celebrate are brief gestures (`NutmegCue`); sit only for the
    /// nap; coloring only while generating.
    var look: NutmegLook {
        switch self {
        case .idle: NutmegLook(face: .happy, ears: .normal)
        case .listening: NutmegLook(face: .listening, ears: .perked)
        case .thinking: NutmegLook(face: .thinking, ears: .normal)
        case .talking: NutmegLook(face: .talking, ears: .normal)
        case .excited: NutmegLook(face: .yay, ears: .perked)
        case .oops: NutmegLook(face: .oops, ears: .flop)
        case .napping: NutmegLook(face: .nap, ears: .normal)
        case .coloring: NutmegLook(face: .happy, ears: .normal)
        }
    }

    /// The resting body pose for this state.
    var basePose: NutmegPose {
        NutmegPose(PoseRules.base(napping: self == .napping, coloring: self == .coloring))
    }
}

/// A one-shot gesture request. A new `id` replays it.
struct NutmegCue: Equatable {
    var gesture: NutmegGesture
    var id = UUID()
}

/// Headless body poses. Each defines where the shared head sits (unit coords on the body canvas),
/// how it tilts and how big it is. Placeholder values; tune after Haylee's Figma export.
enum NutmegPose: String, CaseIterable, Identifiable {
    case idle, wave, point, celebrate, sit, coloring
    var id: String { rawValue }
    var asset: String { "nutmeg-body-\(rawValue)" }
    init(_ name: PoseName) { self = NutmegPose(rawValue: name.rawValue)! }

    var neckAnchor: UnitPoint {
        switch self {
        case .idle, .wave, .point, .coloring: UnitPoint(x: 0.5, y: 0.625)
        case .celebrate: UnitPoint(x: 0.5, y: 0.62)
        case .sit: UnitPoint(x: 0.5, y: 0.685)
        }
    }
    var headRotation: Double {
        switch self { case .idle, .wave, .celebrate: 0; case .point: 4; case .sit: -6; case .coloring: 8 }
    }
    var headScale: CGFloat {
        switch self { case .idle, .wave, .point, .coloring: 0.70; case .celebrate: 0.72; case .sit: 0.68 }
    }
}

enum NutmegFace: String, CaseIterable {
    case happy, talking, listening, thinking, ooh, yay, oops, nap
    var asset: String { "nutmeg-face-\(rawValue)" }
    /// Faces with a built-in mouth; nil means "use the live/closed mouth".
    var fixedMouth: NutmegMouth? {
        switch self {
        case .yay: .wide
        case .ooh: .ooh
        case .thinking: .small
        case .nap: .closed
        case .oops: .small
        default: nil
        }
    }
}

enum NutmegEars: String, CaseIterable { case normal, perked, flop; var asset: String { "nutmeg-ears-\(rawValue)" } }

enum NutmegMouth: String, CaseIterable {
    case closed, small, open, wide, ooh
    var asset: String { "nutmeg-mouth-\(rawValue)" }
    /// Amplitude → mouth (spec C6). `ooh` sprinkles in for variety.
    static func forLevel(_ level: Float, oohBeat: Bool) -> NutmegMouth {
        if level < 0.08 { return .closed }
        if level < 0.25 { return .small }
        if oohBeat { return .ooh }
        return level < 0.5 ? .open : .wide
    }
}

struct NutmegLook: Equatable {
    var face: NutmegFace
    var ears: NutmegEars
    var mouth: NutmegMouth { face.fixedMouth ?? .closed }
}
