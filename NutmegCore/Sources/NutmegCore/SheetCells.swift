import Foundation

// Round 47 (Haylee, decisions/2026-11-17-round47.md): the per-player printables (badges, tickets) are drawn ONCE for all
// 6 players on the first play, as a strict grid of equal pieces with dashed cut lines. The app prints only the first N
// pieces for the count the kids chose, cropped from the drawn page and laid onto the paper with the AI's own look.
// Replays with any count reuse the same art. If a page can't be cut apart safely, the whole page prints instead.

/// Finds the pieces (badges, tickets) on a drawn sheet. Pure pixel math (grayscale in, rectangles out), so it's tested.
///
/// How: the ink (anything darker than near-white) is grouped into connected blobs. The `expected` biggest blobs of
/// about the same size are the pieces (a badge's frame outline holds it together); smaller blobs (dashes of the cut line,
/// a sparkle, a separate clip) belong to the nearest piece. Each piece's crop is its blobs' bounds plus a little paper,
/// never reaching into another piece; a neighbor's dash or sparkle that still falls inside a crop is painted white
/// (`erase`). Any doubt (a wrong number of pieces, two pieces touching, very different sizes) returns nil: the caller
/// prints the whole page.
public enum SheetCells {
    public typealias Rect = CutoutSheet.Rect

    public struct Cell: Equatable, Sendable {
        /// The crop, in the sheet's pixels.
        public var rect: Rect
        /// The piece itself (its main blob), inside `rect`.
        public var body: Rect
        /// Bits of OTHER pieces inside `rect` (in sheet pixels) to paint white, so no neighbor's sliver prints.
        public var erase: [Rect]
    }

    public struct Grid: Equatable, Sendable {
        /// The pieces in reading order (left to right, top to bottom).
        public var cells: [Cell]
        /// The most pieces in one row, and the number of rows.
        public var columns: Int, rows: Int
    }

