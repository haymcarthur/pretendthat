import SwiftUI

/// One checklist / scene picture (checklist-pictures.md): a household-prop drawing, an action drawing, or a piece of
/// this game's printed kit (a ticket, a bill, a role's badge, one cut-out). Never an emoji. While the art isn't there
/// yet (action placeholders until Haylee's vectors land, kit art still drawing), a calm placeholder shows the word.
struct PTPictureTile: View {
    let image: UIImage?
    /// Placeholder word ("wave", "Boarding Pass") while there's no art.
    var placeholder: String = ""
    /// A role badge: the role title in the role color, overlaid like on the printed badge.
    var roleTitle: String? = nil
    var roleTint: Color = Theme.coral
    var size: CGFloat = 56

    var body: some View {
        ZStack(alignment: .bottom) {
            if let image {
                Image(uiImage: image).resizable().interpolation(.high).scaledToFit()
                    .padding(size * 0.06)
            } else {
                Text(placeholder)
                    .font(Theme.uiFont(max(10, size * 0.2), .semibold)).foregroundStyle(Theme.inkMuted)
                    .multilineTextAlignment(.center).lineLimit(2).minimumScaleFactor(0.5)
                    .padding(size * 0.08)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous).fill(Theme.chipGray))
            }
            if let roleTitle {
                Text(roleTitle)
                    .font(Theme.uiFont(max(9, size * 0.16), .bold)).foregroundStyle(Theme.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
                    .padding(.horizontal, size * 0.08).padding(.vertical, size * 0.03)
                    .background(Capsule().fill(roleTint))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
