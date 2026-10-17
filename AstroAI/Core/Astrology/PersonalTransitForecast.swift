//
//  PersonalTransitForecast.swift
//  AstroAI
//

import Foundation

/// One exact hit of a transiting planet on the natal chart.
struct PersonalTransitEvent: Hashable, Identifiable {
    let id: String
    let glyph: String
    /// `Planet.rawValue`, so the month can keep slow planets when it has to choose.
    let glyphPlanet: String
    let when: Date
    let whenLabel: String
    let title: String
    let houseLine: String
    let advice: String
}

/// The coming month of exact transits to this chart, earliest first.
struct PersonalTransitTimeline: Hashable {
    let rangeLabel: String
    let events: [PersonalTransitEvent]
}

/// Exact transits to the natal chart over the next month, and the near ones used for alerts.
enum PersonalTransitForecast {
    private static let transiters: [Planet] = [.sun, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
    private static let natalTargets: [Planet] = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .ascendant]
    private static let majors: Set<Planet> = [.jupiter, .saturn, .uranus, .neptune, .pluto]
    private static let kinds: [AspectKind] = [.conjunction, .sextile, .square, .trine, .opposition]
    private static let exactKinds: [AspectKind] = [.conjunction, .trine, .opposition]

    static func timeline(chart: NatalChart, options: ChartOptions, now: Date = .now) -> PersonalTransitTimeline {
        let end = now.addingTimeInterval(30 * 86_400)
        let events = collect(
            chart: chart,
            options: options,
            kinds: kinds,
            from: now,
            until: end,
            step: 12 * 3_600
        )
        return PersonalTransitTimeline(rangeLabel: rangeLabel(from: now, to: end), events: select(events))
    }

    /// Conjunctions, trines and oppositions that perfect before `until`. The Moon is left out: it is exact every day.
    static func exactPeaks(chart: NatalChart, options: ChartOptions, from: Date, until: Date) -> [PersonalTransitEvent] {
        Array(collect(
            chart: chart,
            options: options,
            kinds: exactKinds,
            from: from,
            until: until,
            step: 6 * 3_600
        ).prefix(8))
    }

    // MARK: - Selection

    /// Keeps the slow planets, then fills the month with the soonest personal-planet hits.
    private static func select(_ events: [PersonalTransitEvent]) -> [PersonalTransitEvent] {
        let major = events.filter { majors.contains(planet(in: $0)) }
        let minor = events.filter { !majors.contains(planet(in: $0)) }
        var chosen = Array(major.prefix(8))
        chosen.append(contentsOf: minor.prefix(max(0, 12 - chosen.count)))
        return chosen.sorted { $0.when < $1.when }
    }

    private static func planet(in event: PersonalTransitEvent) -> Planet {
        Planet(rawValue: event.glyphPlanet) ?? .sun
    }

    private static func collect(
        chart: NatalChart,
        options: ChartOptions,
        kinds: [AspectKind],
        from: Date,
        until: Date,
        step: TimeInterval
    ) -> [PersonalTransitEvent] {
        let targets = chart.placements.filter { natalTargets.contains($0.planet) }.map { placement in
            SkyTarget(planet: placement.planet, longitude: placement.longitude, phrase: "your \(placement.planet.name)")
        }
        let peaks = SkyPeaks.find(
            transiters: transiters,
            targets: targets,
            kinds: kinds,
            from: from,
            until: until,
            options: options,
            step: step
        )
        return peaks.map { event(for: $0, chart: chart, options: options) }
    }

    private static func event(for peak: SkyPeak, chart: NatalChart, options: ChartOptions) -> PersonalTransitEvent {
        let longitude = SkyPeaks.longitude(of: peak.transiting, at: peak.when, options: options)
        let house = chart.house(for: longitude)
        return PersonalTransitEvent(
            id: peak.id,
            glyph: peak.transiting.glyph,
            glyphPlanet: peak.transiting.rawValue,
            when: peak.when,
            whenLabel: stamp(peak.when),
            title: peak.title,
            houseLine: "Exact · your \(AstrologyLexicon.ordinal(house)) house of \(AstrologyLexicon.houseTheme(house))",
            advice: advice(peak.kind)
        )
    }

    private static func advice(_ kind: AspectKind) -> String {
        switch kind {
        case .conjunction: "Let this theme take the day. Don't split your attention."
        case .square: "Name the friction before you decide. Don't push through it."
        case .opposition: "Hold both sides. Don't pick a winner today."
        case .trine: "Use the ease, and don't spend it all at once."
        case .sextile: "A small yes is enough. Don't force a bigger one."
        }
    }

    private static func rangeLabel(from start: Date, to end: Date) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(style)) — \(end.formatted(style))"
    }

    private static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
    }
}
