import CoreImage
import SwiftUI
import UIKit
import NutmegCore

/// Draws one set of the kit's pages with OpenAI (in parallel, on the shared limiter). Round 46 (Haylee,
/// decisions/2026-11-17-ai-drawn-printables.md): each printable is ONE whole-page image drawn by the image model from its
/// recipe (`KitPagePrompt`): frame, layout, pictures and every word. The app draws nothing on it; it only fits the page
/// inside the paper's margins (`KitPageView`, `PageFit`). The color set also draws the kit's ONE character sheet (the
/// roles' characters and the cut-out things, no words), sliced for the in-app pictures. A page whose art never comes is
/// printed app-drawn (round 45's layout) instead. There are no names anywhere (the pages print blank Name lines).
/// Round 27 (Haylee): one service PER STYLE (the full-color set and the outline set are both drawn during the hunt),
/// sharing one limiter so the whole game stays at most 3 image calls at once.
@Observable @MainActor
final class KitArtService {
    /// Page images by art key (`KitPage.artKey`: the item id, `badges@N`, `cutouts#more`).
    private(set) var images: [String: UIImage] = [:]
    /// Slices by sheet id → index: the character sheet (`characters`, color set only), and a replayed older game's
    /// saved slices (round 45's picture sheets, round C1's badge sheet, cut-outs).
    private(set) var cutouts: [String: [Int: UIImage]] = [:]
    private(set) var isGenerating = false
    /// Every page's art has landed or definitively failed (or there's no image service): the kit is final.
    private(set) var finished = false
    /// Pages drawn so far / pages asked for, for the progress bar.
    private(set) var progress: Double = 0
    @ObservationIgnored private let client: ImageClient?
    /// Round 27: the look this set is drawn in.
    let style: PrintStyle
    /// Round 46: the color set draws the kit's character sheet (one per kit).
    var drawsCharacters: Bool { style == .fullColor }

    init(client: ImageClient?, style: PrintStyle, limiter: AsyncLimiter) {
        self.client = client; self.style = style; self.limiter = limiter
    }

    var isAvailable: Bool { client != nil }
    /// Set after OpenAI says this account can't make images this run (no credits, unverified org, bad key).
    var unavailableReason: String? { client?.unavailableReason }

    /// Round 19: a remade kit (corrected theme) starts a new generation; results from an older one are dropped.
    @ObservationIgnored private var generation = 0
    func reset() {
        generation += 1; images = [:]; cutouts = [:]; isGenerating = false; progress = 0; finished = false
        drawnFor = nil; inFlight = []; failed = []; retriedAfterAway = []; finalItems = nil; landedAt = [:]
        context = nil; finishedAt = nil; wordChecks = [:]
        #if DEBUG
        firstDrawings = [:]
        #endif
    }

    func cutout(_ itemID: String, _ index: Int) -> UIImage? { cutouts[itemID]?[index] }

    /// Round D1: a replay's saved page art, exactly as the first play drew it. No image calls: the kit is final at once.
    func restore(images: [String: UIImage], cutouts: [String: [Int: UIImage]]) {
        reset()
        self.images = images; self.cutouts = cutouts
        progress = 1; finished = true
    }
    /// Round D1: every page image and slice (the character sheet's included) by its stored art key, for Save.
    var artByKey: [String: UIImage] {
        var out: [String: UIImage] = [:]
        for (id, img) in images { out[ArtKey.image(id, style: style)] = img }   // round 27: the outline set is o-prefixed
        for (id, m) in cutouts { for (n, img) in m { out[ArtKey.cutout(id, n, style: style)] = img } }
        return out
    }

    // MARK: In-app pictures (round 46: the character sheet)

    /// Role `k`'s character from the character sheet (nil while it isn't drawn: the row shows the role's color chip).
    func character(_ k: Int) -> UIImage? { cutouts[CharacterSheet.id]?[k] }
    /// Cut-out thing `j`'s picture from the character sheet.
    func thing(_ j: Int) -> UIImage? { cutouts[CharacterSheet.id]?[CharacterSheet.roleCount + j] }

