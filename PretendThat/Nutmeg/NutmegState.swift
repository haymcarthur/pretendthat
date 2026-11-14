import SwiftUI
import UIKit

import NutmegCore

/// What Nutmeg is doing right now (app state). Napping is the step-back screen; oops is an error;
/// coloring is the kit/checklist wait (D6).
enum NutmegState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, talking, excited, amazed, oops, napping, coloring
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
        case .amazed: NutmegLook(face: .ooh, ears: .perked)
        case .oops: NutmegLook(face: .oops, ears: .flop)
        case .napping: NutmegLook(face: .nap, ears: .normal)
        // Coloring (planning beats, kit): eyes down on the clipboard (focus art when it's imported, thinking until then).
        case .coloring: NutmegLook(face: NutmegFace.focusAvailable ? .focus : .thinking, ears: .normal)
        }
    }

    /// The resting body pose for this state.
    var basePose: NutmegPose {
        NutmegPose(PoseRules.base(napping: self == .napping, coloring: self == .coloring))
    }
    /// The resting pose with the kit step's clipboard hold (`PoseRules.holdsClipboard`).
    func basePose(holdingClipboard: Bool) -> NutmegPose {
        NutmegPose(PoseRules.base(napping: self == .napping, coloring: self == .coloring, clipboard: holdingClipboard))
    }
}

/// A one-shot gesture request. A new `id` replays it.
struct NutmegCue: Equatable {
    var gesture: NutmegGesture
    var id = UUID()
}

/// Body poses (Haylee's art, 2026-11-13). Every layer shares ONE 1178×1335 canvas: the bodies, head-base, faces and
/// mouths stack full-frame, so the head sits on each body at offset (0,0) by construction. Per pose the head can be
/// nudged (`headOffset`, canvas px) and tilted (`headRotation`) around the neck anchor; values tuned in the simulator.
enum NutmegPose: String, CaseIterable, Identifiable {
    case idle, wave, point, celebrate, sit, coloring, clipboardBoth
    var id: String { rawValue }
    var asset: String { self == .clipboardBoth ? "nutmeg-body-clipboard-both" : "nutmeg-body-\(rawValue)" }
    init(_ name: PoseName) { self = NutmegPose(rawValue: name.rawValue)! }

    static let canvas = CGSize(width: 1178, height: 1335)

    /// Neck plug center from the export manifest (canvas px → unit).
    var neckAnchor: UnitPoint {
        switch self {
        case .sit: UnitPoint(x: 600 / 1178, y: 793.5 / 1335)
        default: UnitPoint(x: 600 / 1178, y: 788 / 1335)
        }
    }
    /// Head nudge in canvas px (fix round 2, re-checked in round 3 with the new head-base and headset layer): the chin
    /// overlaps the shoulders by ~10–20 px on both sides at every pose with the state tilts (thinking −4°, oops −5°).
    /// Round 3 tried 0 (the new head and idle body come from one drawing), but a −4° thinking tilt opened a blue wedge
    /// between the chin and the vest, so the +12 nudge stays.
    var headOffset: CGSize {
        switch self {
        case .sit: CGSize(width: 0, height: 17)
        default: CGSize(width: 0, height: 12)
        }
    }
    /// The neck plug: a SMALL fur-colored oval behind the body, fully hidden under the chin and behind the vest (it must
    /// never reach past the shoulder outline; a wide one showed as a brown lump on the shoulders). The chin overlap
    /// itself comes from `headOffset`.
    static let neckPlug = CGRect(x: 600 - 80, y: 800 - 35, width: 160, height: 70)
    var headRotation: Double {
        switch self { case .idle, .wave, .celebrate, .clipboardBoth: 0; case .point: 3; case .sit: -4; case .coloring: 5 }
    }
}

enum NutmegFace: String, CaseIterable {
    case happy, talking, listening, thinking, ooh, yay, oops, nap, focus
    /// nutmeg-face-focus (eyes down at the clipboard) is new art; fall back until it's imported.
    static let focusAvailable = UIImage(named: "nutmeg-face-focus") != nil
    /// Eyes and brows (the face SVG minus its mouth; tools/import_art.py splits them).
    var asset: String { "nutmeg-face-\(rawValue)" }
    /// This face's own mouth, shown when Nutmeg isn't talking.
    var mouthAsset: String { "nutmeg-face-\(rawValue)-mouth" }
    /// Faces with a built-in mouth; nil means "use the live/closed mouth".
    var fixedMouth: NutmegMouth? {
        switch self {
        case .yay: .wide
        case .ooh: .ooh
        case .thinking: .small
        case .nap, .focus: .closed
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

extension NutmegPose {
    /// Her face center (eyes and nose) in canvas px for this pose: the rest-pose face center turned with the head
    /// around the neck anchor, plus the head nudge. The close-up camera centers this point (PTStageCamera).
    var faceFocus: CGPoint {
        let f = PTStageCamera.faceFocus
        let a = CGPoint(x: neckAnchor.x * Self.canvas.width, y: neckAnchor.y * Self.canvas.height)
        let r = headRotation * .pi / 180
        let dx = f.x - a.x, dy = f.y - a.y
        // Coloring: aim a little lower so the top of the clipboard and the crayon stay in the close-up (a pan, not a zoom).
        let lower: CGFloat = self == .coloring ? 120 : 0
        return CGPoint(x: a.x + dx * cos(r) - dy * sin(r) + headOffset.width,
                       y: a.y + dx * sin(r) + dy * cos(r) + headOffset.height + lower)
    }
}
