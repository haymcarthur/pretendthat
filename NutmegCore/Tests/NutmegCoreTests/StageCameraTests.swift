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

    static let phases: [Phase] = [.pickGame, .players, .props, .makingKit, .kitReady, .scene(0), .end]

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
                                // Round 14: chat open, a fit-closed framing is the closed one scaled to fit left of the panel,
                                // so its minimum is the closed minimum times that fit.
                                let F0 = g.reference.free, F1 = g.free
                                let fit = f.fitClosed && g.chatOpen ? min(1, (F1.width - 24) / F0.width, F1.height / F0.height) : 1
                                #expect(PTStageCamera.layout(f, g).k >= PTStageCamera.minK(g.reference) * fit - 0.0001, "\(f) too small on \(g.size)")
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
            // Round 14: the card zone right of her (where the active card sits) stays readable (≥ 240 pt).
            let zone = PTStageDirector.huntContent(g, nutmeg: L, curtainInset: curtain)
            #expect(zone.minX >= L.maxX + 12, "Nutmeg overlaps the active card")
            #expect(zone.width >= 240, "hunt card zone too narrow: \(zone.width)")
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

    /// Round 14 (Haylee: chat open cut the floor off on the left, Nutmeg low/left): chat open, the talk and prop-card
    /// framings are the chat-closed framing scaled to fit left of the panel: floor fully in frame, centered.
    @Test func chatOpenFitsTheClosedFramingWithTheWholeFloor() {
        for s in Self.screens {
            let open = PTStageGeometry(size: CGSize(width: s.width - 392, height: s.height), leadingInset: PTStageCamera.chromeLeading,
                                       bottomInset: PTStageCamera.chromeBottom, floor: Self.floor(s), chatOpen: true, referenceSize: s)
            for preset in [PTStageDirector.Preset.talk] {   // round 41: propCardChat = the talk framing (below)
                let f = PTStageDirector.frame(preset, curtainInset: 80, open)
                let c = PTStageCamera.compose(f, open)
                if preset == .propCardChat {
                    #expect(c.floor.minX >= open.free.minX - 1 && c.floor.maxX <= open.size.width + 1,
                            "floor cut off: \(c.floor) in \(open.free)")
                }
                // Prop card: her body centered; talk: her face centered (the close-up anchor).
                // (The closed close-up centers her face on the whole screen, so open it lands near the stage's middle.)
                let mid = preset == .talk ? c.nutmeg.screen(PTStageCamera.faceFocus).x : (c.nutmeg.minX + c.nutmeg.maxX) / 2
                #expect(abs(mid - (preset == .talk ? open.size.width / 2 : open.free.midX)) < 30, "\(preset) not centered: \(mid) vs \(open.free.midX)")
                // Same proportions: the closed framing's scale times the fit.
                let closedG = open.reference
                let closed = PTStageCamera.layout(PTStageDirector.frame(preset == .talk ? .talk : .propCard, curtainInset: 80, closedG)
                    .withChatClosedCentered(preset), closedG)
                #expect(c.nutmeg.k <= closed.k + 0.001)
            }
        }
    }

    /// Round 14 (Haylee: the cards got smaller): the kit pages / checklist / hand-off / finale zone is the shared card
    /// zone (~30% of the stage); the hunt's is narrower (done stack on her left) but still readable.
    @Test func cardZoneIsTheSharedSize() {
        for s in Self.screens {
            let g = PTStageGeometry(size: s, leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom,
                                    floor: Self.floor(s), referenceSize: s)
            let curtain = s.height * 238 / 448 * 0.34 * 0.55
            let content = PTStageCamera.layout(PTStageDirector.huntFrame(curtainInset: curtain, doneStack: false, g), g)
            let hunt = PTStageCamera.layout(PTStageDirector.huntFrame(curtainInset: curtain, doneStack: true, g), g)
            let zc = PTStageDirector.huntContent(g, nutmeg: content, curtainInset: curtain).width
            let zh = PTStageDirector.huntContent(g, nutmeg: hunt, curtainInset: curtain).width
            #expect(abs(zc - PTStageDirector.cardZoneWidth(g)) < 1, "content zone \(zc)")
            #expect(zc >= 340 && zh >= 240 && zc > zh, "zones \(zc) / \(zh)")
            #expect(content.minX >= g.free.minX + 8)
        }
    }

    @Test func kitColorsInTheCloseUpUntilThePapers() {
        let g = Self.geometries()[0]
        #expect(PTStageDirector.frame(phase: .makingKit, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                      kitBeat: .coloring, curtainInset: 80, g).shot == .closeUp)
        #expect(PTStageDirector.frame(phase: .kitReady, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                      kitBeat: .lookUp, curtainInset: 80, g).shot == .closeUp)
        // The pages step reuses the prop-card step's camera exactly (Haylee, round 5); round 41: with the chat panel
        // open that is the talking close-up (the papers are in the panel).
        for g in Self.geometries() {
            #expect(PTStageDirector.frame(phase: .kitReady, conversation: false, conversationShot: .wide, cards: 0, hunt: false,
                                          kitBeat: .papers, curtainInset: 80, g)
                    == (g.chatOpen ? PTStageFrame(shot: .closeUp, fitClosed: true) : PTStageDirector.huntFrame(curtainInset: 80, doneStack: false, g)))
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

/// Round 11 (Haylee): ONE set of framings. Every phase, chat open or closed, maps to a named preset, and the floor keeps
/// the same size relative to Nutmeg in every framing.
struct StagePresetTests {
    typealias D = PTStageDirector
    static let curtain: CGFloat = 70

