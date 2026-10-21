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
        /// Composite leaning, once Sanctuary has overlaid this chart. Nil on the free tier.
        var harmony: String?
    }

    let suggestions = [
        Suggestion(icon: "heart", title: "Add a partner", text: "See how you get along in a relationship."),
        Suggestion(icon: "brain.head.profile", title: "Add someone you work with", text: "See how you focus and create together."),
        Suggestion(icon: "infinity", title: "Add a friend or family member", text: "See where things feel easy, and where they don't.")
    ]

    private(set) var rows: [Row] = []
    var isEmpty: Bool { rows.isEmpty }
    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var listNote: String {
        isPremium
            ? "Tap a person for the overlay and the composite chart. Long-press to remove."
            : "Tap a person to read how your charts meet. Long-press to remove."
    }

    @ObservationIgnored private let connections: ConnectionsServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private var harmonyByID: [UUID: String] = [:]
    @ObservationIgnored private var circleKey: String?

    init(connections: ConnectionsServicing, userService: UserServicing, router: MainRouting) {
        self.connections = connections
        self.userService = userService
        self.router = router
    }

    func load() async {
        let saved = connections.connections()
        let key = "\(isPremium)-\(saved.map(\.id.uuidString).joined(separator: ","))"
        reload()
        guard key != circleKey else { return }
        guard isPremium else {
            harmonyByID = [:]
            circleKey = key
            reload()
            return
        }
        var map: [UUID: String] = [:]
        for connection in saved {
            if let report = try? await connections.synastry(with: connection) {
                map[connection.id] = report.composite?.harmony ?? report.harmony
            }
        }
        harmonyByID = map
        circleKey = key
        reload()
    }

    func reload() {
        let premium = isPremium
        rows = connections.connections().map { connection in
            let sign = connection.sunSign
            return Row(
                connection: connection,
                name: connection.name,
                kinship: connection.kinship.relationLabel,
                kinshipIcon: connection.kinship.icon,
                signGlyph: sign.glyph,
                signName: "\(sign.name) Sun",
                harmony: premium ? harmonyByID[connection.id] : nil
            )
        }
    }

    func addConnection() {
        router?.addConnection()
    }

    func openPaywall() {
        router?.present(.paywall)
    }

    func open(_ row: Row) {
        router?.show(.synastry(row.connection))
    }

    func remove(_ row: Row) {
        connections.remove(row.connection)
        circleKey = nil
        reload()
    }
}
