import AppKit
// swift contact.swift out.png cols label1=path1 ...
let args = Array(CommandLine.arguments.dropFirst())
let out = args[0], cols = Int(args[1])!
let items = args.dropFirst(2).map { a -> (String, String) in let p = a.split(separator: "=", maxSplits: 1); return (String(p[0]), String(p[1])) }
let tw: CGFloat = 340, th: CGFloat = 510, lab: CGFloat = 30, pad: CGFloat = 16
let rows = (items.count + cols - 1) / cols
let W = CGFloat(cols) * (tw + pad) + pad, H = CGFloat(rows) * (th + lab + pad) + pad
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(W), pixelsHigh: Int(H), bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(white: 0.93, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
for (i, (label, path)) in items.enumerated() {
    let c = i % cols, r = i / cols
    let x = pad + CGFloat(c) * (tw + pad), yTop = H - pad - CGFloat(r) * (th + lab + pad)
    if let img = NSImage(contentsOfFile: path) { img.draw(in: NSRect(x: x, y: yTop - th, width: tw, height: th)) }
    NSColor(white: 0.75, alpha: 1).setStroke(); NSBezierPath(rect: NSRect(x: x, y: yTop - th, width: tw, height: th)).stroke()
    (label as NSString).draw(at: NSPoint(x: x, y: yTop - th - lab + 6), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 14), .foregroundColor: NSColor(red: 0.16, green: 0.09, blue: 0.27, alpha: 1)])
}
NSGraphicsContext.current = nil
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
