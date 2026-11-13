/// Outline SF Symbols allowed on printables and role badges. Unknown symbols become "star".
public enum PrintSymbols {
    public static let allowlist: Set<String> = [
        "airplane", "ticket", "fork.knife", "pawprint", "bed.double", "key", "star", "heart", "crown",
        "cart", "bag", "gift", "house", "building.2", "car", "bus", "tram", "sailboat", "ferry", "fish",
        "leaf", "tree", "sun.max", "moon", "cloud", "snowflake", "flame", "drop", "bolt", "sparkles",
        "music.note", "paintbrush", "paintpalette", "scissors", "book", "pencil", "envelope", "phone",
        "camera", "clock", "map", "globe.americas", "flag", "trophy", "medal", "stethoscope", "cross.case",
        "bandage", "pills", "cup.and.saucer", "mug", "birthday.cake", "carrot", "takeoutbag.and.cup.and.straw",
        "creditcard", "banknote", "dollarsign.circle", "person", "person.2", "figure.wave", "hare", "tortoise",
        "bird", "ant", "ladybug", "teddybear", "balloon", "party.popper", "wand.and.stars", "theatermasks",
        "binoculars", "magnifyingglass", "wrench", "hammer", "shield", "bell", "megaphone", "headphones",
        "rocket", "tent", "mountain.2", "beach.umbrella", "basket", "washer", "tshirt", "crown.fill"
    ]
    public static func safe(_ s: String) -> String { allowlist.contains(s) ? s : "star" }
}
