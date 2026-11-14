import Foundation

/// Nutmeg's mouth shapes (the art: nutmeg-mouth-<rawValue>).
public enum MouthShape: String, CaseIterable, Sendable {
    case closed, small, open, wide, ooh
}

/// One analysis window of Nutmeg's voice: loudness plus a cheap spectral split.
public struct MouthFeatures: Equatable, Sendable {
    /// Seconds from the start of the analyzed buffer (source samples, before any playback-rate change).
    public var offset: Double
    public var rms: Float
    /// Relative energy in the band above ~2.5 kHz (s, ee: bright sounds); a soft filter, so ~0.1–0.2 is "bright".
    public var bright: Float
    /// Share of the energy below ~800 Hz (oo, o: rounded sounds).
    public var low: Float
    public init(offset: Double, rms: Float, bright: Float, low: Float) {
        self.offset = offset; self.rms = rms; self.bright = bright; self.low = low
    }
}

/// Splits Nutmeg's audio into short windows (10 ms) and measures loudness and the spectral split with cascaded
/// one-pole filters (2nd-order low-pass and high-pass, no FFT). Filter state carries across buffers, so consecutive deltas analyze as one stream.
public struct LipSyncAnalyzer: Sendable {
    public let sampleRate: Double
    public let window: Double
    private let aLow: Float, aHigh: Float
    private var low1: Float = 0, low2: Float = 0, hp1LP: Float = 0, hp2LP: Float = 0

    public init(sampleRate: Double, window: Double = 0.01, lowCut: Double = 800, highCut: Double = 2500) {
        self.sampleRate = sampleRate
        self.window = window
        aLow = Float(1 - exp(-2 * Double.pi * lowCut / sampleRate))
        aHigh = Float(1 - exp(-2 * Double.pi * highCut / sampleRate))
    }

    public mutating func reset() { low1 = 0; low2 = 0; hp1LP = 0; hp2LP = 0 }

    public mutating func analyze(_ samples: [Float]) -> [MouthFeatures] {
        let n = max(1, Int(sampleRate * window))
        var out: [MouthFeatures] = []
        var i = 0
        while i < samples.count {
            let end = min(i + n, samples.count)
            var e: Float = 0, el: Float = 0, eh: Float = 0
            for j in i..<end {
                let x = samples[j]
                low1 += aLow * (x - low1)
                low2 += aLow * (low1 - low2)
                hp1LP += aHigh * (x - hp1LP)
                let hp1 = x - hp1LP
                hp2LP += aHigh * (hp1 - hp2LP)
                let hp = hp1 - hp2LP
                e += x * x; el += low2 * low2; eh += hp * hp
            }
            let count = Float(end - i)
            let total = max(e, 1e-9)
            out.append(MouthFeatures(offset: Double(i) / sampleRate, rms: (e / count).squareRoot(),
                                     bright: min(1, eh / total), low: min(1, el / total)))
            i = end
        }
        return out
    }
}

/// Turns the feature stream into mouth shapes: an envelope with a fast attack (~30 ms) and a quick release (~80 ms) so
/// the mouth snaps open on syllables and closes on pauses; hysteresis between neighbouring shapes; every shape held at
/// least ~60 ms so it never flickers. Silence below the noise floor → closed, soft → small, bright → wide,
/// low/rounded → ooh, loud mid → open.
public struct MouthShaper: Sendable {
    public var attack = 0.03, release = 0.08, hold = 0.06
    /// Loudness → 0…1 (matches the old amplitude mouth's scale).
    public var gain: Float = 7
    public private(set) var envelope: Float = 0
    public private(set) var shape: MouthShape = .closed
    private var lastTime: Double?
    private var shapeSince: Double = -.infinity

    public init() {}

    public mutating func reset() { envelope = 0; shape = .closed; lastTime = nil; shapeSince = -.infinity }

    /// Feeds one window at `time` (seconds, any monotonic clock) and returns the shape to show.
    @discardableResult
    public mutating func step(_ f: MouthFeatures, at time: Double) -> MouthShape {
        let dt = max(0, time - (lastTime ?? time - 0.01))
        lastTime = time
        let level = min(1, f.rms * gain)
        let tau = level > envelope ? attack : release
        envelope += (level - envelope) * Float(1 - exp(-dt / tau))
        let next = candidate(f)
        if next != shape && time - shapeSince >= hold {
            shape = next
            shapeSince = time
        }
        return shape
    }

    private func candidate(_ f: MouthFeatures) -> MouthShape {
        let e = envelope
        // Hysteresis: it takes more to leave a quieter shape than to fall back into it.
        if e < (shape == .closed ? 0.07 : 0.045) { return .closed }
        if e < (shape == .closed || shape == .small ? 0.22 : 0.17) { return .small }
        // Thresholds measured on the cascaded one-pole bands (tones: 1.5 kHz ≈ 0.02 bright / 0.05 low; 5 kHz ≈ 0.16
        // bright; 250 Hz ≈ 0.83 low). Speech: s/ee push `bright` up, oo/o push `low` up, a/e sit in between.
        if f.bright > (shape == .wide ? 0.06 : 0.08) { return .wide }
        if f.low > (shape == .ooh ? 0.62 : 0.7) { return .ooh }
        return .open
    }
}
