//
//  ChartPreparationViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ChartPreparationViewModel {
    enum StepState {
        case pending, active, done
    }

    struct Step: Identifiable {
        let id: Int
        let title: String
        var detail: String
        var state: StepState = .pending
    }

    /// A labelled body drawn on the orbit graphic.
    struct OrbitNode: Identifiable {
        var id: String { glyph }
        let glyph: String
        let label: String
    }

    private(set) var steps: [Step] = []
    private(set) var nodes: [OrbitNode] = []
    private(set) var errorMessage: String?

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private weak var router: OnboardingRouting?
    @ObservationIgnored private var isRunning = false
    @ObservationIgnored private let stepDelay: Duration = .milliseconds(1100)

    init(draft: OnboardingDraft, astrology: AstrologyServicing, router: OnboardingRouting) {
        self.draft = draft
        self.astrology = astrology
        self.router = router
        resetSteps()
    }

    var subtitle: String {
        "Synthesizing planetary coordinates across 12 dimensional houses for \(draft.birthDate.formatted(.dateTime.month(.wide).day().year()))."
    }

    /// 0...1, drives the chord animation of the orbit graphic.
    var progress: Double {
        let done = steps.filter { $0.state == .done }.count
        return Double(done) / Double(max(steps.count, 1))
    }

    func load() async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }
        errorMessage = nil
        resetSteps()

        let birth = draft.birthData
        let astrology = astrology
        let chartTask = Task { try await astrology.natalChart(for: birth) }

        do {
            setState(.active, at: 0)
            try await Task.sleep(for: stepDelay)
            setState(.done, at: 0)

            setState(.active, at: 1)
            try await Task.sleep(for: stepDelay)
            let chart = try await chartTask.value
            draft.chart = chart
            applyChart(chart)
            setState(.done, at: 1)

            setState(.active, at: 2)
            try await Task.sleep(for: stepDelay)
            setState(.done, at: 2)

            try await Task.sleep(for: .milliseconds(400))
            router?.next(from: .preparation)
        } catch is CancellationError {
            chartTask.cancel()
        } catch {
            chartTask.cancel()
            errorMessage = "We couldn't calculate your chart. Check your connection and try again."
        }
    }

    func retry() async {
        await load()
    }

    private func resetSteps() {
        let place = draft.birthPlace
        let placeDetail = place.map { "\($0.title) · \($0.coordinates)" } ?? "Birthplace unknown · solar horizon applied"
        let timeDetail = draft.birthTime.map { "Resolving horizon for \($0.formatted(date: .omitted, time: .shortened))" }
            ?? "Resolving horizon for solar noon"

        steps = [
            Step(id: 0, title: "Mapping topocentric coordinates", detail: placeDetail),
            Step(id: 1, title: "Calculating Placidus house cusps", detail: timeDetail),
            Step(id: 2, title: "Personalizing core synthesis", detail: "Weaving archetypal natal chords & transits...")
        ]

        let sun = astrology.sunSign(for: draft.birthDate)
        nodes = [OrbitNode(glyph: Planet.sun.glyph, label: sun.glyph)]
    }

    private func applyChart(_ chart: NatalChart) {
        if let ascendant = chart.placement(.ascendant) {
            steps[1].detail = "Ascendant locked at \(ascendant.degree) \(ascendant.sign.name)"
        }
        nodes = [Planet.sun, .moon, .mercury].compactMap { planet in
            chart.placement(planet).map { OrbitNode(glyph: planet.glyph, label: "\($0.degree.prefix { $0 != " " }) \($0.sign.glyph)") }
        }
    }

    private func setState(_ state: StepState, at index: Int) {
        guard steps.indices.contains(index) else { return }
        steps[index].state = state
    }
}
