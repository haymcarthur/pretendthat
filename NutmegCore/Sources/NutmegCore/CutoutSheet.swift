import Foundation

/// Round 20 (Haylee, cost): the themed cut-outs are drawn as ONE image (a grid sheet) instead of one image per cut-out,
/// then sliced back into one picture per cut-out, so the printed page and the checklist pictures (cutout:N) work
/// exactly as before. Pure pixel math here (grayscale buffer in, rectangles out), so it's unit-tested.
public enum CutoutSheet {
    /// Flip to false to go back to one image per cut-out.
    public static let enabled = true

    /// The grid for `count` cut-outs: 2 rows, as many columns as needed (6 → 3×2).
    public static func grid(_ count: Int) -> (columns: Int, rows: Int) {
        count <= 3 ? (max(1, count), 1) : (Int((Double(count) / 2).rounded(.up)), 2)
    }

    /// The image size for the sheet (landscape for 2 rows; the API sizes only).
    public static func size(_ count: Int) -> String { grid(count).rows == 1 && count <= 1 ? "1024x1024" : "1536x1024" }

    public struct Rect: Equatable, Sendable {
        public var x: Int, y: Int, width: Int, height: Int
        public init(x: Int, y: Int, width: Int, height: Int) { self.x = x; self.y = y; self.width = width; self.height = height }
    }

    /// Slices a sheet into `count` cells in reading order (left to right, top to bottom). Each boundary is the
    /// emptiest line (fewest ink pixels) near where the grid puts it, so a drawing that leans past its cell isn't cut.
    /// Each cell is then trimmed to its drawing, with a margin, as a square. `gray`: row-major luminance 0...255.
    /// Round C1: `trimToSquare: false` (the badge sheet) keeps each cell's portrait shape, trimmed to the drawing's outer
    /// edge plus a margin.
    public static func cells(gray: [UInt8], width: Int, height: Int, count: Int, inkBelow: UInt8 = 225, trimToSquare: Bool = true) -> [Rect] {
        guard count > 0, width > 0, height > 0, gray.count >= width * height else { return [] }
        let (cols, rows) = grid(count)
        func ink(_ x: Int, _ y: Int) -> Bool { gray[y * width + x] < inkBelow }
        // The emptiest line near `expected` (within ±18% of a cell).
        func boundary(expected: Int, cell: Int, limit: Int, count: (Int) -> Int) -> Int {
            let r = max(1, cell * 18 / 100)
            var best = expected, bestInk = Int.max
            for p in max(1, expected - r)...min(limit - 1, expected + r) {
                let c = count(p)
                if c < bestInk || (c == bestInk && abs(p - expected) < abs(best - expected)) { best = p; bestInk = c }
            }
            return best
        }
        var rowEdges = [0]
        for k in 1..<max(1, rows) {
            let e = height * k / rows
            rowEdges.append(boundary(expected: e, cell: height / rows, limit: height) { y in (0..<width).reduce(0) { $0 + (ink($1, y) ? 1 : 0) } })
        }
        rowEdges.append(height)
        var out: [Rect] = []
        for r in 0..<rows {
            let y0 = rowEdges[r], y1 = rowEdges[r + 1]
            let inRow = r < rows - 1 ? cols : count - cols * (rows - 1)
            guard inRow > 0 else { continue }
            var colEdges = [0]
            for k in 1..<max(1, inRow) {
                let e = width * k / inRow
                colEdges.append(boundary(expected: e, cell: width / inRow, limit: width) { x in (y0..<y1).reduce(0) { $0 + (ink(x, $1) ? 1 : 0) } })
            }
            colEdges.append(width)
            for c in 0..<inRow {
                let cell = Rect(x: colEdges[c], y: y0, width: colEdges[c + 1] - colEdges[c], height: y1 - y0)
                out.append(trimToSquare ? trim(cell, ink: ink) : trimToInk(cell, ink: ink))
            }
        }
        return Array(out.prefix(count))
    }

