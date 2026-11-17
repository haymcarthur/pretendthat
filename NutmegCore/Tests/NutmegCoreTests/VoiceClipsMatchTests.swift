@preconcurrency import AVFAudio
import Accelerate
import Foundation
import Testing
@testable import NutmegCore

/// Voice clips match (decisions/2026-11-17-voice-clips-match.md): measurement + listening renders. Env-gated, no API.
@Suite struct VoiceClipsMatchMeasure {
    static let sr = Realtime.sampleRate

    static func read(_ url: URL) throws -> [Float] {
        if url.pathExtension == "aac" { return try VoicePitchTests.decodeAAC(url) }
        let f = try AVAudioFile(forReading: url)
        let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
        try f.read(into: b)
        return Array(UnsafeBufferPointer(start: b.floatChannelData![0], count: Int(b.frameLength)))
    }

    /// Per-frame F0s (same method as PitchTracker, whole file).
    static func f0s(_ x: [Float], sampleRate: Double) -> [Double] {
        let frame = Int(0.040 * sampleRate), hop = Int(0.010 * sampleRate)
        let minLag = Int(sampleRate / 700), maxLag = Int(sampleRate / 100)
        var out: [Double] = []
        x.withUnsafeBufferPointer { buf in
            let p = buf.baseAddress!
            var rms: [Float] = []; var i = 0
            while i + frame <= x.count { var r: Float = 0; vDSP_rmsqv(p + i, 1, &r, vDSP_Length(frame)); rms.append(r); i += hop }
            guard let peak = rms.max(), peak > 1e-4 else { return }
            var corr = [Float](repeating: 0, count: maxLag + 1)
            for (k, r) in rms.enumerated() where r > peak * 0.0316 {
                let s = p + k * hop
                var e0: Float = 0; vDSP_svesq(s, 1, &e0, vDSP_Length(frame)); guard e0 > 0 else { continue }
                var best: Float = 0
                for lag in minLag...maxLag {
                    var c: Float = 0; let len = frame - lag
                    vDSP_dotpr(s, 1, s + lag, 1, &c, vDSP_Length(len))
                    corr[lag] = c / e0 * Float(frame) / Float(len); best = max(best, corr[lag])
                }
                guard best > 0.5 else { continue }
                for lag in minLag...maxLag where corr[lag] >= best * 0.9 && corr[lag] >= corr[max(minLag, lag - 1)] && corr[lag] >= corr[min(maxLag, lag + 1)] {
                    out.append(sampleRate / Double(lag)); break
                }
            }
        }
        return out
    }

