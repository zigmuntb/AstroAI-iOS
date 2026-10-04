//
//  SynastryViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class SynastryViewModel {
    struct Person {
        let name: String
        let role: String
        let portrait: String
        let placements: [Placement]
    }

    struct Placement: Identifiable {
        var id: String { label }
        let glyph: String
        let label: String
        let value: String
    }

    struct Question: Identifiable {
        var id: Int { number }
        let number: Int
        let text: String
        let prompt: String
    }

    private(set) var report: SynastryReport?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var hidesDegrees = false

    let userName: String
    let partnerName: String
    let relationLabel: String
    private(set) var user: Person
    private(set) var partner: Person

    @ObservationIgnored private let connection: Connection
    @ObservationIgnored private let connections: ConnectionsServicing
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private var userSign: ZodiacSign
    @ObservationIgnored private var partnerSign: ZodiacSign

    init(connection: Connection, connections: ConnectionsServicing, astrology: AstrologyServicing, userService: UserServicing, router: MainRouting) {
        self.connection = connection
        self.connections = connections
        self.astrology = astrology
        self.userService = userService
        self.router = router

        let name = userService.profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        userName = name.isEmpty ? "You" : name
        partnerName = connection.name
        relationLabel = connection.kinship.relationLabel
        userSign = userService.profile.map { astrology.sunSign(for: $0.birth.date) } ?? .scorpio
        partnerSign = astrology.sunSign(for: connection.birth.date)

        user = Person(name: userName, role: "Initiator", portrait: "SynastryElena", placements: [
            Placement(glyph: "☉", label: "SUN", value: userSign.name)
        ])
        partner = Person(name: connection.name, role: "Anchor", portrait: "SynastryJulian", placements: [
            Placement(glyph: "☉", label: "SUN", value: partnerSign.name)
        ])
    }

    var title: String { "\(userName) & \(partnerName)" }
    var userGlyph: String { userSign.glyph }
    var partnerGlyph: String { partnerSign.glyph }

    var cardSubtitle: String {
        hidesDegrees
            ? "\(userSign.element) & \(partnerSign.element) Resonance"
            : "\(userSign.name) Sun • \(partnerSign.name) Sun"
    }

    var questions: [Question] {
        (report?.questions ?? []).enumerated().map { index, text in
            Question(number: index + 1, text: text, prompt: "Prompted by the synastry of \(userName) and \(partnerName)")
        }
    }

    var shareText: String {
        let quote = report?.quote ?? ""
        return "\(title) — Celestial Synastry\n“\(quote)”\nExplore our cosmic architecture on AstroAI."
    }

    func load() async {
        guard report == nil else { return }
        isLoading = true
        errorMessage = nil
        do {
            if let birth = userService.profile?.birth {
                let userChart = try await astrology.natalChart(for: birth)
                let otherChart = try await astrology.natalChart(for: connection.birth)
                userSign = userChart.placement(.sun)?.sign ?? userSign
                partnerSign = otherChart.placement(.sun)?.sign ?? partnerSign
                user = Person(name: userName, role: "Initiator", portrait: user.portrait, placements: Self.placements(from: userChart))
                partner = Person(name: partnerName, role: "Anchor", portrait: partner.portrait, placements: Self.placements(from: otherChart))
            }
            report = try await connections.synastry(with: connection)
        } catch {
            errorMessage = "The synastry matrix couldn't be calculated. Please try again."
        }
        isLoading = false
    }

    func toggleDegrees() {
        hidesDegrees.toggle()
    }

    func addConnection() {
        router?.present(.addConnection)
    }

    private static func placements(from chart: NatalChart) -> [Placement] {
        SynastryCalculator.placements(from: chart).map {
            Placement(glyph: $0.planet.glyph, label: $0.label, value: $0.value)
        }
    }
}
