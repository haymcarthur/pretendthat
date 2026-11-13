import Testing
@testable import NutmegCore

@Suite struct EmojiMatchTests {
    @Test func swapsAConfidentMismatch() {
        #expect(EmojiMatch.fix("🪑", for: "Put the blanket on the table") == "🛏️")
        #expect(EmojiMatch.fix("🍽️", for: "Hold the steering wheel") == "🛞")
    }

    @Test func keepsMatchingAndUnknownEmoji() {
        #expect(EmojiMatch.fix("🪑", for: "Line up the seats") == "🪑")
        #expect(EmojiMatch.fix("🎫", for: "Check each ticket") == "🎫")
        #expect(EmojiMatch.fix("📣", for: "Say: Welcome aboard!") == "📣")          // unknown emoji: trusted
        #expect(EmojiMatch.fix("🙌", for: "Lean back and say whoosh") == "🙌")
        #expect(EmojiMatch.fix("🍽️", for: "Set the table") == "🍽️")                 // listed for table too
        #expect(EmojiMatch.fix("🧸", for: "Wave at the clouds") == "🧸")             // text names nothing known
    }

    @Test func fillsMissingOrNonEmoji() {
        #expect(EmojiMatch.fix("", for: "Stack the pillows") == "🛋️")
        #expect(EmojiMatch.fix("chair", for: "Jump up and down") == "⭐")
    }

    @Test func plurals() {
        #expect(EmojiMatch.fix("📦", for: "Line up the chairs") == "🪑")
        #expect(EmojiMatch.fix("🪑", for: "Stack the boxes") == "📦")
        #expect(EmojiMatch.fix("🧸", for: "Line up the teddies at the desk") == "🧸")   // seen live
        #expect(EmojiMatch.fix("🛋️", for: "Put pillows around the table.") == "🛋️")
    }

    @Test func sanitizerFixesStepsAndProps() {
        var kit = Fallback.airplane.kit
        kit.scenes[0].steps[0] = Step(emoji: "🪑", text: "Put the blanket on the table")
        #expect(Sanitizer.clean(kit, playerCount: 2).scenes[0].steps[0].emoji == "🛏️")
        var props = Fallback.airplane.props
        props.props[0].emoji = "📦"; props.props[0].householdItem = "Pillows"
        #expect(Sanitizer.clean(props).props[0].emoji == "🛋️")
    }

    @Test func fallbackGameEmojiAlreadyMatch() {
        let a = Fallback.airplane
        for s in a.kit.scenes { for step in s.steps { #expect(EmojiMatch.fix(step.emoji, for: step.text) == step.emoji, "\(step.text)") } }
        for p in a.props.props { #expect(EmojiMatch.fix(p.emoji, for: p.householdItem) == p.emoji, "\(p.householdItem)") }
    }
}
