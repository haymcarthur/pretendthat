import SwiftUI
import NutmegCore

// iPhone version (2026-11-17, Haylee's phone mockups): the pieces only the phone's portrait stage uses. Nutmeg stands
// on top; what kids tap sits in the content zone under her (RootView's `phoneSplit`). The iPad never draws these.

/// The prop hunt on the phone (mockup screen 4): ONE big card under Nutmeg (her picture left, the name and what it
/// becomes right, the big green ✓ and the ✗ below), and a pager of dots for the hunt so far (found = lime, the one
/// now = a long coral dot, still to come = gray). Kids tap ✓ / ✗ or just say it.
struct PTPhonePropHunt: View {
    let items: [PTStageItem]
    var total: Int? = nil
    var onHunt: ((Bool) -> Void)? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let active = items.last { !$0.isDone }
        let shown = active ?? items.last
        VStack(spacing: Theme.Space.s) {
            if let item = shown {
                card(item, current: active != nil)
                    .id(item.id)
                    .transition(.asymmetric(insertion: .scale(scale: 0.85).combined(with: .opacity), removal: .opacity))
            }
            pager(active: active)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(reduceMotion ? Theme.stageMoveReduced : Theme.stageMove, value: active?.id)
    }

    private func card(_ item: PTStageItem, current: Bool) -> some View {
        VStack(spacing: Theme.Space.s) {
            HStack(spacing: Theme.Space.m) {
                Group {
                    if let image = item.image { Image(uiImage: image).resizable().scaledToFit() } else { PTShimmer(tint: item.tint) }
                }
                .frame(width: 92, height: 92)
                .saturation(item.isPretend ? 0 : 1).opacity(item.isPretend ? 0.5 : 1)
                .overlay(alignment: .bottomTrailing) {
                    if item.isDone || item.chip == .swapped { PTPropBadge(item: item, side: 28).offset(x: 4, y: 4) }
                    else { PTPropCountBadge(count: item.count, side: 34).offset(x: 6, y: 6) }   // 2026-11-18: "×4"
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title).font(Theme.displayFont(24)).foregroundStyle(Theme.ink)
                        .lineLimit(2).minimumScaleFactor(0.7)
                    if let sub = item.isPretend ? "We'll pretend!" : item.subtitle {
                        Text(sub).font(Theme.uiFont(16, .medium)).foregroundStyle(Theme.inkMuted)
                            .lineLimit(3).minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if current, item.huntButtons, let onHunt {
                PTHuntButtons(size: 64, action: onHunt)
            }
        }
        .padding(Theme.Space.m)
        .frame(maxWidth: .infinity)
        .ptPanel(radius: 28)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title + (item.isPretend ? ", we'll pretend" : (current ? ", find it now" : ", found")))
    }

    /// One dot per prop shown so far (and the ones still to come when the count is known).
    private func pager(active: PTStageItem?) -> some View {
        let count = max(items.count, total ?? 0)
        return HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                let item = items.indices.contains(i) ? items[i] : nil
                let now = item != nil && item?.id == active?.id
                Capsule()
                    .fill(now ? Theme.coral : (item?.isDone == true ? Theme.lime : Theme.chipGray))
                    .frame(width: now ? 26 : 10, height: 10)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Prop \(min(count, (items.firstIndex { $0.id == active?.id } ?? items.count - 1) + 1)) of \(count)")
    }
}

/// The legacy all-props presentation (`show_props`) on the phone: the cards in a 2-column grid under her.
struct PTPhoneCardGrid: View {
    let items: [PTStageItem]
    var onHunt: ((String, Bool) -> Void)? = nil
    var body: some View {
        GeometryReader { geo in
            let cols = 2, rows = max(1, (items.count + 1) / 2)
            let w = (geo.size.width - Theme.Space.s) / 2
            let fitW = ((geo.size.height - CGFloat(rows - 1) * Theme.Space.s) / CGFloat(rows) - 128) / 0.72
            let cardW = max(110, min(w, fitW + 2 * Theme.Space.s))
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(cardW), spacing: Theme.Space.s), count: cols), spacing: Theme.Space.s) {
                ForEach(items) { item in
                    PTItemCard(item: item, chip: item.chip, width: cardW)
                        .overlay(alignment: .bottom) {
                            if item.huntButtons, let onHunt { PTHuntButtons(size: 56) { onHunt(item.id, $0) }.offset(y: 30) }
                        }
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
    }
}

/// Nutmeg's small live head (her real layered art, lip-synced) for the phone's chat sheet header: the sheet covers the
/// stage, and she is never heard unless she's on screen.
/// Round 40 (Haylee): cropped to her FACE (eyes, nose and mouth fill the circle; the ears are cut off) so her mouth is
/// clearly visible while she talks.
struct PTNutmegAvatar: View {
    let model: AppModel
    var diameter: CGFloat = 56
    /// The canvas point the circle centers on (between her eyes and her mouth) and how much of the canvas the circle
    /// spans (about her cheeks), canvas px.
    static let faceCenter = CGPoint(x: 628, y: 532)
    static let faceSpan: CGFloat = 490

    var body: some View {
        let k = diameter / Self.faceSpan
        let canvas = CGSize(width: PTStageCamera.art.width * k, height: PTStageCamera.art.height * k)
        let c = Self.faceCenter
        ZStack {
            Circle().fill(Theme.startSky)
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, holdsClipboard: false)
                .frame(width: canvas.width, height: canvas.height)
                .position(x: diameter / 2 + canvas.width / 2 - c.x * k, y: diameter / 2 + canvas.height / 2 - c.y * k)
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
        .allowsHitTesting(false)
        .accessibilityLabel("Nutmeg")
    }
}
