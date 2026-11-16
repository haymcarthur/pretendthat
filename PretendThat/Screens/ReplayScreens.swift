import SwiftUI
import NutmegCore

// Round D1 (Haylee, design §D5 with her answers): a replay's Pick, Props and Paper steps, in the same card zone as a
// first play's screens. Kids tap; Nutmeg says each step's line (live voice in D1). No AI calls for content.

/// Pick on a replay: only "how many are playing?" (1–6). The playing roles show as their badges, then Let's go!.
struct ReplayPickView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    var body: some View {
        VStack(spacing: Theme.Space.l) {
            PTText(store.currentTitle, .title).multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.7)
            // Two rows of three (six in a row reached Nutmeg's face in the card zone).
            VStack(spacing: Theme.Space.s) {
                ForEach([1, 4], id: \.self) { first in
                    HStack(spacing: Theme.Space.s) {
                        ForEach(first..<(first + 3), id: \.self) { n in
                            PTChoiceTile(label: "\(n)", isSelected: store.playerCount == n, size: 92) { model.replayPick(n) }
                        }
                    }
                }
            }
            if store.playerCount > 0 {
                let roles = store.playingRoles
                // Rows of three badges (4–6 roles wrap).
                VStack(spacing: Theme.Space.m) {
                    ForEach(Array(stride(from: 0, to: roles.count, by: 3)), id: \.self) { row in
                        HStack(spacing: Theme.Space.s) {
                            ForEach(Array(roles[row..<min(row + 3, roles.count)].enumerated()), id: \.element.id) { i, r in
                                PTRoleBadge(role: r, size: 96).ptPopIn(index: row + i)
                            }
                        }
                    }
                }
                Button { model.replayPickDone() } label: { Label("Let's go!", systemImage: "arrow.right") }
                    .buttonStyle(.ptPrimary)
            }
        }
        .animation(Theme.springy, value: store.playerCount)
    }
}

/// Props on a replay: the whole saved list at once ("Do you still have these?"). Every card starts as Got it; Don't
/// have it makes it a pretend swap (its saved alternate is one tap away). One big All set!.
struct ReplayPropsView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            PTText("Do you still have these?", .headline)
            let props = store.props?.props ?? []
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: Theme.Space.s), count: props.count <= 4 ? 2 : 3),
                      spacing: Theme.Space.s) {
                ForEach(props) { p in
                    PTReplayPropCard(prop: p, alternate: store.replayAlternate(for: p.id).flatMap(PropLibrary.name),
                                     onHave: { model.replayProp(p.id, have: $0) },
                                     onAlternate: { model.replayUseAlternate(p.id) })
                }
            }
            Button { model.replayPropsDone() } label: { Text("All set!").frame(maxWidth: .infinity) }
                .buttonStyle(.ptSuccess)
        }
    }
}

/// One saved prop: its art, the item and what it becomes, Got it / Don't have it. Missing = the pretend look.
struct PTReplayPropCard: View {
    let prop: Prop
    let alternate: String?
    let onHave: (Bool) -> Void
    let onAlternate: () -> Void
    var body: some View {
        let missing = prop.isSkipped
        VStack(spacing: Theme.Space.xs) {
            ZStack(alignment: .topTrailing) {
                if let id = prop.libraryID, let art = UIImage(named: PropLibrary.asset(id)) {
                    Image(uiImage: art).resizable().scaledToFit().frame(height: 52)
                        .opacity(missing ? 0.45 : 1).saturation(missing ? 0.3 : 1)
                }
                if missing {
                    Text("Pretend").font(Theme.headlineFont(13)).foregroundStyle(Theme.white)
                        .padding(.horizontal, 8).padding(.vertical, 3).background(Capsule().fill(Theme.purple))
                        .offset(x: 18, y: -6)
                }
            }
            .frame(maxWidth: .infinity)
            Text(prop.householdItem).font(Theme.headlineFont(18)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(prop.becomes).font(Theme.bodyFont(15)).foregroundStyle(Theme.inkMuted)
                .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
            // Round 25 (Haylee: fewer buttons): ONE toggle instead of a Got it / Don't have it pair. Every card starts
            // as Got it (the green card says so); the button offers the other answer.
            if missing {
                choice("Found it!", "checkmark", on: true, tint: Theme.lime) { onHave(true) }
            } else {
                choice("Don't have it", "xmark", on: false, tint: Theme.coral) { onHave(false) }
            }
            if missing, let alternate {
                Button(action: onAlternate) {
                    Text("Use a \(alternate.lowercased()) instead?").font(Theme.headlineFont(14)).foregroundStyle(Theme.purple)
                        .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.Space.s)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(missing ? Theme.cream : Theme.limeTint))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(missing ? Theme.purple.opacity(0.35) : Theme.limeShade, style: StrokeStyle(lineWidth: 2, dash: missing ? [6, 4] : [])))
        .animation(Theme.springy, value: missing)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(prop.householdItem), \(prop.becomes)\(missing ? ", pretend" : "")")
    }

    private func choice(_ title: String, _ symbol: String, on: Bool, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol).font(Theme.headlineFont(15)).lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(on ? Theme.ink : Theme.inkMuted)
                .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 36)
                .background(Capsule().fill(on ? tint : Theme.white))
                .overlay(Capsule().strokeBorder(Theme.line, lineWidth: on ? 0 : 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

/// Print on a replay: Print everything / Just the badges (the saved art, rebuilt for this count) and Let's play!.
/// Round 25 (Haylee: fewer buttons): no Draw it (the no-printer path is gone), and "Skip, we have them" merged into
/// Let's play! (both went straight to Play), which is always there.
struct ReplayPaperView: View {
    let model: AppModel
    private var store: AdventureStore { model.store }
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            PTText("Print", .title)
            ForEach([PaperChoice.everything, .badges], id: \.self) { c in
                let picked = store.replayPrinted == c
                Button { model.replayPaper(c) } label: {
                    Label(c.label, systemImage: picked ? "checkmark.circle.fill" : c.symbol).frame(maxWidth: .infinity)
                }
                .buttonStyle(picked ? .ptSecondary : .ptPrimary)
            }
            Button { model.replayPaper(.skip) } label: { Label("Let's play!", systemImage: "play.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.ptSuccess)
        }
        .frame(maxWidth: 420)
        .animation(Theme.springy, value: store.replayPrinted)
    }
}
