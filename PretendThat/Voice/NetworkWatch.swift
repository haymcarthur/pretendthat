import Foundation
import Network
import Observation

/// Round D3b: is the iPad online? (Haylee's answer 1: offline on a replay, a line Nutmeg never said pauses the game with
/// a "please connect to Wi-Fi" note until the connection is back.) `NWPathMonitor`, nothing sent anywhere.
/// DEBUG: `-PTOffline` starts with the network "off" in the app, and the live driver's `#offline` / `#online` switch it
/// (the app then behaves as if the connection were lost: the voice session drops and can't reconnect).
@Observable @MainActor
final class NetworkWatch {
    private(set) var pathOnline = true
    #if DEBUG
    var debugOffline = ProcessInfo.processInfo.arguments.contains("-PTOffline") { didSet { if oldValue != debugOffline { report() } } }
    #else
    let debugOffline = false
    #endif
    var online: Bool { pathOnline && !debugOffline }
    @ObservationIgnored var onChange: (@MainActor (Bool) -> Void)?
    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private var last: Bool?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let ok = path.status == .satisfied
            Task { @MainActor in
                guard let self else { return }
                self.pathOnline = ok
                self.report()
            }
        }
        monitor.start(queue: DispatchQueue(label: "pt.network"))
    }

    private func report() {
        let now = online
        guard last != now else { return }
        last = now
        onChange?(now)
    }
}
