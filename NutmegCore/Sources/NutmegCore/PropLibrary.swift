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
        ("stool", "Step stool"), ("sheet", "Bedsheet"), ("basket", "Basket"), ("bucket", "Bucket"),
        // Round 30 (Haylee): set 2, 30 more everyday things (crayons, tape and sticky notes are craft items; nothing
        // here implies cutting).
        ("paper", "Paper"), ("paper-towel-tube", "Paper towel tube"), ("paper-bag", "Paper bag"), ("egg-carton", "Egg carton"),
        ("crayons", "Crayons"), ("tape", "Tape"), ("paper-plate", "Paper plate"), ("plastic-container", "Plastic container"),
        ("measuring-cup", "Measuring cup"), ("colander", "Colander"), ("baking-sheet", "Baking sheet"),
        ("wooden-spoon", "Wooden spoon"), ("apron", "Apron"), ("oven-mitt", "Oven mitt"), ("ball", "Ball"), ("scarf", "Scarf"),
        ("sunglasses", "Sunglasses"), ("sneakers", "Sneakers"), ("headband", "Headband"), ("sock", "Sock"),
        ("mittens", "Mittens"), ("umbrella", "Umbrella (closed)"), ("pillowcase", "Pillowcase"), ("toy-keys", "Toy keys"),
        ("wagon", "Wagon"), ("jump-rope", "Jump rope"), ("hula-hoop", "Hula hoop"), ("sidewalk-chalk", "Sidewalk chalk"),
        ("plastic-cups", "Plastic cups"), ("sticky-notes", "Sticky notes")
    ]
    public static let ids: [String] = items.map(\.id)
    public static func name(_ id: String) -> String? { items.first { $0.id == id }?.name }
    public static func contains(_ id: String) -> Bool { name(id) != nil }
    public static func asset(_ id: String) -> String { "prop-\(id)" }

    /// Round 30 (Haylee): a firm number of props per game: 4 for 1–2 kids, 5 for 3 or more.
    public static func target(players: Int) -> Int { players >= 3 ? 5 : 4 }

    /// Off-list fallback guard: drop free-text props that name something unsafe.
    public static func looksUnsafe(_ text: String) -> Bool {
        let t = text.lowercased()
        return ["knife", "knives", "scissor", "glass", "electr", "cord", "cable", "plug", "medicine", "pill", "candle",
                "lighter", "match", "needle", "razor", "saw", "hammer", "stove", "oven", "bleach", "battery", "rope", "bag over"]
            .contains { t.contains($0) }
    }
}
