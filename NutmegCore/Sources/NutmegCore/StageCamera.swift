import CoreGraphics
import Foundation

// One shared stage for every phase (Haylee, fix round 2): Nutmeg, the floor and the stars live in ONE stage world with
// ONE camera. A phase only picks a shot (close / medium / wide) plus where she stands (a lane between reserved zones);
// the floor gets exactly her transform, so it is always under her feet. Pure math, so it is unit-tested.

/// The camera shot.
/// - closeUp: her face fills the stage (planning chat, kit coloring).
/// - medium: head to knees about 70% of the stage height (the prop hunt).
/// - wide: her whole body (arrival from the start screen, presented cards, kit papers, play, hand-off), feet on the
///   stage floor line; smaller when her lane is narrow.
public enum PTCameraShot: Equatable, Sendable { case closeUp, medium, wide }

/// What a phase asks of the camera: a shot and where she stands. Reserves are screen-space zones (points) kept free
/// for other content on the left / right / top of the free stage; she is centered in the lane that's left.
public struct PTStageFrame: Equatable, Sendable {
    public var shot: PTCameraShot
    public var leftReserve: CGFloat = 0
    public var rightReserve: CGFloat = 0
    public var topReserve: CGFloat = 0
    /// Presented cards in two columns beside her (wide shot only).
    public var cards: Int = 0
    /// The landing from the start screen (whole body on the start screen's floor; the only frame below the minimum).
    public var landing = false
    /// Close-up only: the WRITING framing (round 5): her head plus the TOP of the clipboard, the screen's bottom edge
    /// cropping just below the clipboard top so her paws are out of frame.
    public var writing = false
    /// Round 14 (Haylee: with the chat open the floor was cut off and she sat low/left): chat open, this frame is the
    /// SAME framing as chat closed (computed on the full reference stage), scaled down uniformly to fit the free stage
    /// left of the panel and centered there: same proportions, floor fully in frame. Ignored with the chat closed.
    public var fitClosed = false
    public init(shot: PTCameraShot, leftReserve: CGFloat = 0, rightReserve: CGFloat = 0, topReserve: CGFloat = 0, cards: Int = 0,
                landing: Bool = false, writing: Bool = false, fitClosed: Bool = false) {
        self.shot = shot; self.leftReserve = leftReserve; self.rightReserve = rightReserve
        self.topReserve = topReserve; self.cards = cards; self.landing = landing; self.writing = writing
        self.fitClosed = fitClosed
    }
    public static let closeUp = PTStageFrame(shot: .closeUp)
    public static let writing = PTStageFrame(shot: .closeUp, writing: true)
    /// The reference shot: she stands centered, whole body, feet on the stage floor (where the start screen lands her).
    public static let arrival = PTStageFrame(shot: .wide, landing: true)
}

/// The stage's free area and fixed chrome, in the stage view's coordinates.
public struct PTStageGeometry: Equatable, Sendable {
    public var size: CGSize
    /// Floating chrome to keep clear of: the step rail on the left, the control pill at the bottom.
    public var leadingInset: CGFloat
    public var bottomInset: CGFloat
    /// The stage floor ellipse at the arrival shot (the start screen's floor), in stage coordinates.
    public var floor: CGRect
    /// The chat panel is open (the stage is already narrowed by it): close-ups center between rail and panel.
    public var chatOpen: Bool
    /// Round 11 (Haylee: the floor must scale with her): the stage size the camera's REFERENCE (the arrival framing on
    /// the start screen's floor) is computed for: the full, chat-closed, keyboard-free stage. The floor's size relative
    /// to Nutmeg depends only on this, so opening the chat panel or the keyboard can't change it. nil = `size`.
    public var referenceSize: CGSize?
    public init(size: CGSize, leadingInset: CGFloat, bottomInset: CGFloat, floor: CGRect, chatOpen: Bool = false, referenceSize: CGSize? = nil) {
        self.size = size; self.leadingInset = leadingInset; self.bottomInset = bottomInset; self.floor = floor; self.chatOpen = chatOpen
        self.referenceSize = referenceSize
    }
    /// The geometry the camera's reference framing uses (full stage, chat closed).
    public var reference: PTStageGeometry {
        PTStageGeometry(size: referenceSize ?? size, leadingInset: leadingInset, bottomInset: bottomInset, floor: floor)
    }
    static let top: CGFloat = 16
    /// The free stage rect (right of the rail, above the pill).
    public var free: CGRect {
        CGRect(x: leadingInset, y: Self.top, width: max(100, size.width - leadingInset), height: max(200, size.height - bottomInset - Self.top))
    }
}

