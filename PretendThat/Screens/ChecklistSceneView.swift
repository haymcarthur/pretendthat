import SwiftUI
import NutmegCore

// 2026-11-20 (Haylee, decisions/2026-11-20-checklist-then-scenario-scenes.md; layout: design/mockups/checklist-scenes/ v3):
// a play scene is checklists, then a short scenario. Every playing role's checklist card is on screen at once (kids work
// in parallel): the role's picture, name and "1 of 3" on top; each item has a checkbox on the LEFT (kids tick it) and a
// 🔊 on the RIGHT that reads it. Taps while she talks queue up (no marker); the row being read is highlighted. When every
// card is done, Nutmeg says the scenario (with a hear-again 🔊), the cards fold into the "All done!" strip and she goes
// big in the app's normal stage framing. ◀ Previous / ▶ Next scene are one centered pair (`PTSceneNavPair`, RootView).
// iPad: the cards in a row (2 to 3 per row), Nutmeg peeking over the top-right card. iPhone: a shelf like the chat shelf
// holding all the cards (it scrolls inside), Nutmeg's live head in a circle beside the scene title.

/// The checklist scene on the stage (chat closed). `width` × `height` = the zone RootView gives it.
struct ChecklistSceneView: View {
    let model: AppModel
    let index: Int
    var width: CGFloat
    var height: CGFloat
    @Environment(\.layoutMetrics) private var metrics
    private var store: AdventureStore { model.store }