    /// The pieces on a sheet in reading order, or nil when it can't be cut apart safely.
    /// `gray`: row-major luminance 0...255, `width` × `height`.
    public static func find(gray: [UInt8], width: Int, height: Int, expected: Int, inkBelow: UInt8 = 236) -> Grid? {
        guard expected > 0, width > 8, height > 8, gray.count >= width * height else { return nil }
        // 1. A half-size ink mask (a half pixel is ink when any of its pixels is), for speed.
        let f = min(width, height) >= 400 ? 2 : 1
        let w = (width + f - 1) / f, h = (height + f - 1) / f
        var mask = [Bool](repeating: false, count: w * h)
        for y in 0..<height {
            let row = y * width, my = (y / f) * w
            for x in 0..<width where gray[row + x] < inkBelow { mask[my + x / f] = true }
        }
        // 2. Connected blobs (8-neighbors).
        let blobs = components(mask, w, h)
        guard blobs.count >= expected else { return nil }
        // 3. The pieces: the `expected` biggest top-level blobs (by their bounds; a blob inside another blob's bounds, like
        // a badge inside a solid cut line, is part of it), clearly bigger than everything else.
        let bySizeAll = blobs.indices.sorted { blobs[$0].area > blobs[$1].area }
        let big = Array(bySizeAll.prefix(64))
        let bySize = bySizeAll.filter { i in
            !big.contains { j in j != i && blobs[j].area > blobs[i].area && contains(blobs[j].box, blobs[i].box) }
        }
        guard bySize.count >= expected else { return nil }
        let bodies = Array(bySize.prefix(expected))
        let smallest = blobs[bodies.last!].area
        if bySize.count > expected, blobs[bySize[expected]].area * 2 > smallest { return nil }   // another piece-sized blob
        // Not specks: each piece is a fair part of its share of the page.
        guard smallest * expected * 12 >= w * h else { return nil }
        // About the same size (a strict grid of equal pieces): width and height within ±30% of the middle one.
        let ws = bodies.map { blobs[$0].box.width }.sorted(), hs = bodies.map { blobs[$0].box.height }.sorted()
        let mw = Double(ws[ws.count / 2]), mh = Double(hs[hs.count / 2])
        for b in bodies {
            let r = blobs[b].box
            guard Double(r.width) >= mw * 0.7, Double(r.width) <= mw * 1.3,
                  Double(r.height) >= mh * 0.7, Double(r.height) <= mh * 1.3 else { return nil }
        }
        // Pieces never overlap (two touching pieces would be one blob; overlapping bounds mean a tangle).
        for i in bodies.indices { for j in bodies.indices where j > i {
            if intersects(blobs[bodies[i]].box, blobs[bodies[j]].box) { return nil }
        } }
        // 4. Reading order: rows by the pieces' centers, then left to right.
        let order = bodies.sorted { blobs[$0].cy < blobs[$1].cy }
        var rowsOf: [[Int]] = []
        for b in order {
            if let last = rowsOf.last?.first, abs(blobs[b].cy - blobs[last].cy) < mh * 0.5 { rowsOf[rowsOf.count - 1].append(b) }
            else { rowsOf.append([b]) }
        }
        let reading = rowsOf.flatMap { $0.sorted { blobs[$0].cx < blobs[$1].cx } }
        // 5. Every small blob belongs to a piece it's close to (a dash, a clip, a sparkle, a ticket's separate stub and
        // the number on it). The pieces grow outward together, one step at a time: a blob joins the piece it's nearest
        // to as soon as it's within the step, so a stub joins its ticket first and then the number inside the stub is
        // already "in" that ticket, never claimed by the neighbor. A piece never grows onto another piece.
        let reach = max(3, Int(min(mw, mh) * 0.12))
        var owner = [Int](repeating: -1, count: blobs.count)
        for (k, b) in reading.enumerated() { owner[b] = k }
        var grown = reading.map { blobs[$0].box }
        let bodyBoxes = grown
        var open = blobs.indices.filter { owner[$0] < 0 }
        for step in 0...reach where !open.isEmpty {
            let snapshot = grown
            var still: [Int] = []
            for i in open {
                var best = -1, bestD = Int.max
                for (k, g) in snapshot.enumerated() {
                    let d = distance(blobs[i].box, g)
                    if d < bestD { bestD = d; best = k }
                }
                let joined = best >= 0 ? union(grown[best], blobs[i].box) : blobs[i].box
                if best >= 0, bestD <= step, !bodyBoxes.indices.contains(where: { $0 != best && intersects(joined, bodyBoxes[$0]) }) {
                    owner[i] = best; grown[best] = joined
                } else { still.append(i) }
            }
            open = still
        }
        for i in open { owner[i] = -2 }   // a stray: erased wherever it falls
        // 6. Each crop: its blobs' bounds plus a little paper, kept off every other piece.
        var cells: [Cell] = []
        for (k, b) in reading.enumerated() {
            let body = blobs[b].box
            var u = grown[k]
            u = Rect(x: u.x - 2, y: u.y - 2, width: u.width + 4, height: u.height + 4)
            u = clip(u, Rect(x: 0, y: 0, width: w, height: h))
            for (j, other) in reading.enumerated() where j != k {
                let o = blobs[other].box
                guard intersects(u, o) else { continue }
                // Shrink the side facing the other piece (the axis the two pieces are apart on).
                if o.x >= body.x + body.width { u = Rect(x: u.x, y: u.y, width: min(u.width, o.x - u.x), height: u.height) }
                else if o.x + o.width <= body.x { let x1 = u.x + u.width; let nx = max(u.x, o.x + o.width); u = Rect(x: nx, y: u.y, width: x1 - nx, height: u.height) }
                else if o.y >= body.y + body.height { u = Rect(x: u.x, y: u.y, width: u.width, height: min(u.height, o.y - u.y)) }
                else { let y1 = u.y + u.height; let ny = max(u.y, o.y + o.height); u = Rect(x: u.x, y: ny, width: u.width, height: y1 - ny) }
            }
            // Never clip the piece itself.
            guard contains(u, body), u.width > 0, u.height > 0 else { return nil }
            // A neighbor's dash or sparkle (or a stray) that falls inside this crop is painted white; anything over the
            // piece itself is left alone (it's drawn on this piece).
            var erase: [Rect] = []
            for i in blobs.indices where owner[i] != k && i != b {
                let r = blobs[i].box
                guard intersects(r, u), !intersects(r, body) else { continue }
                let wide = Rect(x: r.x - 1, y: r.y - 1, width: r.width + 2, height: r.height + 2)   // its soft edge too
                erase.append(clip(intersects(wide, body) ? r : wide, u))
            }
            cells.append(Cell(rect: full(u, f, width, height), body: full(body, f, width, height),
                              erase: erase.map { full($0, f, width, height) }))
        }
        return Grid(cells: cells, columns: rowsOf.map(\.count).max() ?? 1, rows: rowsOf.count)
    }

    // MARK: Laying the first N pieces onto the paper

