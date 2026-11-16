import SwiftUI
import UIKit

import NutmegCore

/// What Nutmeg is doing right now (app state). Napping is the step-back screen; oops is an error;
/// coloring is the kit/checklist wait (D6).
enum NutmegState: String, CaseIterable, Identifiable {
    case idle, listening, thinking, talking, excited, amazed, oops, napping, coloring
    /// Sleepy Nutmeg (round 9): nobody answered after the reminder + ~30 s. She sits down (eyes open), her eyes droop
    /// (slow heavy blinks), then she's asleep (nap face, slow deep breathing). No text, no "z"s.
    case sitting, drowsy, asleep
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
        case .sitting: NutmegLook(face: .happy, ears: .normal)
        case .drowsy: NutmegLook(face: .happy, ears: .normal)   // heavy slow blinks to the nap eyes (NutmegCharacter Motion)
        case .asleep: NutmegLook(face: .nap, ears: .normal)
        // Coloring (planning beats, kit): eyes down on the clipboard (focus art when it's imported, thinking until then).
        case .coloring: NutmegLook(face: NutmegFace.writing, ears: .normal)
        }
    }

    /// The resting body pose for this state.
    var basePose: NutmegPose {
        NutmegPose(PoseRules.base(napping: isSeated, coloring: self == .coloring))
    }
    /// The sit pose: the step-back nap and the three sleepy stages.
    var isSeated: Bool { self == .napping || self == .sitting || self == .drowsy || self == .asleep }
    /// The resting pose with the kit step's clipboard hold (`PoseRules.holdsClipboard`).
    func basePose(holdingClipboard: Bool) -> NutmegPose {
        NutmegPose(PoseRules.base(napping: isSeated, coloring: self == .coloring, clipboard: holdingClipboard))
    }
}

/// A one-shot gesture request. A new `id` replays it.
struct NutmegCue: Equatable {
    var gesture: NutmegGesture
    /// How long to hold it (nil: `PoseRules.hold`). Round 7: the point holds through her prop line; a cue with 0
    /// releases a held point.
    var hold: TimeInterval? = nil
    var id = UUID()
}

/// Body poses (Haylee's art, 2026-11-13). Every layer shares ONE 1178×1335 canvas: the bodies, head-base, faces and
/// mouths stack full-frame, so the head sits on each body at offset (0,0) by construction. Per pose the head can be
/// nudged (`headOffset`, canvas px) and tilted (`headRotation`) around the neck anchor; values tuned in the simulator.
enum NutmegPose: String, CaseIterable, Identifiable {
    case idle, wave, point, celebrate, sit, coloring, clipboardBoth
    var id: String { rawValue }
    /// clipboardBoth (round 5 layer split): the body behind the head; the clipboard and paws are `frontLayers`.
    /// coloring (round 8): the one-paw writing body (nutmeg-body-writing); the crayon and fingers are front layers.
    var asset: String {
        switch self {
        case .clipboardBoth: "nutmeg-clipboardboth-body"
        case .coloring: "nutmeg-body-writing"
        default: "nutmeg-body-\(rawValue)"
        }
    }
    /// Layers drawn IN FRONT of the head (body → head → face → headset → front layers), so the clipboard sits in front
    /// of her chin and her paws grip it from the front. Round 8: every pose holding the clipboard at her side has a
    /// clipboard layer (tools/split_clipboard.py: the body's own paths clipped to the clipboard + gripping paw), so the
    /// breathing head never covers the clip; the wave's arm is in front of the head too. They share the body's
    /// transform and breathing, never the head bob. (Sit: the clipboard lies on the floor, far from the head.)
    var frontLayers: [String] {
        switch self {
        case .clipboardBoth: ["nutmeg-clipboardboth-clipboard", "nutmeg-clipboardboth-paws"]
        case .idle, .point, .celebrate: ["nutmeg-\(rawValue)-clipboard"]
        case .wave: ["nutmeg-wave-arm", "nutmeg-wave-clipboard"]
        // Round 12: the solid clipboard (+ holding paw) sits over the wiggling crayon (drawn just below these in
        // NutmegCharacter), so the tip tucks behind the board edge; the writing fingers stay on top.
        case .coloring: ["nutmeg-writing-clipboard", "nutmeg-writing-fingers"]
        default: []
        }
    }
    /// Per-pose body transform in canvas px (body AND front layers; the head keeps its own values). The round-8 wave
    /// and writing bodies were drawn at a different size: wave = scale 0.876 at the neck (610.5, 589) then +28.5, +177;
    /// writing = scale 0.69 at (625, 436) then +14, +330.
    var bodyTransform: CGAffineTransform {
        switch self {
        case .wave: CGAffineTransform(a: 0.876, b: 0, c: 0, d: 0.876, tx: 104.2, ty: 250.0)
        case .coloring: CGAffineTransform(a: 0.69, b: 0, c: 0, d: 0.69, tx: 625 * 0.31 + 14, ty: 436 * 0.31 + 330)
        // Round 14 (Haylee: sleeping looked like floating): the sit art's seat ends at y ~1237, ~70 px above the floor
        // line (`PTStageCamera.feet`, 1306), so the seated body moves down onto the floor.
        case .sit: CGAffineTransform(translationX: 0, y: NutmegPose.sitDrop)
        default: .identity
        }
    }
    /// Wave (round 8): the arm in front of the head would open a gap at the chin if the head bobbed up on its own, so
    /// the head only ever follows the breath downward in this pose.
    var headBobsUp: Bool { self != .wave }
    /// Head size per pose around the neck anchor. clipboardBoth's torso is drawn larger (neck top ~30 px higher than the
    /// round-4 idle, frontal), so its head is a little smaller to read at the same visual size.
    var headScale: CGFloat { self == .clipboardBoth ? 0.93 : 1 }
    init(_ name: PoseName) { self = NutmegPose(rawValue: name.rawValue)! }

