#if DEBUG
import SwiftUI
import UIKit
import NutmegCore

/// Round 45 DEBUG harness (`-PTRenderKitPages`): renders every printable type and layout variant, in both print sets,
/// through the app's own `KitPageView`, with FIXTURE art (the hand-drawn prop library pictures, no AI calls), to
/// tmp/pages/*.png plus a contact sheet per set, then quits. Copy them out with `simctl get_app_container … data`.
enum KitPageGallery {
    static var requested: Bool { ProcessInfo.processInfo.arguments.contains("-PTRenderKitPages") }

    static let roles: [Role] = RoleCast.rank([
        Role(id: .R1, roleName: "Captain", emoji: "", symbol: "star", job: "steer the ship"),
        Role(id: .R2, roleName: "First Mate", emoji: "", symbol: "star", job: "read the map"),
        Role(id: .R3, roleName: "Lookout", emoji: "", symbol: "star", job: "spot the island"),
        Role(id: .R4, roleName: "Cook", emoji: "", symbol: "star", job: "make the snacks"),
        Role(id: .R5, roleName: "Treasure Keeper", emoji: "", symbol: "star", job: "count the gold"),
        Role(id: .R6, roleName: "Parrot Pal", emoji: "", symbol: "star", job: "squawk the clues"),
    ])

    /// One fixture item per type and variant.
    static func items() -> [KitItem] {
        func make(_ t: KitRecipe, _ v: KitVariant, title: String, lines: [String], pictures: [String]? = nil) -> KitItem {
            var i = PrintDefaults.item(t, title: title)
            i.lines = lines; i.pictures = pictures; i.variant = v
            i.id = "\(t.rawValue)-\(v.rawValue)"
            i.copies = PrintLibrary.copies(i)
            return i
        }
        var out: [KitItem] = []
        for v in KitRecipe.badges.variants { out.append(make(.badges, v, title: "Rainbow Crew", lines: [])) }
        for v in KitRecipe.sign.variants { out.append(make(.sign, v, title: "Captain Coral's Ship", lines: ["All aboard!"])) }
        for v in KitRecipe.money.variants { out.append(make(.money, v, title: "Sea Bucks", lines: [], pictures: ["a seashell"])) }
        out.append(make(.tickets, .boarding, title: "Boarding Pass", lines: ["Trip to Treasure Island"]))
        out.append(make(.tickets, .admission, title: "Big Top Show", lines: ["Front row fun"]))
        out.append(make(.tickets, .keycard, title: "Appointment Card", lines: ["Paw Check-up"]))
        out.append(make(.menu, .menuCard, title: "Galley Menu", lines: ["Fish Tacos $3", "Coconut Milk $2", "Sea Salad $2", "Treasure Cake $5", "Lemon Fizz $1", "Kelp Chips $1"]))
        out.append(make(.menu, .chalkboard, title: "Lemonade", lines: ["Pink Lemonade $1", "Ice Pop $2", "Cookie $1"]))
        out.append(make(.menu, .program, title: "Circus Spectacular", lines: ["Juggling Bears", "Clown Car", "Flying Hoops", "Big Finale"]))
        out.append(make(.cutouts, .standard, title: "Pirate Cut-outs", lines: ["Spyglass", "Gold coin", "Parrot", "Anchor", "Compass", "Key"]))
        out.append(make(.orderSlips, .standard, title: "Order Up!", lines: ["Pizza", "Juice", "Salad", "Cake"]))
        out.append(make(.map, .standard, title: "Treasure Map", lines: ["Big Rock", "Palm Tree", "Bridge", "Cave"]))
        out.append(make(.clueCards, .standard, title: "Clue Cards", lines: ["Look under something soft", "Find the big rock", "Peek by the door", "Look up high", "Check near a chair", "The treasure is close"]))
        out.append(make(.missionCards, .standard, title: "Hero Missions", lines: ["Rescue the kitten", "Stop the rain", "Help a friend", "Fix the bridge"]))
        out.append(make(.log, .ruled, title: "Captain's Log", lines: ["Islands we saw", "Treasure found"]))
        out.append(make(.log, .chart, title: "Patient Chart", lines: ["Temperature", "Heartbeat", "Ate dinner", "Took a nap"]))
        out.append(make(.medals, .standard, title: "Medals", lines: ["Bravest Pirate", "Best Lookout", "Super Cook"]))
        out.append(make(.stickers, .standard, title: "Stickers", lines: ["Brave!", "Wow!", "Super!"]))
        out.append(make(.passport, .standard, title: "Sky Passport", lines: ["Paris", "The Moon", "Jungle", "Snow Land", "Beach"]))
        out.append(make(.labels, .standard, title: "Price Tags", lines: ["Apples $2", "Carrots $1", "Bread $3", "Milk $2"]))
        out.append(make(.decoder, .standard, title: "Secret Code", lines: ["LOOK UP", "GOLD", "YOU WIN"]))
        out.append(make(.controlPanel, .standard, title: "Rocket Controls", lines: ["Launch", "Lights", "Boost", "Radio", "Shields", "Land"]))
        return out
    }

