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
    /// JPEG of the signed-in user's photo. Nil when they have not chosen one.
    private(set) var userPhoto: Data?
    /// Full calculated charts, used to draw the bi-wheel.
    private(set) var userChart: [PlanetPlacement] = []
    private(set) var partnerChart: [PlanetPlacement] = []
    private(set) var aspects: [SynastryAspect] = []
    var hidesDegrees = false

    let userName: String
    let partnerName: String
    let relationLabel: String
    private(set) var user: Person
    private(set) var partner: Person

    @ObservationIgnored private let connection: Connection
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private var userSign: ZodiacSign?
    @ObservationIgnored private var partnerSign: ZodiacSign

    init(connection: Connection, astrology: AstrologyServicing, userService: UserServicing, router: MainRouting) {
        self.connection = connection
        self.astrology = astrology
        self.userService = userService
        self.router = router

        let name = userService.profile?.name.trimmingCharacters(in: .whitespaces) ?? ""
        userName = name.isEmpty ? "You" : name
        partnerName = connection.name
        relationLabel = connection.kinship.relationLabel
        userPhoto = userService.avatarData
        userSign = userService.profile.map { astrology.sunSign(for: $0.birth.date) }
        partnerSign = astrology.sunSign(for: connection.birth.date)

        user = Person(name: userName, placements: [])
        partner = Person(name: partnerName, placements: [])
    }

    var title: String { "\(userName) & \(partnerName)" }

    var userAvatar: AvatarContent {
        AvatarContent(imageData: userPhoto, name: userName)
    }

    /// Kinship they chose, plus the two Sun signs once both birth dates are known.
    var pairSubtitle: String {
        guard let userSign else { return relationLabel }
        return "\(relationLabel) · \(userSign.name) & \(partnerSign.name)"
    }

    var userGlyph: String { userSign?.glyph ?? "" }
    var partnerGlyph: String { partnerSign.glyph }

    var cardSubtitle: String {
        guard let userSign else { return relationLabel }
        return hidesDegrees
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
        userPhoto = userService.avatarData
        do {
            guard let profile = userService.profile else { throw UserServiceError.noProfile }
            let userChart = try await astrology.natalChart(for: profile.birth)
            let partnerChart = try await astrology.natalChart(for: connection.birth)
            if let sun = userChart.placement(.sun)?.sign { userSign = sun }
            if let sun = partnerChart.placement(.sun)?.sign { partnerSign = sun }
            self.userChart = userChart.placements
            self.partnerChart = partnerChart.placements
            aspects = SynastryCalculator.aspects(between: userChart, and: partnerChart)
            user = Person(name: userName, placements: Self.placements(from: userChart))
            partner = Person(name: partnerName, placements: Self.placements(from: partnerChart))
            report = SynastryCalculator.report(
                user: userChart,
                other: partnerChart,
                userName: userName,
                connection: connection
            )
        } catch {
            errorMessage = "The synastry matrix couldn't be calculated. Please try again."
        }
        isLoading = false
    }

    /// Picks up a photo chosen after this screen was opened.
    func refreshPhoto() {
        userPhoto = userService.avatarData
    }

    func toggleDegrees() {
        hidesDegrees.toggle()
    }

    func addConnection() {
        router?.addConnection()
    }

    func openPaywall() {
        router?.present(.paywall)
    }

    private static func placements(from chart: NatalChart) -> [Placement] {
        SynastryCalculator.placements(from: chart).map {
            Placement(glyph: $0.planet.glyph, label: $0.label, value: $0.value)
        }
    }
}
