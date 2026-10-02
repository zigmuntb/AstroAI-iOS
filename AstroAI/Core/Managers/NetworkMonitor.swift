//
//  NetworkMonitor.swift
//  AstroAI
//

import Foundation
import Network
import Observation

protocol NetworkMonitoring: AnyObject {
    var isConnected: Bool { get }
}

/// Publishes connectivity changes so screens can switch to the offline state.
@Observable
final class NetworkMonitor: NetworkMonitoring {
    private(set) var isConnected = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "NetworkMonitor"))
    }

    deinit {
        monitor.cancel()
    }
}
