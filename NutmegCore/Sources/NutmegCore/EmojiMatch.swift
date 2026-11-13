import Foundation

/// Sanity check for AI-picked emoji: when a step or prop names a common object and its emoji clearly shows a
/// DIFFERENT common object (a chair for "Put the blanket on the table"), swap in the emoji for the object the
/// text names. Emoji we don't know (actions, faces, 📣, 🙌) are left alone: we only fix confident mismatches.
public enum EmojiMatch {
    /// Keyword (singular, lowercase) → emoji. The first emoji is the replacement; the rest also count as a match.
    static let table: [(words: [String], emoji: [String])] = [
        (["blanket", "quilt", "sheet"], ["🛏️", "🛌"]),
        (["pillow", "cushion"], ["🛋️", "🛏️"]),
        (["couch", "sofa"], ["🛋️"]),
        (["bed"], ["🛏️", "🛌"]),
        (["chair", "seat", "stool"], ["🪑", "💺"]),
        (["table", "desk", "counter"], ["🍽️", "🛎️", "🪵"]),
        (["box", "cardboard", "package", "crate"], ["📦"]),
        (["cup", "mug"], ["🥤", "☕", "🍵", "🧃"]),
        (["plate", "dish", "bowl"], ["🍽️", "🥣"]),
        (["spoon", "fork"], ["🥄", "🍴"]),
        (["book", "menu", "notebook"], ["📖", "📚", "📕", "📒", "📋"]),
        (["paper", "page", "sign", "list", "note"], ["📄", "📝", "📃", "🪧", "📋"]),
        (["ticket", "pass"], ["🎫", "🎟️"]),
        (["money", "dollar", "coin", "cash", "bill", "pay"], ["💵", "🪙", "💰", "💲"]),
        (["key", "keycard"], ["🔑", "🗝️", "💳"]),
        (["hat", "cap", "crown"], ["🎩", "🧢", "👑", "👒"]),
        (["towel", "cape", "scarf"], ["🧣", "🦸"]),
        (["teddy", "stuffed", "toy", "doll", "animal"], ["🧸", "🪆"]),
        (["bag", "backpack", "suitcase", "basket"], ["🎒", "🧳", "👜", "🧺", "🛍️"]),
        (["broom", "mop"], ["🧹"]),
        (["phone", "telephone"], ["☎️", "📞", "📱"]),
        (["map"], ["🗺️"]),
        (["wheel", "steering"], ["🛞", "🚗"]),
        (["star"], ["⭐", "🌟", "✨"]),
        (["flower"], ["🌸", "🌼", "🌷", "💐"]),
        (["ball"], ["⚽", "🏀", "🎾", "🏐"]),
        (["shoe", "boot", "sock"], ["👟", "👢", "🧦"]),
        (["clock", "timer", "watch"], ["⏰", "⏱️", "🕰️", "⌚"]),
        (["door", "doorway"], ["🚪"]),
        (["window"], ["🪟"]),
        (["light", "lamp", "flashlight"], ["🔦", "💡"]),
        (["cake", "cupcake"], ["🎂", "🧁", "🍰"]),
        (["fish"], ["🐟", "🐠", "🎣"]),
        (["dog", "puppy"], ["🐶", "🐕"]),
        (["cat", "kitten"], ["🐱", "🐈"]),
        (["bandage", "band-aid"], ["🩹"]),
        (["stethoscope", "doctor"], ["🩺", "🧑‍⚕️"]),
    ]

    private static let emojiOwner: [String: Int] = {
        var m: [String: Int] = [:]
        for (i, row) in table.enumerated() { for e in row.emoji where m[e] == nil { m[e] = i } }
        return m
    }()

    /// Rows named in `text`, in the order they appear.
    static func namedRows(in text: String) -> [Int] {
        let words = text.lowercased().split { !$0.isLetter && $0 != "-" }.map(String.init)
        var found: [Int] = []
        for w in words {
            // teddies → teddy, boxes → box, chairs → chair (try each; the table decides).
            var forms = [w]
            if w.hasSuffix("ies"), w.count > 4 { forms.append(String(w.dropLast(3)) + "y") }
            if w.hasSuffix("es"), w.count > 4 { forms.append(String(w.dropLast(2))) }
            if w.hasSuffix("s"), w.count > 3 { forms.append(String(w.dropLast())) }
            for (i, row) in table.enumerated() where forms.contains(where: row.words.contains) && !found.contains(i) {
                found.append(i)
            }
        }
        return found
    }

    static func isEmoji(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return !t.isEmpty && t.count <= 2 && t.unicodeScalars.contains { $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0xFF }
    }

    /// The emoji to show for `text`. Keeps `emoji` unless it's missing/not an emoji, or it's a known object that
    /// the text doesn't mention while the text does name another known object.
    public static func fix(_ emoji: String, for text: String, fallback: String = "⭐") -> String {
        let named = namedRows(in: text)
        guard isEmoji(emoji) else { return named.first.map { table[$0].emoji[0] } ?? fallback }
        guard let owner = emojiOwner[emoji.trimmingCharacters(in: .whitespaces)] else { return emoji }   // unknown: trust it
        if named.isEmpty || named.contains(owner) { return emoji }
        // Also accept it if any named row lists this emoji (🍽️ is both "plate" and "table").
        if named.contains(where: { table[$0].emoji.contains(emoji) }) { return emoji }
        return table[named[0]].emoji[0]
    }
}
