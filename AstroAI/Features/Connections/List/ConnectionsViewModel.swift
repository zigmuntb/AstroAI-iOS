//
//  ConnectionsViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ConnectionsViewModel {
    struct Suggestion: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let text: String
    }

    struct Row: Identifiable {
        var id: UUID { connection.id }
        let connection: Connection
        let name: String
        let kinship: String
        let kinshipIcon: String
        let signGlyph: String
        let signName: String
    }

    let suggestions = [
        Suggestion(icon: "heart", title: "Add a romantic partner", text: "See how you relate in love."),
        Suggestion(icon: "brain.head.profile", title: "Add a creative collaborator", text: "See how you work and create together."),
        Suggestion(icon: "infinity", title: "Add a close friend or family member", text: "See where you feel easy, and where you don't.")
    ]

    private(set) var rows: [Row] = []
    var isEmpty: Bool { rows.isEmpty }

    @ObservationIgnored private let connections: ConnectionsServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(connections: ConnectionsServicing, router: MainRouting) {
        self.connections = connections
        self.router = router
    }

    func load() async {
        reload()
    }

    func reload() {
        rows = connections.connections().map { connection in
            let sign = connection.sunSign
            return Row(
                connection: connection,
                name: connection.name,
                kinship: connection.kinship.relationLabel,
                kinshipIcon: connection.kinship.icon,
                signGlyph: sign.glyph,
                signName: "\(sign.name) Sun"
            )
        }
    }

    func addConnection() {
        router?.present(.addConnection)
    }

    func open(_ row: Row) {
        router?.show(.synastry(row.connection))
    }

    func remove(_ row: Row) {
        connections.remove(row.connection)
        reload()
    }
}
