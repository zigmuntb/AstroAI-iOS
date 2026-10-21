//
//  OracleContext.swift
//  AstroAI
//

import Foundation

/// Background knowledge about the user that the Oracle model receives with its instructions.
/// Kept compact: the on-device model has a small context window.
struct OracleContext {
    let profile: UserProfile?
    let chart: NatalChart?
    let sky: SkySnapshot
    let connections: [Connection]
    /// Precomputed synastry notes for the closest people, in `connections` order.
    var peopleNotes: [String] = []
    let memory: [OracleMemoryEntry]
    var hasJournal = false
    let date: Date

    private static let maxConnections = 5
    private static let maxTransits = 6
    private static let maxMemories = 6
    private static let locale = Locale(identifier: "en_US_POSIX")

    var prompt: String {
        var sections = [skyDescription]
        guard let profile else { return sections.joined(separator: "\n\n") }

        sections.append(userDescription(profile))
        if let personal = profile.personal, !personal.isEmpty {
            sections.append(personalDescription(personal))
        }
        if let chart {
            sections.append(chartDescription(chart))
        }
        if let transits = transitsDescription {
            sections.append(transits)
        }
        if let memories = memoryDescription {
            sections.append(memories)
        }
        return sections.joined(separator: "\n\n")
    }

    /// When to call each tool. The small model rarely calls tools unless told exactly when.
    var toolRules: String {
        var rules = ["For any date other than today, first call getSkyOnDate with that date; never reuse today's transits for another day."]
        if connections.count > peopleNotes.count {
            rules.append("Use only the placements listed for important people. For anyone else they saved, first call getPersonChart; never invent placements.")
        } else if !connections.isEmpty {
            rules.append("Use only the placements listed for important people; never invent them.")
        }
        if hasJournal {
            rules.append("When the user mentions their journal, past feelings or what they wrote, first call searchJournal.")
        }
        return rules.joined(separator: "\n")
    }

    // MARK: - Sections

    private var skyDescription: String {
        let today = Self.format(date, .dateTime.weekday(.wide).day().month(.wide).year())
        var lines = ["Today is \(today). Moon phase: \(sky.moonPhase.name), \(sky.moonPhase.illumination)% illuminated."]
        let planets = sky.positions
            .filter { $0.planet != .northNode }
            .map { position -> String in
                var text = "\(position.planet.name) in \(position.sign.name)"
                if position.isRetrograde { text += " (retrograde)" }
                if chart != nil, let house = sky.houses[position.planet] {
                    text += ", their \(AstrologyLexicon.ordinal(house)) house"
                }
                return text
            }
        lines.append("Current sky: " + planets.joined(separator: "; ") + ".")
        return lines.joined(separator: "\n")
    }

