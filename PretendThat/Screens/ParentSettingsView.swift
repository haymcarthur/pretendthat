import SwiftUI
import NutmegCore

/// Grown-ups only (behind the hold-to-open gate). Native Form and NavigationStack.
struct ParentSettingsView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var debugState: NutmegState = .idle
    @State private var debugLevel: Float = 0
    @State private var debugPose: NutmegPose = .idle

    var body: some View {
        NavigationStack {
            Form {
                Section("Connections") {
                    LabeledContent("Story brain (Claude)", value: model.hasClaude ? "Key set ✓" : "Not set: using the built-in airplane game")
                    LabeledContent("Kit pictures (OpenAI)", value: !model.hasImages ? "Not set: app-drawn pages"
                        : model.art.unavailableReason.map { "Off (\($0)): app-drawn pages" } ?? "Key set ✓")
                    LabeledContent("Last kit picture", value: model.art.lastResult ?? "none yet")
                    LabeledContent("Last sticker", value: model.stickers.lastResult ?? "none yet")
                    LabeledContent("Speech", value: model.listener.status)
                    if !model.listener.available, let url = URL(string: UIApplication.openSettingsURLString) {
                        Link("Open Settings to allow the mic", destination: url)
                    }
                }
                Section {
                    @Bindable var vs = model.voiceSettings
                    LabeledContent("Conversation (OpenAI Realtime)", value: realtimeStatus)
                    Picker("Nutmeg's voice", selection: $vs.voice) {
                        ForEach(Realtime.voices, id: \.self) { Text($0.capitalized).tag($0) }
                    }
                    Picker("Pitch method", selection: $vs.method) {
                        ForEach(Realtime.PitchMethod.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    if vs.method == .varispeed {
                        LabeledContent("Varispeed rate") {
                            Slider(value: $vs.rate, in: 1.0...1.25, step: 0.01) { Text("Rate") }
                                .onChange(of: vs.rate) { _, _ in model.realtime.setShape(vs.shape) }
                            Text(String(format: "%.2f×", vs.rate)).monospacedDigit().frame(width: 110, alignment: .trailing)
                        }
                    }
                    if vs.method == .timePitch {
                        LabeledContent("TimePitch") {
                            Slider(value: $vs.pitchCents, in: 0...600, step: 25) { Text("Pitch") }
                                .onChange(of: vs.pitchCents) { _, _ in model.realtime.setShape(vs.shape) }
                            Text("+\(Int(vs.pitchCents)) cents").monospacedDigit().frame(width: 110, alignment: .trailing)
                        }
                    }
                    Toggle("Echo cancellation (dulls her voice a little)", isOn: $vs.echoCancel)
                    LabeledContent("Speed") {
                        Slider(value: $vs.speed, in: 0.8...1.5, step: 0.05) { Text("Speed") }
                        Text(String(format: "%.2f×", vs.speed)).monospacedDigit().frame(width: 110, alignment: .trailing)
                    }
                    Button("Reset voice to default") { model.voiceSettings.reset(); model.realtime.setShape(model.voiceSettings.shape) }
                    Button {
                        Task { await model.auditionVoice(vs.voice) }
                    } label: {
                        Label(model.realtime.status == .connecting || model.realtime.isLive ? "Playing…" : "Voice audition: play the sample line",
                              systemImage: "play.circle")
                    }
                    .disabled(!model.hasRealtime || model.realtime.isLive || model.realtime.status == .connecting)
                } header: { Text("Voice") } footer: {
                    Text("Model \(Realtime.model). Pick a voice, then play the sample to compare by ear. Rate and cents apply right away; voice, method, speed and echo cancellation apply to the next conversation.")
                }
                Section("Printing") {
                    Button("Print a test page") {
                        let a = Fallback.airplane(playerCount: 2)
                        let pages = Array(KitLayout.pages(for: a.kit, roles: a.plan.roles, playerCount: 2).prefix(1))
                        KitPrinter.print(KitPrinter.pdf(pages: pages, art: [:]), jobName: "PretendThat test page")
                    }
                }
                Section("Nutmeg debug") {
                    NutmegCharacter(state: debugState, mouthLevel: debugLevel, isSpeaking: debugState == .talking, forcedPose: debugPose)
                        .frame(height: 280)
                    Picker("State", selection: $debugState) { ForEach(NutmegState.allCases) { Text($0.rawValue).tag($0) } }
                    Picker("Pose", selection: $debugPose) { ForEach(NutmegPose.allCases) { Text($0.rawValue).tag($0) } }
                    Slider(value: $debugLevel, in: 0...1) { Text("Mouth level") }
                }
                #if DEBUG
                Section("Design") {
                    NavigationLink("Component gallery") { ComponentGallery() }
                }
                #endif
                Section("Privacy") {
                    Text(Self.privacy)
                }
            }
            .navigationTitle("Grown-ups")
            .toolbar { Button("Done") { dismiss() } }
        }
    }

    private var realtimeStatus: String {
        guard model.hasRealtime else { return "Not set: tap screens" }
        switch model.realtime.status {
        case .idle: return "Ready ✓"
        case .connecting: return "Connecting…"
        case .live: return "Live ✓"
        case .failed(let r): return "Off (\(r)): tap screens"
        }
    }

    static let privacy = """
    We never ask for kids' names. Nutmeg only asks how many kids are playing; badges and tickets print a blank name line kids fill in themselves.
    PretendThat stores nothing: no accounts, no recordings, no transcripts. Audio is processed live by OpenAI under its API terms.
    When the app closes, the adventure is gone. No database, no analytics.
    Story requests go to Anthropic and picture requests to OpenAI, handled under their commercial API terms.
    """
}
