import SwiftUI
import NutmegCore

// 2026-11-21 (Haylee, decisions/2026-11-21-one-scene-music-beats.md; layout: design/mockups/one-scene/, the app's real
// stage framing): the one scene with music. While the kids play, Nutmeg stands centered on the stage (gently bobbing to
// the music) and the only buttons are the small ✕ (left) and the labeled ⏸ Pause pill (right); a small music pill sits
// at the top and a thin scene bar (a dot per event, a star for the finale) at the bottom. At an event the big,
// display-only event card shows beside her (role picture(s) + name(s) + the line; a tense event in the warmer pulsing
// style); a calm-again line shows in a soft card. ⏸ Pause dims the stage under the "Paused" card with a big ▶ Resume.
// The setup and clean-up checklists keep the 11-20 cards; their one big button is `PTOneSceneButton`.

// MARK: - The event / calm-again card (the stage's content zone)

/// What the content zone beside Nutmeg shows in the one scene: the event card, the calm-again card, or nothing.
struct BeatSceneCard: View {
    let model: AppModel
    let index: Int
    var width: CGFloat
    var height: CGFloat
    @Environment(\.layoutMetrics) private var metrics
    private var store: AdventureStore { model.store }

    var body: some View {
        let events = store.kit?.scenes.indices.contains(index) == true ? (store.kit!.scenes[index].beats?.events ?? []) : []
        Group {
            if model.beatCardUp {
                switch model.beatDisplay {
                case .event(let i) where events.indices.contains(i):
                    PTBeatEventCard(model: model, event: events[i], phone: metrics.isPhone)
                        .id("event\(i)")
                        .transition(.scale(scale: 0.9).combined(with: .opacity))
                case .calmAgain(let i) where events.indices.contains(i):
                    PTCalmAgainCard(text: events[i].calmAgain ?? "", phone: metrics.isPhone) { model.hearBeatAgain() }
                        .id("calm\(i)")
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }
        }
        .frame(width: width, height: height)
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: model.beatDisplay)
    }
}

/// One event, readable from across the room: the role picture(s) and name(s) on top, the line below. A tense event is
/// the warmer style (coral border, a yellow "!" badge, a gently pulsing halo). 2026-11-21 (Haylee): it stays up until
/// the next cue, with a 🔊 hear-again (the same take, no new call); not a check button.
struct PTBeatEventCard: View {
    let model: AppModel
    let event: BeatEvent
    var phone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var store: AdventureStore { model.store }

    /// The roles it calls (an "everyone" event shows every playing role).
    private var roles: [Role] {
        let all = store.plan?.roles ?? []
        let ids = event.isEveryone ? RoleCast.playing(all, kids: store.playerCount).map(\.id) : event.roles
        return ids.compactMap { id in all.first { $0.id == id } }
    }

    var body: some View {
        let tense = event.isTense
        let shape = RoundedRectangle(cornerRadius: phone ? 26 : 34, style: .continuous)
        VStack(alignment: .leading, spacing: phone ? Theme.Space.s : Theme.Space.m) {
            header(tense: tense)
            HStack(alignment: .bottom, spacing: Theme.Space.s) {
                Text(event.line)
                    .font(Theme.headlineFont(phone ? 21 : 30))
                    .foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.leading)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PTSpeakerButton(size: phone ? 48 : 60, tint: tense ? Theme.coralStrong : Theme.purple, label: "Hear it again") {
                    model.hearBeatAgain()
                }
                .accessibilityIdentifier("scene.hearAgain")
            }
        }
        .padding(phone ? Theme.Space.m : Theme.Space.l)
        .frame(maxWidth: phone ? .infinity : 560, alignment: .leading)
        .background(shape.fill(tense ? Theme.paper : Theme.white))
        .overlay(shape.strokeBorder(tense ? Theme.coralStrong : Theme.line, lineWidth: tense ? 4 : 2))
        .overlay(alignment: .topTrailing) { if tense { alertBadge.offset(x: 14, y: -14) } }
        .background { if tense { PTTenseHalo(shape: shape, reduceMotion: reduceMotion) } }
        .shadow(color: Theme.panelShadow, radius: 12, y: 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(event.line)
    }