    @Test func everyPhaseMapsToAPresetAndOnlyPresetFrames() {
        let allPhases: [Phase] = [.hello, .pickGame, .players, .props, .makingKit, .kitReady, .scene(0), .end]
        for g in StageCameraTests.geometries() {
            let presetFrames = D.Preset.allCases.map { D.frame($0, cards: 4, curtainInset: Self.curtain, g) }
                + D.Preset.allCases.map { D.frame($0, cards: 0, curtainInset: Self.curtain, g) }
                + [D.frame(.propCard, curtainInset: Self.curtain, doneStack: true, g), D.frame(.propCardChat, curtainInset: Self.curtain, doneStack: true, g)]   // round 14: the hunt's variant
            for phase in allPhases {
                for conv in [false, true] {
                    for shot in [PTCameraShot.closeUp, .medium, .wide] {
                        for cards in [0, 4] {
                            for beat in [D.KitBeat.coloring, .lookUp, .papers] {
                                for writing in [false, true] {
                                    let f = D.frame(phase: phase, conversation: conv, conversationShot: shot, cards: cards, hunt: shot == .medium,
                                                    kitBeat: beat, curtainInset: Self.curtain, writing: writing, g)
                                    #expect(presetFrames.contains(f), "\(phase) produced a non-preset frame \(f)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Round 41 (Haylee: the iPad zoomed out with the chat panel open during Props): with the panel open every card is
    /// in the panel, so a card step keeps exactly the talking framing (no zoom-out, no camera move).
    @Test func chatOpenCardStepsKeepTheTalkingFraming() {
        for s in StageCameraTests.screens {
            let open = PTStageGeometry(size: CGSize(width: s.width - 392, height: s.height), leadingInset: PTStageCamera.chromeLeading,
                                       bottomInset: PTStageCamera.chromeBottom, floor: StageCameraTests.floor(s), chatOpen: true, referenceSize: s)
            let talk = PTStageCamera.layout(PTStageDirector.frame(.talk, curtainInset: 80, open), open)
            let card = PTStageCamera.layout(PTStageDirector.frame(.propCardChat, curtainInset: 80, doneStack: true, open), open)
            #expect(abs(card.k - talk.k) < 0.0001 && abs(card.origin.x - talk.origin.x) < 0.01 && abs(card.origin.y - talk.origin.y) < 0.01)
            // Bigger than round 40's chat-open hunt (the medium shot scaled to fit left of the panel).
            let old = PTStageCamera.layout(PTStageFrame(shot: .medium, topReserve: PTStageDirector.thumbRow, fitClosed: true), open)
            #expect(card.k > old.k * 1.3, "not zoomed in: \(card.k) vs \(old.k)")
        }
    }

    @Test func phaseTable() {
        func p(_ phase: Phase, conv: Bool = false, shot: PTCameraShot = .closeUp, cards: Int = 0, hunt: Bool = false,
               beat: D.KitBeat = .coloring, writing: Bool = false, chat: Bool) -> D.Preset {
            D.preset(phase: phase, conversation: conv, conversationShot: shot, cards: cards, hunt: hunt, kitBeat: beat, writing: writing, chatOpen: chat)
        }
        for chat in [false, true] {
            let card: D.Preset = chat ? .propCardChat : .propCard
            #expect(p(.pickGame, conv: true, chat: chat) == .talk)
            #expect(p(.players, conv: true, chat: chat) == .talk)
            #expect(p(.props, conv: true, shot: .medium, hunt: true, chat: chat) == card)
            #expect(p(.props, conv: true, writing: true, chat: chat) == .writing)
            #expect(p(.makingKit, chat: chat) == .talk)
            #expect(p(.makingKit, writing: true, chat: chat) == .writing)
            #expect(p(.kitReady, beat: .papers, chat: chat) == card)
            #expect(p(.scene(0), chat: chat) == card)
            #expect(p(.end, chat: chat) == card)
            #expect(p(.pickGame, chat: chat) == card)   // tap screens
            #expect(p(.hello, chat: chat) == .hop)
        }
    }

    @Test func floorKeepsItsSizeRelativeToNutmeg() {
        for s in StageCameraTests.screens {
            let full = PTStageGeometry(size: s, leadingInset: PTStageCamera.chromeLeading, bottomInset: PTStageCamera.chromeBottom,
                                       floor: StageCameraTests.floor(s))
            var ratios: [CGFloat] = []
            for chat in [false, true] {
                for keyboardCut: CGFloat in [0, 0] {   // the keyboard no longer changes the stage size (it just covers it)
                    var g = full
                    g.size = CGSize(width: s.width - (chat ? 392 : 0), height: s.height - keyboardCut)
                    g.chatOpen = chat
                    g.referenceSize = s
                    for preset in D.Preset.allCases {
                        let c = PTStageCamera.compose(D.frame(preset, cards: 4, curtainInset: Self.curtain, g), g)
                        ratios.append(c.floor.width / c.nutmeg.k)
                    }
                }
            }
            let lo = ratios.min()!, hi = ratios.max()!
            #expect(hi - lo < 0.5, "floor : Nutmeg varies \(lo)…\(hi) on \(s)")
        }
    }
}

private extension PTStageFrame {
    /// The chat-open prop-card framing's closed counterpart is the centered medium shot (no side zones).
    func withChatClosedCentered(_ preset: PTStageDirector.Preset) -> PTStageFrame {
        preset == .propCardChat ? PTStageFrame(shot: .medium, topReserve: PTStageDirector.thumbRow) : self
    }
}