    #if DEBUG
    /// `-PTFakeArt`: test pages at the real AI size (an off-white sheet with a red edge frame and a label touching the
    /// bottom edge), so the print path can be checked for clipping without paid image calls.
    private func fakeArt(_ kit: Kit, _ ctx: KitArtContext) {
        func make(_ size: String, _ label: String) -> UIImage {
            let p = size.split(separator: "x").compactMap { Double($0) }
            let s = CGSize(width: p.first ?? 1024, height: p.last ?? 1024)
            return PaperWhite.normalize(UIGraphicsImageRenderer(size: s).image { c in
                UIColor(white: 0.95, alpha: 1).setFill(); c.fill(CGRect(origin: .zero, size: s))
                UIColor(white: 0.86, alpha: 1).setFill(); c.fill(CGRect(x: s.width * 0.2, y: s.height * 0.3, width: s.width * 0.6, height: s.height * 0.4))
                UIColor.red.setStroke(); c.cgContext.setLineWidth(12); c.cgContext.stroke(CGRect(origin: .zero, size: s).insetBy(dx: 6, dy: 6))
                let a: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: s.width / 9), .foregroundColor: UIColor.black]
                let t = NSAttributedString(string: label, attributes: a); let ts = t.size()
                t.draw(at: CGPoint(x: (s.width - ts.width) / 2, y: s.height - ts.height - 14))
            })
        }
        for job in KitArtPlan.jobs(items: kit.items, ctx: ctx, style: style, settled: [], characters: drawsCharacters) {
            if job.isSheet {
                for k in 0..<job.count { cutouts[CharacterSheet.id, default: [:]][k] = make("384x384", "C\(k + 1)") }
            } else { images[job.key] = make(job.size, "BOTTOM") }
        }
        finished = true; progress = 1
    }
    #endif

    /// The slices an older (replayed) item's app-drawn page uses, or a round 46 fallback page's pictures: the badges'
    /// characters and the cut-outs' things from the character sheet (nil where not drawn).
    func cutoutImages(_ item: KitItem) -> [UIImage?] {
        if item.aiPage {
            switch item.recipe {
            case .badges?: return cutouts[CharacterSheet.id] == nil ? [] : (0..<CharacterSheet.roleCount).map { character($0) }
            case .cutouts?: return cutouts[CharacterSheet.id] == nil ? [] : item.lines.indices.map { thing($0) }
            default: return []
            }
        }
        if item.recipe == .badges {
            guard let m = cutouts[item.id], !m.isEmpty else { return [] }
            return (0..<RoleCast.count).map { m[$0] }
        }
        // Round 45 (replays): a library printable's saved sheet of pictures (one per entry).
        if item.pictureOnly, item.recipe != .cutouts {
            guard let m = cutouts[item.id], !m.isEmpty else { return [] }
            return (0..<(m.keys.max() ?? -1) + 1).map { m[$0] }
        }
        guard let m = cutouts[item.id], !m.isEmpty else { return [] }
        return (0..<max(item.lines.count, (m.keys.max() ?? -1) + 1)).map { m[$0] }
    }

    /// Round 46: this page's whole-page image (nil while it's drawing, or when it never came: app-drawn instead).
    func pageImage(_ page: KitPage) -> UIImage? { images[page.artKey] }

    /// This item's art hasn't landed yet (a page with nothing to draw, like the decoder, never waits).
    func isMissing(_ item: KitItem) -> Bool {
        guard item.aiPage else { return false }   // older kits are only replayed: their art is all there
        let keys = KitArtPlan.keys(items: [item], ctx: context ?? KitArtContext(title: ""))
        return keys.contains { images[$0] == nil && !failed.contains($0) }
    }
    /// Round 46: one page's art hasn't landed yet.
    func isMissing(_ page: KitPage) -> Bool {
        guard page.item.aiPage, page.item.recipe != .decoder else { return false }
        return images[page.artKey] == nil && !failed.contains(page.artKey)
    }
    /// Round 28: role `k`'s own slice of an older game's badge sheet (nil while it isn't drawn).
    func badgeSlice(_ itemID: String, role k: Int) -> UIImage? { cutouts[itemID]?[k] }
    /// Role `k`'s badge picture: round 46's character, else an older game's badge slice, else its shared badge image.
    func badge(_ itemID: String, role k: Int?, aiPage: Bool = false) -> UIImage? {
        if aiPage { return k.flatMap { character($0) } }
        if let k, let slice = cutouts[itemID]?[k] { return slice }
        return images[itemID]
    }

    /// What the art in hand was drawn for (title + style + the 6 role titles). A different one starts over.
    @ObservationIgnored private var drawnFor: String?
    /// The latest context (title, setting, roles, players): a changed player count only redraws the badge page.
    @ObservationIgnored private var context: KitArtContext?
    /// Jobs running or settled this generation (landed, or given up after one retry: the page is app-drawn).
    @ObservationIgnored private var inFlight: Set<String> = []
    @ObservationIgnored private var failed: Set<String> = []
    @ObservationIgnored private var retriedAfterAway: Set<String> = []
    /// The final kit's items (nil during the hunt): `finished` is about these.
    @ObservationIgnored private var finalItems: [KitItem]?
    /// Round 20: at most 3 image calls at once (the relay's 40 images/min limit; no 429 bursts). Round 27: the limiter
    /// is shared by both sets and the cover.
    static let concurrency = 3
    @ObservationIgnored private let limiter: AsyncLimiter
    /// DEBUG timing: when each job landed.
    @ObservationIgnored private(set) var landedAt: [String: Date] = [:]

    /// Round 20: the kit pages written during the hunt: their art starts now, in the background (no commentary).
    func prepare(items: [KitItem], context ctx: KitArtContext) {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { return }
        #endif
        guard let client else { return }
        startOver(ifNot: Self.drawKey(ctx, style))
        context = ctx
        NSLog("[RT] kit art (%@): hunt prefetch, %d item(s)", style.toolValue, items.count)
        launch(KitArtPlan.jobs(items: items, ctx: ctx, style: style, settled: settled, characters: drawsCharacters), client: client)
    }

    /// What the art is drawn for: the title, the style and the 6 role titles (the player count isn't here: a new count
    /// only adds the badge page for it, `badges@N`).
    static func drawKey(_ ctx: KitArtContext, _ style: PrintStyle) -> String {
        "\(ctx.title)|\(style.rawValue)|" + ctx.roles.map(\.roleName).joined(separator: ",")
    }

    /// The final kit (hunt over): any page not drawn or drawing yet starts now (the skipped props' cut-outs page, the
    /// badge page for a changed count, a page that was never prefetched); `finished` once every page has landed or
    /// definitively failed.
    func generate(kit: Kit, context ctx: KitArtContext) async {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTFakeArt") { context = ctx; fakeArt(kit, ctx); return }
        #endif
        guard let client else { finished = true; progress = 1; return }   // app-drawn pages: final right away
        startOver(ifNot: Self.drawKey(ctx, style))
        context = ctx
        finished = false
        finalItems = kit.items
        let gen = generation
        let jobs = KitArtPlan.jobs(items: kit.items, ctx: ctx, style: style, settled: settled, characters: drawsCharacters)
        NSLog("[RT] kit art (%@): final kit, %d new job(s), %d already drawing, %d landed", style.toolValue, jobs.count,
              inFlight.count, images.count)
        launch(jobs, client: client)
        updateFinished()
        // Wait here until the kit is final (callers don't depend on it, but it keeps the old async shape).
        while gen == generation && !finished { try? await Task.sleep(for: .milliseconds(200)) }
    }

    private var settled: Set<String> { inFlight.union(failed).union(images.keys).union(cutouts[CharacterSheet.id] == nil ? [] : [KitArtPlan.characterKey]) }

    private func startOver(ifNot key: String) {
        guard drawnFor != key else { return }
        if drawnFor != nil { reset() }
        drawnFor = key
    }

    /// Round 46: the word check of each page (the first drawing, and the redraw when there was one), for the logs and
    /// the DEBUG live harness. Page keys and counts only; the words are the kit's own (nothing about kids).
    struct WordCheck {
        var first: PageWordCheck.Result
        var firstRead: [String]
        var redraw: PageWordCheck.Result?
        var redrawRead: [String]?
        var keptRedraw: Bool
    }
    @ObservationIgnored private(set) var wordChecks: [String: WordCheck] = [:]
    #if DEBUG
    /// The first drawing of a page that was redrawn (the live harness saves both).
    @ObservationIgnored private(set) var firstDrawings: [String: UIImage] = [:]
    #endif

    /// One drawing, decoded off the main actor: paper-white, then sliced (a sheet) or read for its words (a page).
    private nonisolated static func decode(_ data: Data, job: KitArtJob, style: PrintStyle) async -> (images: [UIImage], check: (PageWordCheck.Result, [String])?) {
        await Task.detached(priority: .utility) { () -> ([UIImage], (PageWordCheck.Result, [String])?) in
            guard let img = UIImage(data: data) else { return ([], nil) }
            let white = PaperWhite.normalize(img, style: job.isSheet ? .fullColor : style)
            if job.isSheet { return (CutoutSlicer.slice(white, columns: job.columns, rows: job.rows, count: job.count), nil) }
            let page = white.preparedForDisplay()
            return ([page], job.words.isEmpty ? nil : PageOCR.check(page, words: job.words))
        }.value
    }

    private func launch(_ jobs: [KitArtJob], client: ImageClient) {
        let gen = generation, style = style
        isGenerating = isGenerating || !jobs.isEmpty
        for job in jobs {
            inFlight.insert(job.key)
            Task { @MainActor in
                let limiter = self.limiter
                func draw(_ prompt: String) async -> Result<Data, Error> {
                    // Retry once, then the existing fallback (that page is app-drawn).
                    do { return .success(try await RetryOnce.run { try await limiter.run { try await client.generate(prompt: prompt, size: job.size, quality: ImageQuality.kit) } }) }
                    catch { return .failure(error) }
                }
                // Round 21: decode + paper-white + slicing (+ round 46's word check) run OFF the main actor.
                let result = await draw(job.prompt)
                var decoded: [UIImage] = []
                var check: (PageWordCheck.Result, [String])?
                if case .success(let data) = result { (decoded, check) = await Self.decode(data, job: job, style: style) }
                guard gen == self.generation else { return }   // a remade kit: this old page is dropped
                // Round 46: a word really missing or misspelled: the page is redrawn ONCE and the better one kept.
                if let (first, read) = check, let firstImage = decoded.first {
                    var log = WordCheck(first: first, firstRead: read, redraw: nil, redrawRead: nil, keptRedraw: false)
                    NSLog("[RT] kit art words %@ (%@): %d of %d words read%@", job.key, style.toolValue,
                          first.wanted.count - first.missing.count, first.wanted.count, first.ok ? "" : ": redrawing once")
                    #if DEBUG
                    if !first.ok { NSLog("[RT] kit art words %@ missing: %@", job.key, first.missing.joined(separator: " | ")) }
                    #endif
                    if !first.ok {
                        let again = KitPagePrompt.redraw(PagePrompt(prompt: job.prompt, words: job.words), missing: first.missing)
                        if case .success(let d2) = await draw(again.prompt) {
                            let (images2, check2) = await Self.decode(d2, job: job, style: style)
                            guard gen == self.generation else { return }
                            if let (second, read2) = check2, let image2 = images2.first {
                                log.redraw = second; log.redrawRead = read2
                                log.keptRedraw = !PageWordCheck.better(first, second)   // strictly better, else the first stays
                                if log.keptRedraw {
                                    #if DEBUG
                                    self.firstDrawings[job.key] = firstImage
                                    #endif
                                    decoded = [image2]
                                } else {
                                    #if DEBUG
                                    self.firstDrawings[job.key] = image2   // (the one not kept)
                                    #endif
                                }
                                NSLog("[RT] kit art words %@ (%@): redraw %d of %d words read: kept the %@", job.key, style.toolValue,
                                      second.wanted.count - second.missing.count, second.wanted.count, log.keptRedraw ? "redraw" : "first drawing")
                            }
                        } else {
                            NSLog("[RT] kit art words %@ (%@): the redraw failed: kept the first drawing", job.key, style.toolValue)
                        }
                    }
                    self.wordChecks[job.key] = log
                }
                self.inFlight.remove(job.key)
                switch result {
                case .success:
                    if job.isSheet {
                        if decoded.count == job.count {
                            for (n, img) in decoded.enumerated() { self.cutouts[CharacterSheet.id, default: [:]][n] = img }
                            self.landedAt[job.key] = Date()
                        } else {
                            NSLog("[RT] kit art: the character sheet didn't slice (%d of %d): rows show the role colors", decoded.count, job.count)
                            self.failed.insert(job.key)
                        }
                    } else if let image = decoded.first {
                        self.images[job.key] = image
                        self.landedAt[job.key] = Date()
                    } else { self.failed.insert(job.key) }
                case .failure(let e):
                    // Round 9: a network failure (locked or backgrounded mid-kit) gets one more try once the app is back.
                    let transient = e is URLError || (e as? ClaudeError) == .transport
                    if transient, client.unavailableReason == nil, !self.retriedAfterAway.contains(job.key) {
                        self.retriedAfterAway.insert(job.key)
                        while UIApplication.shared.applicationState != .active { try? await Task.sleep(for: .milliseconds(500)) }
                        guard gen == self.generation else { return }
                        NSLog("[RT] kit art: retrying %@ after a network failure", job.key)
                        self.launch([job], client: client)
                        return
                    }
                    NSLog("[RT] kit art: %@ failed twice (%@): app-drawn", job.key, client.unavailableReason ?? String(describing: e))
                    self.failed.insert(job.key)
                }
                self.updateFinished()
            }
        }
    }

    private func updateFinished() {
        isGenerating = !inFlight.isEmpty
        guard let items = finalItems, let ctx = context else { return }
        let need = KitArtPlan.keys(items: items, ctx: ctx)
        let s = settled.subtracting(inFlight)
        progress = need.isEmpty ? 1 : Double(need.intersection(s).count) / Double(need.count)
        if need.isSubset(of: s) && !finished { finished = true; finishedAt = Date() }
    }
    /// Round 27 DEBUG timing: when this set became final.
    @ObservationIgnored private(set) var finishedAt: Date?
    /// Round 27: pages of the final kit still drawing (for the per-set progress on the Print screen).
    var drawing: Bool { !finished }
}