/// The stage camera math: where Nutmeg's canvas goes for a frame, the floor under her, the card slots.
public enum PTStageCamera {
    /// Room the stage keeps for its floating chrome (step rail on the left, control pill at the bottom).
    public static let chromeLeading: CGFloat = 132, chromeBottom: CGFloat = 108
    /// Nutmeg's art canvas (all layers share it) and focal points measured from Haylee's export
    /// (alpha bounds: head-base x 59–1055, y 16–798; bodies x 163–1049, y 628–1311).
    public static let art = CGSize(width: 1178, height: 1335)
    /// Her VISUAL center: the horizontal mass center of head and body (the tail on her left skews the bounding box).
    public static let bodyFocus = CGPoint(x: 578, y: 663)
    /// Her head's center (ears included).
    public static let headFocus = CGPoint(x: 566, y: 410)
    /// Her FACE center (eyes and nose) in the rest pose: the close-up anchor.
    public static let faceFocus = CGPoint(x: 630, y: 470)
    /// How far her head reaches from the face center (ears x 59–1055, top y 16, chin y ~800), canvas px.
    public static let faceToLeftEar: CGFloat = 569, faceToRightEar: CGFloat = 425, faceToTop: CGFloat = 455
    /// Visible art height and her widest half-width from the visual center, in canvas px.
    public static let visibleHeight: CGFloat = 1296
    public static let halfWidth: CGFloat = 517
    public static let headHeight: CGFloat = 785
    public static let headWidth: CGFloat = 994
    /// Her horizontal extent (ears / waving paw) and the top of her ears, canvas px.
    public static let extentLeft: CGFloat = 59, extentRight: CGFloat = 1055, headTop: CGFloat = 16
    /// Her knees (idle legs), canvas px: the medium shot frames head to knees.
    public static let kneeY: CGFloat = 1160
    /// Where her soles touch the floor (center of her stance; feet span x 377–745), canvas px.
    public static let feet = CGPoint(x: 561, y: 1306)
    /// Her chest (where the hunt card centers), canvas px.
    public static let chestY: CGFloat = 900
    /// clipboardBoth (round 5 layer split): the clipboard's top (its clip, ~777; panel ~807) and the top of her paws
    /// (~872), canvas px. Round 8: the writing moment uses the one-paw writing body (scaled 0.69), whose clipboard
    /// bottom lands at ~1070 and writing paw at ~965; the writing shot (a medium close-up) puts the screen's bottom edge
    /// at `writeBottom`, just under the clipboard, so her head, the clipboard and the writing paw all show.
    /// Round 10 (Haylee: too wide): halfway back toward round 7's tight crop: bottom edge at 1015 (was 1120): head, the
    /// top ~2/3 of the clipboard and the writing paw with its crayon.
    public static let clipboardTop: CGFloat = 777, pawsTop: CGFloat = 872, writeBottom: CGFloat = 1015

    public struct Star: Sendable { public let asset: String; public let point: CGPoint; public let size: CGFloat; public let maxPoints: CGFloat; public let tilt: Double }
    /// Placed clear of her head (ears end at x 59 and 1055) and body; static.
    public static let stars = [
        Star(asset: "stage-star", point: CGPoint(x: 1150, y: 170), size: 150, maxPoints: 84, tilt: 12),
        Star(asset: "stage-sparkle", point: CGPoint(x: -20, y: 560), size: 100, maxPoints: 56, tilt: 0),
        Star(asset: "stage-sparkle", point: CGPoint(x: 1090, y: 1010), size: 70, maxPoints: 40, tilt: 0)
    ]

