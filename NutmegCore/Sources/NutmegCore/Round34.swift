import Foundation

// Round 34 (Haylee, 2026-11-16): replay prop lines, short tasks on screen with the specifics spoken, the whole row
// as the tap target, the in-app speech model download, and a one-sentence returning greeting.

// MARK: - Prop lines (the same words on a first play and a replay)

/// Haylee: a replay says the SAME prop lines as the first play ("Can you find a plate? It'll be the steering wheel!"),
/// ideally her exact recorded first-play clip, and never "do you still have…". The repeated "Next," lead-in is gone on
/// both: the lines rotate a few natural phrasings (the first prop keeps "First,"). Every prop line is written HERE, by
/// the app, from the prop and its place in the hunt only (item, what it becomes, the reason, its number and the answer
/// before it), so a first play and a replay with the same answers say the same words and the clip (keyed by the
/// normalized words, `ClipKey`) is found again. A new prop or answer on a replay is a new line: live once, then saved.
public enum PropLines {
    /// The cheer after a found prop, by the NEXT prop's number (deterministic, so a replay says the same one).
    public static let cheers = ["Yay!", "Great job!", "Woo-hoo!", "Awesome!"]
    public static func cheer(n: Int) -> String { cheers[max(0, n) % cheers.count] }

    /// "a pot", "an apron", "some books".
    public static func some(_ item: String) -> String {
        let l = item.lowercased().trimmingCharacters(in: .whitespaces)
        if l.count > 2, l.hasSuffix("s"), !l.hasSuffix("ss") { return "some \(l)" }
        return ("aeiou".contains(l.first ?? "x") ? "an " : "a ") + l
    }

    /// What the prop becomes, as a short spoken label without an article ("captain's hat", "plane seats").
    static func label(_ becomes: String) -> String {
        let cut = KitDraft.cutoutLabel(becomes: becomes)
        var l = (cut.isEmpty ? becomes : cut).trimmingCharacters(in: .whitespaces)
        for a in ["the ", "a ", "an ", "your ", "our "] where l.lowercased().hasPrefix(a) { l = String(l.dropFirst(a.count)) }
        return PlayCast.lowerFirst(l)
    }
    static func plural(_ word: String) -> Bool {
        let w = word.lowercased()
        return w.count > 2 && w.hasSuffix("s") && !w.hasSuffix("ss")
    }

    /// How the first prop explains the card's two buttons, once (round 26: a green check and an X).
    public static let howTo = "Tap the green check when you find it, or the X if you don't have one!"

    /// The ask for prop `n` (1-based). Prop 1 opens with "First," and explains the buttons; every 3rd prop uses the
    /// words "pretend that" (round 13); the others rotate four phrasings. The reason (round 24) follows in a few words.
    public static func ask(item: String, becomes: String, reason: String?, n: Int) -> String {
        let a = some(item), what = label(becomes)
        let the = "the " + what
        let one = plural(item) ? "some" : "one"
        let why = reason.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.flatMap { $0.isEmpty ? nil : PlayCast.endSentence($0) }
        let core: String
        if n <= 1 {
            core = "First, can you find \(a)? It'll be \(the)!"
        } else if n % 3 == 0 {
            core = "Can you find \(a)? Let's pretend that it's \(the)!"
        } else {
            switch (n / 3 + n) % 4 {
            case 0: core = "Can you find \(a)? It'll be \(the)!"
            case 1: core = "Ooh, \(a) would make \(plural(what) ? "great" : "a great") \(what)! Can you find \(one)?"
            case 2: core = "Now let's look for \(a). It'll be \(the)!"
            default: core = "How about \(a)? It can be \(the)!"
            }
        }
        return [core, why, n <= 1 ? howTo : nil].compactMap { $0 }.joined(separator: " ")
    }

    /// The whole line for prop `n`: the lead for the answer before it (a cheer after a found prop, the pretend line after
    /// a missing one), then the ask. Prop 1 has no lead.
    public static func line(item: String, becomes: String, reason: String?, n: Int, previous: Answer?) -> String {
        let ask = ask(item: item, becomes: becomes, reason: reason, n: n)
        guard n > 1, let previous else { return ask }
        switch previous {
        case .found: return cheer(n: n) + " " + ask
        case .pretend(let becomes): return ReplayLines.pretend(becomes) + " " + ask
        }
    }
    public enum Answer: Equatable, Sendable { case found, pretend(becomes: String) }

