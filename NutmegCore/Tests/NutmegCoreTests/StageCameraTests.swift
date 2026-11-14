import CoreGraphics
import Testing
@testable import NutmegCore

/// One shared stage (fix round 2): her feet sit on the floor surface in every phase and shot, on 11" and 13" iPads,
/// with the chat panel open or closed.
struct StageCameraTests {
    /// iPad Pro 11" and 13" landscape (points); the chat panel takes 360 + 2 × 16.
    static let screens = [CGSize(width: 1210, height: 834), CGSize(width: 1376, height: 1032)]

    /// PTStage.floor (the start screen's floor oval), replicated: curtain swag reach, then the ellipse.
    static func floor(_ s: CGSize) -> CGRect {
        let h = min(s.height, s.width * 1.15), visible = h * 238 / 448 * 0.34
        let w = min(s.width - 2 * visible + 40, s.height * 1.25), fh = s.height * 0.2
        return CGRect(x: (s.width - w) / 2, y: s.height * 0.79 - fh / 2, width: w, height: fh)
    }

    static func geometries() -> [PTStageGeometry] {
        screens.flatMap { s in
            [false, true].map { chat in
                PTStageGeometry(size: CGSize(width: s.width - (chat ? 392 : 0), height: s.height),
                                leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom,
                                floor: floor(s), chatOpen: chat)
            }
        }
    }

    static let phases: [Phase] = [.pickGame, .players, .props, .makingKit, .kitReady, .handoff(sceneIndex: 0), .scene(0), .end]

    @Test func feetOnTheFloorInEveryPhaseAndShot() {
        var checked = 0
        for g in Self.geometries() {
            let curtain = g.size.height * 238 / 448 * 0.34 * 0.55
            var frames: [PTStageFrame] = []
            for phase in Self.phases {
                for conv in [false, true] {
                    for shot in [PTCameraShot.closeUp, .medium, .wide] {
                        for cards in [0, 4] {
                            for beat in [PTStageDirector.KitBeat.coloring, .lookUp, .papers] {
                                frames.append(PTStageDirector.frame(phase: phase, conversation: conv, conversationShot: shot, cards: cards,
                                                                    hunt: shot == .medium, kitBeat: beat, curtainInset: curtain, g))
                            }
                        }
                    }
                }
            }
            for f in frames {
                for focus in [PTStageCamera.faceFocus, CGPoint(x: 640, y: 600)] {
                    let c = PTStageCamera.compose(f, g, faceFocus: focus)
                    let feet = c.nutmeg.feetPoint
                    #expect(abs(feet.y - c.floorLine) < 3, "feet \(feet.y) vs floor \(c.floorLine) for \(f) on \(g.size)")
                    #expect(feet.x > c.floor.minX && feet.x < c.floor.maxX, "feet off the floor sideways for \(f)")
                    checked += 1
                }
            }
        }
        #expect(checked > 100)
    }

    @Test func neverSmallerThanTheHuntMediumShot() {
        for g in Self.geometries() {
            let curtain = g.size.height * 238 / 448 * 0.34 * 0.55
            for phase in Self.phases {
                for conv in [false, true] {
                    for shot in [PTCameraShot.closeUp, .medium, .wide] {
                        for cards in [0, 4] {
                            for beat in [PTStageDirector.KitBeat.coloring, .papers] {
                                let f = PTStageDirector.frame(phase: phase, conversation: conv, conversationShot: shot, cards: cards,
                                                              hunt: shot == .medium, kitBeat: beat, curtainInset: curtain, g)
                                if f == .arrival { continue }   // the 0.9 s landing from the start screen
                                #expect(PTStageCamera.layout(f, g).k >= PTStageCamera.minK(g) - 0.0001, "\(f) too small on \(g.size)")
                            }
                        }
                    }
                }
            }
        }
    }

    @Test func arrivalShotStandsOnTheStartScreenFloor() {
        for g in Self.geometries() where !g.chatOpen {
            let c = PTStageCamera.compose(.arrival, g)
            #expect(abs(c.floor.minY - g.floor.minY) < 0.5 && abs(c.floor.width - g.floor.width) < 0.5)
            #expect(abs(c.nutmeg.feetPoint.y - g.floor.midY) < 1)
        }
    }

    @Test func huntChatClosedKeepsZonesClear() {
        for g in Self.geometries() where !g.chatOpen {
            let curtain = g.size.height * 238 / 448 * 0.34 * 0.55
            let f = PTStageDirector.huntFrame(curtainInset: curtain, g)
            let L = PTStageCamera.layout(f, g)
            let stackRight = g.free.minX + 8 + PTStageDirector.doneStackWidth
            #expect(L.minX >= stackRight + 16, "Nutmeg overlaps the done stack")
            let cardLeft = g.size.width - curtain - PTStageDirector.curtainGap - PTStageDirector.huntCardWidth(g)
            #expect(L.maxX + 12 <= cardLeft, "Nutmeg overlaps the active card")
            // Large: head to knees about 70% of the height (at least 64%).
            let span = (PTStageCamera.kneeY - PTStageCamera.headTop) * L.k
            #expect(span / g.size.height > 0.64, "medium shot too small: \(span / g.size.height)")
            #expect(L.screen(CGPoint(x: 0, y: PTStageCamera.headTop)).y > 0)
        }
    }

    @Test func huntChatOpenKeepsHerBelowTheThumbnailRow() {
        for g in Self.geometries() where g.chatOpen {
            let L = PTStageCamera.layout(PTStageDirector.huntFrame(curtainInset: 0, g), g)
            #expect(L.screen(CGPoint(x: 0, y: PTStageCamera.headTop)).y >= g.free.minY + PTStageDirector.thumbRow)
            #expect(L.minX >= g.free.minX && L.maxX <= g.size.width)
        }
    }

    @Test func kitColorsInTheCloseUpUntilThePapers() {
        let g = Self.geometries()[0]
        #expect(PTStageDirector.frame(phase: .makingKit, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                      kitBeat: .coloring, curtainInset: 80, g).shot == .closeUp)
        #expect(PTStageDirector.frame(phase: .kitReady, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                      kitBeat: .lookUp, curtainInset: 80, g).shot == .closeUp)
        // The pages step reuses the prop-card step's camera exactly (Haylee, round 5).
        for g in Self.geometries() {
            #expect(PTStageDirector.frame(phase: .kitReady, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                          kitBeat: .papers, curtainInset: 80, g) == PTStageDirector.huntFrame(curtainInset: 80, g))
        }
    }

    /// Round 8 writing moment (zoomed out): a medium close-up that shows her head, the clipboard and the writing paw
    /// (art ~965) on screen, with the screen's bottom edge just under the clipboard.
    @Test func writingShowsHeadClipboardAndWritingPaw() {
        for g in Self.geometries() {
            #expect(PTStageDirector.frame(phase: .props, conversation: true, conversationShot: .medium, cards: 2, hunt: true,
                                          kitBeat: .coloring, curtainInset: 80, writing: true, g).writing)
            let L = PTStageCamera.layout(.writing, g)
            #expect(L.screen(CGPoint(x: 0, y: 1000)).y < g.size.height - 5)   // writing paw + crayon
            #expect(L.screen(CGPoint(x: 0, y: PTStageCamera.kneeY)).y > g.size.height)   // not a medium (head-to-knees) shot
            #expect(L.screen(CGPoint(x: 0, y: PTStageCamera.faceFocus.y)).y > g.free.minY)
            #expect(abs(L.screen(CGPoint(x: 0, y: PTStageCamera.writeBottom)).y - g.size.height) < 0.5)
        }
    }
}