    /// The camera move between two layouts as a world transform (screen points at `from` → screen points at `to`).
    public struct WorldMove: Sendable {
        public let from: Layout, to: Layout
        public init(from: Layout, to: Layout) { self.from = from; self.to = to }
        public var scale: CGFloat { to.k / from.k }
        /// Star scale with ~70% parallax.
        public var parallaxScale: CGFloat { 1 + (scale - 1) * 0.7 }
        public func apply(_ p: CGPoint, parallax: CGFloat = 1) -> CGPoint {
            let full = CGPoint(x: to.origin.x + (p.x - from.origin.x) * scale, y: to.origin.y + (p.y - from.origin.y) * scale)
            return CGPoint(x: p.x + (full.x - p.x) * parallax, y: p.y + (full.y - p.y) * parallax)
        }
        public func apply(_ r: CGRect) -> CGRect {
            let o = apply(r.origin)
            return CGRect(x: o.x, y: o.y, width: r.width * scale, height: r.height * scale)
        }
    }

    public struct Layout: Sendable {
        /// Points per canvas px.
        public var k: CGFloat
        /// Screen position of canvas (0,0).
        public var origin: CGPoint
        public var canvas: CGSize
        public var cardWidth: CGFloat
        public var cards: [Slot]
        public struct Slot: Sendable { public var point: CGPoint; public var tilt: Double }
        public func screen(_ p: CGPoint) -> CGPoint { CGPoint(x: origin.x + p.x * k, y: origin.y + p.y * k) }
        /// Her horizontal extent on screen.
        public var minX: CGFloat { origin.x + extentLeft * k }
        public var maxX: CGFloat { origin.x + extentRight * k }
        public var feetPoint: CGPoint { screen(feet) }
        /// A star shows only on screen, clear of the rail, the pill and every card.
        public func starFits(_ p: CGPoint, side: CGFloat, in size: CGSize, leadingInset: CGFloat, bottomInset: CGFloat) -> Bool {
            let r = CGRect(x: p.x - side / 2, y: p.y - side / 2, width: side, height: side)
            guard r.minX > leadingInset + 8, r.maxX < size.width - 8, r.minY > 8, r.maxY < size.height - bottomInset else { return false }
            let h = PTStageCamera.cardHeight(cardWidth)
            return !cards.contains { c in
                CGRect(x: c.point.x - cardWidth / 2 - 12, y: c.point.y - h / 2 - 12, width: cardWidth + 24, height: h + 24).intersects(r)
            }
        }
        public func slot(_ i: Int, fallback: CGPoint) -> Slot { cards.indices.contains(i) ? cards[i] : Slot(point: fallback, tilt: 0) }
        public var canvasCenter: CGPoint { CGPoint(x: origin.x + canvas.width / 2, y: origin.y + canvas.height / 2) }
    }

    /// Card height for a width (art square + tag strip + 2-line title + subtitle + padding).
    public static func cardHeight(_ w: CGFloat) -> CGFloat { w * 0.72 + 128 }

    /// Everything the stage draws for one frame: Nutmeg's layout, the reference (arrival) layout and the floor, which
    /// is the arrival floor moved by exactly her camera move (so her feet stay on it in every shot).
    public struct Composition: Sendable {
        public var nutmeg: Layout
        public var reference: Layout
        public var floor: CGRect
        public var world: WorldMove { WorldMove(from: reference, to: nutmeg) }
        /// The floor surface line her feet stand on (the ellipse's center line).
        public var floorLine: CGFloat { floor.midY }
    }

    public static func compose(_ frame: PTStageFrame, _ g: PTStageGeometry, faceFocus: CGPoint = faceFocus) -> Composition {
        // Round 11: the reference is always the full chat-closed stage, so floor : Nutmeg is the same in every framing.
        let ref = layout(.arrival, g.reference)
        let L = layout(frame, g, faceFocus: faceFocus)
        return Composition(nutmeg: L, reference: ref, floor: WorldMove(from: ref, to: L).apply(g.floor))
    }

    /// Her MINIMUM scale in every phase (Haylee): the chat-open hunt's medium shot, head to knees ~70% of the stage
    /// height. Only the arrival (the 0.9 s landing from the start screen, which must match the start screen's floor)
    /// is smaller.
    public static func minK(_ g: PTStageGeometry) -> CGFloat { g.size.height * 0.70 / (kneeY - headTop) }

    /// The whole-body scale at the arrival shot: ~70% of the screen height, kept above the pill and inside the width.
    static func wideK(_ g: PTStageGeometry) -> CGFloat {
        let F = g.free
        return min(g.size.height * 0.70, F.height * 0.94, (g.size.width / 2 - 24) / halfWidth * visibleHeight) / visibleHeight
    }

