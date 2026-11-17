import AVFoundation
import Foundation
import Observation
import Speech
import NutmegCore

/// Round 34 (Haylee): Apple's on-device English speech model, downloaded IN the app on iPadOS 26+ (SpeechAnalyzer's
/// `AssetInventory`), instead of sending a grown-up to Settings › Dictation. It starts quietly at onboarding's mic step
/// (usually ready before the first press); a press before it's there opens a friendly one-tap grown-up sheet with
/// progress. Older iPadOS keeps the Settings note. The model is Apple's and stays on the iPad; no audio is involved.
///
/// The simulator can't load the model (round 31), so `-PTSpeechModel needs|downloading|failed|installed|old` forces a
/// state for screenshots, and `-PTSpeechModelFake` fakes a ~6 s download on the tap.
@Observable @MainActor
final class SpeechModelInstaller {
    private(set) var state: SpeechModelState = .unknown
    /// The sheet is up (a mic press before the model was there, or Grown-ups).
    var showingSheet = false
    @ObservationIgnored private var task: Task<Void, Never>?
    @ObservationIgnored var onInstalled: (() -> Void)?
    static let locale = Locale(identifier: "en-US")

    /// The in-app download exists on this OS (the sheet replaces the Settings note).
    var offersDownload: Bool {
        switch state { case .notSupportedHere, .unsupportedLanguage: return false; default: return true }
    }

    /// Reads the current status (no download).
    func refresh() async {
        #if DEBUG
        if let forced = Self.forced { state = forced; return }
        #endif
        guard #available(iOS 26, *) else { state = state.next(.osTooOld); return }
        let status = await AssetInventory.status(forModules: [Self.module()])
        state = state.next(.status(Self.map(status)))
        rtLog("SPEECHMODEL status: \(status) → \(state)")
        if state.isReady { onInstalled?() }
    }

    /// Starts (or resumes) the download. `quiet`: from onboarding, no sheet.
    func start(quiet: Bool = false) {
        guard task == nil else { return }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-PTSpeechModelFake") { fakeDownload(); return }
        if Self.forced != nil { return }
        #endif
        guard #available(iOS 26, *) else { state = state.next(.osTooOld); return }
        task = Task { @MainActor [weak self] in
            await self?.download(quiet: quiet)
            self?.task = nil
        }
    }

    @available(iOS 26, *)
    private func download(quiet: Bool) async {
        do {
            let module = Self.module()
            guard let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) else {
                state = state.next(.finished)   // already on the iPad
                onInstalled?()
                return
            }
            state = state.next(.started)
            rtLog("SPEECHMODEL download started (\(quiet ? "quiet, onboarding" : "grown-up sheet"))")
            let progress = request.progress
            let watcher = Task { @MainActor [weak self] in
                while !Task.isCancelled {
                    self?.state = self?.state.next(.progress(progress.fractionCompleted)) ?? .unknown
                    try? await Task.sleep(for: .milliseconds(250))
                }
            }
            try await request.downloadAndInstall()
            watcher.cancel()
            state = state.next(.finished)
            rtLog("SPEECHMODEL installed")
            onInstalled?()
        } catch {
            state = state.next(.error)
            rtLog("SPEECHMODEL download failed: \(error.localizedDescription)")
        }
    }

    @available(iOS 26, *)
    static func module() -> DictationTranscriber {
        DictationTranscriber(locale: locale, preset: .shortDictation)
    }

    @available(iOS 26, *)
    static func map(_ s: AssetInventory.Status) -> SpeechModelState.AssetStatus {
        switch s {
        case .installed: return .installed
        case .downloading: return .downloading
        case .supported: return .supported
        default: return .unsupported
        }
    }

    #if DEBUG
    /// `-PTSpeechModel needs|downloading|failed|installed|old|unsupported`: a fixed state (simulator screenshots).
    static var forced: SpeechModelState? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-PTSpeechModel"), i + 1 < a.count else { return nil }
        switch a[i + 1] {
        case "needs": return .needsDownload
        case "downloading": return .downloading(0.42)
        case "failed": return .failed
        case "installed": return .installed
        case "old": return .notSupportedHere
        case "unsupported": return .unsupportedLanguage
        default: return nil
        }
    }
    private func fakeDownload() {
        task = Task { @MainActor [weak self] in
            self?.state = .downloading(0)
            for k in 1...24 { try? await Task.sleep(for: .milliseconds(250)); self?.state = .downloading(Double(k) / 24) }
            self?.state = .installed
            self?.task = nil
        }
    }
    #endif
}
