import Foundation

/// iPhone version (2026-11-17): the device word in grown-up text ("this iPad" / "this iPhone"). The app sets it once at
/// launch from the device; it defaults to "iPad", so the iPad's words (and the tests) are unchanged.
public enum DeviceWord {
    nonisolated(unsafe) public static var noun = "iPad"
}