    /// Fixture pictures: the prop library's hand-drawn art (never AI), gray for the outline set.
    static func fixture(_ k: Int, outline: Bool) -> UIImage? {
        let ids = PropLibrary.ids
        guard !ids.isEmpty, let img = UIImage(named: PropLibrary.asset(ids[(k * 7) % ids.count])) else { return nil }
        guard outline, let ci = CIImage(image: img), let f = CIFilter(name: "CIPhotoEffectMono") else { return img }
        f.setValue(ci, forKey: kCIInputImageKey)
        guard let out = f.outputImage, let cg = CIContext().createCGImage(out, from: ci.extent) else { return img }
        return UIImage(cgImage: cg)
    }

    @MainActor static func renderAll() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.removeItem(at: dir)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for style in PrintStyle.sets {
            var thumbs: [(String, UIImage)] = []
            for (n, item) in items().enumerated() {
                let kit = Kit(nutmegSays: "", items: [item], scenes: [])
                guard let page = KitLayout.pages(for: kit, roles: roles, playerCount: item.recipe == .badges ? 6 : 4).first else { continue }
                let outline = style == .colorIn
                let art: UIImage? = PrintLibrary.art(item) == .none ? nil : fixture(n, outline: outline)
                let count: Int
                switch PrintLibrary.art(item, roles: roles) {
                case .sheet(let c): count = c
                case .characters: count = 6
                case .cutouts: count = item.lines.count
                default: count = 0
                }
                let pics = (0..<count).map { fixture(n * 3 + $0 + 1, outline: outline) }
                let view = KitPageView(page: page, art: art, cutouts: pics, style: style)
                let r = ImageRenderer(content: view); r.scale = 1.5
                guard let img = r.uiImage, let png = img.pngData() else { continue }
                let name = "\(String(format: "%02d", n + 1))-\(item.id)-\(style.toolValue)"
                try? png.write(to: dir.appendingPathComponent(name + ".png"))
                thumbs.append(("\(item.recipe?.spokenName ?? "") · \(item.variant?.name ?? "")", img))
            }
            if let sheet = contactSheet(thumbs, title: style == .fullColor ? "Round 45 printables: color set" : "Round 45 printables: outline set") {
                try? sheet.pngData()?.write(to: dir.appendingPathComponent("contact-sheet-\(style.toolValue).png"))
            }
        }
        NSLog("[RT] KIT PAGES rendered to %@", dir.path)
    }

    /// `-PTLiveKit "<game>"`: ONE live kit with real AI (keyed Debug build only): the roles, the kit pages from the
    /// library, the play guide (with its setup / clean-up jobs), both art sets and the cover; renders every page of
    /// both sets to tmp/live/<game>/ and logs the kit, the coverage and the cost (numbers only, never keys). No voice.
    static var liveKitGame: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-PTLiveKit"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    @MainActor static func liveKit(_ game: String, info: [String: Any] = Bundle.main.infoDictionary ?? [:]) async {
        guard let config = ClaudeConfig.from(info: info), let images = ImageClient.from(info: info) else { NSLog("[RT] LIVEKIT no keys"); return }
        let svc = PhaseService(llm: ClaudeClient(config: config))
        ClaudeUsageMeter.shared.reset(); ImageUsageLog.reset()
        let started = Date()
        var ctx = AdventureContext(gameTitle: game, playerCount: 3)
        do {
            let plan = try await svc.plan(game: game, ctx: ctx)
            ctx.plan = plan
            let memory = RecentPrintMemory()
            let picks = PrintPicks.make(game: [game], recent: memory.games)
            NSLog("[RT] LIVEKIT %@: game=%@ shortlist=%@ recent=%@", game, picks.game?.id ?? "made-up",
                  picks.shortlist.map(\.rawValue).joined(separator: ","), memory.games.map { $0.joined(separator: "+") }.joined(separator: " | "))
            let items = try await svc.kitPages(ctx: ctx, picks: picks)
            for i in items {
                NSLog("[RT] LIVEKIT item %@ (%@): \"%@\" lines=%@ pictures=%@ purpose=%@", i.recipe?.rawValue ?? "?", i.variant?.name ?? "-", i.title,
                      i.lines.joined(separator: " | "), (i.pictures ?? []).joined(separator: " | "), i.purpose ?? "")
            }
            memory.record(items)
            // The art (both sets) starts now, like the hunt; the guide is written meanwhile.
            let limiter = AsyncLimiter(limit: KitArtService.concurrency)
            let color = KitArtService(client: images, style: .fullColor, limiter: limiter)
            let outline = KitArtService(client: images, style: .colorIn, limiter: limiter)
            let cover = CoverArtService(client: images, limiter: limiter)
            color.prepare(items: items, gameTitle: game, roles: plan.roles)
            outline.prepare(items: items, gameTitle: game, roles: plan.roles)
            cover.start(title: game, setting: plan.setting)
            var kit = try await svc.earlyGuide(ctx: ctx, items: items)
            kit = Bookends.repair(kit, props: [], roles: plan.roles, title: game).kit
            let scenes = PlayCast.kit(kit, roles: plan.roles, players: 3, props: []).scenes
            let cover3 = Bookends.coverItems(items: kit.items, props: [])
            for line in SetupCoverage.log(scenes, items: cover3, roles: plan.roles) { NSLog("[RT] LIVEKIT COVERAGE %@", line) }
            NSLog("[RT] LIVEKIT setup missing=%@ cleanup missing=%@", SetupCoverage.setupMissing(scenes, items: cover3).joined(separator: ","),
                  SetupCoverage.cleanupMissing(scenes, items: cover3).joined(separator: ","))
            for it in cover3 {
                let play = kit.playScenes.flatMap(\.steps).filter { Bookends.mentions($0.text, it) }.count
                NSLog("[RT] LIVEKIT play tasks naming %@: %d", it.id, play)
            }
            for s in kit.playScenes { for st in s.steps where st.role == .R1 || st.role == .R2 { NSLog("[RT] LIVEKIT task %@ %@: %@", s.title, st.role.rawValue, st.text) } }
            async let a: Void = color.generate(kit: kit, gameTitle: game, roles: plan.roles)
            async let b: Void = outline.generate(kit: kit, gameTitle: game, roles: plan.roles)
            _ = await (a, b)
            for _ in 0..<600 where cover.settledAt == nil { try? await Task.sleep(for: .milliseconds(100)) }
            // Render both sets.
            let slug = game.lowercased().replacingOccurrences(of: " ", with: "-")
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent("live/\(slug)", isDirectory: true)
            try? FileManager.default.removeItem(at: dir)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let pages = KitLayout.pages(for: kit, roles: plan.roles, playerCount: 3)
            var thumbs: [(String, UIImage)] = []
            for set in [color, outline] {
                for (n, page) in pages.enumerated() {
                    let r = ImageRenderer(content: KitPageView(page: page, art: set.images[page.item.id], cutouts: set.cutoutImages(page.item), style: set.style))
                    r.scale = 1.5
                    guard let img = r.uiImage else { continue }
                    try? img.pngData()?.write(to: dir.appendingPathComponent("\(set.style.toolValue)-\(n + 1)-\(page.item.id).png"))
                    thumbs.append(("\(set.style.toolValue) · \(page.item.recipe?.spokenName ?? "") · \(page.item.variant?.name ?? "")", img))
                }
                for (key, img) in set.artByKey { try? img.pngData()?.write(to: dir.appendingPathComponent("art-\(ArtKey.fileName(key)).png")) }
            }
            if let c = cover.image { try? c.pngData()?.write(to: dir.appendingPathComponent("cover.png")) }
            if let sheet = contactSheet(thumbs, title: "Live: \(game)") { try? sheet.pngData()?.write(to: dir.appendingPathComponent("contact-sheet.png")) }
            let calls = ClaudeUsageMeter.shared.calls
            let cents = calls.map { ClaudeUsageMeter.cents(input: $0.input, output: $0.output) }.reduce(0, +)
            let u = ImageUsageLog.snapshot()
            NSLog("[RT] LIVEKIT COST %@: claude %d calls %.2f cents; images %d requests (%d per set + cover) %d in + %d out tokens = $%.3f; %.0f s",
                  game, calls.count, cents, u.requests, KitArtPlan.imageCount(items, roles: plan.roles), u.inputTokens, u.outputTokens, u.dollars,
                  Date().timeIntervalSince(started))
        } catch {
            NSLog("[RT] LIVEKIT %@ failed: %@", game, String(describing: error))
        }
        NSLog("[RT] LIVEKIT-END")
    }

    /// Thumbnails in a grid with a label under each.
    static func contactSheet(_ thumbs: [(String, UIImage)], title: String) -> UIImage? {
        guard !thumbs.isEmpty else { return nil }
        let cols = 7, tw: CGFloat = 306, th: CGFloat = 396, lab: CGFloat = 34, pad: CGFloat = 16, head: CGFloat = 70
        let rows = Int(ceil(Double(thumbs.count) / Double(cols)))
        let size = CGSize(width: pad + CGFloat(cols) * (tw + pad), height: head + CGFloat(rows) * (th + lab + pad) + pad)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor(white: 0.93, alpha: 1).setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            (title as NSString).draw(at: CGPoint(x: pad, y: 18), withAttributes: [.font: UIFont.boldSystemFont(ofSize: 32)])
            for (i, t) in thumbs.enumerated() {
                let x = pad + CGFloat(i % cols) * (tw + pad), y = head + CGFloat(i / cols) * (th + lab + pad)
                let r = CGRect(x: x, y: y, width: tw, height: th)
                UIColor.white.setFill(); ctx.fill(r)
                t.1.draw(in: r)
                UIColor(white: 0.6, alpha: 1).setStroke(); ctx.stroke(r)
                (t.0 as NSString).draw(in: CGRect(x: x, y: y + th + 4, width: tw, height: lab),
                                       withAttributes: [.font: UIFont.systemFont(ofSize: 20, weight: .semibold)])
            }
        }
    }
}
#endif
