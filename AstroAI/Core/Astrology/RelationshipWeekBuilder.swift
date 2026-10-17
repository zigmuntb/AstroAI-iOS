//
//  RelationshipWeekBuilder.swift
//  AstroAI
//

import Foundation

/// One exact contact between the sky and this pair during the coming week.
struct RelationshipBeat: Hashable, Identifiable {
    let id: String
    let glyph: String
    let title: String
    let detail: String
    let when: String
}

/// The week's sky on the relationship, plus one question to ask tonight.
struct RelationshipWeek: Hashable {
    let rangeLabel: String
    let beats: [RelationshipBeat]
    let question: String
}

enum RelationshipWeekBuilder {
    private static let transiters: [Planet] = [.moon, .sun, .mercury, .venus, .mars]
    private static let kinds: [AspectKind] = [.conjunction, .sextile, .square, .trine, .opposition]

    static func week(
        user: NatalChart,
        other: NatalChart,
        connection: Connection,
        options: ChartOptions,
        now: Date = .now
    ) -> RelationshipWeek {
        let end = now.addingTimeInterval(7 * 86_400)
        let name = connection.name
        var targets: [SkyTarget] = []
        for planet in [Planet.sun, .moon, .venus, .mars] {
            if let placement = other.placement(planet) {
                targets.append(SkyTarget(planet: planet, longitude: placement.longitude, phrase: "\(name)'s \(planet.name)"))
            }
        }
        for point in SynastryCalculator.compositeLongitudes(user: user, other: other)
        where [Planet.sun, .moon, .venus].contains(point.planet) {
            targets.append(SkyTarget(planet: point.planet, longitude: point.longitude, phrase: "the composite \(point.planet.name)"))
        }

        let peaks = SkyPeaks.find(
            transiters: transiters,
            targets: targets,
            kinds: kinds,
            from: now,
            until: end,
            options: options,
            step: 6 * 3_600
        )
        let chosen = Array(peaks.sorted { rank($0, name: name) < rank($1, name: name) }.prefix(3))
            .sorted { $0.when < $1.when }

        let beats = chosen.map { beat(for: $0) }
        let range = rangeLabel(from: now, to: end)
        if beats.isEmpty {
            return RelationshipWeek(
                rangeLabel: range,
                beats: [RelationshipBeat(
                    id: "quiet",
                    glyph: "☽",
                    title: "A quiet week",
                    detail: "No exact aspect falls on \(name) or the composite before the week ends. The portrait is the whole story.",
                    when: "This week"
                )],
                question: "Ask \(name) what feels easy between you, and what you have been leaving unsaid."
            )
        }
        return RelationshipWeek(
            rangeLabel: range,
            beats: beats,
            question: question(for: chosen.first, name: name)
        )
    }

    // MARK: - Copy

    /// Venus or Mars on the other person comes first, then the composite, then everything else.
    private static func rank(_ peak: SkyPeak, name: String) -> Int {
        let onThem = peak.target.phrase.hasPrefix(name)
        if onThem, peak.transiting == .venus || peak.transiting == .mars { return 0 }
        if peak.target.phrase.hasPrefix("the composite") { return 1 }
        if onThem { return 2 }
        return 3
    }

    private static func beat(for peak: SkyPeak) -> RelationshipBeat {
        let detail = switch peak.kind {
        case .square, .opposition:
            "The contact is exact. Leave room for both of you to want different things."
        case .conjunction:
            "The contact is exact. Let it be felt before you turn it into a plan."
        case .trine, .sextile:
            "The contact is exact. A small honesty is enough."
        }
        return RelationshipBeat(
            id: peak.id,
            glyph: peak.transiting.glyph,
            title: peak.title,
            detail: detail,
            when: peak.when.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        )
    }

    private static func question(for peak: SkyPeak?, name: String) -> String {
        switch peak?.kind {
        case .square, .opposition:
            "Ask \(name) where the pace between you feels too fast, before either of you decides for both."
        case .conjunction:
            "Ask \(name) what they want from this week, before you assume you already know."
        default:
            "Ask \(name) what feels easy between you, and what you want to protect."
        }
    }

    private static func rangeLabel(from start: Date, to end: Date) -> String {
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(start.formatted(style)) — \(end.formatted(style))"
    }
}
