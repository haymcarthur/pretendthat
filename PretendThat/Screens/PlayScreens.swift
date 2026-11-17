import SwiftUI
import NutmegCore

struct HandoffView: View {
    let model: AppModel
    let sceneIndex: Int
    /// Chat open: pinned at the top of the chat panel (round 10), same card at full readable size.
    var pinned = false
    private var store: AdventureStore { model.store }

    var body: some View {
        if let id = store.kit?.scenes[sceneIndex].owner.role, let role = store.plan?.role(for: id) {
            // Nutmeg points at the card from the shared stage (no second Nutmeg inside the card). Round 26 (Haylee's
            // button audit): one big green check, and no "Back to the checklist" (the rail and voice still go back).
            PTHandoffCard(role: role, figure: { EmptyView() }, onTap: { model.tapHandoff(id) }, pinned: pinned,
                          badge: model.handoffBadge(role))   // round 28: the colored badge, not the text
                .id(sceneIndex)
        }
    }
}

/// The play step's scene checklist on the stage (chat closed). Round 8 (Haylee): it never scrolls. Round 26 (Haylee's
/// button audit): no Done button; once every step is checked it moves on by itself after a short grace (an accidental
/// last tap can still be unchecked), and "we're done" by voice finishes early. It sits in the shared card zone.
/// Round 14 (Haylee: "Sunset Closing Time" clipped its title and last checkbox): the paper is sized to its CONTENT
/// (measured, the title may wrap to 2 lines) and fits the stage by stepping down pictures and padding first (text
/// ≥ 18 pt); no picture next to the title (pictures only next to each step). With the chat open the checklist is in
/// the chat panel's Checklist tab instead (`PTScenePinnedCard`).
struct SceneView: View {
    let model: AppModel
    let index: Int
    /// The shared card zone's width (round 14: natural size, no scale-down).
    var width: CGFloat = 380
    /// The room the stage gives the whole checklist.
    var maxHeight: CGFloat = .infinity
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the checklist beside her.
    @State private var revealed = false
    /// Measured content height per density tier (round 14).
    @State private var heights: [Int: CGFloat] = [:]

    static let pad = Theme.Space.m
    /// The paper's reveal slack (round 26: no Done! button under it any more).
    static let chrome: CGFloat = 20

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            let avail = maxHeight - Self.chrome - 2 * Self.pad
            let tier = PTSceneChecklist.tiers.indices.first { (heights[$0] ?? .infinity) <= avail } ?? PTSceneChecklist.tiers.count - 1
            let paper = CGSize(width: width, height: (heights[tier] ?? 300) + 2 * Self.pad)
            VStack(spacing: Theme.Space.m) {
                GeometryReader { geo in
                    PTPaperReveal(count: 1, isRevealed: revealed, origin: CGPoint(x: -geo.size.width / 2 - 150, y: 60),
                                  slot: { _ in (.zero, -1.5) }, paperSize: paper,
                                  onLanded: { model.gesture(.celebrate) }) { _ in
                        PTSceneChecklist(model: model, scene: scene, tier: tier)
                            .padding(Self.pad)
                            .frame(width: paper.width, height: paper.height, alignment: .top)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                }
                .frame(height: paper.height + 20)
            }
            // Measure every tier's natural height at this width (hidden), then use the densest one that's needed.
            .background {
                ZStack {
                    ForEach(PTSceneChecklist.tiers.indices, id: \.self) { t in
                        PTSceneChecklist(model: model, scene: scene, tier: t)
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

/// The checklist itself (title + one row per step), shared by the stage paper and the chat panel's Checklist tab.
/// Round 14: the title has no picture and may wrap to 2 lines; denser tiers shrink pictures and padding before text.
struct PTSceneChecklist: View {
    let model: AppModel
    let scene: KitScene
    var tier = 0
    struct Tier { let title: CGFloat; let picture: CGFloat; let font: CGFloat; let padding: CGFloat; let spacing: CGFloat }
    static let tiers: [Tier] = [
        Tier(title: 32, picture: 52, font: 22, padding: Theme.Space.s, spacing: Theme.Space.s),
        Tier(title: 30, picture: 44, font: 21, padding: Theme.Space.xs, spacing: Theme.Space.s),
        Tier(title: 28, picture: 36, font: 20, padding: Theme.Space.xs, spacing: 6),
        Tier(title: 26, picture: 30, font: 18, padding: 4, spacing: 4)
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
                PTChecklistRow(text: step.text, isChecked: Binding(
                    get: { store.checkedSteps.contains(i) }, set: { _ in model.checkStep(i) }),
                               fontSize: t.font, padding: t.padding) {
                    model.pictureTile(step.picture, size: t.picture)
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

/// The scene checklist in the chat panel's Checklist tab (chat open). Round 14 (Haylee: no pinned/collapsing list):
/// the full-size checklist, the same as the stage's (no summary row, no picture by the title); the tab scrolls if a
/// long scene needs it. Round 26: no Done! (it moves on by itself once every step is checked).
struct PTScenePinnedCard: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.m) {
                PTSceneChecklist(model: model, scene: scene, tier: scene.steps.count <= 4 ? 1 : 3)   // the panel is narrower: smaller pictures, same readable text
            }
            .padding(.vertical, Theme.Space.xs)
            .ptPinnedCard()
            .accessibilityElement(children: .contain)
        }
    }
}

/// The End. Round 26 (Haylee's button audit): two big icon buttons, no text. ⭐ saves the game and goes home (once
/// her shelf line ends); 🏠 goes home without saving (the round 19 hang-up rules: silence, the voice session closes).
/// A replay is already saved, so it shows only 🏠. The step rail's Play (finished, ↺) still goes back to the checklist.
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
