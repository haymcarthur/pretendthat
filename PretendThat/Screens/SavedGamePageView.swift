import SwiftUI
import NutmegCore

/// Saved game page (Haylee, decisions/2026-11-17-saved-game-page-and-play-bar.md; mockup design/mockups/after-cancel,
/// 2-game-page-a.png, WITHOUT the player picker). Opened by a bookshelf card, for everyone. On the stage: Nutmeg peeks
/// over a white sheet (`NutmegPeek`), which holds the cover and title, the big "Play with Nutmeg" (the one main action,
/// ▶ and her face on it: kids 4–8 can't read), the printables (Color / Black & white, the kit pages, always the full
/// 6-role sheets) and Print (one tap; the iOS print sheet is the second). Without a pass, Play opens Nutmeg's
/// ask-a-grown-up card (no prices), then the gate and the grown-up card.
struct SavedGamePageView: View {
    let model: AppModel
    let game: SavedGame
    @Environment(\.layoutMetrics) private var metrics

    private var phone: Bool { metrics.isPhone }

    var body: some View {
        GeometryReader { geo in
            let full = CGSize(width: geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing,
                              height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let curtain = PTCurtain.metrics(full)
            let sheetW = min(full.width - (phone ? 0 : 2 * Theme.Space.xl), 760)
            let peekW = phone ? min(full.width * 0.42, 190) : 200
            let above = NutmegPeek.heightAboveEdge(width: peekW), overhang = NutmegPeek.pawOverhang(width: peekW)
            let sheetTop = max(curtain.valance * 0.55, geo.safeAreaInsets.top + 8) + above
            ZStack(alignment: .top) {
                PTStageBackdrop()
                // Nutmeg behind the sheet (tail, body), paws in front of its top edge, looking down at the page.
                NutmegPeek(part: .back, state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                           isSpeaking: model.isSpeaking)
                    .frame(width: peekW, height: above + overhang)
                    .position(x: full.width / 2, y: sheetTop - above + (above + overhang) / 2)
                    .allowsHitTesting(false)
                sheet(width: sheetW, bottomInset: geo.safeAreaInsets.bottom, topClear: overhang)
                    .frame(width: sheetW, height: full.height - sheetTop)
                    .background(UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous).fill(Theme.white))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 36, topTrailingRadius: 36, style: .continuous))
                    .shadow(color: Theme.panelShadow, radius: 12, y: -2)
                    .position(x: full.width / 2, y: sheetTop + (full.height - sheetTop) / 2)
                NutmegPeek(part: .front, state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                           isSpeaking: model.isSpeaking)
                    .frame(width: peekW, height: above + overhang)
                    .position(x: full.width / 2, y: sheetTop - above + (above + overhang) / 2)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                PTIconButton(symbol: "arrow.left", label: SavedGamePageCopy.back, fill: Theme.white, size: phone ? 52 : 64) { model.closeSavedPage() }
                    .shadow(color: Theme.panelShadow, radius: 8, y: 2)
                    .position(x: (phone ? 16 : max(Theme.Space.l, curtain.visible * 0.3)) + (phone ? 26 : 32),
                              y: max(curtain.valance, geo.safeAreaInsets.top) + (phone ? 34 : 40))
                if model.savedPageAsk {
                    SavedPageAskCard(model: model, game: game, size: full, safe: geo.safeAreaInsets)
                        .transition(.opacity)
                        .zIndex(3)
                }
            }
            .frame(width: full.width, height: full.height)
            .offset(x: -geo.safeAreaInsets.leading, y: -geo.safeAreaInsets.top)
        }
        .animation(.easeOut(duration: 0.25), value: model.savedPageAsk)
        .sheet(isPresented: Binding(get: { model.savedPageGrownUp }, set: { model.savedPageGrownUp = $0 })) {
            SavedPageGrownUpSheet(model: model, game: game)
        }
    }

    // MARK: The sheet

    private func sheet(width: CGFloat, bottomInset: CGFloat, topClear: CGFloat) -> some View {
        let pad: CGFloat = phone ? 20 : 32
        return ScrollView {
            VStack(alignment: .leading, spacing: phone ? 20 : 26) {
                header
                playButton
                printables(width: width - 2 * pad)
                printButton
            }
            .padding(.horizontal, pad)
            .padding(.top, topClear + (phone ? 14 : 20))
            .padding(.bottom, max(bottomInset, 16) + 8)
        }
        .scrollIndicators(.hidden)
    }

    private var header: some View {
        let coverW: CGFloat = phone ? 132 : 160
        return HStack(spacing: phone ? 14 : 20) {
            Group {
                if let c = model.cover(for: game) {
                    Image(uiImage: c).resizable().aspectRatio(contentMode: .fill)
                } else {
                    Theme.startSky
                }
            }
            .frame(width: coverW, height: coverW * 2 / 3)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Theme.white, lineWidth: 4))
            .shadow(color: Theme.panelShadow, radius: 6, y: 2)
            .accessibilityHidden(true)
            Text(game.title).font(Theme.displayFont(phone ? 26 : 36)).foregroundStyle(Theme.ink)
                .lineLimit(3).minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
        }
    }

    /// The one main action: big, yellow, ▶ and Nutmeg's face (her live head: it talks when she does).
    private var playButton: some View {
        let h: CGFloat = phone ? 84 : 96
        return Button { model.tapPlaySavedPage() } label: {
            HStack(spacing: phone ? 10 : 16) {
                Image(systemName: "play.fill").font(.system(size: phone ? 30 : 38, weight: .black)).foregroundStyle(Theme.ink)
                PTNutmegAvatar(model: model, diameter: phone ? 56 : 72)
                Text(SavedGamePageCopy.play).font(Theme.displayFont(phone ? 25 : 34)).foregroundStyle(Theme.ink)
                    .lineLimit(1).minimumScaleFactor(0.6)
            }
            .padding(.horizontal, phone ? 14 : 24)
            .frame(maxWidth: .infinity, minHeight: h)
            .background(Capsule().fill(Theme.yellow))
            .background(Capsule().fill(Theme.yellowShade).offset(y: Theme.depth))
            .padding(.bottom, Theme.depth)
            .contentShape(Capsule())
        }
        .buttonStyle(PTPressStyle())
        .accessibilityLabel(SavedGamePageCopy.play)
        .accessibilityIdentifier("savedPage.play")
    }

    @ViewBuilder private func printables(width: CGFloat) -> some View {
        let pages = model.savedPagePages
        VStack(alignment: .leading, spacing: phone ? 12 : 16) {
            HStack(alignment: .firstTextBaseline) {
                Text(SavedGamePageCopy.printables).font(Theme.headlineFont(phone ? 22 : 28)).foregroundStyle(Theme.ink)
                Spacer()
                Text(SavedGamePageCopy.pageCount(pages.count)).font(Theme.bodyFont(phone ? 17 : 20)).foregroundStyle(Theme.inkMuted)
            }
            if model.savedPageSets.count > 1 {
                HStack(spacing: phone ? 10 : 14) {
                    setButton(.fullColor)
                    setButton(.colorIn)
                }
            }
            let thumbW: CGFloat = phone ? 132 : 148
            let thumbH = thumbW * KitPageView.size.height / KitPageView.size.width
            let art = model.pageArtSet(model.savedPageStyle)
            ScrollView(.horizontal) {
                HStack(spacing: phone ? 12 : 16) {
                    ForEach(pages.indices, id: \.self) { i in
                        art.pageView(pages[i])
                            .scaleEffect(thumbW / KitPageView.size.width)
                            .frame(width: thumbW, height: thumbH)
                            .background(Theme.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.line, lineWidth: 1))
                            .shadow(color: Theme.panelShadow, radius: 4, y: 2)
                            .padding(.vertical, 6)
                            .accessibilityLabel("Page \(i + 1)")
                    }
                }
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func setButton(_ style: PrintStyle) -> some View {
        let on = model.savedPageStyle == style
        return Button { model.savedPageStyle = style } label: {
            // 2026-11-18 (Haylee: the label was cut off): words only, no dot / ring icons, so the label fits everywhere.
            Text(style == .fullColor ? SavedGamePageCopy.color : SavedGamePageCopy.blackAndWhite)
                .font(Theme.headlineFont(phone ? 18 : 22)).foregroundStyle(Theme.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: phone ? 56 : 64)
            .background(Capsule().fill(on ? Theme.cream : Theme.white))
            .overlay(Capsule().strokeBorder(on ? Theme.yellow : Theme.lavenderShade, lineWidth: on ? 4 : 2.5))
            .contentShape(Capsule())
        }
        .buttonStyle(PTPressStyle())
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var printButton: some View {
        Button { model.printSavedPage() } label: {
            Label(SavedGamePageCopy.print, systemImage: "printer.fill")
                .font(Theme.displayFont(phone ? 24 : 30)).foregroundStyle(Theme.white)
                .frame(maxWidth: .infinity, minHeight: phone ? 68 : 80)
                .background(Capsule().fill(Theme.cta))
                .background(Capsule().fill(Color.black).offset(y: Theme.depth))
                .padding(.bottom, Theme.depth)
                .contentShape(Capsule())
        }
        .buttonStyle(PTPressStyle())
        .accessibilityIdentifier("savedPage.print")
    }
}

/// A button that dips a little when pressed (the page's big buttons).
struct PTPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Theme.press, value: configuration.isPressed)
    }
}