    var body: some View {
        if let scenes = store.kit?.scenes, scenes.indices.contains(index), scenes[index].isChecklist {
            let scene = scenes[index]
            if store.sceneDone(index) && scene.arc == .play {
                PTScenarioPanel(model: model, index: index, scene: scene, width: width, height: height)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if metrics.isPhone {
                // 2026-11-20 (Haylee): the iPhone's checklist is the chat's edge-to-edge bottom sheet, drawn by
                // RootView in the sheet layer (`phoneChecklistSheet`), not in the stage's content zone.
                EmptyView()
            } else {
                PTChecklistBoard(model: model, index: index, scene: scene, width: width, height: height)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Sizes

/// One density for the checklist cards (iPad tiers shrink for 4 to 6 cards; the phone has its own).
struct PTChecklistSize {
    var font: CGFloat
    var name: CGFloat
    var picture: CGFloat
    /// The round check and the 🔊 (both ≥ 44 pt: a tap target).
    var button: CGFloat
    var rowHeight: CGFloat
    var rowGap: CGFloat
    var pad: CGFloat

    static let padLarge = PTChecklistSize(font: 24, name: 30, picture: 72, button: 56, rowHeight: 72, rowGap: 14, pad: 20)
    static let padMedium = PTChecklistSize(font: 21, name: 25, picture: 58, button: 50, rowHeight: 62, rowGap: 10, pad: 16)
    static let padSmall = PTChecklistSize(font: 18, name: 21, picture: 46, button: 44, rowHeight: 54, rowGap: 8, pad: 12)
    /// iPhone (Haylee: more space between items so they don't feel squished).
    static let phone = PTChecklistSize(font: 20, name: 22, picture: 48, button: 48, rowHeight: 62, rowGap: 14, pad: 14)
}

// MARK: - The title (with its 🔊: the scene's cue, or its scenario once done)

struct PTChecklistTitle: View {
    let model: AppModel
    let text: String
    var font: CGFloat = 34
    var speaker: CGFloat = 52
    var body: some View {
        HStack(spacing: Theme.Space.s) {
            Text(text).font(Theme.displayFont(font)).foregroundStyle(Theme.ink)
                .lineLimit(2).minimumScaleFactor(0.7).fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            PTSpeakerButton(size: speaker, tint: Theme.purple, label: "Hear the scene again") { model.repeatScene() }
                .accessibilityIdentifier("scene.titleSpeaker")
        }
    }
}

// MARK: - iPad: the cards in a row, Nutmeg peeking over the top-right card

struct PTChecklistBoard: View {
    let model: AppModel
    let index: Int
    let scene: KitScene
    let width: CGFloat
    let height: CGFloat
    private var store: AdventureStore { model.store }

    /// The board's numbers for this many cards (review pass: worked out once, outside the view body, so the body
    /// stays small enough for the type checker).
    @MainActor private struct BoardLayout {
        let rows: [[ChecklistScenes.Card]]
        let gap: CGFloat
        let cardW: CGFloat
        let size: PTChecklistSize
        let peekW: CGFloat
        let above: CGFloat
        let titleH: CGFloat
        let titleFont: CGFloat
        let topRight: Int

        init(cards: [ChecklistScenes.Card], width: CGFloat, areas: Bool = false) {
            let n = max(1, cards.count)
            // 2026-11-21 (Haylee, area cards): 3 kids = two cards on top, one centered below.
            let columns = n <= 3 ? (areas && n == 3 ? 2 : n) : (n == 4 ? 2 : 3)
            let gap = Theme.Space.m
            let maxW: CGFloat = n == 1 ? 560 : 520
            let fitW: CGFloat = (width - CGFloat(columns - 1) * gap) / CGFloat(columns)
            let cardW = min(maxW, fitW)
            // Her peek over the top-right card: big when there's room, smaller with two rows of cards.
            // 2026-11-20: by rows, not count: 3 kids with area cards are two rows (2 + 1), and the big peek pushed
            // the bottom card past the screen (the board fell back to scrolling and cut it off).
            let oneRow = n <= columns
            let share: CGFloat = oneRow ? 0.42 : 0.34
            let cap: CGFloat = oneRow ? 210 : 150
            let peekW = min(cardW * share, cap)
            var rows: [[ChecklistScenes.Card]] = []
            var i = 0
            while i < cards.count {
                rows.append(Array(cards[i..<min(i + columns, cards.count)]))
                i += columns
            }
            self.rows = rows
            self.gap = gap
            self.cardW = cardW
            self.size = n <= 2 ? .padLarge : (n <= 3 && !areas ? .padMedium : (n <= 4 && areas ? .padMedium : .padSmall))
            self.peekW = peekW
            self.above = NutmegPeek.heightAboveEdge(width: peekW)
            self.titleH = 64
            self.titleFont = n <= 3 ? 34 : 30
            self.topRight = min(columns, n) - 1
        }

        /// The peek's frame height (above the card's edge plus the paws over it).
        var peekH: CGFloat { above + NutmegPeek.pawOverhang(width: peekW) }
    }

    var body: some View {
        let layout = BoardLayout(cards: ChecklistScenes.cards(scene), width: width, areas: scene.areaJobs != nil)
        ViewThatFits(in: .vertical) {
            board(layout)
            ScrollView(.vertical) { board(layout).padding(.bottom, Theme.Space.m) }.scrollIndicators(.visible).frame(height: height)
        }
        .frame(width: width, height: height, alignment: .top)
    }

    private func board(_ L: BoardLayout) -> some View {
        VStack(spacing: L.gap) {
            titleRow(L)
            ForEach(Array(L.rows.enumerated()), id: \.offset) { item in
                cardRow(L, row: item.element, rowIndex: item.offset)
            }
        }
        .padding(.top, max(0, L.above - L.titleH - L.gap))
        .frame(width: width)
    }

    private func titleRow(_ L: BoardLayout) -> some View {
        HStack {
            PTChecklistTitle(model: model, text: ChecklistScenes.shownTitle(scene, number: store.playNumber(index)), font: L.titleFont)
                .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.xs)
                .frame(minHeight: L.titleH)
                .background(Capsule().fill(Theme.white))
                .shadow(color: Theme.panelShadow, radius: 8, y: 2)
            Spacer(minLength: L.peekW + Theme.Space.s)   // the peek rises beside the title
        }
    }

    private func cardRow(_ L: BoardLayout, row: [ChecklistScenes.Card], rowIndex: Int) -> some View {
        HStack(alignment: .top, spacing: L.gap) {
            ForEach(Array(row.enumerated()), id: \.element.role) { item in
                cardView(L, item.element, peeks: rowIndex == 0 && item.offset == L.topRight)
            }
        }
    }

    private func cardView(_ L: BoardLayout, _ card: ChecklistScenes.Card, peeks: Bool) -> some View {
        PTChecklistCard(model: model, scene: scene, card: card, size: L.size,
                        topClearance: peeks ? NutmegPeek.pawClearance(width: L.peekW) : 0)
            .frame(width: L.cardW)
            .background(alignment: .topTrailing) {
                if peeks { peekPart(.back).frame(width: L.peekW, height: L.peekH).offset(x: -Theme.Space.m, y: -L.above) }
            }
            .overlay(alignment: .topTrailing) {
                if peeks {
                    peekPart(.front).frame(width: L.peekW, height: L.peekH).offset(x: -Theme.Space.m, y: -L.above)
                        .allowsHitTesting(false)
                }
            }
    }

    private func peekPart(_ part: NutmegPeek.Part) -> some View {
        NutmegPeek(part: part, state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                   isSpeaking: model.isSpeaking)
    }
}

// MARK: - iPhone: the shelf (like the chat shelf) holding every card

/// 2026-11-20 (Haylee): the same sheet as the iPhone chat (`PTChatPanelShape(shelf: true)`): edge to edge, attached to
/// the bottom of the screen, rounded top corners only, under the ✕ + step rail. RootView places it; the one big button
/// (▶ Let's play! / ▶ The End, or the ◀ / ▶ pair) floats over its bottom, so the rows keep `bottomClearance` free.
struct PTChecklistShelf: View {
    let model: AppModel
    let index: Int
    let scene: KitScene
    var bottomClearance: CGFloat = 0
    private var store: AdventureStore { model.store }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.Space.s) {
                // Her live head in a circle beside the title (Haylee: so the shelf can be taller).
                PTNutmegAvatar(model: model, diameter: 64)
                Text(ChecklistScenes.shownTitle(scene, number: store.playNumber(index)))
                    .font(Theme.displayFont(22)).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.75).fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                PTSpeakerButton(size: 48, tint: Theme.purple, label: "Hear the scene again") { model.repeatScene() }
                    .accessibilityIdentifier("scene.titleSpeaker")
            }
            .padding(.horizontal, Theme.Space.m)
            .padding(.top, Theme.Space.m)
            .padding(.bottom, Theme.Space.s)
            ScrollView(.vertical) {
                VStack(spacing: Theme.Space.m) {
                    ForEach(ChecklistScenes.cards(scene), id: \.role) { card in
                        PTChecklistCard(model: model, scene: scene, card: card, size: .phone)
                    }
                }
                .padding(.horizontal, Theme.Space.s)
                .padding(.bottom, Theme.Space.s)
            }
            .scrollIndicators(.visible)
            .scrollIndicatorsFlash(onAppear: true)
            // The sheet's white footer: the floating button sits on it (like the chat's input row), so the rows
            // stop above it instead of running behind the button.
            Color.clear.frame(height: bottomClearance)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(PTChatPanelShape(shelf: true))
    }
}

// MARK: - One role's checklist card

struct PTChecklistCard: View {
    let model: AppModel
    let scene: KitScene
    let card: ChecklistScenes.Card
    let size: PTChecklistSize
    /// Room at the top for Nutmeg's paws (the card she peeks over).
    var topClearance: CGFloat = 0
    private var store: AdventureStore { model.store }

