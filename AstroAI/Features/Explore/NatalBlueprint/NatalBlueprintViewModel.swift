//
//  NatalBlueprintViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class NatalBlueprintViewModel {
    enum Mode: String, CaseIterable, Identifiable {
        case quick = "In short"
        case deep = "The details"

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

    struct HouseRule: Identifiable {
        var id: Int { house }
        let house: Int
        let label: String
        let cusp: String
        let ruler: String
    }

    struct DignityLine: Identifiable {
        var id: Planet { planet }
        let planet: Planet
        let status: String
        let text: String
    }

    struct NodalPath {
        let axis: String
        let north: String
        let south: String
        let text: String
    }

    private(set) var chart: NatalChart?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var mode: Mode = .quick
    var selectedPlanet: Planet?
    var isInspectorPresented = false
    private(set) var expanded: Set<Planet> = []

    let eyebrow = "Birth chart · calculated on this phone"
    var houseSystem: String { chart?.houseSystem ?? "Whole Sign Houses" }

    var outOfBounds: Declination {
        guard let chart, let declination = chart.moonDeclination else {
            return Declination(label: "Lunar Declination", value: "—", caption: "")
        }
        let value = "Moon \(NatalChartCalculator.formatDegrees(abs(declination))) \(declination >= 0 ? "N" : "S")"
        guard abs(declination) > chart.obliquity else {
            return Declination(
                label: "Lunar Declination",
                value: value,
                caption: "Your Moon stays inside the Sun's range (±\(NatalChartCalculator.formatDegrees(chart.obliquity))). Your feelings tend to follow rhythms other people recognize."
            )
        }
        return Declination(
            label: "Out-of-Bounds Status",
            value: value + " (OOB)",
            caption: "Your Moon goes outside the Sun's range (±\(NatalChartCalculator.formatDegrees(chart.obliquity))). Your feelings often follow your own rules, and that can look unusual to other people."
        )
    }

    var rulers: [Declination] {
        guard let chart else { return [] }
        var result: [Declination] = []
        if let rising = chart.placement(.ascendant) ?? chart.placement(.sun),
           let ruler = chart.placement(rising.sign.ruler) {
            if chart.hasLocation, chart.isTimeKnown, let house = ruler.houseNumber {
                result.append(Declination(
                    label: "A guiding planet",
                    value: "\(ruler.planet.name) in \(ruler.sign.name)",
                    caption: "This part of the chart points toward \(AstrologyLexicon.houseTheme(house)). Astrologers call the planet that leads it the chart ruler."
                ))
            } else {
                result.append(Declination(
                    label: "A guiding planet",
                    value: "\(ruler.planet.name) in \(ruler.sign.name)",
                    caption: "\(ruler.planet.name) is associated with \(ruler.planet.meaning). An exact birth time and place are needed before this can name a house."
                ))
            }
        }
        if let aspect = chart.aspects.first {
            result.append(Declination(
                label: "Closest Aspect",
                value: "\(aspect.first.glyph) \(aspect.kind.glyph) \(aspect.second.glyph) \(NatalChartCalculator.formatDegrees(aspect.orb))",
                caption: "Your \(aspect.first.meaning) and your \(aspect.second.meaning). \(AstrologyLexicon.aspectSentence(aspect.kind, aspect.first, aspect.second))"
            ))
        }
        return result
    }

    /// Traditional ruler of each house cusp, and the house that ruler occupies.
    var houseRules: [HouseRule] {
        guard let chart else { return [] }
        return (1...12).map { house in
            let longitude = cuspLongitude(house, chart: chart)
            let sign = ZodiacSign.containing(longitude)
            let ruler = sign.ruler
            let degree = NatalChartCalculator.formatDegrees(longitude.truncatingRemainder(dividingBy: 30))
            let sits: String
            if let placement = chart.placement(ruler) {
                sits = "\(ruler.name) sits in \(placement.sign.name), \(placement.house)"
            } else {
                sits = "Ruled by \(ruler.name)"
            }
            return HouseRule(
                house: house,
                label: "House \(AstrologyLexicon.roman(house))",
                cusp: "\(degree) \(sign.glyph) \(sign.name)",
                ruler: sits
            )
        }
    }

    var houseNote: String {
        guard let chart else { return "" }
        if !chart.hasLocation {
            return "These areas are estimated from your Sun sign. They are not exact houses, because a birthplace is needed for that. The daily reading does not treat them as certain."
        }
        if !chart.isTimeKnown {
            return "These areas can shift until the birth time is exact. The daily reading does not treat them as certain."
        }
        return "Each area of life is led by the planet associated with the sign on its edge. Astrologers call these areas houses."
    }

    var dignities: [DignityLine] {
        let classical: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]
        guard let chart else { return [] }
        return classical.compactMap { planet in
            guard let placement = chart.placement(planet) else { return nil }
            let status = AstrologyLexicon.dignityStatus(of: planet, in: placement.sign)
            return DignityLine(planet: planet, status: status.name, text: status.text)
        }
    }

    var nodalPath: NodalPath? {
        guard let chart, let north = chart.placement(.northNode) else { return nil }
        let southSign = north.sign.opposite
        guard chart.hasLocation, chart.isTimeKnown, let house = north.houseNumber else {
            return NodalPath(
                axis: "\(north.sign.name) / \(southSign.name)",
                north: "\(north.degree) \(north.sign.glyph) \(north.sign.name)",
                south: "\(north.degree) \(southSign.glyph) \(southSign.name)",
                text: "What already feels familiar is a \(southSign.qualities) style. A direction of growth is the \(north.sign.qualities) side of \(north.sign.name). Houses need an exact birth time and place, so they are left out. This is a direction, not a prediction."
            )
        }
        let southHouse = (house + 5) % 12 + 1
        let southTheme = AstrologyLexicon.houseTheme(southHouse)
        let northTheme = AstrologyLexicon.houseTheme(house)
        return NodalPath(
            axis: "\(north.sign.name) / \(southSign.name)",
            north: "\(north.degree) \(north.sign.glyph) · \(northTheme)",
            south: "\(north.degree) \(southSign.glyph) · \(southTheme)",
            text: "What already feels familiar is \(southTheme). A direction of growth is \(northTheme). Astrologers call these the South Node and the North Node. This is a direction, not a prediction."
        )
    }

    var inspectorNote: String {
        var note = "Positions are calculated on this phone. The house system in settings is \(houseSystem)."
        if let chart, !chart.hasLocation {
            note += " No birthplace was given, so there is no rising sign, and house areas are not treated as exact."
        } else if let chart, !chart.isTimeKnown {
            note += " The birth time is approximate, so the rising sign and house areas may shift."
        }
        return note
    }

    let disclaimer = "This is a way of reading patterns. It is not a forecast, and it does not decide what you do."

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

    func openPaywall() {
        router?.present(.paywall)
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
        case .northNode: "North Node"
        default: planet.name
        }
    }

    private func cuspLongitude(_ house: Int, chart: NatalChart) -> Double {
        if chart.cusps.count == 12 {
            return chart.cusps[house - 1]
        }
        let sun = chart.placement(.sun)?.longitude ?? 0
        let origin = Double(Int(sun / 30) * 30)
        return (origin + Double(house - 1) * 30).truncatingRemainder(dividingBy: 360)
    }

    private func opposite(_ sign: ZodiacSign) -> ZodiacSign {
        let all = ZodiacSign.allCases
        let index = all.firstIndex(of: sign) ?? 0
        return all[(index + 6) % all.count]
    }
}