/// Paper-white AI art (Haylee, page preview fix): the image model paints near-white, off-white or light-gray paper and
/// soft drop shadows behind items. A tone curve lifts everything above ~84% luminance to pure white, so every tile
/// sits flat on the one white sheet (dark line art is unchanged).
extension UIImage {
    /// Round 21: fully decoded off the main thread, so the first draw on screen doesn't decode it there.
    nonisolated func preparedForDisplay() -> UIImage { preparingForDisplay() ?? self }
}

enum PaperWhite {
    private static let context = CIContext(options: [.useSoftwareRenderer: false])
    /// Round 20: full-color art only lifts the near-white paper (above ~94%), so light colors keep their tint.
    static func normalize(_ image: UIImage, style: PrintStyle = .colorIn) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let f = CIFilter(name: "CIToneCurve")!
        f.setValue(input, forKey: kCIInputImageKey)
        let points: [(CGFloat, CGFloat)] = style == .fullColor
            ? [(0, 0), (0.25, 0.25), (0.5, 0.5), (0.9, 0.9), (0.95, 1)]
            : [(0, 0), (0.3, 0.3), (0.6, 0.62), (0.76, 0.84), (0.84, 1)]
        for (i, p) in points.enumerated() { f.setValue(CIVector(x: p.0, y: p.1), forKey: "inputPoint\(i)") }
        guard let out = f.outputImage, let cg = context.createCGImage(out, from: input.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

/// Slices a picture sheet into one image per cell (`CutoutSheet.cells` finds the cells). Round 46: the character sheet.
enum CutoutSlicer {
    static func slice(_ image: UIImage, columns: Int, rows: Int, count: Int) -> [UIImage] {
        guard let cg = image.cgImage, let gray = grayPixels(cg) else { return [] }
        let cells = CutoutSheet.cells(gray: gray, width: cg.width, height: cg.height, columns: columns, rows: rows, count: count)
        return cells.compactMap { r in
            cg.cropping(to: CGRect(x: r.x, y: r.y, width: r.width, height: r.height)).map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) }
        }
    }

    /// The image as 8-bit grayscale, top row first.
    static func grayPixels(_ cg: CGImage) -> [UInt8]? {
        let w = cg.width, h = cg.height
        var gray = [UInt8](repeating: 255, count: w * h)
        let ok = gray.withUnsafeMutableBytes { buf -> Bool in
            guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        return ok ? gray : nil
    }
}

/// Round 29 (Haylee, ensemble scenes): an older game's scene row character: the illustration between a badge slice's two
/// blank banners (`BadgeCharacter` finds them), with no badge frame or blank fields. Kept for replays of games saved
/// before round 45 (their badge slices have banners).
enum CharacterCropper {
    static func crop(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage, let gray = CutoutSlicer.grayPixels(cg) else { return image }
        let r = BadgeCharacter.rect(gray: gray, width: cg.width, height: cg.height)
        return cg.cropping(to: CGRect(x: r.x, y: r.y, width: r.width, height: r.height))
            .map { UIImage(cgImage: $0, scale: image.scale, orientation: .up) } ?? image
    }
}
