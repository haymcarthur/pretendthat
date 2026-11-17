import SwiftUI
import UIKit
import NutmegCore

/// iPhone version (2026-11-17): the ONE place the app decides between the iPad layout and the iPhone (portrait)
/// layout, and the sizes that differ. RootView reads the horizontal size class once (the iPad app is full screen and
/// landscape only, so it is always `.regular` there; an iPhone in portrait is `.compact`) and injects the result as
/// `\.layoutMetrics`, so sheets and full-screen covers (whose own size class can differ) get the same answer.
/// `.pad` returns exactly the iPad's existing numbers: every iPad layout is unchanged.
struct LayoutMetrics: Equatable, Sendable {
    var isPhone: Bool

    static let pad = LayoutMetrics(isPhone: false)
    static let phone = LayoutMetrics(isPhone: true)

    init(isPhone: Bool) { self.isPhone = isPhone }
    init(horizontal: UserInterfaceSizeClass?) { isPhone = horizontal == .compact }

    // MARK: Control pill (Hear it again · Mic · Chat)

    var pillSide: CGFloat { isPhone ? 58 : PTControlBar.side }
    var pillMic: CGFloat { isPhone ? 82 : PTControlBar.micSize }
    var pillInset: CGFloat { isPhone ? 8 : PTControlBar.inset }
    var pillGap: CGFloat { isPhone ? 16 : PTControlBar.gap }
    /// The pill's full height (the mic's circle plus its backing).
    var pillHeight: CGFloat { pillMic + 2 * pillInset }
    /// Space under the pill (above the home indicator on the phone).
    var pillBottom: CGFloat { isPhone ? 2 : Theme.Space.m }

    // MARK: Phone chrome (top bar = the X + the compact step rail)

    /// The compact rail's height (and the X's row).
    static let phoneTopBar: CGFloat = 68
    static let phoneClose: CGFloat = 48
    static let phoneSide: CGFloat = 12

    /// The top bar's distance from the top of the safe area: just under the valance.
    static func phoneTopInset(screen: CGSize, safeTop: CGFloat) -> CGFloat {
        max(0, PTCurtain.metrics(screen).valance - safeTop) + 6
    }

    /// The phone stage's free band (stage coordinates, the stage = the safe area): from under the top bar to above the
    /// control pill.
    /// The phone stage geometry's bottom inset (the pill's room).
    var phoneChromeBottom: CGFloat { pillBottom + pillHeight + 6 }

    func phoneBand(stage: CGSize, screen: CGSize, safeTop: CGFloat) -> (top: CGFloat, bottom: CGFloat) {
        let top = Self.phoneTopInset(screen: screen, safeTop: safeTop) + Self.phoneTopBar + 8
        let bottom = stage.height - phoneChromeBottom
        return (top, max(top + 120, bottom))
    }

    /// The phone's first framing (start screen hand-off and the talking stage): whole body, filling the band.
    func phoneFirstFrame(stage: CGSize, screen: CGSize, safeTop: CGFloat, writing: Bool = false) -> PTStageFrame {
        let band = phoneBand(stage: stage, screen: screen, safeTop: safeTop)
        let split = PTPhoneStage.split(width: stage.width, top: band.top, bottom: band.bottom, content: 0)
        return PTStageFrame(shot: .closeUp, writing: writing, phoneRegion: split.nutmeg)
    }

    // MARK: Content zone heights under Nutmeg (phone)

    enum PhoneContent: Equatable {
        case none, hunt, cards, print, scene(rows: Int), end, cover, players, propsGrid
    }

    /// How tall the content zone below her asks to be (clamped by `PTPhoneStage.split`, which keeps her on screen).
    static func phoneContentHeight(_ c: PhoneContent, noVoice: Bool = false) -> CGFloat {
        switch c {
        case .none: 0
        case .hunt: 268
        case .cards: 300
        case .print: 340
        case .scene(let rows): 64 + CGFloat(rows) * 78 + 118
        case .end: 232
        case .cover: noVoice ? 470 : 270
        case .players: 320
        case .propsGrid: 2000
        }
    }
}

extension EnvironmentValues {
    /// iPhone version: iPad (`.pad`, the default) or iPhone portrait (`.phone`). Set once at the root.
    @Entry var layoutMetrics = LayoutMetrics.pad
}

/// The device word for grown-up text ("this iPad" / "this iPhone"). Text only: layouts go through `LayoutMetrics`.
@MainActor enum PTDevice {
    static var noun: String { UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "iPad" }
}

/// The key window's safe-area insets (full-screen views that ignore the safe area still keep their buttons clear of
/// the Dynamic Island and the home indicator on the phone).
/// (Measured once by RootView from SwiftUI's own layout and injected; reading the UIKit window during a view update
/// fed back into layout and froze the start screen's intro on the phone.)
extension EnvironmentValues {
    @Entry var ptSafeInsets = EdgeInsets()
}
