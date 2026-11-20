import Foundation

// 2026-11-21 (Haylee, decisions/2026-11-21-one-game-plan.md; build: decisions/2026-11-21-round-game-plan-build.md):
// "whatever we print should be used during play". Every printable TYPE has a PLAY JOB, written once here (like the
// prop stand-ins): what the kids do with it in the scene, how it's placed in its area at setup, a calm-stretch idea
// the app can say when the plan gave it none, and how it's put away. The table is fed to the game plan prompt (and to
// the kit pages prompt), and the app uses its lines to repair a plan that left a printout without a use (no AI call).
// Wearables and hung-up things (badges, the sign, labels) count their setup as their use.

public struct PrintPlayJob: Equatable, Sendable {
    /// What the kids do with it during play (the prompt's line).
    public var use: String
    /// The setup verb phrase before the page's name ("Hang", "Stack", "Set out").
    public var placeVerb: String
    /// An app-written calm-stretch idea, `{it}` = the page's name ("the captain's log"). No role title (the app puts
    /// the owner's title in).
    public var idea: String
    /// True when putting it in place (or on) IS its use (a sign hangs, a badge is worn, labels are stuck on).
    public var setupIsUse: Bool
}

public enum PrintPlayJobs {
    public static func job(_ t: KitRecipe) -> PrintPlayJob {
        switch t {
        case .badges: PrintPlayJob(use: "each kid wears their own the whole game", placeVerb: "Put on",
                                   idea: "show everyone your badge and tell them your job!", setupIsUse: true)
        case .sign: PrintPlayJob(use: "hangs at the entrance of its area; kids point new visitors to it", placeVerb: "Hang",
                                 idea: "welcome a new visitor by {it}!", setupIsUse: true)
        case .money: PrintPlayJob(use: "paid for things, counted and given as change", placeVerb: "Stack",
                                  idea: "count {it} and pay for something special!", setupIsUse: false)
        case .tickets: PrintPlayJob(use: "shown, checked and punched to get in or on board", placeVerb: "Set out",
                                    idea: "check everyone's ticket from {it} and punch it!", setupIsUse: false)
        case .menu: PrintPlayJob(use: "read out loud so someone can choose and order", placeVerb: "Put out",
                                 idea: "read {it} out loud and ask what everyone wants!", setupIsUse: false)
        case .cutouts: PrintPlayJob(use: "held and used as the pretend things they show, handed out when needed", placeVerb: "Lay out",
                                    idea: "hand out {it} to anyone who needs one!", setupIsUse: false)
        case .orderSlips: PrintPlayJob(use: "a waiter ticks an order, the cook makes it", placeVerb: "Set out",
                                       idea: "take a new order on {it}!", setupIsUse: false)
        case .map: PrintPlayJob(use: "followed to pick where to go next, stops marked as you reach them", placeVerb: "Lay out",
                                idea: "look at {it} and pick where we go next!", setupIsUse: false)
        case .clueCards: PrintPlayJob(use: "hidden at setup, found and read out loud one at a time", placeVerb: "Hide",
                                      idea: "find a clue from {it} and read it to everyone!", setupIsUse: false)
        case .missionCards: PrintPlayJob(use: "drawn one at a time in a calm stretch and acted out together", placeVerb: "Stack",
                                         idea: "draw a card from {it} and do it together!", setupIsUse: false)
        case .log: PrintPlayJob(use: "written or ticked after something happens (what you saw, who you helped)", placeVerb: "Put",
                                idea: "write in {it} what just happened!", setupIsUse: false)
        case .medals: PrintPlayJob(use: "given to someone who helped, and at the big finish", placeVerb: "Set aside",
                                   idea: "give a medal from {it} to someone who helped!", setupIsUse: false)
        case .stickers: PrintPlayJob(use: "given as a reward or stamped when a job is done", placeVerb: "Set out",
                                     idea: "give a sticker from {it} to someone who did a great job!", setupIsUse: false)
        case .passport: PrintPlayJob(use: "stamped at each stop", placeVerb: "Fold",
                                     idea: "stamp everyone's passport from {it} for this stop!", setupIsUse: false)
        case .labels: PrintPlayJob(use: "stuck on the things they name at setup", placeVerb: "Stick on",
                                   idea: "check {it} and fix any that fell off!", setupIsUse: true)
        case .decoder: PrintPlayJob(use: "used to crack one secret word at a time", placeVerb: "Put",
                                    idea: "crack one secret word with {it}!", setupIsUse: false)
        case .controlPanel: PrintPlayJob(use: "pressed and turned to steer, launch and fix things", placeVerb: "Set up",
                                         idea: "press the buttons on {it} to keep us going!", setupIsUse: false)
        }
    }

    /// True when its setup counts as its use (wearables and hung-up things).
    public static func setupIsUse(_ t: KitRecipe?) -> Bool { t.map { job($0).setupIsUse } ?? false }

    /// The prompt's table: one line per printable in THIS kit ("- page:log (the Captain's Log): written or ticked…").
    public static func promptList(_ items: [KitItem]) -> String {
        items.compactMap { item -> String? in
            guard let r = item.recipe, r != .badges else { return nil }
            return "- \(Bookends.pageID(r)) (\(Bookends.pageLabel(item))): \(job(r).use)"
        }.joined(separator: "\n")
    }

    /// The whole library's play jobs (the kit pages prompt: every pick has a real use in the scene).
    public static var libraryList: String {
        KitRecipe.allCases.map { "\($0.rawValue): \(job($0).use)" }.joined(separator: "; ")
    }

    /// The app's idea line for a page (`{it}` filled in), no role title.
    public static func idea(_ t: KitRecipe, label: String) -> String {
        job(t).idea.replacingOccurrences(of: "{it}", with: label)
    }
}
