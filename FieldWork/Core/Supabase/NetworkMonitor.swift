import Foundation
import Network

// @unchecked Sendable: its state is only changed on the main queue (see init).
@Observable
final class NetworkMonitor: @unchecked Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    var isConnected = true
    var connectionType: NWInterface.InterfaceType?

    /// Called on the main thread each time the connection comes back after being offline.
    /// AppState uses it to send the work saved while offline (the sync queue).
    @ObservationIgnored var onReconnect: (() -> Void)?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                guard let self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied
                self.connectionType = path.availableInterfaces.first?.type
                if !wasConnected && self.isConnected {
                    NSLog("[FieldWork] Network is back, sending queued changes")
                    self.onReconnect?()
                }
            }
        }
        monitor.start(queue: queue)
    }

    deinit {
        monitor.cancel()
    }
}
