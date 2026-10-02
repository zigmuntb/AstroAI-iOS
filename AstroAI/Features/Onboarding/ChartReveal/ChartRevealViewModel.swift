//
//  ChartRevealViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ChartRevealViewModel {
    struct KeyPlacement: Identifiable {
        var id: Planet { planet }
        let planet: Planet
        let glyph: String
        let label: String
        let location: String
        let sign: String
        let degree: String
        let quote: String
    }

    let chart: NatalChart
    var selectedPlanet: Planet? = .sun
    var showsExplanation = false

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, userService: UserServicing, router: OnboardingRouting) {
        self.draft = draft
        self.userService = userService
        self.router = router
        chart = draft.chart ?? MockData.natalChart
    }

    var calculatedFor: String {
        let place = draft.birthPlace?.title ?? "your birthplace"
        let date = draft.birthDate.formatted(.dateTime.month(.abbreviated).day().year())
        guard let time = draft.birthTime else {
            return "Calculated for \(place) • \(date), time unknown"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "hh:mm a"
        return "Calculated for \(place) • \(date) at \(formatter.string(from: time))"
    }

    var bigThree: [KeyPlacement] {
        chart.bigThree.map { placement in
            KeyPlacement(
                planet: placement.planet,
                glyph: placement.planet == .ascendant ? "ASC" : placement.planet.glyph,
                label: label(for: placement.planet),
                location: placement.planet == .ascendant ? "Eastern Horizon" : placement.house,
                sign: placement.sign.name,
                degree: placement.degree,
                quote: "\"\(placement.title)\""
            )
        }
    }

    var synthesis: String { "\"\(chart.synthesis)\"" }
    var accuracyText: String { "Full Chart Density: \(chart.accuracy)% Accurate" }

    /// e.g. "Fixed Water & Earth Balance", from the dominant modality and two leading elements.
    var archetype: String {
        let modality = chart.modalities.max { $0.percent < $1.percent }?.name
        let elements = chart.elements.sorted { $0.percent > $1.percent }.prefix(2).map(\.name)
        let parts = [modality, elements.joined(separator: " & ")].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Celestial Balance" : parts.joined(separator: " ") + " Balance"
    }

    func select(_ planet: Planet) {
        guard [Planet.sun, .moon, .ascendant].contains(planet) else { return }
        selectedPlanet = selectedPlanet == planet ? nil : planet
    }

    func toggleExplanation() {
        showsExplanation.toggle()
    }

    func explore() {
        userService.save(draft.makeProfile())
        router?.finish()
    }

    func back() {
        router?.back()
    }

    private func label(for planet: Planet) -> String {
        switch planet {
        case .sun: "Sun Sign"
        case .moon: "Moon Sign"
        default: "Ascendant"
        }
    }
}