    private func header(tense: Bool) -> some View {
        let pic: CGFloat = phone ? 60 : 96
        return HStack(spacing: Theme.Space.s) {
            HStack(spacing: -pic * 0.28) {
                ForEach(Array(roles.prefix(3).enumerated()), id: \.element.id) { k, role in
                    PTCharacterPicture(role: role, image: model.characterPicture(role), size: k == 0 ? pic : pic * 0.78, ring: true)
                        .zIndex(Double(3 - k))
                }
            }
            Text(roles.isEmpty ? "Everyone" : roles.map(\.roleName).joined(separator: " + "))
                .font(Theme.displayFont(phone ? 24 : 38))
                .foregroundStyle(tense ? Theme.coralStrong : Theme.playerColor(roles.first?.id.index ?? 0))
                .lineLimit(2).minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var alertBadge: some View {
        Text("!").font(Theme.displayFont(phone ? 24 : 34)).foregroundStyle(Theme.ink)
            .frame(width: phone ? 44 : 60, height: phone ? 44 : 60)
            .background(Circle().fill(Theme.yellow))
            .overlay(Circle().strokeBorder(Theme.white, lineWidth: 3))
            .accessibilityHidden(true)
    }
}

/// The tense card's warm halo, gently pulsing (still with reduced motion).
struct PTTenseHalo: View {
    let shape: RoundedRectangle
    let reduceMotion: Bool
    var body: some View {
        if reduceMotion {
            shape.fill(Theme.yellow.opacity(0.35)).padding(-14)
        } else {
            shape.fill(Theme.yellow.opacity(0.35)).padding(-14)
                .phaseAnimator([false, true]) { halo, big in
                    halo.scaleEffect(big ? 1.03 : 0.99).opacity(big ? 1 : 0.55)
                } animation: { _ in .easeInOut(duration: 0.8) }
        }
    }
}

/// The calm-again line in a soft card ("Phew, the rush has died down.").
struct PTCalmAgainCard: View {
    let text: String
    var phone = false
    /// 2026-11-21: its 🔊 hear-again (the same take).
    var onHear: () -> Void = {}
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: phone ? 26 : 34, style: .continuous)
        HStack(spacing: Theme.Space.s) {
            Image(systemName: "sparkles").font(.system(size: phone ? 24 : 34, weight: .bold)).foregroundStyle(Theme.limeShade)
            Text(text)
                .font(Theme.headlineFont(phone ? 21 : 30))
                .foregroundStyle(Theme.ink)
                .multilineTextAlignment(.leading)
                .minimumScaleFactor(0.6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            PTSpeakerButton(size: phone ? 44 : 52, tint: Theme.limeShade, label: "Hear it again", action: onHear)
                .accessibilityIdentifier("scene.hearCalmAgain")
        }
        .padding(phone ? Theme.Space.m : Theme.Space.l)
        .frame(maxWidth: phone ? .infinity : 520, alignment: .leading)
        .background(shape.fill(Theme.lime.paleTint(0.22)))
        .overlay(shape.strokeBorder(Theme.lime.paleTint(0.5), lineWidth: 2))
        .shadow(color: Theme.panelShadow, radius: 10, y: 3)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Chrome: the music pill, ⏸ Pause, the scene bar

/// The small music pill at the top ("♫ ılıl Space adventure"; "· uh-oh!" in coral while it's tense). 2026-11-21
/// (Haylee): a tap turns the background music off / on (a crossed-out note and "Music off"); her voice and the chime
/// still play. Thin edge, at least 44 pt tall.
struct PTMusicPill: View {
    let family: MusicFamily
    var tense = false
    var phone = false
    var musicOn = true
    var onToggle: () -> Void = {}
    var body: some View {
        let tint = !musicOn ? Theme.inkMuted : (tense ? Theme.coralStrong : Theme.purple)
        let h: CGFloat = phone ? 44 : 48
        Button(action: onToggle) {
            HStack(spacing: phone ? 6 : Theme.Space.xs) {
                Image(systemName: musicOn ? "music.note" : "speaker.slash.fill").font(.system(size: phone ? 15 : 20, weight: .bold))
                if musicOn { Image(systemName: "chart.bar.fill").font(.system(size: phone ? 13 : 17, weight: .bold)) }
                Text(!musicOn ? "Music off" : (tense ? "\(family.label) · uh-oh!" : family.label))
                    .font(Theme.headlineFont(phone ? 15 : 20)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, phone ? 12 : Theme.Space.m)
            .frame(minHeight: h)
        }
        .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(h), face: tense && musicOn ? Theme.coral.paleTint(0.2) : Theme.white,
                                             shade: Theme.lavenderShade, outlined: true))
        .animation(.easeInOut(duration: 0.3), value: tense)
        .animation(.easeInOut(duration: 0.2), value: musicOn)
        .accessibilityLabel(musicOn ? "Music: \(family.label)" : "Music off")
        .accessibilityHint(musicOn ? "Turns the music off" : "Turns the music on")
        .accessibilityIdentifier("scene.music")
    }
}

/// 2026-11-21 (Haylee): "End scene", small and clear but not tempting for kids (a plain text pill next to ⏸ Pause; it
/// asks first): straight to the finale, then the clean-up.
struct PTEndScenePill: View {
    var height: CGFloat = 44
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "flag.checkered").font(.system(size: height * 0.3, weight: .bold))
                Text("End scene").font(Theme.bodyFont(height * 0.36))
            }
            .foregroundStyle(Theme.inkMuted)
            .padding(.horizontal, height * 0.32)
            .frame(minHeight: max(44, height))
        }
        .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(height), face: Theme.white.opacity(0.9), shade: Theme.line, outlined: true))
        .accessibilityLabel("End scene")
        .accessibilityHint("Goes to the big finish, then clean-up")
        .accessibilityIdentifier("scene.end")
    }
}