    private func userDescription(_ profile: UserProfile) -> String {
        var lines = ["The user's name is \(profile.name).", birthDescription(profile.birth)]
        if !profile.interests.isEmpty {
            lines.append("Interested in: " + profile.interests.map(\.title).sorted().joined(separator: ", ") + ".")
        }
        if !profile.intentions.isEmpty {
            lines.append("What they hope to get from AstroAI: " + profile.intentions.map(\.title).sorted().joined(separator: ", ") + ".")
        }
        let others = connections.dropFirst(peopleNotes.count).prefix(Self.maxConnections - peopleNotes.count)
        if !peopleNotes.isEmpty {
            lines.append("Important people in their life:\n" + peopleNotes.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !others.isEmpty {
            let people = others.map {
                "\($0.name) (\($0.kinship.title), \(ZodiacSign.sunSign(on: $0.birth.date).name) Sun)"
            }
            lines.append((peopleNotes.isEmpty ? "Important people in their life: " : "Also: ") + people.joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    private func personalDescription(_ personal: PersonalContext) -> String {
        var lines: [String] = []
        if let pronouns = personal.pronouns {
            lines.append("Pronouns: \(pronouns.title.lowercased()).")
        }
        if let relationship = personal.relationship {
            lines.append("Relationship status: \(relationship.title.lowercased()).")
        }
        if let stage = personal.lifeStage {
            lines.append("Life stage: \(stage.title.lowercased()).")
        }
        if let focus = personal.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines), !focus.isEmpty {
            lines.append("What is on their mind lately, in their own words: \"\(focus)\"")
        }
        return lines.joined(separator: "\n")
    }

    private func chartDescription(_ chart: NatalChart) -> String {
        let placements = chart.isTimeKnown
            ? chart.placements
            : chart.placements.filter { $0.planet != .moon && $0.planet != .ascendant }
        var lines = ["Natal chart (\(chart.houseSystem)): " + placements.map(Self.describe).joined(separator: "; ") + "."]
        if !chart.isTimeKnown {
            lines.append("Birth time is missing or approximate. The natal Moon sign and rising sign are omitted. Do not invent them. Today's Moon in the sky is still usable.")
        }
        if let element = chart.elements.max(by: { $0.percent < $1.percent }),
           let modality = chart.modalities.max(by: { $0.percent < $1.percent }) {
            lines.append("Dominant element: \(element.name). Dominant modality: \(modality.name).")
        }
        let aspects = chart.aspects
            .filter { chart.isTimeKnown || ($0.first != .moon && $0.second != .moon && $0.first != .ascendant && $0.second != .ascendant) }
            .sorted { $0.orb < $1.orb }
            .prefix(5)
            .map { "\($0.first.name) \($0.kind.name.lowercased()) \($0.second.name)" }
        if !aspects.isEmpty {
            lines.append("Tightest natal aspects: " + aspects.joined(separator: ", ") + ".")
        }
        if !chart.hasLocation {
            lines.append("Birthplace is missing. Do not mention houses or a rising sign.")
        } else if !chart.isTimeKnown {
            lines.append("Birth time is missing or approximate. Do not state houses, the rising sign, or a natal Moon sign.")
        }
        if chart.hasLocation, chart.isTimeKnown {
            lines.append(cuspsDescription(chart))
        } else {
            lines.append("House cusps: unavailable. Do not mention houses.")
        }
        return lines.joined(separator: "\n")
    }

    /// Exact cusp degrees, so answers can name the house boundary and not only the house number.
    private func cuspsDescription(_ chart: NatalChart) -> String {
        guard chart.cusps.count == 12 else {
            return "House cusps: none. Houses are counted from the Sun sign, so there is no degree on the cusps."
        }
        let cusps = chart.cusps.enumerated().map { index, longitude in
            let sign = ZodiacSign.containing(longitude)
            let degree = NatalChartCalculator.formatDegrees(longitude.truncatingRemainder(dividingBy: 30))
            return "\(AstrologyLexicon.roman(index + 1)) \(degree) \(sign.name)"
        }
        return "House cusps: " + cusps.joined(separator: "; ") + "."
    }

    private var transitsDescription: String? {
        let transits = sky.transits.filter { transit in
            guard let chart else { return false }
            if chart.isTimeKnown { return true }
            return transit.natal != .moon && transit.natal != .ascendant
        }.prefix(Self.maxTransits)
        guard chart != nil, !transits.isEmpty else { return nil }
        let items = transits.map {
            "transiting \($0.title) (orb \(NatalChartCalculator.formatDegrees($0.orb)), \($0.isApplying ? "applying" : "separating"))"
        }
        return "Transits to their chart today, tightest first: " + items.joined(separator: "; ") + "."
    }

    private var memoryDescription: String? {
        let memories = memory.suffix(Self.maxMemories)
        guard !memories.isEmpty else { return nil }
        let items = memories.map {
            "- \(Self.format($0.date, .dateTime.day().month(.abbreviated))): they asked \"\($0.question)\"; you said: \($0.gist)"
        }
        return "Earlier conversations (refer back only when relevant):\n" + items.joined(separator: "\n")
    }

    private func birthDescription(_ birth: BirthData) -> String {
        var text = "Born \(Self.format(birth.date, .dateTime.day().month(.wide).year()))"
        if let time = birth.time {
            text += " at \(birth.isTimeApproximate == true ? "about " : "")\(Self.format(time, .dateTime.hour().minute()))"
        }
        if let place = birth.place {
            text += " in \(place.title)"
        }
        if let age = Calendar.current.dateComponents([.year], from: birth.date, to: date).year {
            text += ", currently \(age) years old"
        }
        text += "."
        if birth.time == nil {
            text += " Birth time is unknown, so the rising sign and houses are uncertain."
        } else if !birth.isTimeKnown {
            text += " Birth time is approximate, so the rising sign and house cusps may be slightly off."
        }
        return text
    }

    private static func describe(_ placement: PlanetPlacement) -> String {
        var text = "\(placement.planet.name) in \(placement.sign.name) \(placement.degree)"
        if placement.isRetrograde { text += " retrograde" }
        if placement.planet != .ascendant { text += ", \(placement.house)" }
        return text
    }

    private static func format(_ date: Date, _ style: Date.FormatStyle) -> String {
        date.formatted(style.locale(locale))
    }
}
