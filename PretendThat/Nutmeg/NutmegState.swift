import SwiftUI

/// What Nutmeg is doing right now (app state). Napping is the step-back screen; oops is an error.
enum NutmegState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, talking, excited, oops, napping
    var id: String { rawValue }

    /// Art contract mapping (Haylee, 2026-11-13): state → pose, face, ears.
    /// Talking keeps the current pose; the caller passes it in.
    func look(talkingPose: NutmegPose = .wave) -> NutmegLook {
        switch self {
        case .idle: NutmegLook(pose: .wave, face: .happy, ears: .normal)
        case .listening: NutmegLook(pose: .point, face: .listening, ears: .perked)
        case .thinking: NutmegLook(pose: .wave, face: .thinking, ears: .normal)
        case .talking: NutmegLook(pose: talkingPose, face: .talking, ears: .normal)
        case .excited: NutmegLook(pose: .celebrate, face: .yay, ears: .perked)
        case .oops: NutmegLook(pose: .wave, face: .oops, ears: .flop)
        case .napping: NutmegLook(pose: .sit, face: .nap, ears: .normal)
        }
    }
}

/// Headless body poses. Each defines where the shared head sits (unit coords on the body canvas),
/// how it tilts and how big it is. Placeholder values; tune after Haylee's Figma export.
enum NutmegPose: String, CaseIterable, Identifiable {
    case wave, point, celebrate, sit
    var id: String { rawValue }
    var asset: String { "nutmeg-body-\(rawValue)" }

    var neckAnchor: UnitPoint {
        switch self {
        case .wave, .point: UnitPoint(x: 0.5, y: 0.625)
        case .celebrate: UnitPoint(x: 0.5, y: 0.62)
        case .sit: UnitPoint(x: 0.5, y: 0.685)
        }
    }
    var headRotation: Double {
        switch self { case .wave: 0; case .point: 4; case .celebrate: 0; case .sit: -6 }
    }
    var headScale: CGFloat {
        switch self { case .wave, .point: 0.70; case .celebrate: 0.72; case .sit: 0.68 }
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
    var pose: NutmegPose
    var face: NutmegFace
    var ears: NutmegEars
    var mouth: NutmegMouth { face.fixedMouth ?? .closed }
}
