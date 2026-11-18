import XCTest
import CoreGraphics
@testable import NutmegCore

/// iPhone version (2026-11-17): the phone's portrait stage. Her whole body fits her box with her feet on its bottom
/// edge (the floor follows her camera), the box fills the stage when nothing is showing, content never pushes her
/// below the minimum, and the iPad framings are untouched (no `phoneRegion` = the old math).
final class PhoneStageTests: XCTestCase {
    let phones = [CGSize(width: 390, height: 763), CGSize(width: 402, height: 778), CGSize(width: 440, height: 860)]

    func geometry(_ s: CGSize) -> PTStageGeometry {
        PTStageGeometry(size: s, leadingInset: 0, bottomInset: 110,
                        floor: CGRect(x: -s.width * 0.125, y: s.height * 0.62, width: s.width * 1.25, height: s.width * 0.4))
    }

    func testNothingShowingSheFillsTheStage() {
        for s in phones {
            let split = PTPhoneStage.split(width: s.width, top: 80, bottom: s.height - 110, content: 0)
            XCTAssertEqual(split.content.height, 0)
            XCTAssertEqual(split.nutmeg.height, s.height - 190, accuracy: 0.5)
            let L = PTStageCamera.layout(PTStageFrame(shot: .closeUp, phoneRegion: split.nutmeg), geometry(s))
            // Whole body inside her box, as wide as it allows (width or height limited). 2026-11-18 (Haylee: too low
            // alone): a width-limited body is centered vertically in the box (equal room above her head and below
            // her feet), never standing on its bottom edge with the sky empty.
            let headY = L.origin.y + PTStageCamera.headTop * L.k
            XCTAssertLessThanOrEqual(L.feetPoint.y, split.nutmeg.maxY + 0.5)
            XCTAssertEqual(headY - split.nutmeg.minY, split.nutmeg.maxY - L.feetPoint.y, accuracy: 1)
            XCTAssertGreaterThanOrEqual(L.origin.y + PTStageCamera.headTop * L.k, split.nutmeg.minY - 0.5)
            XCTAssertLessThanOrEqual(L.maxX - L.minX, s.width + 0.5)
            XCTAssertGreaterThan(L.k, 0.3, "she grows to fill the empty stage")
        }
    }

    func testContentBelowKeepsHerOnScreen() {
        for s in phones {
            for c: CGFloat in [120, 260, 400, 2000] {
                let split = PTPhoneStage.split(width: s.width, top: 80, bottom: s.height - 110, content: c)
                XCTAssertGreaterThanOrEqual(split.nutmeg.height, PTPhoneStage.minNutmeg - 0.5)
                XCTAssertLessThanOrEqual(split.nutmeg.maxY + PTPhoneStage.gap, split.content.minY + 0.5)
                XCTAssertEqual(split.content.maxY, s.height - 110, accuracy: 0.5)
                let L = PTStageCamera.layout(PTStageFrame(shot: .medium, phoneRegion: split.nutmeg), geometry(s))
                XCTAssertLessThanOrEqual(L.feetPoint.y, split.content.minY + 0.5, "her feet stay above the content")
                XCTAssertGreaterThanOrEqual(L.origin.y + PTStageCamera.headTop * L.k, split.nutmeg.minY - 0.5)
            }
        }
    }

    func testFloorStaysUnderHerFeet() {
        for s in phones {
            let g = geometry(s)
            let split = PTPhoneStage.split(width: s.width, top: 80, bottom: s.height - 110, content: 260)
            let c = PTStageCamera.compose(PTStageFrame(shot: .medium, phoneRegion: split.nutmeg), g)
            XCTAssertEqual(c.nutmeg.feetPoint.y, c.floorLine, accuracy: 3)
        }
    }

    func testWritingShowsHeadAndClipboard() {
        let s = phones[1]
        let split = PTPhoneStage.split(width: s.width, top: 80, bottom: s.height - 110, content: 0)
        let L = PTStageCamera.layout(PTStageFrame(shot: .closeUp, writing: true, phoneRegion: split.nutmeg), geometry(s))
        XCTAssertEqual(L.screen(CGPoint(x: 0, y: PTStageCamera.writeBottom)).y, split.nutmeg.maxY, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(L.screen(CGPoint(x: 0, y: PTStageCamera.headTop)).y, split.nutmeg.minY - 0.5)
    }

    func testIPadFramingsUnchanged() {
        // No phone region: the iPad math (the same frame with and without the new field's default).
        let g = PTStageGeometry(size: CGSize(width: 1366, height: 1000), leadingInset: PTStageCamera.chromeLeading,
                                bottomInset: PTStageCamera.chromeBottom, floor: CGRect(x: 200, y: 700, width: 960, height: 200))
        for f in [PTStageFrame.closeUp, .writing, .arrival, PTStageFrame(shot: .medium, leftReserve: 160)] {
            var copy = f; copy.phoneRegion = nil
            let a = PTStageCamera.layout(f, g), b = PTStageCamera.layout(copy, g)
            XCTAssertEqual(a.k, b.k); XCTAssertEqual(a.origin, b.origin)
            XCTAssertNil(f.phoneRegion)
        }
    }
}
