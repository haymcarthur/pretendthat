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
            // Nutmeg points at the card from the shared stage (no second Nutmeg inside the card).
            PTHandoffCard(role: role, figure: { EmptyView() }, onTap: { store.badgeTapped(id) },
                          onBack: store.canGoBackToChecklist ? { store.backToChecklist() } : nil, pinned: pinned)
                .id(sceneIndex)
        }
    }
}

/// "← Back to the checklist" (round 10, Haylee): undo a "Done!", restoring the checkmarks exactly as they were.
struct PTBackToChecklistButton: View {
    var compact = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Back to the checklist", systemImage: "arrow.left").frame(maxWidth: compact ? .infinity : nil)
        }
        .buttonStyle(.ptSecondary)
        .accessibilityLabel("Back to the checklist")
    }
}

/// The play step's scene checklist on the stage (chat closed). Round 8 (Haylee): it never scrolls; "Done!" is a
/// full-width button under the paper, always visible (round 10: tapped early, it checks the rest for the kid, then the
/// next hand-off card comes). It sits in the prop-card preset's shared card zone.
/// Round 14 (Haylee: "Sunset Closing Time" clipped its title and last checkbox): the paper is sized to its CONTENT
/// (measured, the title may wrap to 2 lines) and fits the stage by stepping down pictures and padding first (text
/// ≥ 18 pt); no picture next to the title (pictures only next to each step). With the chat open the checklist is in
/// the chat panel's Checklist tab instead (`PTScenePinnedCard`).
struct SceneView: View {
    let model: AppModel
    let index: Int
    /// The shared card zone's width (round 14: natural size, no scale-down).
    var width: CGFloat = 380
    /// The room the stage gives the whole checklist (paper + Done!).
    var maxHeight: CGFloat = .infinity
    private var store: AdventureStore { model.store }
    /// D6 (revised): one sheet of paper flies off Nutmeg's clipboard and becomes the checklist beside her.
    @State private var revealed = false
    /// Measured content height per density tier (round 14).
    @State private var heights: [Int: CGFloat] = [:]

    static let pad = Theme.Space.m
    /// Done! (64 pt) + the gap above it + the paper's reveal slack.
    static let chrome: CGFloat = 64 + Theme.Space.m + 20

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            let n = scene.steps.count
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
                PTChecklistActions(model: model, allChecked: store.checkedSteps.count == n)
                    .frame(width: width)
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

/// "Done!" as a real full-size button (round 8): full width of its card, 64 pt tall, big label; lime once every
/// step is checked. Round 10: always enabled (an early tap auto-checks the rest); ignored while that runs.
struct PTSceneDoneButton: View {
    var allChecked: Bool
    var busy = false
    var size: CGFloat = 26
    var action: () -> Void
    var body: some View {
        Button(action: action) { Text("Done!").frame(maxWidth: .infinity) }
            .buttonStyle(PTButtonStyle(kind: allChecked ? .success : .primary, size: size))
            .allowsHitTesting(!busy)
    }
}

/// Round 16 (Haylee): the checklist's bottom row, on the stage card and in the chat panel's Checklist tab: "Hear it
/// again" (Nutmeg reads the title and the steps left, for kids who can't read yet) beside "Done!". Same 64 pt height
/// as Done! alone, so the round 14 fit (no clipping, long lists) is unchanged.
struct PTChecklistActions: View {
    let model: AppModel
    var allChecked: Bool
    var body: some View {
        HStack(spacing: Theme.Space.s) {
            PTHearAgainButton { model.repeatChecklist() }
            PTSceneDoneButton(allChecked: allChecked, busy: model.store.autoChecking) { Task { await model.sceneDone() } }
        }
    }
}

/// "Hear it again": speaker icon + label, a 64 pt tall secondary pill (well over the 44 pt minimum).
struct PTHearAgainButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Hear it again", systemImage: "speaker.wave.2.fill")
        }
        .buttonStyle(PTButtonStyle(kind: .secondary, size: 19))
        .fixedSize(horizontal: true, vertical: false)
        .accessibilityLabel("Hear it again")
        .accessibilityHint("Nutmeg reads the checklist out loud")
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
/// long scene needs it. "Done!" sits under it.
struct PTScenePinnedCard: View {
    let model: AppModel
    let index: Int
    private var store: AdventureStore { model.store }

    var body: some View {
        if let scene = store.kit?.scenes[index] {
            VStack(spacing: Theme.Space.m) {
                PTSceneChecklist(model: model, scene: scene, tier: scene.steps.count <= 4 ? 1 : 3)   // the panel is narrower: smaller pictures, same readable text
                PTChecklistActions(model: model, allChecked: store.checkedSteps.count == scene.steps.count)
            }
            .padding(.vertical, Theme.Space.xs)
            .ptPinnedCard()
            .accessibilityElement(children: .contain)
        }
    }
}

struct EndView: View {
    let model: AppModel
    private var playAgain: some View {
        Button { model.store.playAgain() } label: { Label("Play again", systemImage: "arrow.counterclockwise") }
            .buttonStyle(.ptSecondary)
    }
    private var newGame: some View {
        Button { model.art.reset(); model.store.newGame() } label: { Label("New game", systemImage: "sparkles") }
            .buttonStyle(.ptPrimary)
    }
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText("The End!", .hero)
            // Round 10: right after the last "Done!", the finale can still go back to that checklist.
            if model.store.canGoBackToChecklist { PTBackToChecklistButton { model.store.backToChecklist() } }
            // Round 14: natural size in the shared card zone; the two buttons stack when the row doesn't fit.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Theme.Space.m) { playAgain; newGame }
                VStack(spacing: Theme.Space.s) { newGame; playAgain }
            }
        }
    }
}