/// "End the scene now?" (a grown-up's choice; kids who tap it by accident just keep playing).
struct PTEndSceneDialog: View {
    var phone = false
    let onKeep: () -> Void
    let onEnd: () -> Void
    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea().onTapGesture(perform: onKeep)
            VStack(spacing: phone ? Theme.Space.m : Theme.Space.l) {
                Text("End the scene now?").font(Theme.displayFont(phone ? 30 : 42)).foregroundStyle(Theme.ink)
                    .multilineTextAlignment(.center)
                Text("Nutmeg jumps to the big finish, then clean-up.")
                    .font(Theme.bodyFont(phone ? 18 : 22)).foregroundStyle(Theme.inkMuted).multilineTextAlignment(.center)
                HStack(spacing: Theme.Space.m) {
                    Button(action: onKeep) {
                        Text("Keep playing").font(Theme.headlineFont(phone ? 18 : 22)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, Theme.Space.m).frame(minHeight: phone ? 52 : 60)
                    }
                    .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(56), face: Theme.lime, shade: Theme.limeShade))
                    .accessibilityIdentifier("scene.keepPlaying")
                    Button(action: onEnd) {
                        Text("End scene").font(Theme.headlineFont(phone ? 18 : 22)).foregroundStyle(Theme.ink)
                            .padding(.horizontal, Theme.Space.m).frame(minHeight: phone ? 52 : 60)
                    }
                    .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(56), face: Theme.white, shade: Theme.lavenderShade, outlined: true))
                    .accessibilityIdentifier("scene.endConfirm")
                }
            }
            .padding(phone ? Theme.Space.l : Theme.Space.xl)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.white))
            .shadow(color: Theme.panelShadow, radius: 16, y: 6)
            .padding(.horizontal, Theme.Space.m)
        }
    }
}

/// ⏸ Pause, a labeled white pill (Haylee: kids may want to pause; it's the only button besides the ✕ during play).
struct PTPausePill: View {
    var height: CGFloat = 64
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "pause.fill").font(.system(size: height * 0.3, weight: .heavy))
                Text("Pause").font(Theme.headlineFont(height * 0.38))
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, height * 0.42)
            .frame(height: height)
        }
        .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(height), face: Theme.white, shade: Theme.lavenderShade, outlined: true))
        .accessibilityLabel("Pause")
        .accessibilityIdentifier("scene.pause")
    }
}

