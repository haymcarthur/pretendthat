#if DEBUG
import SwiftUI

/// DEBUG: every pose with every face, to verify Haylee's layered art lines up (`-PTDemo artPoses` / `artFaces`).
struct ArtCheckView: View {
    var mode: String
    var body: some View {
        VStack(spacing: 8) {
            Text(mode == "artFaces" ? "Faces on idle (and talking mouths)" : "Poses × faces").font(Theme.uiFont(16))
            if mode == "artFaces" {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow { ForEach(NutmegState.allCases.prefix(4)) { cell($0, .idle) } }
                    GridRow { ForEach(NutmegState.allCases.dropFirst(4)) { cell($0, .idle) } }
                    GridRow {
                        ForEach([Float(0.05), 0.2, 0.4, 0.8], id: \.self) { lvl in
                            NutmegCharacter(state: .talking, mouthLevel: lvl, isSpeaking: true, forcedPose: .idle)
                                .frame(height: 170).overlay(alignment: .bottom) { Text("mouth \(lvl, specifier: "%.2f")").font(.caption) }
                        }
                    }
                }
            } else {
                let faces: [NutmegState] = mode == "artPoses2" ? [.talking, .oops, .listening] : [.idle, .excited, .thinking]
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(faces) { st in
                        GridRow { ForEach(NutmegPose.allCases) { pose in cell(st, pose) } }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
    }

    private func cell(_ st: NutmegState, _ pose: NutmegPose) -> some View {
        NutmegCharacter(state: st, forcedPose: pose)
            .frame(height: mode == "artFaces" ? 200 : 230)
            .overlay(alignment: .bottom) { Text("\(pose.rawValue)/\(st.rawValue)").font(.caption2) }
    }
}
#endif