    /// Round 45 (the badge sheet "sliver"): the drawing's bounds in a cell, ignoring a strip of a NEIGHBOR's drawing that
    /// leaned over the cell edge: ink is grouped into bands of columns (then rows) split by empty gaps, and a small band
    /// that touches the cell's edge (under a quarter of the biggest band's ink) is dropped, so a sliver of the next badge
    /// no longer widens the crop. A drawing in two parts (a pair of shoes) keeps both.
    static func mainInk(_ cell: Rect, ink: (Int, Int) -> Bool) -> (minX: Int, maxX: Int, minY: Int, maxY: Int)? {
        func band(_ counts: [Int], gap: Int) -> ClosedRange<Int>? {
            var bands: [(range: ClosedRange<Int>, ink: Int)] = []
            var start: Int?, last = -1, sum = 0
            func close() {
                if let s = start { bands.append((s...last, sum)) }
                start = nil; sum = 0
            }
            for (i, c) in counts.enumerated() where c > 0 {
                if start != nil, i - last > gap { close() }
                if start == nil { start = i }
                last = i; sum += c
            }
            close()
            guard let biggest = bands.map(\.ink).max() else { return nil }
            let edge = max(1, counts.count / 100)
            let kept = bands.filter { b in
                let touches = b.range.lowerBound <= edge || b.range.upperBound >= counts.count - 1 - edge
                return !(touches && bands.count > 1 && b.ink * 4 < biggest)
            }
            guard let lo = kept.map(\.range.lowerBound).min(), let hi = kept.map(\.range.upperBound).max() else { return nil }
            return lo...hi
        }
        var cols = [Int](repeating: 0, count: cell.width)
        for y in cell.y..<(cell.y + cell.height) {
            for x in cell.x..<(cell.x + cell.width) where ink(x, y) { cols[x - cell.x] += 1 }
        }
        guard let cx = band(cols, gap: max(3, cell.width / 25)) else { return nil }
        var rows = [Int](repeating: 0, count: cell.height)
        for y in cell.y..<(cell.y + cell.height) {
            for x in (cell.x + cx.lowerBound)...(cell.x + cx.upperBound) where ink(x, y) { rows[y - cell.y] += 1 }
        }
        guard let cy = band(rows, gap: max(3, cell.height / 25)) else { return nil }
        return (cell.x + cx.lowerBound, cell.x + cx.upperBound, cell.y + cy.lowerBound, cell.y + cy.upperBound)
    }

    /// The cell's drawing bounds plus a 3% margin, kept inside the cell (the whole cell if it's blank). Not squared.
    static func trimToInk(_ cell: Rect, ink: (Int, Int) -> Bool) -> Rect {
        guard let b = mainInk(cell, ink: ink) else { return cell }
        let (minX, maxX, minY, maxY) = (b.minX, b.maxX, b.minY, b.maxY)
        let m = max(2, max(maxX - minX, maxY - minY) * 3 / 100)
        let x0 = max(cell.x, minX - m), y0 = max(cell.y, minY - m)
        let x1 = min(cell.x + cell.width - 1, maxX + m), y1 = min(cell.y + cell.height - 1, maxY + m)
        return Rect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
    }

    /// The cell's drawing bounds plus a 6% margin, squared up and kept inside the cell (the whole cell if it's blank).
    static func trim(_ cell: Rect, ink: (Int, Int) -> Bool) -> Rect {
        guard let b = mainInk(cell, ink: ink) else { return cell }
        let (minX, maxX, minY, maxY) = (b.minX, b.maxX, b.minY, b.maxY)
        let side0 = max(maxX - minX, maxY - minY) + 1
        let side = min(min(cell.width, cell.height), side0 + side0 * 12 / 100)
        let cx = (minX + maxX) / 2, cy = (minY + maxY) / 2
        let x = min(max(cell.x, cx - side / 2), cell.x + cell.width - side)
        let y = min(max(cell.y, cy - side / 2), cell.y + cell.height - side)
        return Rect(x: x, y: y, width: side, height: side)
    }
}

/// Round C1: the 6 role badges are ONE image, a 3 × 2 grid of portrait badges (the same 3 × 2 layout a badge page
/// prints), sliced into one badge per role (rank order: left to right, then top to bottom).
public enum BadgeSheet {
    public static let enabled = true
    public static let count = RoleCast.count
    public static let size = "1024x1536"
    /// The sheet's slices are kept like cut-outs: `<badge item id>#<k>` is role R(k+1)'s badge.
    public static func key(_ itemID: String, _ k: Int) -> String { KitArtPlan.cutoutKey(itemID, k) }

    public static func cells(gray: [UInt8], width: Int, height: Int) -> [CutoutSheet.Rect] {
        CutoutSheet.cells(gray: gray, width: width, height: height, count: count, trimToSquare: false)
    }
}