    var body: some View {
        if let role = store.plan?.role(for: card.role) {
            let tint = Theme.playerColor(role.id.index)
            let done = store.progress.count(scene: scene.id, rows: card.rows)
            let finished = done == card.rows.count
            VStack(alignment: .leading, spacing: size.rowGap) {
                // The header: a tap on the picture or the name reads the whole checklist (the cue: "Tap your picture").
                Button { model.readRole(card.role) } label: {
                    HStack(spacing: Theme.Space.s) {
                        PTCharacterPicture(role: role, image: model.characterPicture(role), size: size.picture, ring: true)
                        titles(role: role, tint: tint)
                        Spacer(minLength: 4)
                        progressMark(done: done, finished: finished)
                    }
                    .frame(minHeight: max(44, size.picture))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PTRowPressStyle(tint: tint))
                .accessibilityLabel(SceneRowTap.accessibilityLabel(roleName: role.roleName))
                .accessibilityValue(finished ? "Done" : "\(done) of \(card.rows.count)")
                ForEach(card.rows, id: \.self) { k in
                    if scene.steps.indices.contains(k) {
                        PTChecklistRow(model: model, text: scene.steps[k].short ?? scene.steps[k].text, step: k, tint: tint,
                                       checked: store.progress.isChecked(scene: scene.id, step: k),
                                       reading: model.checklistReader.highlighted == k, size: size,
                                       picture: scene.areaJobs == nil ? nil : scene.steps[k].picture)
                    }
                }
            }
            .padding(.top, topClearance)
            .padding(size.pad)
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.white))
            .background(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).fill(Theme.line).offset(y: Theme.cardDepth))
            .padding(.bottom, Theme.cardDepth)
            .animation(.easeInOut(duration: 0.2), value: finished)
            .accessibilityElement(children: .contain)
        }
    }
}

