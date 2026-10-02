//
//  ConnectionsService.swift
//  AstroAI
//

import Foundation

protocol ConnectionsServicing {
    func connections() -> [Connection]
    func add(_ connection: Connection)
    func remove(_ connection: Connection)
    func synastry(with connection: Connection) async throws -> SynastryReport
}

/// Saved people and synastry reports. Will move to a Supabase `connections` table.
final class ConnectionsService: ConnectionsServicing {
    private let storage: StorageManaging

    init(storage: StorageManaging) {
        self.storage = storage
    }

    func connections() -> [Connection] {
        storage.load([Connection].self, for: .connections) ?? []
    }

    func add(_ connection: Connection) {
        storage.save(connections() + [connection], for: .connections)
    }

    func remove(_ connection: Connection) {
        storage.save(connections().filter { $0.id != connection.id }, for: .connections)
    }

    func synastry(with connection: Connection) async throws -> SynastryReport {
        try await Task.sleep(for: .milliseconds(400))
        return MockData.synastry
    }
}
