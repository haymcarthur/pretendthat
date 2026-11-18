import SwiftUI
import NutmegCore

@main
struct PretendThatApp: App {
    /// iPhone version: grown-up text says "this iPhone" on a phone ("this iPad" stays the default).
    init() {
        DeviceWord.noun = PTDevice.noun
        GrownUpFont.styleNavigationBars()   // round 39: Poppins titles (only grown-up screens have navigation bars)
        #if DEBUG
        // Round 45: render every printable type and layout with fixture art (no AI), then quit.
        if KitPageGallery.requested { DispatchQueue.main.async { KitPageGallery.renderAll(); exit(0) } }
        #endif
    }

    var body: some SwiftUI.Scene {
        WindowGroup {
            RootView()
        }
    }
}