    /// The answer before prop `n` in a hunt list (nil for the first).
    public static func previous(_ props: [Prop], before index: Int) -> Answer? {
        guard index > 0, props.indices.contains(index - 1) else { return nil }
        let p = props[index - 1]
        return p.isSkipped ? .pretend(becomes: p.becomes) : .found
    }

    /// The prop line for card `index` of `props` (first play and replay share it).
    public static func line(for props: [Prop], index: Int) -> String? {
        guard props.indices.contains(index) else { return nil }
        let p = props[index]
        return line(item: p.householdItem, becomes: p.becomes, reason: p.reason, n: index + 1, previous: previous(props, before: index))
    }

    /// The tool output on a FIRST play when the app says the prop line itself (the model picked the prop; it says nothing,
    /// and is told the words so the conversation knows what was asked).
    public static func appSaysOutput(id: String, n: Int, target: Int, line: String) -> String {
        let last = n >= target
        return "Card \(id) is ready (prop \(n) of \(target)). Say NOTHING: the app shows the card and says the prop line "
            + "itself, in your voice: \"\(line)\" Then wait for the kids. "
            + (last
               ? "This is the LAST prop. Found: mark_found then finish_planning. Missing: swap_prop (one alternate) or skip_prop, then finish_planning."
               : "Found: mark_found then show_next_prop. Missing: swap_prop (one alternate) or skip_prop, then show_next_prop. This game has exactly \(target) props: finish_planning only after prop \(target).")
    }
}

// MARK: - Short tasks on screen, specifics spoken

/// Haylee: each role's ON-SCREEN task is short and broad (about 3–7 words, "Get the pet ready to go home"); the 🔊
/// SPOKEN version (`Step.text`, the guide's `say`) adds 1–2 concrete ideas with their props or kit. `TaskShort`
/// enforces the shown text with no AI call: no role title, no quotes, no end punctuation, 2–7 words; a missing or bad
/// one is cut down from the spoken text.
public enum TaskShort {
    public static let maxWords = 7
    public static let minWords = 2

    static func wordCount(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }

    /// Leading "<Role title>, " / "<Role title>: " / "<Role title> - " taken off ("Pet Trainer, get…" → "get…").
    public static func stripTitle(_ text: String, roles: [Role]) -> String {
        var t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for r in roles.sorted(by: { $0.roleName.count > $1.roleName.count }) where !r.roleName.isEmpty {
            let p = #"(?i)^(the\s+)?"# + NSRegularExpression.escapedPattern(for: r.roleName) + #"\s*[,:\-–—!]\s*"#
            if t.range(of: p, options: .regularExpression) != nil {
                t = t.replacingOccurrences(of: p, with: "", options: .regularExpression)
                break
            }
        }
        return t
    }

    static let leadIns = ["it's time to ", "it is time to ", "time to ", "now it's time to ", "now ", "please ", "you can ",
                          "you get to ", "your job is to ", "go ahead and ", "let's "]
    static let weakEnds: Set<String> = ["the", "a", "an", "to", "and", "with", "for", "of", "your", "their", "his", "her",
                                        "then", "or", "at", "in", "on", "so", "its", "it's", "every", "each", "some"]