/// The thin ~10 minute scene bar: a dot per event (filled once it has happened) and a star for the finale.
struct PTSceneBar: View {
    let dots: [Double]
    let progress: Double
    let fired: Int
    var width: CGFloat = 560
    var body: some View {
        let h: CGFloat = 8, dot: CGFloat = 18
        ZStack(alignment: .leading) {
            Capsule().fill(Theme.white.opacity(0.85)).frame(width: width, height: h)
            Capsule().fill(Theme.lime).frame(width: max(h, width * progress), height: h)
            ForEach(Array(dots.enumerated()), id: \.offset) { k, x in
                Circle().fill(k < fired ? Theme.lime : Theme.white)
                    .overlay(Circle().strokeBorder(k < fired ? Theme.limeShade : Theme.lavenderShade, lineWidth: 2.5))
                    .frame(width: dot, height: dot)
                    .offset(x: width * x - dot / 2)
            }
            Image(systemName: "star.fill").font(.system(size: 24, weight: .bold))
                .foregroundStyle(progress >= 1 ? Theme.yellow : Theme.lavenderShade)
                .offset(x: width - 12)
        }
        .frame(width: width + 12, height: 28, alignment: .leading)
        .animation(.linear(duration: 0.25), value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Scene")
        .accessibilityValue("\(Int(progress * 100)) percent")
    }
}

// MARK: - Paused

/// ⏸ Pause: the stage dims under the "Paused" card with a big ▶ Resume (the music, the clock and her voice stopped).
struct PTPausedCard: View {
    var phone = false
    let onResume: () -> Void
    var body: some View {
        ZStack {
            Theme.scrim.ignoresSafeArea()
            VStack(spacing: phone ? Theme.Space.m : Theme.Space.l) {
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: "pause.fill").font(.system(size: phone ? 30 : 44, weight: .heavy)).foregroundStyle(Theme.purple)
                    Text("Paused").font(Theme.displayFont(phone ? 40 : 60)).foregroundStyle(Theme.ink)
                }
                Text("Music stopped. Nutmeg waits for you.")
                    .font(Theme.bodyFont(phone ? 18 : 24)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center)
                PTOneSceneButton(title: "Resume", ready: true, height: phone ? 68 : 84, width: phone ? 240 : 340, action: onResume)
                    .accessibilityIdentifier("scene.resume")
            }
            .padding(phone ? Theme.Space.l : Theme.Space.xl)
            .background(RoundedRectangle(cornerRadius: 36, style: .continuous).fill(Theme.white))
            .shadow(color: Theme.panelShadow, radius: 16, y: 6)
            .padding(.horizontal, Theme.Space.m)
        }
    }
}

// MARK: - The big button of the setup / clean-up checklist (and Resume)

/// ▶ Let's play! / ▶ The End / ▶ Resume. 2026-11-21 (Haylee): always green and always works (pressed early, the app
/// checks what's left first); the soft halo shows once everything is checked (`ready`).
struct PTOneSceneButton: View {
    let title: String
    let ready: Bool
    var height: CGFloat = 76
    var width: CGFloat = 340
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.s) {
                Image(systemName: "play.fill").font(.system(size: height * 0.32, weight: .heavy, design: .rounded))
                Text(title).font(Theme.headlineFont(height * 0.36)).lineLimit(1).minimumScaleFactor(0.6)
            }
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, Theme.Space.m)
            .frame(width: width, height: height)
        }
        .buttonStyle(PTNextSceneButton.Style(edge: Theme.edge(height), face: Theme.lime, shade: Theme.limeShade))
        .background {
            if ready {
                Capsule().fill(Theme.lime.opacity(0.3)).padding(-10)
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: ready)
        .sensoryFeedback(.success, trigger: ready) { _, new in new }
        .accessibilityLabel(title)
    }
}
