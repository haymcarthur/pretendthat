/// The vetted household-prop library (decision prop-art-library.md). The Realtime model picks props from these IDs
/// (an enum in the show_props tool), so every suggestion is a known-safe item with hand-drawn art (`prop-<id>`).
/// Anything outside the list is a logged fallback with generated sticker art.
public enum PropLibrary {
    public static let items: [(id: String, name: String)] = [
        ("stuffed-animal", "Stuffed animal"), ("chair", "Chair"), ("table", "Table"), ("couch", "Couch"),
        ("pillow", "Pillow"), ("blanket", "Blanket"), ("rug", "Rug"), ("cardboard-box", "Cardboard box"),
        ("plate", "Plastic plate"), ("cup", "Plastic cup"), ("bowl", "Bowl"), ("tray", "Tray"), ("spoon", "Spoon"),
        ("pot", "Pot"), ("towel", "Towel"), ("laundry-basket", "Laundry basket"), ("books", "Books"), ("hat", "Hat"),
        ("bag", "Bag"), ("backpack", "Backpack"), ("toy-car", "Toy car"), ("flashlight", "Flashlight"),
        ("broom", "Toy broom"), ("teddy-bed", "Doll bed"), ("lamp-off", "Lamp (unplugged)"), ("cushion", "Cushion"),
        ("stool", "Step stool"), ("sheet", "Bedsheet"), ("basket", "Basket"), ("bucket", "Bucket")
    ]
    public static let ids: [String] = items.map(\.id)
    public static func name(_ id: String) -> String? { items.first { $0.id == id }?.name }
    public static func contains(_ id: String) -> Bool { name(id) != nil }
    public static func asset(_ id: String) -> String { "prop-\(id)" }

    /// Off-list fallback guard: drop free-text props that name something unsafe.
    public static func looksUnsafe(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["knife", "knives", "scissor", "glass", "electr", "cord", "cable", "plug", "medicine", "pill", "candle",
                "lighter", "match", "needle", "razor", "saw", "hammer", "stove", "oven", "bleach", "battery", "rope", "bag over"]
            .contains { t.contains($0) }
    }
}