/// Nutmeg's ask-a-grown-up card (mockup 3): her line in a speech bubble, OK and Grown-ups (lock), Nutmeg pointing at
/// it, and a speaker that says it again. Kids never see prices here.
struct SavedPageAskCard: View {
    let model: AppModel
    let game: SavedGame
    let size: CGSize
    let safe: EdgeInsets
    @Environment(\.layoutMetrics) private var metrics

    var body: some View {
        let phone = metrics.isPhone
        let cardW = min(size.width - 2 * (phone ? 20 : 40), 620)
        let nutH = min(size.height * (phone ? 0.34 : 0.42), phone ? 330 : 440)
        ZStack(alignment: .topLeading) {
            Theme.scrim.ignoresSafeArea().onTapGesture { model.savedPageAsk = false }
            VStack(alignment: .leading, spacing: phone ? 22 : 28) {
                Text(SavedGamePageCopy.askGrownUp(title: game.title))
                    .font(Theme.displayFont(phone ? 26 : 34)).foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Button { model.savedPageAsk = false } label: {
                        Text(SavedGamePageCopy.ok).font(Theme.headlineFont(phone ? 22 : 26)).foregroundStyle(Theme.purple)
                            .frame(minWidth: phone ? 96 : 130, minHeight: phone ? 64 : 72)
                            .background(Capsule().strokeBorder(Theme.purple.opacity(0.45), lineWidth: 2.5))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PTPressStyle())
                    Button { model.savedPageGrownUps() } label: {
                        Label(SavedGamePageCopy.grownUps, systemImage: "lock.fill")
                            .font(Theme.headlineFont(phone ? 22 : 26)).foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, minHeight: phone ? 64 : 72)
                            .background(Capsule().fill(Theme.yellow))
                            .background(Capsule().fill(Theme.yellowShade).offset(y: Theme.depth))
                            .padding(.bottom, Theme.depth)
                            .contentShape(Capsule())
                    }
                    .buttonStyle(PTPressStyle())
                    .accessibilityIdentifier("savedPage.grownUps")
                }
            }
            .padding(phone ? 26 : 34)
            .frame(width: cardW, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.white))
            .overlay(alignment: .bottomLeading) {
                // The bubble's tail, toward Nutmeg below.
                Triangle().fill(Theme.white).frame(width: 44, height: 30).offset(x: cardW * 0.3, y: 28)
            }
            .position(x: size.width / 2, y: size.height - nutH - safe.bottom - 40 - 130)
            NutmegCharacter(state: model.nutmegState, mouthLevel: model.mouthLevel, mouthShape: model.mouthShape,
                            isSpeaking: model.isSpeaking, forcedPose: .point, showsGround: false)
                .frame(width: nutH * 1178 / 1335, height: nutH)
                .position(x: (size.width - cardW) / 2 + nutH * 0.36, y: size.height - safe.bottom - nutH / 2 - 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            Button { model.repeatSavedPageAsk() } label: {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: phone ? 30 : 36, weight: .bold)).foregroundStyle(Theme.ink)
                    .frame(width: phone ? 84 : 96, height: phone ? 84 : 96)
                    .background(Circle().fill(Theme.white))
                    .background(Circle().fill(Theme.lavenderShade).offset(y: 5))
                    .contentShape(Circle())
            }
            .buttonStyle(PTPressStyle())
            .accessibilityLabel("Hear it again")
            .position(x: (size.width + cardW) / 2 - (phone ? 46 : 52), y: size.height - safe.bottom - (phone ? 70 : 90))
        }
        .frame(width: size.width, height: size.height)
    }
}

