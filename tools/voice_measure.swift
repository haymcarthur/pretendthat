// Round 35 prep (voice A/B v2): measures Nutmeg recordings. Input: raw float32 little-endian mono files at 16 kHz
// (tools/voice-measure.sh converts anything with ffmpeg first). For each file prints:
//   voiced span (s, first to last frame above -40 dBFS of the file's peak), median F0 (Hz, autocorrelation on voiced
//   frames), and a 12-coefficient cepstral timbre fingerprint (mean of log mel-band energies → DCT, voiced frames).
// With `--ref a,b,c` the fingerprint distance to the mean of the reference files is printed too (smaller = closer).
// Usage: swift tools/voice_measure.swift [--ref f1,f2] file1 file2 ...   (labels = file names)
import Accelerate
import Foundation

let sr = 16_000.0
let frame = 1024, hop = 256

func load(_ path: String) -> [Float] {
    let d = (try? Data(contentsOf: URL(fileURLWithPath: path))) ?? Data()
    return d.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
}

struct Stats { var span: Double; var f0: Double; var ceps: [Double]; var voicedFrames: Int }

let melBands = 32
func hz2mel(_ f: Double) -> Double { 2595 * log10(1 + f / 700) }
func mel2hz(_ m: Double) -> Double { 700 * (pow(10, m / 2595) - 1) }
let edges: [Double] = (0...(melBands + 1)).map { mel2hz(hz2mel(80) + (hz2mel(7600) - hz2mel(80)) * Double($0) / Double(melBands + 1)) }

let log2n = vDSP_Length(log2(Double(frame)))
let fft = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
let window: [Float] = { var w = [Float](repeating: 0, count: frame); vDSP_hann_window(&w, vDSP_Length(frame), Int32(vDSP_HANN_NORM)); return w }()

func spectrum(_ x: ArraySlice<Float>) -> [Float] {
    var buf = [Float](x); vDSP_vmul(buf, 1, window, 1, &buf, 1, vDSP_Length(frame))
    var re = [Float](repeating: 0, count: frame / 2), im = [Float](repeating: 0, count: frame / 2)
    var mag = [Float](repeating: 0, count: frame / 2)
    re.withUnsafeMutableBufferPointer { rp in im.withUnsafeMutableBufferPointer { ip in
        var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
        buf.withUnsafeBufferPointer { b in b.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: frame / 2) {
            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(frame / 2)) } }
        vDSP_fft_zrip(fft, &split, 1, log2n, FFTDirection(FFT_FORWARD))
        vDSP_zvmags(&split, 1, &mag, 1, vDSP_Length(frame / 2))
    } }
    return mag
}

func pitch(_ x: ArraySlice<Float>) -> Double? {
    // Normalized autocorrelation, 120–600 Hz.
    let a = Array(x), n = a.count
    let minLag = Int(sr / 600), maxLag = Int(sr / 120)
    var e0: Float = 0; vDSP_svesq(a, 1, &e0, vDSP_Length(n))
    guard e0 > 0 else { return nil }
    var best = 0.0, bestLag = 0
    for lag in minLag...maxLag {
        var r: Float = 0
        vDSP_dotpr(a, 1, Array(a[lag...]), 1, &r, vDSP_Length(n - lag))
        let v = Double(r) / Double(e0) * Double(n) / Double(n - lag)
        if v > best { best = v; bestLag = lag }
    }
    return best > 0.5 ? sr / Double(bestLag) : nil
}

func analyze(_ x: [Float]) -> Stats {
    guard x.count > frame else { return Stats(span: 0, f0: 0, ceps: [], voicedFrames: 0) }
    var rms: [Float] = []
    var i = 0
    while i + frame <= x.count { var r: Float = 0; vDSP_rmsqv(Array(x[i..<i + frame]), 1, &r, vDSP_Length(frame)); rms.append(r); i += hop }
    let peak = rms.max() ?? 0, thr = peak * 0.01   // -40 dB
    let first = rms.firstIndex { $0 > thr } ?? 0, last = rms.lastIndex { $0 > thr } ?? 0
    let span = Double((last - first) * hop + frame) / sr
    var f0s: [Double] = []
    var bandSum = [Double](repeating: 0, count: melBands); var voiced = 0
    for (k, r) in rms.enumerated() where r > peak * 0.1 {   // -20 dB: speech frames
        let s = k * hop
        let seg = x[s..<s + frame]
        if let p = pitch(seg) { f0s.append(p) } else { continue }
        let mag = spectrum(seg)
        for b in 0..<melBands {
            let lo = edges[b], mid = edges[b + 1], hi = edges[b + 2]
            var e = 0.0
            for bin in 1..<(frame / 2) {
                let f = Double(bin) * sr / Double(frame)
                let w = f < lo || f > hi ? 0 : (f <= mid ? (f - lo) / (mid - lo) : (hi - f) / (hi - mid))
                e += w * Double(mag[bin])
            }
            bandSum[b] += log(e + 1e-9)
        }
        voiced += 1
    }
    f0s.sort()
    let med = f0s.isEmpty ? 0 : f0s[f0s.count / 2]
    let logMel = bandSum.map { $0 / Double(max(voiced, 1)) }
    // DCT-II, coefficients 1...12 (c0 = loudness, dropped).
    let ceps = (1...12).map { c in (0..<melBands).reduce(0.0) { $0 + logMel[$1] * cos(Double.pi * Double(c) * (Double($1) + 0.5) / Double(melBands)) } }
    return Stats(span: span, f0: med, ceps: ceps, voicedFrames: voiced)
}

func dist(_ a: [Double], _ b: [Double]) -> Double { sqrt(zip(a, b).reduce(0) { $0 + ($1.0 - $1.1) * ($1.0 - $1.1) }) }

var args = Array(CommandLine.arguments.dropFirst())
var refs: [String] = []
if let i = args.firstIndex(of: "--ref"), i + 1 < args.count { refs = args[i + 1].split(separator: ",").map(String.init); args.removeSubrange(i...i + 1) }
var refMean: [Double]? = nil
if !refs.isEmpty {
    let cs = refs.map { analyze(load($0)).ceps }.filter { !$0.isEmpty }
    refMean = (0..<12).map { k in cs.map { $0[k] }.reduce(0, +) / Double(cs.count) }
}
print("file\tspan_s\tf0_hz\tvoiced\tdist_to_ref\tceps1-4")
for path in args {
    let s = analyze(load(path))
    let d = refMean.map { String(format: "%.2f", dist(s.ceps, $0)) } ?? "-"
    print(String(format: "%@\t%.3f\t%.1f\t%d\t%@\t%@", (path as NSString).lastPathComponent, s.span, s.f0, s.voicedFrames, d,
                 s.ceps.prefix(4).map { String(format: "%.1f", $0) }.joined(separator: ",")))
}