    public static func layout(_ frame: PTStageFrame, _ g: PTStageGeometry, faceFocus: CGPoint = faceFocus) -> Layout {
        if frame.fitClosed && g.chatOpen {
            // Round 14: the chat-closed framing on the full stage, uniformly scaled into the free stage left of the
            // panel (right of the rail) and centered there.
            var closed = frame; closed.fitClosed = false
            let G0 = g.reference
            let L0 = layout(closed, G0, faceFocus: faceFocus)
            let F0 = G0.free, F1 = g.free
            // A small side margin so the floor's rim never touches the panel's gap.
            let s = min(1, (F1.width - 24) / F0.width, F1.height / F0.height)
            let k = L0.k * s
            let origin = CGPoint(x: F1.midX + (L0.origin.x - F0.midX) * s, y: F1.midY + (L0.origin.y - F0.midY) * s)
            return Layout(k: k, origin: origin, canvas: CGSize(width: art.width * k, height: art.height * k), cardWidth: 0, cards: [])
        }
        let size = g.size, F = g.free
        // The lane she stands in (free stage minus the reserved zones).
        let laneMinX = F.minX + frame.leftReserve, laneMaxX = F.maxX - frame.rightReserve
        let laneMinY = F.minY + frame.topReserve
        let laneW = max(80, laneMaxX - laneMinX)
        let floorY = g.floor.midY
        var k: CGFloat
        var origin: CGPoint
        var cardW: CGFloat = 0
        var cards: [Layout.Slot] = []
        // Centers her horizontal extent (ears / paw) in the lane.
        func centeredX(_ k: CGFloat) -> CGFloat { (laneMinX + laneMaxX) / 2 - (extentLeft + extentRight) / 2 * k }

        switch frame.shot {
        case .closeUp:
            // Her FACE centered both ways: on the screen (with the pill) when the chat is closed, between the rail and
            // the chat panel when it's open; the head as big as fits (the far ear may crop by up to ~6%).
            let centerY = F.minY + F.height / 2
            var centerX = size.width / 2
            if g.chatOpen || frame.leftReserve > 0 || frame.rightReserve > 0 { centerX = (laneMinX + laneMaxX) / 2 }
            let leftRoom = centerX - (g.chatOpen ? F.minX + 8 : 0)
            let rightRoom = laneMaxX - centerX
            k = min(F.height / 2 / faceToTop, leftRoom / (faceToLeftEar * 1.02), rightRoom / (faceToRightEar * 0.94),
                    size.height * 0.85 / headHeight)
            origin = CGPoint(x: centerX - faceFocus.x * k, y: centerY - faceFocus.y * k)
            if frame.writing {
                // Writing (round 8, Haylee: zoomed out): a medium close-up, the screen's bottom edge at `writeBottom`
                // (just under the clipboard), so her head, the clipboard and the writing paw with its crayon all show.
                // Her ear tops may crop; the far ear may crop a little at the sides (as above).
                k = max(size.height * 0.95 / (writeBottom - headTop),
                        min(size.height / (writeBottom - headTop), leftRoom / (faceToLeftEar * 1.02), rightRoom / (faceToRightEar * 0.94)))
                origin = CGPoint(x: centerX - faceFocus.x * k, y: size.height - writeBottom * k)
            }
        case .medium:
            // Head to knees ~70% of the stage height, never wider than the lane, ears below any top reserve.
            let roomH = F.maxY + 60 - laneMinY   // the knees may dip a little behind the pill
            k = min(size.height * 0.70, roomH) / (kneeY - headTop)
            k = max(minK(g), min(k, (laneW - 8) / (extentRight - extentLeft)))
            let span = (kneeY - headTop) * k
            let top = laneMinY + max(8, (F.maxY + 30 - laneMinY - span) / 2)
            origin = CGPoint(x: centeredX(k), y: top - headTop * k)
        case .wide:
            let n = frame.cards
            if n == 0 {
                // The arrival / hop (the only whole-body framing without cards, round 11): whole body, feet on the start
                // screen's floor line, visual center on the screen.
                k = wideK(g)
                origin = CGPoint(x: size.width / 2 - bodyFocus.x * k, y: floorY - feet.y * k)
            } else {
                // Presented cards in two columns beside her, Nutmeg between them, feet on the floor line.
                let center = CGPoint(x: size.width / 2, y: F.minY + F.height / 2)
                let left = (n + 1) / 2, rows = max(1, left)
                let gap: CGFloat = 16
                let fitW = ((F.height - CGFloat(rows - 1) * gap) / CGFloat(rows) - 128) / 0.72
                cardW = max(140, min(210, fitW, size.width * 0.19))
                let edgeL = F.minX + 12, edgeR = size.width - 12
                let half = min(center.x - edgeL - cardW - 20, edgeR - cardW - 20 - center.x)
                k = max(minK(g), min(wideK(g) * 0.82, half / halfWidth))
                let nutHalf = halfWidth * k
                origin = CGPoint(x: center.x - bodyFocus.x * k, y: floorY - feet.y * k)
                let headY = origin.y + headTop * k
                if headY < F.minY + 8 { origin.y += F.minY + 8 - headY }
                let xl = max(edgeL + cardW / 2, center.x - nutHalf - 20 - cardW / 2)
                let xr = min(edgeR - cardW / 2, center.x + nutHalf + 20 + cardW / 2)
                let h = cardHeight(cardW)
                for i in 0..<n {
                    let isLeft = i < left
                    let count = isLeft ? left : n - left
                    let j = isLeft ? i : i - left
                    let c = CGFloat(j) - CGFloat(count - 1) / 2
                    cards.append(Layout.Slot(point: CGPoint(x: isLeft ? xl : xr, y: center.y + c * (h + gap)), tilt: Double(c) * (isLeft ? -2.5 : 2.5)))
                }
            }
        }
        return Layout(k: k, origin: origin, canvas: CGSize(width: art.width * k, height: art.height * k), cardWidth: cardW, cards: cards)
    }
}