extension PTChecklistCard {
    /// The role's name; on an area card (2026-11-21, Haylee: design/mockups/area-setup/) the name is small above the
    /// area job in big text ("Captain" / "Build the cockpit").
    @ViewBuilder func titles(role: Role, tint: Color) -> some View {
        if let job = scene.areaJob(role.id) {
            VStack(alignment: .leading, spacing: 0) {
                Text(role.roleName).font(Theme.headlineFont(size.font * 0.85)).foregroundStyle(tint)
                    .lineLimit(1).minimumScaleFactor(0.6)
                Text(job).font(Theme.displayFont(size.name)).foregroundStyle(Theme.ink)
                    .lineLimit(2).minimumScaleFactor(0.6).fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
        } else {
            Text(role.roleName).font(Theme.headlineFont(size.name)).foregroundStyle(tint)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
    }

    /// "1 of 3", or a green check once the card is done.
    @ViewBuilder func progressMark(done: Int, finished: Bool) -> some View {
        if finished {
            Image(systemName: "checkmark.circle.fill").font(.system(size: size.name * 1.1, weight: .bold))
                .foregroundStyle(Theme.limeShade)
                .accessibilityLabel("Done")
        } else {
            Text("\(done) of \(card.rows.count)").font(Theme.headlineFont(size.font * 0.95)).foregroundStyle(Theme.inkMuted)
                .monospacedDigit()
        }
    }
}

/// One checklist item: the round check on the LEFT (a kid ticks it), the item, the 🔊 on the RIGHT (reads it). The
/// text is a tap target too (reads it). The row being read is highlighted; a ticked row turns green.
struct PTChecklistRow: View {
    let model: AppModel
    let text: String
    let step: Int
    let tint: Color
    let checked: Bool
    let reading: Bool
    let size: PTChecklistSize
    /// 2026-11-21 (area cards): the small picture chip of the object the item places (prop art or the kit page);
    /// nil or `.point` = none.
    var picture: Picture? = nil

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size.rowHeight / 2.6, style: .continuous)
        let fill = checked ? Theme.lime.paleTint(0.28) : tint.paleTint()
        HStack(spacing: Theme.Space.s) {
            PTRoundCheck(checked: checked, size: size.button) { model.tapCheck(step) }
                .accessibilityLabel(checked ? "Checked: \(text)" : "Check: \(text)")
            if let picture, picture != .point {
                model.pictureTile(picture, size: size.button)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.white))
                    .opacity(checked ? 0.6 : 1)
            }
            Button { model.tapChecklistRow(step) } label: {
                Text(text).font(Theme.bodyFont(size.font)).foregroundStyle(checked ? Theme.inkMuted : Theme.ink)
                    // 2026-11-20 (Haylee): up to 3 lines, so a row never ends in "…" on the iPhone.
                    .multilineTextAlignment(.leading).lineLimit(3).minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: size.button, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
            PTSpeakerButton(size: size.button, tint: tint, label: "Hear: \(text)", active: reading) { model.tapChecklistRow(step) }
        }
        .padding(.horizontal, 8)
        .frame(minHeight: size.rowHeight)
        .background(shape.fill(reading ? tint.paleTint(0.32) : fill))
        .overlay(shape.strokeBorder(reading ? tint : .clear, lineWidth: 3))
        .background(shape.fill(checked ? Theme.limeShade.opacity(0.5) : tint.paleTint(0.38)).offset(y: Theme.cardDepth))
        .padding(.bottom, Theme.cardDepth)
        .animation(.easeInOut(duration: 0.18), value: reading)
        .animation(.easeInOut(duration: 0.18), value: checked)
    }
}