    static let canvas = CGSize(width: 1178, height: 1335)
    /// Round 14: how far the sit pose moves down so her seat rests on the floor line (canvas px).
    static let sitDrop: CGFloat = 62
    /// Round 14: the sit pose's clipboard (split out of the sit art, tools/split_sit_clipboard.py) lies on the floor.
    /// Round 22 (Haylee: she sat ON it): at +125 it spanned canvas x ~298–603, right under her seat (~383–875), so it
    /// moves to lie flat on the floor beside her feet on her right (x ~850–1156, tucked just behind her toes; drawn
    /// behind her). This far right of where the art drew it (canvas px). Transform only, no redraw.
    static let sitClipboardShift: CGFloat = 678
    /// Her contact shadow per pose (canvas px): center x and width. The seated body is wider and sits right of the
    /// standing stance.
    var shadow: (x: CGFloat, width: CGFloat) { self == .sit ? (668, 560) : (603, 445) }

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
        case .sit: CGSize(width: 0, height: 17 + NutmegPose.sitDrop)   // round 14: rides the body down onto the floor
        // Round 5: up onto the higher, frontal neck (V center x ~590 vs the idle's 3/4 neck) instead of sinking into it.
        case .clipboardBoth: CGSize(width: -12, height: -18)
        default: CGSize(width: 0, height: 12)
        }
    }
    /// The neck plug: a SMALL fur-colored oval behind the body, fully hidden under the chin and behind the vest (it must
    /// never reach past the shoulder outline; a wide one showed as a brown lump on the shoulders). The chin overlap
    /// itself comes from `headOffset`.
    static let neckPlug = CGRect(x: 600 - 80, y: 800 - 35, width: 160, height: 70)
    var headRotation: Double {
        switch self { case .idle, .wave, .celebrate, .clipboardBoth, .coloring: 0; case .point: 3; case .sit: -4 }   // writing: head at the idle values (round 8)
    }
}

enum NutmegFace: String, CaseIterable {
    case happy, talking, listening, thinking, ooh, yay, oops, nap, focus
    /// nutmeg-face-focus (eyes down at the clipboard) is new art; fall back until it's imported.
    static let focusAvailable = UIImage(named: "nutmeg-face-focus") != nil
    /// The writing moment's face (round 5): the focus EYES (looking down at the clipboard). Its own lopsided tongue-tip
    /// mouth is replaced by the happy face's simple closed smile (`mouthAsset`), Haylee.
    static let writing: NutmegFace = .focus
    /// Eyes (the face SVG minus its mouth; tools/import_art.py splits them).
    var asset: String { "nutmeg-face-\(rawValue)" }
    /// This face's own mouth, shown when Nutmeg isn't talking.
    /// Round 14 (Haylee: the thinking state looked grumpy): thinking keeps its eyes (open, looking up and aside) but
    /// uses the listening face's small soft mouth instead of its own "^" (which read as a frown).
    var mouthAsset: String {
        switch self {
        case .focus: NutmegFace.happy.mouthAsset
        case .thinking: NutmegFace.listening.mouthAsset
        default: "nutmeg-face-\(rawValue)-mouth"
        }
    }
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
        let dx = (f.x - a.x) * headScale, dy = (f.y - a.y) * headScale
        // Coloring: aim a little lower so the top of the clipboard and the crayon stay in the close-up (a pan, not a zoom).
        let lower: CGFloat = self == .coloring ? 120 : 0
        return CGPoint(x: a.x + dx * cos(r) - dy * sin(r) + headOffset.width,
                       y: a.y + dx * sin(r) + dy * cos(r) + headOffset.height + lower)
    }
}