/// Which frame each phase asks for (pure, so every phase/shot can be checked for her feet on the floor).
public enum PTStageDirector {
    /// The kit step's beats: coloring (close-up) until the whole kit is final, the look-up, then zoom out for the papers.
    public enum KitBeat: Sendable { case coloring, lookUp, papers }

    /// Prop hunt zones (chat closed): the DONE stack on the left (≥ 24 pt from the rail), the ACTIVE card on the right
    /// (≥ 32 pt inside the curtain).
    public static let doneStackWidth: CGFloat = 140, railGap: CGFloat = 24, curtainGap: CGFloat = 32
    /// Round 14 (Haylee: the cards got smaller): ONE card size for everything the prop-card preset shows on her right
    /// (active prop card, kit pages, checklist, hand-off card, The End): the content zone is this wide, and the content
    /// draws at its natural size in it (no scale-down). ~30% of the stage (≈ 360 pt on an 11" iPad); the prop hunt's zone is narrower (done stack on her left).
    public static func cardZoneWidth(_ g: PTStageGeometry) -> CGFloat { min(420, max(300, (g.referenceSize ?? g.size).width * 0.30)) }
    /// The active prop card's width = the shared card zone.
    public static func huntCardWidth(_ g: PTStageGeometry) -> CGFloat { cardZoneWidth(g) }
    /// Chat open: a row of small round done thumbnails along the top of the stage.
    public static let thumbRow: CGFloat = 92

    /// Round 11 (Haylee: ONE way everywhere): the only framings the stage camera uses, from the ones Haylee approved.
    /// Every phase, chat open or closed (and with the keyboard up, which only covers the stage), maps to one of them.
    public enum Preset: String, CaseIterable, Sendable {
        /// The start → game hop's landing (whole body on the start screen's floor). Also the conversation's wide shot
        /// before any card is out.
        case hop
        /// The talking close-up (planning conversation, kit coloring).
        case talk
        /// The writing shot (round 10): head, clipboard and writing paw.
        case writing
        /// The prop-card step, chat closed: Nutmeg medium shot, the card's zone on her right (done stack on her left).
        /// Reused by the kit pages, the play checklist, the hand-off card, the finale and the tap screens.
        case propCard
        /// The prop-card step, chat open: the same medium shot centered between rail and panel, the card pinned in
        /// the panel (done thumbnails along the top).
        case propCardChat
        /// The legacy all-props presentation (cards in two columns beside her; `show_props`).
        case presentedCards
    }

