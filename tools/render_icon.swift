// Renders tools/nutmeg-composite.svg onto a solid brand background as a 1024px PNG app icon.
import AppKit
let args = CommandLine.arguments
let svg = NSImage(contentsOfFile: args[1])!
let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
NSColor(srgbRed: 1.0, green: 0.784, blue: 0.239, alpha: 1).setFill()   // sunny yellow
NSRect(x: 0, y: 0, width: size, height: size).fill()
svg.draw(in: NSRect(x: 62, y: 20, width: 900, height: 900))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: args[2]))
