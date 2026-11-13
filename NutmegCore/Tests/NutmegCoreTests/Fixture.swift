import Foundation
@testable import NutmegCore

enum Fixture {
    static let kitJSON = Data(#"""
    {"nutmegSays":"Here's your kit!","items":[
      {"id":"pass","kind":"card","size":"ticket","title":"Boarding Pass","symbol":"airplane","lines":["Seat 1A"],"bigNumber":"1A","perPlayer":true,"copies":1,"colorMe":true},
      {"id":"money","kind":"card","size":"bill","title":"Sky Dollars","symbol":"star","lines":["Sky Dollars"],"bigNumber":"5","perPlayer":false,"copies":8,"colorMe":true},
      {"id":"menu","kind":"sheet","size":"fullPage","title":"Snack Menu","symbol":"fork.knife","lines":["Juice","Crackers"],"bigNumber":null,"perPlayer":false,"copies":1,"colorMe":true}],
     "scenes":[{"id":"s1","owner":"R1","title":"Pre-flight","emoji":"🧑‍✈️","nutmegSays":"Captain, check the plane!","steps":[
        {"emoji":"🪑","text":"Line up the seats"},{"emoji":"🎫","text":"Check tickets"},{"emoji":"🧃","text":"Load snacks"},{"emoji":"📣","text":"Say welcome aboard"}]}]}
    """#.utf8)

    static func item(_ id: String, symbol: String = "airplane", copies: Int = 1) -> KitItem {
        KitItem(id: id, kind: .card, size: .ticket, title: id, symbol: symbol, lines: [], bigNumber: nil, perPlayer: false, copies: copies, colorMe: true)
    }
    static func scene(_ id: String, owner: SceneOwner = .all, steps: Int = 4) -> Scene {
        Scene(id: id, owner: owner, title: id, emoji: "⭐️", nutmegSays: "Go!", steps: (0..<steps).map { Step(emoji: "✅", text: "step \($0)") })
    }
    static var oversizedKit: Kit {
        var items = (0..<6).map { item("i\($0)", copies: 20) }
        items[0].symbol = "rocket.fake"
        let owners: [SceneOwner] = [.R1, .R2, .R3, .R4, .all, .R1, .R2, .R3]
        return Kit(nutmegSays: "Hi", items: items, scenes: owners.enumerated().map { scene("s\($0.offset)", owner: $0.element, steps: 7) })
    }
    static var propsWithUnsafe: Props {
        Props(nutmegSays: "Find these!", props: [
            Prop(id: "a", householdItem: "plate", becomes: "steering wheel", emoji: "🍽️", forRole: .R1, safetyOK: true),
            Prop(id: "b", householdItem: "knife", becomes: "sword", emoji: "🔪", forRole: .all, safetyOK: false),
            Prop(id: "c", householdItem: "chair", becomes: "seat", emoji: "🪑", forRole: .all, safetyOK: true)])
    }
}
