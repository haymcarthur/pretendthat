import SwiftUI
import NutmegCore

/// The play step's scene card on the stage (chat closed). Round 29 (Haylee, ensemble scenes): the iPad stays in the
/// middle and everyone plays the scene at once: the scene title, one row per playing role (its character picture, its
/// task, a 🔊 that reads just that task), and ONE big green ▶ "Next scene" below. No hand-off, no checkboxes, no timer.
/// Round 14's sizing rules stay: the paper is sized to its CONTENT (measured) and fits the stage by stepping down the
/// pictures and padding first (text ≥ 18 pt); if 6 rows still don't fit, the rows scroll (never clip). The ▶ is always
/// visible. With the chat open the card is in the chat panel's Scene tab instead (`PTScenePinnedCard`).
struct SceneView: View {
    let model: AppModel
    let index: Int
    /// The shared card zone's width (round 14: natural size, no scale-down).
    var width: CGFloat = 380
    /// The room the stage gives the whole card (rows + the ▶).
    var maxHeight: CGFloat = .infinity
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the scene card beside her.
    @State private var revealed = false
    /// Measured content height per density tier (round 14).
    @State private var heights: [Int: CGFloat] = [:]

    static let pad = Theme.Space.m
    /// The paper's reveal slack and the ▶ under it.
    static let chrome: CGFloat = 20 + 76 + Theme.Space.m + Theme.depth

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            let avail = maxHeight - Self.chrome - 2 * Self.pad
            let fits = PTSceneCard.tiers.indices.first { (heights[$0] ?? .infinity) <= avail }
            let tier = fits ?? PTSceneCard.tiers.count - 1
            let natural = (heights[tier] ?? 300) + 2 * Self.pad
            let paper = CGSize(width: width, height: fits == nil && avail.isFinite ? max(200, avail + 2 * Self.pad) : natural)
            VStack(spacing: Theme.Space.m) {
                GeometryReader { geo in
                    PTPaperReveal(count: 1, isRevealed: revealed, origin: CGPoint(x: -geo.size.width / 2 - 150, y: 60),
                                  slot: { _ in (.zero, -1.5) }, paperSize: paper,
                                  onLanded: { model.gesture(.celebrate) }) { _ in
                        Group {
                            if fits == nil {
                                ScrollView { PTSceneCard(model: model, scene: scene, tier: tier) }.scrollIndicators(.automatic)
                            } else {
                                PTSceneCard(model: model, scene: scene, tier: tier)
                            }
                        }
                        .padding(Self.pad)
                        .frame(width: paper.width, height: paper.height, alignment: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: paper.height + 20)
                PTNextSceneButton { model.tapNextScene() }
                    .padding(.bottom, Theme.depth)
                    .opacity(revealed ? 1 : 0)
            }
            // Measure every tier's natural height at this width (hidden), then use the densest one that's needed.
            .background {
                ZStack {
                    ForEach(PTSceneCard.tiers.indices, id: \.self) { t in
                        PTSceneCard(model: model, scene: scene, tier: t)
                            .frame(width: width - 2 * Self.pad)
                            .fixedSize(horizontal: false, vertical: true)
                            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { heights[t] = $0 }
                    }
                }
                .hidden().allowsHitTesting(false).accessibilityHidden(true)
            }
            .onAppear { revealed = true }   // round 11: in the same frame as the camera move (round 10: 60 ms after)
        }
    }
}

/// The scene card's content (title + one row per playing role), shared by the stage paper and the chat panel's Scene
/// tab. Round 14: the title may wrap to 2 lines; denser tiers shrink pictures and padding before text.
struct PTSceneCard: View {
    let model: AppModel
    let scene: KitScene
    var tier = 0
    struct Tier { let title: CGFloat; let picture: CGFloat; let font: CGFloat; let padding: CGFloat; let spacing: CGFloat }
    static let tiers: [Tier] = [
        Tier(title: 32, picture: 72, font: 22, padding: Theme.Space.s, spacing: Theme.Space.s),
        Tier(title: 30, picture: 60, font: 21, padding: Theme.Space.xs, spacing: Theme.Space.s),
        Tier(title: 28, picture: 52, font: 20, padding: Theme.Space.xs, spacing: 6),
        Tier(title: 26, picture: 44, font: 18, padding: 4, spacing: 4)
    ]
    private var store: AdventureStore { model.store }

    var body: some View {
        let t = Self.tiers[min(tier, Self.tiers.count - 1)]
        VStack(spacing: t.spacing) {
            Text(scene.title).font(Theme.displayFont(t.title)).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 2)
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(scene.steps.enumerated()), id: \.offset) { i, step in
                if let role = step.role.role.flatMap({ store.plan?.role(for: $0) }) {
                    PTTaskRow(text: step.text, tint: Theme.playerColor(role.id.index), fontSize: t.font, padding: t.padding,
                              speakLabel: "Hear \(role.spoken)'s task", onSpeak: { model.readTask(i) }) {
                        PTCharacterPicture(role: role, image: model.characterPicture(role), size: t.picture)
                    }
                }
            }
        }
    }
}

/// Round 10 rule (Haylee): every interactive card pinned in the chat panel (prop, kit, checklist, hand-off) shares
/// one treatment: the panel's full width, a white rounded card with a hairline, readable sizes.
struct PTPinnedCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Theme.Space.s)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.white))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.line, lineWidth: 1.5))
    }
}
extension View { func ptPinnedCard() -> some View { modifier(PTPinnedCardStyle()) } }

/// The most a pinned card may take of the chat panel's height (round 10: ~50%, so the transcript stays readable).
private struct PTPinnedCapKey: EnvironmentKey { static let defaultValue: CGFloat = .infinity }
extension EnvironmentValues {
    var ptPinnedCap: CGFloat {
        get { self[PTPinnedCapKey.self] }
        set { self[PTPinnedCapKey.self] = newValue }
    }
}

/// The scene card in the chat panel's Scene tab (chat open). Round 14: the full-size card, the same as the stage's;
/// the tab scrolls if 6 rows need it. Round 29: the rows and the green ▶ Next scene.
struct PTScenePinnedCard: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.m) {
                PTSceneCard(model: model, scene: scene, tier: scene.steps.count <= 3 ? 2 : 3)   // the panel is narrower: smaller pictures, same readable text
                PTNextSceneButton(height: 64) { model.tapNextScene() }
                    .padding(.bottom, Theme.depth)
            }
            .padding(.vertical, Theme.Space.xs)
            .ptPinnedCard()
            .accessibilityElement(children: .contain)
        }
    }
}

/// The End. Round 26 (Haylee's button audit): two big icon buttons, no text. ⭐ saves the game and goes home (once
/// her shelf line ends); 🏠 goes home without saving (the round 19 hang-up rules: silence, the voice session closes).
/// A replay is already saved, so it shows only 🏠. The step rail's Play (finished, ↺) reopens the last scene.
struct EndView: View {
    let model: AppModel
    var body: some View {
        let store = model.store
        let saving = model.saveState == .saving || (store.savedAs != nil && !store.isReplay)
        VStack(spacing: Theme.Space.l) {
            PTText("The End!", .hero)
            HStack(spacing: Theme.Space.xl) {
                if store.canSave || saving {
                    PTBigIconButton(kind: .star, size: 96, label: model.saveState == .failed ? "Try saving again" : "Save it and go home") {
                        model.tapSave()
                    }
                    .disabled(saving)
                    .opacity(saving ? 0.6 : 1)
                }
                PTBigIconButton(kind: .home, size: 96, label: "Go home") { model.tapNewGame() }
            }
            .padding(.bottom, Theme.depth)
        }
    }
}
