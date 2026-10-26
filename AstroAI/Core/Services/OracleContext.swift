//
//  OracleContext.swift
//  AstroAI
//

import Foundation

/// Calendar-day facts for the model. Components come from the calendar that stored the date,
/// so a time-zone conversion cannot move the birthday onto another day or onto today.
enum OracleDates {
    private static let months = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]

    static func iso(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func long(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let month = parts.month, (1...12).contains(month), let day = parts.day, let year = parts.year else {
            return "unknown"
        }
        return "\(months[month - 1]) \(day), \(year)"
    }

    static func weekday(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(secondsFromGMT: 0)!
        gregorian.locale = Locale(identifier: "en_US")
        let noon = gregorian.date(from: DateComponents(year: parts.year, month: parts.month, day: parts.day, hour: 12)) ?? date
        return noon.formatted(.dateTime.weekday(.wide).locale(Locale(identifier: "en_US")))
    }

    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// Completed years, using calendar days. The birthday counts on the day it occurs.
    static func age(born: Date, on now: Date, calendar: Calendar = .current) -> Int? {
        let birth = calendar.dateComponents([.year, .month, .day], from: born)
        let current = calendar.dateComponents([.year, .month, .day], from: now)
        guard let birthYear = birth.year, let birthMonth = birth.month, let birthDay = birth.day,
              let year = current.year, let month = current.month, let day = current.day else { return nil }
        var years = year - birthYear
        if month < birthMonth || (month == birthMonth && day < birthDay) { years -= 1 }
        return years >= 0 ? years : nil
    }

    static func birthdayHasOccurred(born: Date, on now: Date, calendar: Calendar = .current) -> Bool {
        let birth = calendar.dateComponents([.month, .day], from: born)
        let current = calendar.dateComponents([.month, .day], from: now)
        guard let birthMonth = birth.month, let birthDay = birth.day,
              let month = current.month, let day = current.day else { return false }
        return month > birthMonth || (month == birthMonth && day >= birthDay)
    }
}

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
    /// The same reading the Today screen shows for this chart and sky.
    let reading: DailyReading

    private static let maxConnections = 5
    private static let maxTransits = 6
    private static let maxMemories = 6

    /// Standing facts for the session. Today's recommendation is not included:
    /// it is attached to a message only when that message asks for it.
    /// Saved people stay in their own section so they are not treated as the topic of every question.
    var prompt: String {
        var sections = [profileFacts]
        if let profile {
            sections.append(lifeNotes(profile))
        }
        sections.append(skyDescription)
        if let chart {
            sections.append(chartDescription(chart))
        }
        if let transits = transitsDescription {
            sections.append(transits)
        }
        if chart == nil {
            let basis = reading.ephemerisTitle.isEmpty ? "today's Moon" : reading.ephemerisTitle
            sections.append("No natal chart is available. Do not invent placements. If they ask what to focus on today and no recommendation is attached to that message, the only calculated basis is \(basis).")
        }
        if let people = peopleDescription {
            sections.append(people)
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
            rules.append("Use only the placements listed under Saved people. For anyone else they saved, first call getPersonChart; never invent placements.")
        } else if !connections.isEmpty {
            rules.append("Use only the placements listed under Saved people; never invent them.")
        }
        if hasJournal {
            rules.append("When the user mentions their journal or something they wrote, first call searchJournal.")
        }
        return rules.joined(separator: "\n")
    }

    // MARK: - Sections

    private var housesAreUsable: Bool {
        chart?.isTimeKnown == true && chart?.hasLocation == true
    }

    private var profileFacts: String {
        var lines = ["Profile facts (stored values; never replace these with the current date, a zodiac sign, or something said in the chat):"]
        lines.append("Current date: \(OracleDates.iso(date)) (\(OracleDates.weekday(date)), \(OracleDates.long(date))). Time zone: \(TimeZone.current.identifier). This is today, not the birth date.")
        if let birth = profile?.birth {
            lines.append("Birth date: \(OracleDates.iso(birth.date)) (\(OracleDates.long(birth.date))).")
            if let time = birth.time {
                let qualifier = birth.isTimeApproximate == true ? "approximate " : ""
                lines.append("Birth time: \(qualifier)\(OracleDates.time(time)).")
            } else {
                lines.append("Birth time: not stored.")
            }
            if let place = birth.place {
                lines.append("Birthplace: \(place.title). Time zone: \(place.timeZoneIdentifier ?? place.timeZone).")
            } else {
                lines.append("Birthplace: not stored.")
            }
            if let age = OracleDates.age(born: birth.date, on: date) {
                let occurred = OracleDates.birthdayHasOccurred(born: birth.date, on: date)
                lines.append("Age on the current date: \(age). The birthday \(occurred ? "has already occurred" : "has not occurred yet") this year.")
            }
            if birth.time == nil {
                lines.append("Birth time is unknown. Do not state a rising sign or houses.")
            } else if !birth.isTimeKnown {
                lines.append("Birth time is approximate. Do not state an exact rising sign or exact houses.")
            }
        } else {
            lines.append("Birth date: not stored. Do not use the current date as the birth date.")
        }
        return lines.joined(separator: "\n")
    }

    private var skyDescription: String {
        var lines = ["Current sky for \(OracleDates.iso(date)). Moon phase: \(sky.moonPhase.name), \(sky.moonPhase.illumination)% illuminated."]
        let planets = sky.positions
            .filter { $0.planet != .northNode }
            .map { position -> String in
                var text = "\(position.planet.name) in \(position.sign.name)"
                if position.isRetrograde { text += " (retrograde)" }
                if housesAreUsable, let house = sky.houses[position.planet] {
                    text += ", their \(AstrologyLexicon.ordinal(house)) house"
                }
                return text
            }
        lines.append("Current sky: " + planets.joined(separator: "; ") + ".")
        return lines.joined(separator: "\n")
    }

    private func lifeNotes(_ profile: UserProfile) -> String {
        var lines = ["Life notes (background only; do not turn these into the reply unless they asked about this part of their life):"]
        lines.append("Name: \(profile.name).")
        if let personal = profile.personal, !personal.isEmpty {
            lines.append(contentsOf: personalLines(personal))
        }
        if !profile.interests.isEmpty {
            lines.append("Interested in: " + profile.interests.map(\.title).sorted().joined(separator: ", ") + ".")
        }
        if !profile.intentions.isEmpty {
            lines.append("Hopes to get from StellarSage: " + profile.intentions.map(\.title).sorted().joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    private func personalLines(_ personal: PersonalContext) -> [String] {
        var lines: [String] = []
        if let pronouns = personal.pronouns {
            lines.append("Pronouns: \(pronouns.title.lowercased()).")
        }
        if let relationship = personal.relationship {
            lines.append("Relationship: \(relationship.title.lowercased()).")
        }
        if let stage = personal.lifeStage {
            lines.append("Life stage: \(stage.title.lowercased()).")
        }
        if let focus = personal.currentFocus?.trimmingCharacters(in: .whitespacesAndNewlines), !focus.isEmpty {
            lines.append("On their mind, in their words: \"\(focus)\". Mention this only when the question is about it.")
        }
        return lines
    }

    /// Kept out of the life notes so a question about a goal is not pulled toward a saved person.
    private var peopleDescription: String? {
        let others = connections.dropFirst(peopleNotes.count).prefix(Self.maxConnections - peopleNotes.count)
        guard !peopleNotes.isEmpty || !others.isEmpty else { return nil }
        var lines = ["Saved people (use only when the question is about one of them):"]
        if !peopleNotes.isEmpty {
            lines.append(peopleNotes.map { "- \($0)" }.joined(separator: "\n"))
        }
        if !others.isEmpty {
            let people = others.map {
                "\($0.name) (\($0.kinship.title), \(ZodiacSign.sunSign(on: $0.birth.date).name) Sun)"
            }
            lines.append("Also saved: " + people.joined(separator: ", ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    private func chartDescription(_ chart: NatalChart) -> String {
        let placements = chart.isTimeKnown
            ? chart.placements
            : chart.placements.filter { $0.planet != .moon && $0.planet != .ascendant }
        var lines = ["Chart reference (an interpretation aid, not a fact about their future; never add a placement that is not written here):"]
        lines.append("Natal chart (\(chart.houseSystem)): " + placements.map { Self.describe($0, includeHouse: housesAreUsable) }.joined(separator: "; ") + ".")
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
        if housesAreUsable {
            lines.append(cuspsDescription(chart))
        } else if !chart.isTimeKnown {
            lines.append("Birth time is missing or approximate. The natal Moon sign and rising sign are omitted. Do not invent them, and do not state houses. Today's Moon in the sky is still usable.")
        } else {
            lines.append("Birthplace is missing. Do not mention houses or a rising sign.")
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
            "- \(OracleDates.iso($0.date)): they asked \"\($0.question)\""
        }
        return "Earlier questions (background only; do not copy their wording, and do not answer a new question with an old reply):\n" + items.joined(separator: "\n")
    }

    private static func describe(_ placement: PlanetPlacement, includeHouse: Bool) -> String {
        var text = "\(placement.planet.name) in \(placement.sign.name) \(placement.degree)"
        if placement.isRetrograde { text += " retrograde" }
        if includeHouse, placement.planet != .ascendant { text += ", \(placement.house)" }
        return text
    }
}
