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

    /// The cell's drawing bounds plus a 3% margin, kept inside the cell (the whole cell if it's blank). Not squared.
    static func trimToInk(_ cell: Rect, ink: (Int, Int) -> Bool) -> Rect {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in cell.y..<(cell.y + cell.height) {
            for x in cell.x..<(cell.x + cell.width) where ink(x, y) {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return cell }
        let m = max(2, max(maxX - minX, maxY - minY) * 3 / 100)
        let x0 = max(cell.x, minX - m), y0 = max(cell.y, minY - m)
        let x1 = min(cell.x + cell.width - 1, maxX + m), y1 = min(cell.y + cell.height - 1, maxY + m)
        return Rect(x: x0, y: y0, width: x1 - x0 + 1, height: y1 - y0 + 1)
    }

    /// The cell's drawing bounds plus a 6% margin, squared up and kept inside the cell (the whole cell if it's blank).
    static func trim(_ cell: Rect, ink: (Int, Int) -> Bool) -> Rect {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in cell.y..<(cell.y + cell.height) {
            for x in cell.x..<(cell.x + cell.width) where ink(x, y) {
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return cell }
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
