// Round 47: renders the per-player crops (badges, tickets) of drawn sheets for 1–6 players, exactly the way the app
// finds and lays them out (NutmegCore's SheetCells + PageFit), plus a contact sheet. No AI calls.
//
//   tools/sheet-crops/run.sh <out-dir> <expected>:<label>:<drawn.png> ...
//
// For each sheet: <out>/<label>/cell-k.png (each piece with neighbors' slivers painted white), printed-N.png for
// N = 1…expected (a Letter page at 2x: the first N pieces; N = expected prints the whole page), and <out>/contact-sheet.png.
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func load(_ path: String) -> CGImage? {
    guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil) else { return nil }
    return CGImageSourceCreateImageAtIndex(src, 0, nil)
}
func save(_ img: CGImage, _ path: String) {
    let url = URL(fileURLWithPath: path)
    guard let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
}
func gray(_ cg: CGImage) -> [UInt8] {
    let w = cg.width, h = cg.height
    var g = [UInt8](repeating: 255, count: w * h)
    g.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return g
}
func canvas(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.setFillColor(CGColor(gray: 1, alpha: 1)); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
    // Top-left origin like UIKit.
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    return c
}
func draw(_ img: CGImage, in r: CGRect, _ c: CGContext) {
    c.saveGState(); c.translateBy(x: r.minX, y: r.maxY); c.scaleBy(x: 1, y: -1)
    c.interpolationQuality = .high
    c.draw(img, in: CGRect(x: 0, y: 0, width: r.width, height: r.height)); c.restoreGState()
}
func text(_ s: String, at p: CGPoint, size: CGFloat, _ c: CGContext) {
    NSGraphicsContext.saveGraphicsState()
    c.saveGState(); c.translateBy(x: p.x, y: p.y + size); c.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: c, flipped: false)
    NSAttributedString(string: s, attributes: [.font: NSFont.boldSystemFont(ofSize: size), .foregroundColor: NSColor.black]).draw(at: .zero)
    c.restoreGState(); NSGraphicsContext.restoreGraphicsState()
}
/// A piece cropped from the sheet with its `erase` boxes painted white (what the app prints).
func crop(_ sheet: CGImage, _ cell: SheetCells.Cell) -> CGImage {
    let r = cell.rect
    let c = canvas(r.width, r.height)
    draw(sheet, in: CGRect(x: -r.x, y: -r.y, width: sheet.width, height: sheet.height), c)
    c.setFillColor(CGColor(gray: 1, alpha: 1))
    for e in cell.erase { c.fill(CGRect(x: e.x - r.x, y: e.y - r.y, width: e.width, height: e.height)) }
    return c.makeImage()!
}

let args = CommandLine.arguments
guard args.count >= 3 else { print("usage: sheet-crops <out> <expected>:<label>:<png> ..."); exit(1) }
let out = args[1]
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
let letter = CGSize(width: 612, height: 792), px: CGFloat = 2
var rows: [(String, [CGImage])] = []
for spec in args.dropFirst(2) {
    let parts = spec.split(separator: ":", maxSplits: 2).map(String.init)
    guard parts.count == 3, let expected = Int(parts[0]), let sheet = load(parts[2]) else { print("skip \(spec)"); continue }
    let label = parts[1], dir = "\(out)/\(label)"
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    let t0 = Date()
    let grid = SheetCells.find(gray: gray(sheet), width: sheet.width, height: sheet.height, expected: expected)
    let ms = Int(Date().timeIntervalSince(t0) * 1000)
    var pages: [CGImage] = []
    let fit = PageFit.rect(image: CGSize(width: sheet.width, height: sheet.height), page: letter)
    let box = CGRect(x: PageFit.margin, y: PageFit.margin, width: letter.width - 2 * PageFit.margin, height: letter.height - 2 * PageFit.margin)
    func page(_ body: (CGContext) -> Void) -> CGImage {
        let c = canvas(Int(letter.width * px), Int(letter.height * px)); c.scaleBy(x: px, y: px)
        body(c)
        c.setStrokeColor(CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)); c.setLineWidth(0.5); c.stroke(box)   // the margin (guide only)
        return c.makeImage()!
    }
    guard let grid else {
        print("\(label): NOT CUT (\(ms) ms): every count prints the whole page")
        for n in 1...expected {
            let img = page { draw(sheet, in: fit, $0) }
            save(img, "\(dir)/printed-\(n).png"); pages.append(img)
        }
        rows.append(("\(label) — not cut apart: whole page for every count", pages)); continue
    }
    print("\(label): \(grid.cells.count) pieces, \(grid.columns) columns × \(grid.rows) rows (\(ms) ms); erase boxes: \(grid.cells.map(\.erase.count))")
    let crops = grid.cells.map { crop(sheet, $0) }
    for (k, c) in crops.enumerated() { save(c, "\(dir)/cell-\(k + 1).png") }
    let scale = Double(fit.width) / Double(sheet.width)
    for n in 1...expected {
        let img: CGImage
        if n >= grid.cells.count {
            img = page { draw(sheet, in: fit, $0) }
        } else {
            let sizes = crops.prefix(n).map { CGSize(width: $0.width, height: $0.height) }
            let rects = SheetCells.layout(sizes: Array(sizes), columns: grid.columns, scale: scale, box: box)
            img = page { c in for (r, piece) in zip(rects, crops) { draw(piece, in: r, c) } }
        }
        save(img, "\(dir)/printed-\(n).png"); pages.append(img)
    }
    rows.append(("\(label) — \(grid.columns)×\(grid.rows), printed for 1…\(expected) players (the last is the whole page)", pages))
}
// The contact sheet: one row per sheet, its printed pages for 1…N players.
let tw: CGFloat = 300, th = tw * letter.height / letter.width, pad: CGFloat = 16, head: CGFloat = 34
let cols = rows.map(\.1.count).max() ?? 1
let W = Int(pad + CGFloat(cols) * (tw + pad)), H = Int(pad + CGFloat(rows.count) * (head + th + 22 + pad))
let c = canvas(W, H)
for (i, row) in rows.enumerated() {
    let y = pad + CGFloat(i) * (head + th + 22 + pad)
    text(row.0, at: CGPoint(x: pad, y: y), size: 18, c)
    for (n, img) in row.1.enumerated() {
        let x = pad + CGFloat(n) * (tw + pad)
        let r = CGRect(x: x, y: y + head, width: tw, height: th)
        draw(img, in: r, c)
        c.setStrokeColor(CGColor(gray: 0.6, alpha: 1)); c.setLineWidth(1); c.stroke(r)
        text("\(n + 1) player\(n == 0 ? "" : "s")", at: CGPoint(x: x, y: y + head + th + 2), size: 15, c)
    }
}
save(c.makeImage()!, "\(out)/contact-sheet.png")
print("contact sheet: \(out)/contact-sheet.png")
