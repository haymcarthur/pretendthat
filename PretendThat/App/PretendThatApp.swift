import SwiftUI
import NutmegCore

@main
struct PretendThatApp: App {
    /// iPhone version: grown-up text says "this iPhone" on a phone ("this iPad" stays the default).
    init() { DeviceWord.noun = PTDevice.noun }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
        }
    }
}