    /// Spectral centroid (Hz) of loud frames, 2048-point FFT.
    static func centroid(_ x: [Float], sampleRate: Double) -> Double {
        let n = 2048, log2n = vDSP_Length(11)
        let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        defer { vDSP_destroy_fftsetup(setup) }
        var win = [Float](repeating: 0, count: n); vDSP_hann_window(&win, vDSP_Length(n), Int32(vDSP_HANN_NORM))
        var frames: [(Float, Double)] = []
        var i = 0
        while i + n <= x.count {
            var seg = Array(x[i..<i + n]); vDSP_vmul(seg, 1, win, 1, &seg, 1, vDSP_Length(n))
            var re = [Float](repeating: 0, count: n / 2), im = [Float](repeating: 0, count: n / 2)
            var mag = [Float](repeating: 0, count: n / 2)
            re.withUnsafeMutableBufferPointer { r in im.withUnsafeMutableBufferPointer { m in
                var sc = DSPSplitComplex(realp: r.baseAddress!, imagp: m.baseAddress!)
                seg.withUnsafeBufferPointer { s in s.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: n / 2) {
                    vDSP_ctoz($0, 2, &sc, 1, vDSP_Length(n / 2)) } }
                vDSP_fft_zrip(setup, &sc, 1, log2n, FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&sc, 1, &mag, 1, vDSP_Length(n / 2))
            } }
            var e: Float = 0; vDSP_sve(mag, 1, &e, vDSP_Length(n / 2))
            var w = 0.0
            for (k, m) in mag.enumerated() { w += Double(m) * Double(k) * sampleRate / Double(n) }
            if e > 0 { frames.append((e, w / Double(e))) }
            i += n / 2
        }
        guard let peak = frames.map(\.0).max() else { return 0 }
        let loud = frames.filter { $0.0 > peak * 0.1 }.map(\.1)
        return loud.reduce(0, +) / Double(max(1, loud.count))
    }

    /// The voice pitch build's per-clip plan (removed by voice clips match), kept here for the "before" renders:
    /// shift toward 266 Hz × 2^(2/12) raw, clamped ±6 st, formants placed at the live +2 when the shift differs.
    static func oldPerClipPlan(_ hz: Double?) -> ClipPitch.Plan {
        guard let hz, hz > 0 else { return ClipPitch.plan(PitchShift()) }
        let st = min(max(12 * log2(266 * pow(2, 2.0 / 12) / hz), -6), 6)
        return ClipPitch.Plan(semitones: st, formantSemitones: abs(st - 2) < 0.25 ? nil : 2)
    }

    static func pct(_ v: [Double], _ p: Double) -> Double {
        guard !v.isEmpty else { return 0 }
        let s = v.sorted(); return s[min(s.count - 1, Int(Double(s.count) * p))]
    }

    /// PT_MEASURE_IN=a.caf,b.aac (and PT_MEASURE_OUT=dir to write renders): raw F0 p10/median/p90, raw centroid, then the
    /// heard F0 and centroid through the app's chain (Varispeed 1.20 → 48 kHz) for: the round's per-clip plan ("perclip")
    /// and the live processing ("same", fixed +2).
    @Test func measureClipsAndLive() throws {
        let env = ProcessInfo.processInfo.environment
        guard let ins = env["PT_MEASURE_IN"] else { return }
        let outDir = env["PT_MEASURE_OUT"]
        var keyToLine: [String: String] = [:]
        for l in CommonLines.all { keyToLine[CommonLines.key(l)] = l }
        for path in ins.split(separator: ",").map(String.init) {
            let url = URL(fileURLWithPath: path)
            let x = try Self.read(url)
            let f = Self.f0s(x, sampleRate: Self.sr)
            let hz = PitchTracker.medianHz(x)
            let name = url.deletingPathExtension().lastPathComponent
            let key = name.replacingOccurrences(of: "common-", with: "")
            let perclip = Self.oldPerClipPlan(hz)
            let same = ClipPitch.plan(PitchShift())
            var line = String(format: "MEASURE %@ | %.1fs | raw F0 p10 %.0f med %.0f p90 %.0f (tracker %.0f) | raw centroid %.0f | perclip %+.2f st form %@",
                              String(name.prefix(16)), Double(x.count) / Self.sr, Self.pct(f, 0.1), Self.pct(f, 0.5), Self.pct(f, 0.9), hz ?? 0,
                              Self.centroid(x, sampleRate: Self.sr), perclip.semitones, perclip.formantSemitones.map { String(format: "%+.1f", $0) } ?? "follows")
            for (tag, p) in [("perclip", perclip), ("same", same)] {
                let y = try VoicePitchTests.renderThroughGraph(x, plan: p, chunk: url.pathExtension == "aac" ? 2400 : 1200)
                let fy = Self.f0s(y, sampleRate: 48_000)
                line += String(format: " | %@ heard F0 %.0f centroid %.0f", tag, Self.pct(fy, 0.5), Self.centroid(y, sampleRate: 48_000))
                if let outDir {
                    try y.withUnsafeBufferPointer { Data(buffer: $0) }.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("\(name)-\(tag).f32"))
                }
            }
            if let t = keyToLine[key] { line += " | \"\(t)\"" }
            print(line)
        }
    }
}
