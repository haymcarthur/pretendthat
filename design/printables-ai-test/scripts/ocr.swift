import Foundation
import Vision
import AppKit
// Usage: swift ocr.swift <png>...  -> JSON {file: [{text, confidence}]}, accurate, no language correction.
var out: [String: [[String: Any]]] = [:]
for path in CommandLine.arguments.dropFirst() {
    guard let img = NSImage(contentsOfFile: path), let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
    let req = VNRecognizeTextRequest()
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = false
    req.recognitionLanguages = ["en-US"]
    try? VNImageRequestHandler(cgImage: cg).perform([req])
    out[(path as NSString).lastPathComponent] = (req.results ?? []).compactMap { o in
        guard let c = o.topCandidates(1).first else { return nil }
        return ["text": c.string, "confidence": Double(c.confidence)]
    }
}
let d = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys])
print(String(data: d, encoding: .utf8)!)
