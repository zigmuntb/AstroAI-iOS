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
    private(set) var yearCard: ExploreYearCard?
    private(set) var monthCards: [ExploreCard] = []
    private(set) var weekCards: [ExploreCard] = []
    private(set) var cycleCards: [ExploreCard] = []
    /// Placements drawn on the blueprint card. Empty until the user's chart is calculated.
    private(set) var placements: [PlanetPlacement] = []
    /// "Scorpio Sun · Cancer Moon · Leo Rising", from the user's chart.
    private(set) var blueprintLine: String?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""

    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let polisher: any ExploreCopyPolishing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private var chartKey: ChartKey?
    @ObservationIgnored private var natalChart: NatalChart?
    @ObservationIgnored private var polishToken = 0
    @ObservationIgnored private var polishMemory: [String: [String: String]] = [:]
    @ObservationIgnored private var failedPolishKeys = Set<String>()
    @ObservationIgnored private var pendingDrafts: [ExploreDraft] = []
    @ObservationIgnored private var draftKey = ""

    init(
        astrology: AstrologyServicing,
        userService: UserServicing,
        router: MainRouting,
        polisher: any ExploreCopyPolishing = FoundationExplorePolisher()
    ) {
        self.astrology = astrology
        self.userService = userService
        self.router = router
        self.polisher = polisher
    }

    // MARK: - Display state

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredYear: ExploreYearCard? {
        guard let yearCard else { return nil }
        guard !query.isEmpty else { return yearCard }
        let fields = [yearCard.eyebrow, yearCard.headline, yearCard.summary, yearCard.caution, yearCard.detail, yearCard.trailing]
        return fields.contains { $0.localizedCaseInsensitiveContains(query) } ? yearCard : nil
    }

    var filteredMonth: [ExploreCard] { monthCards.filter(matches) }
    var filteredWeek: [ExploreCard] { weekCards.filter(matches) }

    var filteredCycles: [ExploreCard] {
        guard isPremium else { return [] }
        return cycleCards.filter(matches)
    }

    /// Free accounts see the promise, not the dates. Hidden while a search is active.
    var showsLockedForecasts: Bool {
        library != nil && !isPremium && query.isEmpty && !cycleCards.isEmpty
    }

    var hasNoResults: Bool {
        library != nil && !query.isEmpty && filteredWeek.isEmpty && filteredCycles.isEmpty && filteredMonth.isEmpty && filteredYear == nil
    }

    var showsMonth: Bool {
        timeline != nil && (query.isEmpty || !filteredMonth.isEmpty)
    }

    var showsYear: Bool {
        filteredYear != nil
    }

    var weekRange: String { library?.weekRange ?? "" }

    private func matches(_ card: ExploreCard) -> Bool {
        query.isEmpty || [card.headline, card.summary, card.detail, card.when].contains { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Actions

    func load() async {
        refreshPremium()
        guard !isLoading else { return }
        isLoading = true
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
        isLoading = false
        await polishIfNeeded()
    }

    func retry() async {
        failedPolishKeys.removeAll()
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
            natalChart = nil
            timeline = nil
            year = nil
            rebuildCards()
            return
        }
        let chart = NatalChartCalculator.chart(for: birth, options: astrology.chartOptions)
        natalChart = chart
        timeline = PersonalTransitForecast.timeline(chart: chart, options: astrology.chartOptions)
        year = AnnualProfection.reading(chart: chart, born: birth.date)
        rebuildCards()
    }

    private func rebuildCards() {
        let profile = userService.profile
        let focus = profile?.personal?.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasFocus = focus?.isEmpty == false
        let focusOnYear = hasFocus && year != nil
        yearCard = year.map { ExploreVoice.year($0, profile: profile, includeFocus: focusOnYear) }
        let events = timeline?.events ?? []
        monthCards = events.enumerated().map { index, event in
            ExploreVoice.month(event, profile: profile, includeFocus: !focusOnYear && index == 0 && hasFocus)
        }
        let week = library?.transits ?? []
        let focusOnWeek = hasFocus && !focusOnYear && events.isEmpty
        weekCards = week.enumerated().map { index, transit in
            ExploreVoice.sky(transit, profile: profile, chart: natalChart, includeFocus: focusOnWeek && index == 0)
        }
        cycleCards = (library?.lifeCycles ?? []).map {
            ExploreVoice.sky($0, profile: profile, chart: natalChart, includeFocus: false)
        }
        pendingDrafts = freshDrafts()
        draftKey = pendingDrafts.map { "\($0.id)|\($0.summary)" }.joined(separator: "\n")
        if let summaries = polishMemory[draftKey] {
            apply(summaries)
        }
    }

    private func freshDrafts() -> [ExploreDraft] {
        var drafts: [ExploreDraft] = []
        if let yearCard { drafts.append(yearCard.draft) }
        drafts.append(contentsOf: monthCards.map(\.draft))
        drafts.append(contentsOf: weekCards.map(\.draft))
        if isPremium {
            drafts.append(contentsOf: cycleCards.map(\.draft))
        }
        return Array(drafts.prefix(8))
    }

    // MARK: - Polish

    private func polishIfNeeded() async {
        let drafts = pendingDrafts
        let key = draftKey
        guard !drafts.isEmpty else { return }
        if polishMemory[key] != nil { return }
        if failedPolishKeys.contains(key) { return }
        polishToken += 1
        let token = polishToken
        let outcome = await polisher.polish(drafts)
        guard token == polishToken, key == draftKey else { return }
        switch outcome {
        case .unavailable:
            return
        case .unchanged:
            failedPolishKeys.insert(key)
        case .summaries(let summaries):
            polishMemory[key] = summaries
            apply(summaries)
        }
    }

    private func apply(_ summaries: [String: String]) {
        if let yearCard, let text = summaries[yearCard.id] {
            self.yearCard?.summary = text
        }
        for index in monthCards.indices {
            if let text = summaries[monthCards[index].id] {
                monthCards[index].summary = text
            }
        }
        for index in weekCards.indices {
            if let text = summaries[weekCards[index].id] {
                weekCards[index].summary = text
            }
        }
        for index in cycleCards.indices {
            if let text = summaries[cycleCards[index].id] {
                cycleCards[index].summary = text
            }
        }
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
