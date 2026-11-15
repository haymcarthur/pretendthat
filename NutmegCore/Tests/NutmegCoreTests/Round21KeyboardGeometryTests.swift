import CoreGraphics
import Testing
@testable import NutmegCore

/// Round 21 (Haylee: with the chat open and the keyboard up, Nutmeg rendered tiny): the round 14 rule. The stage keeps
/// its exact framing when the keyboard opens; the keyboard only covers its lower part.
struct Round21KeyboardGeometryTests {
    static let screens = [CGSize(width: 1210, height: 834), CGSize(width: 1376, height: 1032), CGSize(width: 1180, height: 820)]
    static func floor(_ s: CGSize) -> CGRect { CGRect(x: s.width * 0.2, y: s.height * 0.78, width: s.width * 0.6, height: s.height * 0.12) }

    @Test func keyboardNeverShortensTheStage() {
        for s in Self.screens {
            let keyboard = s.height * 0.45
            let measured = CGSize(width: s.width - 392, height: s.height - keyboard)   // chat open, keyboard up
            let size = PTStageGeometry.keyboardProofSize(measured, reference: s)
            #expect(size.height == s.height)            // the keyboard takes no height
            #expect(size.width == measured.width)       // the chat panel still narrows it
            #expect(PTStageGeometry.keyboardProofSize(measured, reference: nil) == measured)
        }
    }

    @Test func herFramingIsIdenticalWithTheKeyboardUp() {
        for s in Self.screens {
            for chat in [false, true] {
                let width = s.width - (chat ? 392 : 0)
                func layout(_ h: CGFloat) -> PTStageCamera.Layout {
                    let size = PTStageGeometry.keyboardProofSize(CGSize(width: width, height: h), reference: s)
                    let g = PTStageGeometry(size: size, leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom,
                                            floor: Self.floor(s), chatOpen: chat, referenceSize: s)
                    return PTStageCamera.layout(PTStageFrame(shot: .closeUp), g)
                }
                let closed = layout(s.height), up = layout(s.height * 0.55)
                #expect(abs(closed.k - up.k) < 0.0001, "scale changed with the keyboard (chat \(chat))")
                #expect(abs(closed.origin.x - up.origin.x) < 0.01 && abs(closed.origin.y - up.origin.y) < 0.01)
            }
        }
    }

    /// Round 21 (Haylee: the choice buttons "show up on top"): with a choice row along the top, her close-up keeps her
    /// ears below it, chat open or closed.
    @Test func closeUpClearsATopChoiceRow() {
        for s in Self.screens {
            for chat in [false, true] {
                let g = PTStageGeometry(size: CGSize(width: s.width - (chat ? 392 : 0), height: s.height),
                                        leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom,
                                        floor: Self.floor(s), chatOpen: chat, referenceSize: s)
                let reserve: CGFloat = 150
                let L = PTStageCamera.layout(PTStageFrame(shot: .closeUp, topReserve: reserve, fitClosed: true), g)
                let earTop = L.origin.y + PTStageCamera.headTop * L.k
                #expect(earTop >= g.free.minY + reserve - 1, "ears at \(earTop) (chat \(chat))")
                let plain = PTStageCamera.layout(PTStageFrame(shot: .closeUp, fitClosed: true), g)
                #expect(L.k <= plain.k)
            }
        }
    }
}
