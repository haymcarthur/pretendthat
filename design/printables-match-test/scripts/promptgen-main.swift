import Foundation
import NutmegCore

let roles = [
  Role(id: .R1, roleName: "Head Baker", emoji: "", symbol: "star", job: "bakes the moon bread"),
  Role(id: .R2, roleName: "Cupcake Chef", emoji: "", symbol: "star", job: "frosts the cupcakes"),
  Role(id: .R3, roleName: "Delivery Rover", emoji: "", symbol: "star", job: "drives treats to the craters"),
  Role(id: .R4, roleName: "Customer", emoji: "", symbol: "star", job: "orders yummy treats"),
  Role(id: .R5, roleName: "Cashier", emoji: "", symbol: "star", job: "takes the moon coins"),
  Role(id: .R6, roleName: "Taste Tester", emoji: "", symbol: "star", job: "tries every treat"),
]
let ctx = KitArtContext(title: "Moon Bakery", setting: "a bakery on the moon", roles: roles, players: 4)
func item(_ id: String, _ r: KitRecipe, _ v: KitVariant, _ title: String, _ lines: [String], _ pics: [String]?) -> KitItem {
  KitItem(id: id, recipe: r, kind: r == .badges || r == .tickets ? .sheet : .card, size: .fullPage, title: title, symbol: "star",
          lines: lines, bigNumber: nil, perPlayer: r == .badges || r == .tickets, copies: 1, colorMe: false,
          variant: v, pictures: pics, wholePage: true)
}
let items: [(String, KitItem)] = [
  ("badges", item("badges", .badges, .lanyard, "Bakery Badges", [], nil)),
  ("sign", item("sign", .sign, .door, "Moon Bakery", ["Fresh Moon Treats"], ["a smiling cupcake on a crescent moon"])),
  ("menu", item("menu", .menu, .menuCard, "Moon Menu", ["Star Cookie $1", "Moon Pie $2", "Crater Cupcake $2", "Comet Donut $1"],
               ["a star-shaped cookie", "a round moon pie", "a cupcake with sprinkles", "a donut with a comet tail"])),
  ("tickets", item("tickets", .tickets, .admission, "Bakery Pass", ["Rocket Ride"], ["a little rocket carrying a cake box"])),
]
var out: [String: [String: String]] = [:]
for (k, it) in items {
  let o = KitPagePrompt.prompt(for: it, ctx: ctx, style: .colorIn)!
  out[k] = ["outline": o.prompt, "words": o.words.joined(separator: " | ")]
}
out["_style"] = ["fullColor": KitPagePrompt.style(.fullColor), "colorIn": KitPagePrompt.style(.colorIn), "size": KitPagePrompt.size, "quality": ImageQuality.kit, "models": ImageClient.models.joined(separator: ",")]
let d = try JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
FileManager.default.createFile(atPath: CommandLine.arguments[1], contents: d)