    /// A short shown task cut from a longer one (the spoken text, or a too-long short).
    public static func derive(from text: String, roles: [Role]) -> String {
        var t = GuideRepair.unscripted(stripTitle(text, roles: roles))
        // The first sentence, then the first part of it.
        if let r = t.range(of: #"[.!?]"#, options: .regularExpression) { t = String(t[..<r.lowerBound]) }
        for sep in [#"\s*[;:]\s*"#, #",\s*(then|and then|while|so)\s+"#, #"\s+(then|and then|while)\s+"#, #",\s+"#] {
            if let r = t.range(of: sep, options: [.regularExpression, .caseInsensitive]), wordCount(String(t[..<r.lowerBound])) >= minWords {
                t = String(t[..<r.lowerBound])
            }
        }
        for lead in leadIns where t.lowercased().hasPrefix(lead) && wordCount(t) > 3 { t = String(t.dropFirst(lead.count)) }
        var words = t.split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count > maxWords, let k = words.prefix(maxWords + 1).lastIndex(where: { $0.lowercased() == "and" }), k >= minWords {
            words = Array(words.prefix(k))   // "Feed the pet and brush its fur and…" → "Feed the pet"
        }
        words = Array(words.prefix(maxWords))
        while words.count > minWords, let last = words.last, weakEnds.contains(last.lowercased().trimmingCharacters(in: .punctuationCharacters)) {
            words.removeLast()
        }
        return tidy(words.joined(separator: " "))
    }

    /// No end punctuation or quotes, first letter capital.
    static func tidy(_ s: String) -> String {
        var t = s.replacingOccurrences(of: #"["\x{201C}\x{201D}]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while let last = t.last, ".!?,;:".contains(last) { t.removeLast() }
        t = t.trimmingCharacters(in: .whitespaces)
        guard let f = t.first else { return t }
        return f.uppercased() + t.dropFirst()
    }

    /// The shown task (`short` from the guide, or nil) made valid for the spoken task `say`.
    public static func clean(_ short: String?, say: String, roles: [Role]) -> String {
        if let s = short?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty {
            let t = tidy(GuideRepair.unscripted(stripTitle(s, roles: roles)))
            let n = wordCount(t)
            if n >= minWords && n <= maxWords { return t }
            if n > maxWords { return derive(from: t, roles: roles) }
        }
        return derive(from: say, roles: roles)
    }

    /// Whether a shown task is valid as it is.
    public static func isValid(_ short: String?, roles: [Role]) -> Bool {
        guard let s = short else { return false }
        return clean(s, say: s, roles: roles) == s
    }
}

extension GuideRepair {
    /// Round 34: every task gets a valid short shown text (`TaskShort`). Idempotent.
    public static func shortTasks(_ scenes: [Scene], roles: [Role]) -> [Scene] {
        scenes.map { sc in
            var sc = sc
            sc.steps = sc.steps.map { st in
                var st = st
                st.short = TaskShort.clean(st.short, say: st.text, roles: roles)
                return st
            }
            return sc
        }
    }
}

// MARK: - The scene opening: the setup and a cue, not every task

extension HandOffLines {
    /// Round 34 (Haylee): a scene opens with ONLY the "Pretend that…" setup plus the cue; each kid taps their own row
    /// to hear their job. Repeat says the same. (Measured: the old openings read every task, ~30 s each.)
    public static let taskCue = "Tap your speaker when you're ready to hear your job!"
}

// MARK: - The whole row is the tap target

/// Haylee: tapping ANYWHERE on a scene row (picture, text or 🔊) plays that role's spoken task. One accessibility
/// element per row. Pure mapping from the visible rows, so a row tap and the 🔊 can't disagree.
public enum SceneRowTap {
    /// The line a tap on row `index` plays (nil: no such row).
    public static func line(rows: [Step], index: Int) -> String? {
        guard rows.indices.contains(index) else { return nil }
        return HandOffLines.task(rows[index])
    }
    /// Round 37: the voice "what do I do?" (`read_job`) reads ALL of that role's rows in the scene (the setup and
    /// clean-up scenes may give a role 2 to 4 rows), in order, as one line. A tap still reads just its own row.
    public static func roleLine(rows: [Step], index: Int) -> String? {
        guard rows.indices.contains(index) else { return nil }
        let role = rows[index].role
        let mine = rows.filter { $0.role == role }
        return mine.map(HandOffLines.task).joined(separator: " ")
    }
    /// The row's accessibility label: "Hear the Pet Trainer's job".
    public static func accessibilityLabel(roleName: String) -> String {
        let name = roleName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Hear your job" : "Hear the \(name)'s job"
    }
    /// The voice "what do I do, Pet Trainer?" (`read_job`): the row whose role is named, or nil.
    public static func row(named role: String, rows: [Step], roles: [Role]) -> Int? {
        let wanted = ClipText.normalize(role)
        guard !wanted.isEmpty else { return nil }
        let ranked = rows.indices.compactMap { i -> (Int, String)? in
            guard let id = rows[i].role.role, let r = roles.first(where: { $0.id == id }) else { return nil }
            return (i, ClipText.normalize(r.roleName))
        }
        if let hit = ranked.first(where: { $0.1 == wanted }) { return hit.0 }
        if let hit = ranked.first(where: { wanted.contains($0.1) || $0.1.contains(wanted) }) { return hit.0 }
        // "R2" / "role 2"
        if let n = Int(wanted.filter(\.isNumber)), let hit = rows.indices.first(where: { rows[$0].role.role?.rank == n }) { return hit }
        return nil
    }
}

// MARK: - The in-app speech model download (iOS 26+)

/// Haylee: on iPadOS versions with SpeechAnalyzer / AssetInventory (26+), the app downloads Apple's on-device English
/// speech model itself, from a friendly one-tap grown-up screen with progress, started quietly at onboarding's mic step
/// so it's usually ready before the first press. Older versions keep the Settings › Dictation note. Pure state + copy;
/// the app drives it (`SpeechModelInstaller`).
public enum SpeechModelState: Equatable, Sendable {
    /// Not looked at yet.
    case unknown
    /// The OS has no in-app download (before iPadOS 26): the Settings note.
    case notSupportedHere
    /// English can't be installed on this device at all.
    case unsupportedLanguage
    /// Ready to download (one tap).
    case needsDownload
    /// Downloading: 0…1.
    case downloading(Double)
    /// On the iPad: Nutmeg can listen.
    case installed
    /// The download stopped (no network, out of space…): try again.
    case failed

    public var isReady: Bool { self == .installed }
    public var canStart: Bool { self == .needsDownload || self == .failed }
    public var progress: Double? { if case .downloading(let p) = self { return max(0, min(1, p)) } else { return nil } }

    /// The grown-up screen's words for this state.
    public var copy: (title: String, body: String, button: String?) {
        switch self {
        case .unknown, .needsDownload:
            return (SpeechModelCopy.title, SpeechModelCopy.body, SpeechModelCopy.button)
        case .downloading(let p):
            return (SpeechModelCopy.downloadingTitle, SpeechModelCopy.downloadingBody(p), nil)
        case .installed:
            return (SpeechModelCopy.doneTitle, SpeechModelCopy.doneBody, SpeechModelCopy.doneButton)
        case .failed:
            return (SpeechModelCopy.failedTitle, SpeechModelCopy.failedBody, SpeechModelCopy.retryButton)
        case .unsupportedLanguage, .notSupportedHere:
            return (SpeechModelCopy.settingsTitle, SpeechModelCopy.settingsBody, nil)
        }
    }

    /// The next state for an installer event (the app's `SpeechModelInstaller` feeds these).
    public func next(_ event: Event) -> SpeechModelState {
        switch event {
        case .osTooOld: return .notSupportedHere
        case .status(let s):
            switch s {
            case .installed: return .installed
            case .unsupported: return .unsupportedLanguage
            case .downloading: return self.progress != nil ? self : .downloading(0)
            case .supported: return self == .failed ? .failed : .needsDownload
            }
        case .started: return .downloading(0)
        case .progress(let p): return self == .installed ? .installed : .downloading(p)
        case .finished: return .installed
        case .error: return self == .installed ? .installed : .failed
        }
    }
    public enum Event: Equatable, Sendable {
        case osTooOld, status(AssetStatus), started, progress(Double), finished, error
    }
    /// Mirrors `AssetInventory.Status` (unsupported < supported < downloading < installed).
    public enum AssetStatus: Equatable, Sendable { case unsupported, supported, downloading, installed }
}

public enum SpeechModelCopy {
    public static let title = "Help Nutmeg learn to listen"
    public static let body = "Nutmeg needs to learn to listen, one time. It's Apple's English speech model, and it stays on "
        + "this iPad, so your child's voice is turned into words right here and never sent anywhere. About a minute on Wi-Fi."
    public static let button = "Download now"
    public static let downloadingTitle = "Nutmeg is learning to listen…"
    public static func downloadingBody(_ p: Double) -> String {
        let pct = Int((max(0, min(1, p)) * 100).rounded())
        return "\(pct)% done. You can keep using the iPad; it finishes in the background. About a minute on Wi-Fi."
    }
    public static let doneTitle = "All set!"
    public static let doneBody = "Nutmeg can hear you now. Hold the big red mic button and talk!"
    public static let doneButton = "Done"
    public static let failedTitle = "The download stopped"
    public static let failedBody = "Check that the iPad is on Wi-Fi and has a little free space, then try again."
    public static let retryButton = "Try again"
    public static let settingsTitle = "Grown-ups: Nutmeg's ears need a download"
    public static let settingsBody = "On this iPad, turn on Dictation in Settings › General › Keyboard, and let it download "
        + "English. Until then, kids can type to Nutmeg."
    /// The alert's title when the mic is pressed before the model is there (iPadOS 26+).
    public static let micAlertTitle = "Nutmeg needs to learn to listen"
    public static let micAlertBody = "One quick download, about a minute on Wi-Fi. It stays on this iPad."
}
