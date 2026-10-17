//
//  ExploreViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ExploreViewModel {
    private struct ChartKey: Equatable {
        let birth: BirthData
        let options: ChartOptions
    }

    private(set) var library: ExploreLibrary?
    private(set) var isPremium = false
    private(set) var timeline: PersonalTransitTimeline?
    private(set) var year: YearAhead?
    /// Placements drawn on the blueprint card. Empty until the user's chart is calculated.
    private(set) var placements: [PlanetPlacement] = []
    /// "Scorpio Sun · Cancer Moon · Leo Rising", from the user's chart.
    private(set) var blueprintLine: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""

    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private var chartKey: ChartKey?

    init(astrology: AstrologyServicing, userService: UserServicing, router: MainRouting) {
        self.astrology = astrology
        self.userService = userService
        self.router = router
    }

    // MARK: - Display state

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var transits: [Transit] {
        guard let library else { return [] }
        return library.transits.filter { matches($0.title, $0.detail, $0.kind, $0.date) }
    }

    var lifeCycles: [Transit] {
        guard isPremium, let library else { return [] }
        return library.lifeCycles.filter { matches($0.title, $0.detail, $0.kind, $0.date) }
    }

    /// Free accounts see the promise, not the dates. Hidden while a search is active.
    var showsLockedForecasts: Bool {
        library != nil && !isPremium && query.isEmpty && !(library?.lifeCycles.isEmpty ?? true)
    }

    var hasNoResults: Bool {
        library != nil && !query.isEmpty && transits.isEmpty && lifeCycles.isEmpty && monthEvents.isEmpty && !showsYear
    }

    var monthEvents: [PersonalTransitEvent] {
        guard let timeline else { return [] }
        return timeline.events.filter { matches($0.title, $0.houseLine, $0.advice, $0.whenLabel) }
    }

    var showsMonth: Bool {
        timeline != nil && (query.isEmpty || !monthEvents.isEmpty)
    }

    var showsYear: Bool {
        guard let year else { return false }
        guard !query.isEmpty else { return true }
        return matches(year.eyebrow, year.title, year.lordLine, year.theme, year.refrain, year.turningLine ?? "", year.basis)
    }

    private func matches(_ fields: String...) -> Bool {
        query.isEmpty || fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Actions

    func load() async {
        refreshPremium()
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            library = try await astrology.library(for: userService.profile?.birth)
            errorMessage = nil
        } catch {
            if library == nil {
                errorMessage = error.localizedDescription
            }
        }
        await refreshChart()
        refreshForecasts()
    }

    func retry() async {
        await load()
    }

    func openBlueprint() {
        router?.show(.natalBlueprint)
    }

    func openProfile() {
        router?.select(.profile)
    }

    func openPaywall() {
        router?.present(.paywall)
    }

    func refreshPremium() {
        isPremium = userService.profile?.isPremium ?? false
    }

    private func refreshChart() async {
        guard let birth = userService.profile?.birth else {
            placements = []
            blueprintLine = nil
            chartKey = nil
            return
        }
        let key = ChartKey(birth: birth, options: astrology.chartOptions)
        guard key != chartKey else { return }
        do {
            let chart = try await astrology.natalChart(for: birth)
            chartKey = key
            placements = chart.placements
            let line = Self.blueprintLine(for: chart)
            blueprintLine = line.isEmpty ? nil : line
        } catch {
            // Keep a chart we already drew. Never fall back to the sample wheel.
            if chartKey == nil {
                placements = []
                blueprintLine = nil
            }
        }
    }

    private func refreshForecasts() {
        guard let birth = userService.profile?.birth else {
            timeline = nil
            year = nil
            return
        }
        let chart = NatalChartCalculator.chart(for: birth, options: astrology.chartOptions)
        timeline = PersonalTransitForecast.timeline(chart: chart, options: astrology.chartOptions)
        year = AnnualProfection.reading(chart: chart, born: birth.date)
    }

    private static func blueprintLine(for chart: NatalChart) -> String {
        chart.bigThree.map { placement in
            let role = switch placement.planet {
            case .sun: "Sun"
            case .moon: "Moon"
            case .ascendant: "Rising"
            default: placement.planet.name
            }
            return "\(placement.sign.name) \(role)"
        }.joined(separator: " · ")
    }
}
