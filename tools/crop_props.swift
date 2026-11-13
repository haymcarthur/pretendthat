// Splits a household-prop sheet (3 rows x 5 items on white) into one PNG per item using connected components:
// the 15 largest ink blobs are the items; small blobs (lids, tassels) join the nearest item.
// Usage: swift tools/crop_props.swift <sheet.webp> <outdir> id1 ... id15 (row by row)
import AppKit
let args = CommandLine.arguments
let img = NSImage(contentsOfFile: args[1])!
var rect = CGRect(origin: .zero, size: img.size)
let cg = img.cgImage(forProposedRect: &rect, context: nil, hints: nil)!
let w = cg.width, h = cg.height
let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
let px = ctx.data!.bindMemory(to: UInt8.self, capacity: w * h * 4)
var inkMask = [Bool](repeating: false, count: w * h)
for y in 0..<h { for x in 0..<w {
    let i = (y * w + x) * 4   // bitmap rows run top to bottom
    inkMask[y * w + x] = Int(px[i]) + Int(px[i + 1]) + Int(px[i + 2]) < 3 * 232
}}
struct Box { var x0: Int, y0: Int, x1: Int, y1: Int, area: Int
    var cx: Double { Double(x0 + x1) / 2 }; var cy: Double { Double(y0 + y1) / 2 }
    mutating func add(_ b: Box) { x0 = min(x0, b.x0); y0 = min(y0, b.y0); x1 = max(x1, b.x1); y1 = max(y1, b.y1); area += b.area }
}
var label = [Int32](repeating: -1, count: w * h)
var boxes: [Box] = []
var stack: [Int] = []
for start in 0..<(w * h) where inkMask[start] && label[start] < 0 {
    let id = Int32(boxes.count); var b = Box(x0: w, y0: h, x1: 0, y1: 0, area: 0)
    stack.append(start); label[start] = id
    while let p = stack.popLast() {
        let x = p % w, y = p / w
        b.x0 = min(b.x0, x); b.x1 = max(b.x1, x); b.y0 = min(b.y0, y); b.y1 = max(b.y1, y); b.area += 1
        for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
            let nx = x + dx, ny = y + dy
            guard nx >= 0, ny >= 0, nx < w, ny < h else { continue }
            let q = ny * w + nx
            if inkMask[q] && label[q] < 0 { label[q] = id; stack.append(q) }
        }
    }
    boxes.append(b)
}
let sorted = boxes.sorted { $0.area > $1.area }
// Biggest blobs first; a blob inside an item's box (a rug's center, a star on a mug) joins that item.
var items: [Box] = []
var rest: [Box] = []
for b in sorted where b.area > 30 {
    if let j = items.firstIndex(where: { $0.x0 - 4 <= b.x0 && $0.x1 + 4 >= b.x1 && $0.y0 - 4 <= b.y0 && $0.y1 + 4 >= b.y1 }) { items[j].add(b) }
    else if items.count < 15 { items.append(b) } else { rest.append(b) }
}
for small in rest {
    // Join the nearest item if it's close (a lid, a tassel); ignore far specks.
    if let j = items.indices.min(by: { hypot(items[$0].cx - small.cx, items[$0].cy - small.cy) < hypot(items[$1].cx - small.cx, items[$1].cy - small.cy) }),
       hypot(items[j].cx - small.cx, items[j].cy - small.cy) < 160 { items[j].add(small) }
}
let rowH = Double(h) / 3
items.sort { (Int($0.cy / rowH), $0.cx) < (Int($1.cy / rowH), $1.cx) }
let ids = Array(args[3...])
for (n, b) in items.enumerated() where n < ids.count {
    let pad = 12
    let x0 = max(0, b.x0 - pad), y0 = max(0, b.y0 - pad), x1 = min(w - 1, b.x1 + pad), y1 = min(h - 1, b.y1 + pad)
    // Copy only this item's pixels (others in the box become white).
    let cw = x1 - x0 + 1, ch = y1 - y0 + 1
    let out = CGContext(data: nil, width: cw, height: ch, bitsPerComponent: 8, bytesPerRow: cw * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    out.draw(cg.cropping(to: CGRect(x: x0, y: y0, width: cw, height: ch))!, in: CGRect(x: 0, y: 0, width: cw, height: ch))
    let op = out.data!.bindMemory(to: UInt8.self, capacity: cw * ch * 4)
    for yy in 0..<ch { for xx in 0..<cw {
        let l = label[(y0 + yy) * w + (x0 + xx)]
        guard l >= 0 else { continue }
        let lb = boxes[Int(l)]
        // Keep pixels whose blob lies inside this item's box; whiten blobs that belong elsewhere.
        if lb.x0 < b.x0 || lb.x1 > b.x1 || lb.y0 < b.y0 || lb.y1 > b.y1 {
            let i = (yy * cw + xx) * 4; op[i] = 255; op[i + 1] = 255; op[i + 2] = 255
        }
    }}
    let rep = NSBitmapImageRep(cgImage: out.makeImage()!)
    let dir = "\(args[2])/prop-\(ids[n]).imageset"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(dir)/prop-\(ids[n]).png"))
    try! #"{"images":[{"filename":"prop-\#(ids[n]).png","idiom":"universal"}],"info":{"author":"xcode","version":1}}"#.write(toFile: "\(dir)/Contents.json", atomically: true, encoding: .utf8)
}
print("cropped \(min(items.count, ids.count))")
