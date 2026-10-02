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
    let user: Person
    let partner: Person

    @ObservationIgnored private let connection: Connection
    @ObservationIgnored private let connections: ConnectionsServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private let userSign: ZodiacSign
    @ObservationIgnored private let partnerSign: ZodiacSign

    init(connection: Connection, connections: ConnectionsServicing, userService: UserServicing, router: MainRouting) {
        self.connection = connection
        self.connections = connections
        self.userService = userService
        self.router = router

        let name = userService.profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        userName = name.isEmpty ? "You" : name
        partnerName = connection.name
        relationLabel = connection.kinship.relationLabel
        userSign = userService.profile.map { ZodiacSign.sunSign(on: $0.birth.date) } ?? .scorpio
        partnerSign = connection.sunSign

        // Moon / Venus / Mars degrees are static until the synastry backend provides them.
        user = Person(name: userName, role: "Initiator", portrait: "SynastryElena", placements: [
            Placement(glyph: "☉", label: "SUN", value: "\(userSign.name) 18°"),
            Placement(glyph: "☽", label: "MOON", value: "Taurus 04°"),
            Placement(glyph: "♀", label: "VENUS", value: "Virgo 11°")
        ])
        partner = Person(name: connection.name, role: "Anchor", portrait: "SynastryJulian", placements: [
            Placement(glyph: "☉", label: "SUN", value: "\(partnerSign.name) 22°"),
            Placement(glyph: "☽", label: "MOON", value: "Capricorn 29°"),
            Placement(glyph: "♂", label: "MARS", value: "Taurus 16°")
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
        let prompts = ["Prompted by Capricorn Moon 4th House cusp", "Prompted by Scorpio Sun in natal opposition to Taurus"]
        return (report?.questions ?? []).enumerated().map { index, text in
            Question(number: index + 1, text: text, prompt: prompts[safe: index] ?? "Prompted by the current lunar cycle")
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
}
