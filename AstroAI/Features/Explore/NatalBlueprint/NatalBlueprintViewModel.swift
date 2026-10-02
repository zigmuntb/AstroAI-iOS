//
//  NatalBlueprintViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class NatalBlueprintViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case quick = "Quick Overview"
        case deep = "Explore Deeply"

        var id: String { rawValue }
    }

    struct Coordinate: Identifiable {
        var id: Planet { planet }
        let planet: Planet
        let title: String
        let value: String
    }

    struct Declination: Identifiable {
        var id: String { label }
        let label: String
        let value: String
        let caption: String
    }

    private(set) var chart: NatalChart?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var mode: Mode = .quick
    var selectedPlanet: Planet?
    var isInspectorPresented = false
    private(set) var expanded: Set<Planet> = []

    let eyebrow = "Natal Synthesis • Ephemeris 4.2"
    let houseSystem = "Placidus Houses"
    let outOfBounds = Declination(
        label: "Out-of-Bounds Status",
        value: "Moon 24° 12' N (OOB)",
        caption: "Your Moon operates beyond the standard ecliptic limit of the Sun (±23°27'). In traditional and modern syncretic astrology, Out-of-Bounds placements signify an innate independence in subjective experience—you intuitively craft your own rules regarding emotional sovereignty."
    )
    let rulers = [
        Declination(label: "Ascendant Ruler", value: "Sun in IV", caption: "Life directed inward"),
        Declination(label: "Almuten Figuris", value: "Venus at 29°", caption: "Harmonic arbiter")
    ]
    let inspectorNote = "Declinations calculate Moon at +24°12'11\", exceeding ecliptic bounds. House system: Placidus standard with true geocentric oblate spheroidal curvature."
    let disclaimer = "AstroAI treats your natal chart not as an unalterable fate or deterministic script, but as a symbolic mirror and reflective language. It highlights psychological predispositions, archetypal tensions, and seasonal cycles. Your consciousness, deliberate choices, and lived agency remain sovereign in determining who you become."

    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(astrology: AstrologyServicing, userService: UserServicing, router: MainRouting) {
        self.astrology = astrology
        self.userService = userService
        self.router = router
    }

    // MARK: - Display state

    private var birth: BirthData {
        userService.profile?.birth ?? BirthData(
            date: DateComponents(calendar: .init(identifier: .gregorian), year: 1994, month: 11, day: 24).date ?? .now,
            time: DateComponents(calendar: .init(identifier: .gregorian), year: 1994, month: 11, day: 24, hour: 3, minute: 14).date,
            place: MockData.places.first
        )
    }

    var birthLine: String {
        let date = birth.date.formatted(.dateTime.month(.abbreviated).day().year())
        guard let time = birth.time else { return date }
        return "\(date) • \(time.formatted(date: .omitted, time: .shortened))"
    }

    var dominantElement: String {
        guard let top = chart?.elements.max(by: { $0.percent < $1.percent }) else { return "" }
        return "\(top.name) Dominant"
    }

    var dominantModality: String {
        guard let top = chart?.modalities.max(by: { $0.percent < $1.percent }) else { return "" }
        return "\(top.percent)% \(top.name) Anchor"
    }

    var coordinates: [Coordinate] {
        (chart?.placements ?? []).map { placement in
            Coordinate(
                planet: placement.planet,
                title: "\(placement.planet.glyph) \(inspectorName(placement.planet))",
                value: "\(placement.degree) \(placement.sign.glyph) • \(placement.house)"
            )
        }
    }

    func headline(for placement: PlanetPlacement) -> String {
        switch placement.planet {
        case .northNode: "\(placement.planet.name) (\(placement.sign.name) / \(opposite(placement.sign).name))"
        default: "\(placement.planet.name) in \(placement.sign.name)"
        }
    }

    func position(for placement: PlanetPlacement) -> String {
        "\(placement.house) • \(placement.degree)"
    }

    func houseLine(for placement: PlanetPlacement) -> String {
        "\(placement.house) • \(placement.title)"
    }

    func isExpanded(_ planet: Planet) -> Bool {
        expanded.contains(planet)
    }

    // MARK: - Actions

    func load() async {
        guard chart == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            chart = try await astrology.natalChart(for: birth)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func retry() async {
        chart = nil
        await load()
    }

    func select(_ planet: Planet) {
        selectedPlanet = planet
        isInspectorPresented = true
    }

    func inspectDegrees() {
        isInspectorPresented = true
    }

    func closeInspector() {
        isInspectorPresented = false
        selectedPlanet = nil
    }

    func toggle(_ planet: Planet) {
        if expanded.contains(planet) {
            expanded.remove(planet)
        } else {
            expanded.insert(planet)
        }
    }

    // MARK: - Helpers

    private func inspectorName(_ planet: Planet) -> String {
        switch planet {
        case .ascendant: "Ascendant"
        case .northNode: "True Node"
        default: planet.name
        }
    }

    private func opposite(_ sign: ZodiacSign) -> ZodiacSign {
        let all = ZodiacSign.allCases
        let index = all.firstIndex(of: sign) ?? 0
        return all[(index + 6) % all.count]
    }
}