/// The round checkbox (a slim depth edge from `Theme.edge`, like every button).
struct PTRoundCheck: View {
    let checked: Bool
    var size: CGFloat = 52
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "checkmark").font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
                .opacity(checked ? 1 : 0)
                .scaleEffect(checked ? 1 : 0.3)
                .frame(width: size, height: size)
        }
        .buttonStyle(PTEdgeCircleStyle(face: checked ? Theme.lime : Theme.white, shade: checked ? Theme.limeShade : Theme.line,
                                       outlined: !checked, edge: Theme.edge(size)))
        .sensoryFeedback(.success, trigger: checked) { _, new in new }
        .animation(Theme.press, value: checked)
    }
}

/// A round 🔊: white face, the icon in the role color, a slim depth edge. `active` = she's reading this one.
struct PTSpeakerButton: View {
    var size: CGFloat = 52
    var tint: Color = Theme.purple
    var label: String
    var active = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill").font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(active ? Theme.white : tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(PTEdgeCircleStyle(face: active ? tint : Theme.white, shade: tint.opacity(0.3), outlined: false, edge: Theme.edge(size)))
        .accessibilityLabel(label)
    }
}

/// A round button face on its slim depth edge; a press pushes the face down by the edge (Haylee: thinner button edges).
struct PTEdgeCircleStyle: ButtonStyle {
    let face: Color
    let shade: Color
    var outlined = false
    let edge: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        let down = configuration.isPressed ? edge : 0
        configuration.label
            .background(Circle().fill(face))
            .overlay(Circle().strokeBorder(outlined ? Theme.line : .clear, lineWidth: 2))
            .offset(y: down)
            .background(Circle().fill(shade).offset(y: edge))
            .padding(.bottom, edge)
            .contentShape(Circle())
            .animation(Theme.press, value: configuration.isPressed)
    }
}

// MARK: - The scenario moment

/// Every card is done: the scenario in a bubble beside Nutmeg (she's back on the stage, big, in the normal framing),
/// "Hear it again", and the cards folded into the "All done!" strip.
struct PTScenarioPanel: View {
    let model: AppModel
    let index: Int
    let scene: KitScene
    let width: CGFloat
    let height: CGFloat
    @Environment(\.layoutMetrics) private var metrics
    private var store: AdventureStore { model.store }