private struct Triangle: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY)); p.addLine(to: CGPoint(x: r.maxX, y: r.minY)); p.addLine(to: CGPoint(x: r.minX + r.width * 0.25, y: r.maxY))
        p.closeSubpath()
        return p
    }
}

/// Behind the gate (mockup 5, WITHOUT the footnote: the Free Preview games don't replay either, Haylee 2026-11-17):
/// "Your saved games are still yours." with See passes (the plans) and Not now.
struct SavedPageGrownUpSheet: View {
    let model: AppModel
    let game: SavedGame
    @State private var unlocked: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-PTGateOpen")
        #else
        return false
        #endif
    }()
    @State private var showingPasses = false
    @State private var webPage: GUWebPage?

    var body: some View {
        NavigationStack {
            ScrollView {
                Group {
                    if !unlocked {
                        PTGrownUpGate(onPass: { withAnimation(Theme.gentle) { unlocked = true } }).frame(maxWidth: .infinity)
                    } else if showingPasses {
                        PlansContent(model: model, mode: .grownUps, webPage: $webPage)
                            .onAppear { Analytics.send(.paywallShown(.showsUsedUp)) }
                    } else {
                        card
                    }
                }
                .padding(Theme.Space.l)
            }
            .background(Theme.white)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { model.savedPageGrownUp = false } } }
        }
        .tint(Theme.purple)
        .guSafari($webPage)
        .modifier(GUPageSizing())
    }

    private var card: some View {
        VStack(spacing: Theme.Space.m) {
            if let c = model.cover(for: game) {
                Image(uiImage: c).resizable().aspectRatio(3 / 2, contentMode: .fill)
                    .frame(maxWidth: 360)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Theme.white, lineWidth: 6))
                    .shadow(color: Theme.panelShadow, radius: 10, y: 3)
                    .accessibilityHidden(true)
            }
            Text(game.title).font(OBType.small.weight(.semibold)).foregroundStyle(Theme.inkMuted)
            Text(SavedGamePageCopy.grownUpTitle).font(OBType.title).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
            Text(SavedGamePageCopy.grownUpBody).font(OBType.body).foregroundStyle(Theme.ink)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            OBPrimaryButton(label: SavedGamePageCopy.seePasses, symbol: "ticket.fill") { withAnimation(Theme.gentle) { showingPasses = true } }
                .frame(maxWidth: 420)
                .padding(.top, Theme.Space.s)
                .accessibilityIdentifier("savedPage.seePasses")
            Button(SavedGamePageCopy.notNow) { model.savedPageGrownUp = false }
                .font(OBType.button).foregroundStyle(Theme.purple)
                .frame(minHeight: 56)
        }
        .frame(maxWidth: .infinity)
    }
}
