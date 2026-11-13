import Foundation
import Testing
@testable import NutmegCore

/// Checklist and scene pictures (checklist-pictures.md): one prop, action or kit picture each; fallback action-point.
struct PictureTests {
    let kit = Fallback.airplane.kit
    let roles = Fallback.airplane(playerCount: 3).plan.roles

    @Test func propsAndActionsResolveToTheirArt() {
        #expect(PictureResolver.resolve(.prop("plate"), kit: kit, roles: roles) == .prop("plate"))
        #expect(PictureResolver.resolve(.prop("plate"), kit: kit, roles: roles).assetName == "prop-plate")
        #expect(PictureResolver.resolve(.action("ring-bell"), kit: kit, roles: roles).assetName == "action-ring-bell")
        #expect(PictureResolver.resolve(Picture(kind: .prop, id: "prop:chair"), kit: kit, roles: roles) == .prop("chair"))
    }

    @Test func kitPicturesPointAtThisKitsItems() {
        let ticket = kit.items.first { $0.recipe == .tickets }!.id
        #expect(PictureResolver.resolve(.kit("ticket"), kit: kit, roles: roles) == .kitItem(itemID: ticket, recipe: .tickets, role: nil))
        let money = kit.items.first { $0.recipe == .money }!.id
        #expect(PictureResolver.resolve(.kit("money"), kit: kit, roles: roles) == .kitItem(itemID: money, recipe: .money, role: nil))
        let badge = kit.items.first { $0.recipe == .badges }!.id
        #expect(PictureResolver.resolve(.kit("badge:R1"), kit: kit, roles: roles) == .kitItem(itemID: badge, recipe: .badges, role: roles[0]))
        #expect(PictureResolver.resolve(.kit("badge:captain"), kit: kit, roles: roles) == .kitItem(itemID: badge, recipe: .badges, role: roles[0]))
        let cut = kit.items.first { $0.recipe == .cutouts }!
        #expect(PictureResolver.resolve(.kit("cutout:4"), kit: kit, roles: roles) == .cutout(itemID: cut.id, index: 4, label: cut.lines[4]))
    }

    @Test func unresolvableFallsBackToPoint() {
        #expect(PictureResolver.resolve(.prop("knife"), kit: kit, roles: roles) == .action("point"))
        #expect(PictureResolver.resolve(.action("juggle"), kit: kit, roles: roles) == .action("point"))
        #expect(PictureResolver.resolve(.kit("cutout:12"), kit: kit, roles: roles) == .action("point"))
        #expect(PictureResolver.resolve(.kit("badge:R4"), kit: kit, roles: roles) == .action("point"))   // 3 kids: no R4
        #expect(PictureResolver.resolve(.kit("ticket"), kit: nil, roles: roles) == .action("point"))
        #expect(PictureResolver.resolve(nil, kit: kit, roles: roles) == .action("point"))
        #expect(PictureResolver.resolve(.prop("plate"), kit: nil, roles: []) == .prop("plate"))   // props need no kit
    }

    @Test func missingPictureDecodesAsPoint() throws {
        let step = try JSONDecoder().decode(Step.self, from: Data(#"{"text":"Wave","emoji":"👋"}"#.utf8))
        #expect(step.picture == .point)
    }

    @Test func schemaConstrainsPictureKindsAndIDs() {
        let json = Realtime.json(Schemas.kit())
        #expect(json.contains("\"cutout:7\"") && json.contains("\"badge:R1\"") && json.contains("\"ring-bell\"") && json.contains("\"laundry-basket\""))
        #expect(!json.contains("\"emoji\""))
        #expect(!Realtime.json(Schemas.props()).contains("\"emoji\""))
    }

    @Test func fallbackStepsAllResolve() {
        for s in kit.scenes {
            for step in s.steps + [Step(picture: s.picture, text: s.title)] {
                let r = PictureResolver.resolve(step.picture, kit: kit, roles: roles)
                #expect(r != .action("point") || step.picture == .point, "\(step.text) → \(step.picture)")
            }
        }
    }

    @Test func propsAreLibraryOnly() {
        let p = Sanitizer.clean(Fixture.propsWithUnsafe)
        #expect(p.props.map(\.libraryID) == ["plate", "chair"])
        #expect(p.props.allSatisfy { $0.emoji == nil })
        #expect(p.props.first?.householdItem == "Plastic plate")
    }

    @Test @MainActor func offListRealtimePropsAreDropped() async {
        let store = AdventureStore(service: nil)
        store.beginConversation()
        _ = await store.apply(.showProps([.init(itemID: "tray", becomes: "cart", forRole: "all"),
                                          .init(itemID: "magic wand", becomes: "wand", forRole: "all")]))
        #expect(store.props?.props.map(\.id) == ["tray"])
    }
}
