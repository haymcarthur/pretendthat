import SwiftUI
import NutmegCore

@main
struct PretendThatApp: App {
    /// iPhone version: grown-up text says "this iPhone" on a phone ("this iPad" stays the default).
    init() {
        DeviceWord.noun = PTDevice.noun
        GrownUpFont.styleNavigationBars()   // round 39: Poppins titles (only grown-up screens have navigation bars)
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
        }
    }
}