    /// Where the pieces go on the paper (in points): in reading order, `columns` to a row, each row centered, starting at
    /// the top of `box`, `gap` apart, at `scale` points per sheet pixel (the scale the whole page would print at, so a
    /// badge prints the same size whatever the count). Shrunk evenly only if they wouldn't fit.
    public static func layout(sizes: [CGSize], columns: Int, scale: Double, box: CGRect, gap: Double = 14) -> [CGRect] {
        guard !sizes.isEmpty, columns > 0, scale > 0 else { return [] }
        let rows = stride(from: 0, to: sizes.count, by: columns).map { Array(sizes[$0..<min($0 + columns, sizes.count)]) }
        func extent(_ s: Double) -> (w: Double, h: Double) {
            let widths = rows.map { r in r.reduce(0) { $0 + $1.width * s } + gap * Double(r.count - 1) }
            let heights = rows.map { r in r.map { $0.height * s }.max() ?? 0 }
            return (widths.max() ?? 0, heights.reduce(0, +) + gap * Double(rows.count - 1))
        }
        var s = scale
        let e = extent(s)
        if e.w > box.width || e.h > box.height {
            // Only the pieces shrink (the gaps stay): the scale where the widest row and the stack of rows just fit.
            let across = rows.map { r in (Double(box.width) - gap * Double(r.count - 1)) / max(r.reduce(0) { $0 + $1.width }, 1) }
            let down = (Double(box.height) - gap * Double(rows.count - 1)) / max(rows.map { r -> Double in Double(r.map(\.height).max() ?? 0) }.reduce(0.0, +), 1)
            s = max(0, min(across.min() ?? s, down)) * 0.999
        }
        var out: [CGRect] = []
        var y = Double(box.minY)
        for r in rows {
            let rw = r.reduce(0) { $0 + $1.width * s } + gap * Double(r.count - 1)
            let rh = r.map { $0.height * s }.max() ?? 0
            var x = Double(box.midX) - rw / 2
            for size in r {
                let cw = size.width * s, ch = size.height * s
                out.append(CGRect(x: x, y: y + (rh - ch) / 2, width: cw, height: ch))
                x += cw + gap
            }
            y += rh + gap
        }
        return out
    }

    // MARK: Pixel helpers

    struct Blob {
        var box: Rect, pixels: Int
        var area: Int { box.width * box.height }
        var cx: Double { Double(box.x) + Double(box.width) / 2 }
        var cy: Double { Double(box.y) + Double(box.height) / 2 }
    }

    static func components(_ mask: [Bool], _ w: Int, _ h: Int) -> [Blob] {
        var label = [Int32](repeating: -1, count: w * h)
        var out: [Blob] = []
        var stack: [Int] = []
        for start in 0..<(w * h) where mask[start] && label[start] < 0 {
            let id = Int32(out.count)
            var minX = Int.max, maxX = -1, minY = Int.max, maxY = -1, n = 0
            label[start] = id; stack.append(start)
            while let p = stack.popLast() {
                let x = p % w, y = p / w
                n += 1
                if x < minX { minX = x }; if x > maxX { maxX = x }
                if y < minY { minY = y }; if y > maxY { maxY = y }
                for dy in -1...1 {
                    let ny = y + dy
                    guard ny >= 0, ny < h else { continue }
                    for dx in -1...1 {
                        let nx = x + dx
                        guard nx >= 0, nx < w else { continue }
                        let q = ny * w + nx
                        if mask[q] && label[q] < 0 { label[q] = id; stack.append(q) }
                    }
                }
            }
            out.append(Blob(box: Rect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1), pixels: n))
        }
        return out
    }

    static func intersects(_ a: Rect, _ b: Rect) -> Bool {
        a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
    }
    static func contains(_ a: Rect, _ b: Rect) -> Bool {
        b.x >= a.x && b.y >= a.y && b.x + b.width <= a.x + a.width && b.y + b.height <= a.y + a.height
    }
    static func union(_ a: Rect, _ b: Rect) -> Rect {
        let x0 = min(a.x, b.x), y0 = min(a.y, b.y)
        return Rect(x: x0, y: y0, width: max(a.x + a.width, b.x + b.width) - x0, height: max(a.y + a.height, b.y + b.height) - y0)
    }
    static func clip(_ a: Rect, _ to: Rect) -> Rect {
        let x0 = max(a.x, to.x), y0 = max(a.y, to.y)
        let x1 = min(a.x + a.width, to.x + to.width), y1 = min(a.y + a.height, to.y + to.height)
        return Rect(x: x0, y: y0, width: max(0, x1 - x0), height: max(0, y1 - y0))
    }
    /// The gap between two boxes (0 when they touch or overlap).
    static func distance(_ a: Rect, _ b: Rect) -> Int {
        let dx = max(0, max(b.x - (a.x + a.width), a.x - (b.x + b.width)))
        let dy = max(0, max(b.y - (a.y + a.height), a.y - (b.y + b.height)))
        return Int(Double(dx * dx + dy * dy).squareRoot())
    }
    /// A half-size rectangle back in sheet pixels.
    static func full(_ r: Rect, _ f: Int, _ width: Int, _ height: Int) -> Rect {
        clip(Rect(x: r.x * f, y: r.y * f, width: r.width * f, height: r.height * f), Rect(x: 0, y: 0, width: width, height: height))
    }
}