    /// Which preset a phase uses. `chatOpen` picks the prop-card variant; the keyboard never changes it.
    public static func preset(phase: Phase, conversation: Bool, conversationShot: PTCameraShot, cards: Int, hunt: Bool,
                              kitBeat: KitBeat, writing: Bool = false, chatOpen: Bool) -> Preset {
        let card: Preset = chatOpen ? .propCardChat : .propCard
        if writing { return .writing }
        if conversation {
            if hunt { return card }
            switch conversationShot {
            case .closeUp: return .talk
            case .medium: return card
            case .wide: return cards > 0 ? .presentedCards : .hop
            }
        }
        switch phase {
        case .hello: return .hop
        case .makingKit, .kitReady: return kitBeat == .papers ? card : .talk
        default: return card   // tap screens, play checklist, hand-off, finale
        }
    }

    /// The camera frame for a preset.
    /// - doneStack: the prop hunt (done props stack on her left); the other prop-card phases have nothing there.
    public static func frame(_ preset: Preset, cards: Int = 0, curtainInset: CGFloat, doneStack: Bool = false, _ g: PTStageGeometry) -> PTStageFrame {
        switch preset {
        case .hop: return .arrival
        case .talk: return PTStageFrame(shot: .closeUp, fitClosed: true)   // round 14: chat open = closed framing, scaled
        case .writing: return .writing
        case .propCard, .propCardChat: return huntFrame(curtainInset: curtainInset, doneStack: doneStack, g)
        case .presentedCards: return PTStageFrame(shot: .wide, cards: cards)
        }
    }

    /// - conversationShot: the planning camera's current pick (close-up, wide with cards, arrival).
    /// - writing: the writing moment (planning beat or the kit being made) overrides every other shot.
    public static func frame(phase: Phase, conversation: Bool, conversationShot: PTCameraShot, cards: Int,
                             hunt: Bool, kitBeat: KitBeat, curtainInset: CGFloat, writing: Bool = false, _ g: PTStageGeometry) -> PTStageFrame {
        frame(preset(phase: phase, conversation: conversation, conversationShot: conversationShot, cards: cards, hunt: hunt,
                     kitBeat: kitBeat, writing: writing, chatOpen: g.chatOpen), cards: cards, curtainInset: curtainInset,
              doneStack: hunt, g)
    }

    /// The prop-card step's content zone right of her (chat closed): where the active hunt card sits, reused by the
    /// kit pages step.
    public static func huntContent(_ g: PTStageGeometry, nutmeg L: PTStageCamera.Layout, curtainInset: CGFloat) -> CGRect {
        let x0 = L.maxX + 20, x1 = g.size.width - curtainInset - curtainGap
        return CGRect(x: x0, y: g.free.minY, width: max(160, x1 - x0), height: g.free.height)
    }

    public static func huntFrame(curtainInset: CGFloat, doneStack: Bool = true, _ g: PTStageGeometry) -> PTStageFrame {
        if g.chatOpen {
            // The active card docks in the chat panel; done props are a thumbnail row along the top. Round 14: the
            // framing is the chat-closed centered medium shot scaled to fit left of the panel (floor fully in frame).
            return PTStageFrame(shot: .medium, topReserve: thumbRow, fitClosed: true)
        }
        // Round 14: she stands so the card zone right of her is `cardZoneWidth` (she's at her minimum medium scale, so
        // the lane is solved from where her right edge must be). The prop hunt keeps her clear of the done stack on
        // her left, so its zone is what's left (~270 pt); the other phases (kit pages, checklist, hand-off, finale)
        // have nothing on her left and get the full shared card zone.
        let zoneR = g.size.width - curtainInset - curtainGap
        let half = (PTStageCamera.extentRight - PTStageCamera.extentLeft) / 2 * PTStageCamera.minK(g)
        let leftReserve: CGFloat = doneStack ? 8 + doneStackWidth + 18 : 8
        let laneMin = g.free.minX + leftReserve
        let center = max(laneMin + half, zoneR - 20 - cardZoneWidth(g) - half)
        let laneMax = 2 * center - laneMin
        return PTStageFrame(shot: .medium, leftReserve: leftReserve, rightReserve: max(0, g.free.maxX - laneMax))
    }
}
