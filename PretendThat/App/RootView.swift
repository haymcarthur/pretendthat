import SwiftUI

struct RootView: View {
    var body: some View {
        Text("PretendThat")
            .font(Theme.displayFont(Theme.TextSize.hero))
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
    }
}
