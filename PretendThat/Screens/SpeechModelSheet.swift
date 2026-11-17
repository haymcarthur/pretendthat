import SwiftUI
import NutmegCore

/// Round 34 (Haylee): "Nutmeg needs to learn to listen, one time, about a minute on Wi-Fi." A friendly one-tap grown-up
/// screen for Apple's on-device English speech model (iPadOS 26+): Download now → progress → All set. Older iPadOS
/// shows the Settings › Dictation steps instead. Kids can type meanwhile.
struct SpeechModelSheet: View {
    let installer: SpeechModelInstaller
    var onType: () -> Void

    var body: some View {
        let s = installer.state
        let copy = s.copy
        VStack(spacing: Theme.Space.l) {
            Image(systemName: s.isReady ? "checkmark.circle.fill" : "ear.and.waveform")
                .font(.system(size: 64, weight: .bold)).foregroundStyle(s.isReady ? Theme.limeShade : Theme.coral)
                .frame(width: 120, height: 120)
                .background(Circle().fill(Theme.white))
                .accessibilityHidden(true)
            Text(copy.title).font(Theme.displayFont(30)).foregroundStyle(Theme.ink).multilineTextAlignment(.center)
            Text(copy.body).font(Theme.bodyFont(19)).foregroundStyle(Theme.ink.opacity(0.85))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 460)
            if let p = s.progress {
                ProgressView(value: p)
                    .progressViewStyle(.linear).tint(Theme.coral)
                    .frame(maxWidth: 360)
                    .accessibilityLabel("Download progress")
                    .accessibilityValue("\(Int(p * 100)) percent")
            }
            if let button = copy.button {
                Button(button) {
                    if s.isReady { installer.showingSheet = false } else { installer.start() }
                }
                .buttonStyle(s.isReady ? .ptSuccess : .ptPrimary)
            }
            if !s.isReady {
                Button("Type instead for now", action: onType).buttonStyle(.ptQuiet)
            }
        }
        .padding(Theme.Space.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.cream.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.25), value: s)
        .task { await installer.refresh() }
    }
}
