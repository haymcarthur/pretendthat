import Foundation
import Testing
import CoreGraphics
import ImageIO
@testable import NutmegCore

/// Round 20 (cost, Haylee reviews): one sample kit's pages + the cut-out sheet at "medium" and "low", in both styles.
/// LIVE_IMAGES=1 and keys via tools/with-keys.sh (real image calls, about $0.65). Writes PNGs and the sheet's slices
/// to /tmp/pt-round20/quality/.
@Test(.enabled(if: ProcessInfo.processInfo.environment["LIVE_IMAGES"] == "1"
               && ProcessInfo.processInfo.environment["OPENAI_API_KEY"]?.isEmpty == false))
func liveImageQualitySamples() async throws {
    let env = ProcessInfo.processInfo.environment
    let out = URL(fileURLWithPath: "/tmp/pt-round20/quality")
    try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    let client = ImageClient(mode: .direct(apiKey: env["OPENAI_API_KEY"]!))
    var items = Fallback.airplane(playerCount: 2).kit.items
    if let key = env["ANTHROPIC_API_KEY"], !key.isEmpty {
        let svc = PhaseService(llm: ClaudeClient(config: ClaudeConfig(mode: .direct(apiKey: key))))
        let roles = [Role(id: .R1, roleName: "Head Baker", emoji: "", symbol: "star", job: "bakes"),
                     Role(id: .R2, roleName: "Space Server", emoji: "", symbol: "star", job: "serves")]
        let plan = GamePlan(gameTitle: "Bakery on the Moon", gameEmoji: "", setting: "Bakery on the Moon", roles: roles, nutmegSays: "")
        items = try await svc.kitPages(ctx: AdventureContext(gameTitle: "Bakery on the Moon", plan: plan, playerCount: 2))
        try JSONEncoder().encode(items).write(to: out.appendingPathComponent("items.json"))
    }
    let title = "Bakery on the Moon"
    let limiter = AsyncLimiter(limit: 3)
    var jobs: [(String, KitArtJob, String)] = []
    for style in PrintStyle.allCases {
        for q in ["medium", "low"] {
            for j in KitArtPlan.jobs(items: items, ctx: KitArtContext(title: title, roles: RoleCast.rank([])), style: style, settled: []) {
                jobs.append(("\(style.rawValue)-\(q)-\(j.key.replacingOccurrences(of: "#", with: "-"))", j, q))
            }
        }
    }
    let times = await withTaskGroup(of: (String, Double, Bool).self) { g -> [(String, Double, Bool)] in
        for (name, job, q) in jobs {
            g.addTask {
                let t = Date()
                do {
                    let png = try await limiter.run { try await client.generate(prompt: job.prompt, size: job.size, quality: q) }
                    try png.write(to: out.appendingPathComponent("\(name).png"))
                    return (name, Date().timeIntervalSince(t), true)
                } catch { return (name, Date().timeIntervalSince(t), false) }
            }
        }
        var r: [(String, Double, Bool)] = []
        for await x in g { r.append(x) }
        return r
    }
    for (n, s, ok) in times.sorted(by: { $0.0 < $1.0 }) { print("LIVE image \(n): \(String(format: "%.1f", s)) s \(ok ? "ok" : "FAILED")") }
    let allOK = times.allSatisfy { $0.2 }
    #expect(allOK)
}

private func slice(_ png: Data, count: Int, name: String, out: URL) {
    guard let src = CGImageSourceCreateWithData(png as CFData, nil), let cg = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return }
    let w = cg.width, h = cg.height
    var gray = [UInt8](repeating: 255, count: w * h)
    gray.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    for (i, r) in CutoutSheet.cells(gray: gray, width: w, height: h, count: count).enumerated() {
        guard let c = cg.cropping(to: CGRect(x: r.x, y: r.y, width: r.width, height: r.height)) else { continue }
        let url = out.appendingPathComponent("\(name)-slice\(i).png")
        if let d = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
            CGImageDestinationAddImage(d, c, nil); CGImageDestinationFinalize(d)
        }
    }
}