    var body: some View {
        let phone = metrics.isPhone
        let line = store.scenarioLine(index) ?? scene.nutmegSays
        let parts = Self.split(line)
        VStack(spacing: phone ? Theme.Space.s : Theme.Space.m) {
            Spacer(minLength: 0)
            VStack(alignment: .leading, spacing: phone ? Theme.Space.s : Theme.Space.m) {
                (Text(parts.0).foregroundStyle(Theme.ink) + Text(parts.1.isEmpty ? "" : " " + parts.1).foregroundStyle(Theme.purple))
                    .font(Theme.headlineFont(phone ? 21 : 30))
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                Button { model.hearScenario() } label: {
                    HStack(spacing: Theme.Space.s) {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: phone ? 20 : 26, weight: .bold))
                            .foregroundStyle(Theme.purple)
                            .frame(width: phone ? 48 : 64, height: phone ? 48 : 64)
                            .background(Circle().fill(Theme.chipGray))
                        Text("Hear it again").font(Theme.headlineFont(phone ? 18 : 24)).foregroundStyle(Theme.inkMuted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PTPressStyle())
                .accessibilityLabel("Hear it again")
            }
            .padding(phone ? Theme.Space.m : Theme.Space.l)
            .frame(maxWidth: phone ? .infinity : min(width, 620), alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.white))
            .shadow(color: Theme.panelShadow, radius: 10, y: 3)
            PTAllDoneStrip(model: model, scene: scene, phone: phone)
            Spacer(minLength: 0)
        }
        .frame(width: width, height: height)
    }

    /// "Pretend that … uh-oh!" and "Everyone, …!" (the everyone action shows in purple, like the mockup).
    static func split(_ line: String) -> (String, String) {
        guard let r = line.range(of: "Everyone", options: .backwards) ?? line.range(of: "everyone", options: .backwards),
              r.lowerBound > line.startIndex else { return (line, "") }
        let head = line[..<r.lowerBound].trimmingCharacters(in: .whitespaces)
        // Only when "Everyone" starts the last sentence.
        guard let last = head.last, ".!?…".contains(last) else { return (line, "") }
        return (head, String(line[r.lowerBound...]))
    }
}

/// The cards folded up: "✓ All done!" and each playing role's picture with a check.
struct PTAllDoneStrip: View {
    let model: AppModel
    let scene: KitScene
    var phone = false
    private var store: AdventureStore { model.store }
    var body: some View {
        let pic: CGFloat = phone ? 40 : 56
        HStack(spacing: phone ? 6 : Theme.Space.s) {
            Image(systemName: "checkmark").font(.system(size: phone ? 18 : 24, weight: .heavy)).foregroundStyle(Theme.limeShade)
            Text("All done!").font(Theme.headlineFont(phone ? 18 : 24)).foregroundStyle(Theme.limeShade).fixedSize()
            ForEach(ChecklistScenes.cards(scene), id: \.role) { card in
                if let role = store.plan?.role(for: card.role) {
                    PTCharacterPicture(role: role, image: model.characterPicture(role), size: pic, ring: true)
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "checkmark.circle.fill").font(.system(size: pic * 0.36, weight: .bold))
                                .foregroundStyle(Theme.limeShade).background(Circle().fill(Theme.white))
                        }
                }
            }
        }
        .padding(.horizontal, Theme.Space.m).padding(.vertical, Theme.Space.s)
        .background(Capsule().fill(Theme.white))
        .shadow(color: Theme.panelShadow, radius: 8, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("All done!")
    }
}

// MARK: - Resume offer (start screen)

/// 2026-11-20 (Haylee): the game left mid-play, offered on the start screen after a relaunch, in the saved-game offer's
/// style: just its picture (with a ▶ on it), a tap continues at the scene it was on. A small ✕ forgets it. Home stays
/// silent (round 19), so Nutmeg says nothing here.
struct PTResumeOffer: View {
    let offer: ResumeOffer
    let cover: UIImage?
    var phone = false
    let onContinue: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        let box = phone ? CGSize(width: 120, height: 80) : CGSize(width: 220, height: 150)
        ZStack(alignment: .topTrailing) {
            PTSoundsLikeOffer(game: offer.game, cover: cover, box: box, onReplay: onContinue)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "play.fill").font(.system(size: phone ? 16 : 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                        .frame(width: phone ? 34 : 46, height: phone ? 34 : 46)
                        .background(Circle().fill(Theme.lime))
                        .offset(x: 6, y: 6)
                        .allowsHitTesting(false)
                }
                .accessibilityLabel("Keep playing \(offer.game.title)")
                .accessibilityIdentifier("resume.continue")
            Button(action: onDismiss) {
                Image(systemName: "xmark").font(.system(size: 13, weight: .heavy)).foregroundStyle(Theme.inkMuted)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Theme.white))
                    .overlay(Circle().strokeBorder(Theme.line, lineWidth: 1.5))
                    .frame(width: 44, height: 44)   // tap target
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .offset(x: 16, y: -16)
            .accessibilityLabel("Don't keep playing")
            .accessibilityIdentifier("resume.dismiss")
        }
    }
}
