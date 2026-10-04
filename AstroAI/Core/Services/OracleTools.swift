//
//  OracleTools.swift
//  AstroAI
//

import Foundation
import FoundationModels

/// Data the Oracle model can look up on demand instead of carrying it in every prompt.
/// Tools are called off the main actor, so they only hold main-actor lookups.
typealias OracleLookup = @Sendable @MainActor (String) async -> String

nonisolated struct JournalSearchTool: Tool {
    let name = "searchJournal"
    let description = "Searches the user's private journal of reflections and saved Oracle answers. Use it when the user refers to something they wrote or felt before."

    @Generable
    struct Arguments {
        @Guide(description: "A keyword or topic to look for, e.g. 'career' or 'mother'. Empty for the latest entries.")
        var query: String
    }

    let lookup: OracleLookup

    func call(arguments: Arguments) async throws -> String {
        await lookup(arguments.query)
    }
}

nonisolated struct PersonChartTool: Tool {
    let name = "getPersonChart"
    let description = "Returns the birth chart of someone from the user's saved people and how it interacts with the user's chart (synastry). Use it for questions about a partner, friend or relative."

    @Generable
    struct Arguments {
        @Guide(description: "The person's name as the user saved it")
        var name: String
    }

    let lookup: OracleLookup

    func call(arguments: Arguments) async throws -> String {
        await lookup(arguments.name)
    }
}

nonisolated struct SkyOnDateTool: Tool {
    let name = "getSkyOnDate"
    let description = "Returns planet positions, the moon phase and transits to the user's natal chart on a given date. Use it for questions about a specific day, week or upcoming event."

    @Generable
    struct Arguments {
        @Guide(description: "Date in YYYY-MM-DD format")
        var date: String
    }

    let lookup: OracleLookup

    func call(arguments: Arguments) async throws -> String {
        await lookup(arguments.date)
    }
}

/// Builds tool answers from the app's services.
final class OracleToolbox {
    private let journal: JournalServicing
    private let connections: ConnectionsServicing
    private let astrology: AstrologyServicing
    private let natal: NatalChart?

    /// Outer planets are shared by a whole generation, so they say little about a couple.
    private static let personalPlanets: Set<Planet> = [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn]

    init(journal: JournalServicing, connections: ConnectionsServicing, astrology: AstrologyServicing, natal: NatalChart?) {
        self.journal = journal
        self.connections = connections
        self.astrology = astrology
        self.natal = natal
    }

    var tools: [any Tool] {
        var tools: [any Tool] = [
            SkyOnDateTool { [self] in sky(on: $0) }
        ]
        if !journal.entries().isEmpty {
            tools.append(JournalSearchTool { [self] in searchJournal($0) })
        }
        if !connections.connections().isEmpty {
            tools.append(PersonChartTool { [self] in await personChart(named: $0) })
        }
        return tools
    }

    // MARK: - Journal

    func searchJournal(_ query: String) -> String {
        let entries = journal.entries().sorted { $0.date > $1.date }
        let words = query.lowercased().split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        let matches = words.isEmpty ? entries : entries.filter { entry in
            let text = [entry.context, entry.quote, entry.body, entry.tags.joined(separator: " ")].joined(separator: " ").lowercased()
            return words.contains { text.contains($0) }
        }
        let header = matches.isEmpty ? "No entries mention \"\(query)\". The latest entries:\n" : ""
        return header + (matches.isEmpty ? entries : matches).prefix(3).map { entry in
            let date = entry.date.formatted(.dateTime.day().month(.wide).year().locale(Locale(identifier: "en_US_POSIX")))
            let body = entry.body.count > 300 ? entry.body.prefix(300) + "…" : Substring(entry.body)
            return "\(date) (\(entry.context)): \"\(entry.quote)\" \(body)"
        }.joined(separator: "\n")
    }

    // MARK: - People

    func personChart(named name: String) async -> String {
        let people = connections.connections()
        let query = name.lowercased().trimmingCharacters(in: .whitespaces)
        guard let person = people.first(where: { $0.name.lowercased() == query })
            ?? people.first(where: { $0.name.lowercased().contains(query) || query.contains($0.name.lowercased()) }) else {
            let known = people.map(\.name).joined(separator: ", ")
            return "No saved person called \(name). Saved people: \(known)."
        }
        return await personChart(person)
    }

    /// Key placements of a saved person and the strongest contacts with the user's chart.
    func personChart(_ person: Connection) async -> String {
        guard let chart = try? await astrology.natalChart(for: person.birth) else {
            return "\(person.name)'s chart couldn't be calculated."
        }
        let core: [Planet] = person.birth.isTimeKnown
            ? [.sun, .moon, .mercury, .venus, .mars, .ascendant]
            : [.sun, .moon, .mercury, .venus, .mars]
        let placements = chart.placements
            .filter { core.contains($0.planet) }
            .map { "\($0.planet.name) in \($0.sign.name)" }
        var text = "\(person.name) (\(person.kinship.title)): " + placements.joined(separator: ", ") + "."
        if let natal {
            let contacts = astrology.sky(at: person.birth.moment, natal: natal).transits
                .filter { Self.personalPlanets.contains($0.transiting) && $0.natal != .northNode }
                .prefix(4)
                .map { "their \($0.transiting.name) \($0.kind.name.lowercased()) the user's \($0.natal.name)" }
            if !contacts.isEmpty {
                text += " Contacts with the user's chart: " + contacts.joined(separator: "; ") + "."
            }
        }
        return text
    }

    // MARK: - Sky

    func sky(on dateText: String) -> String {
        guard let date = Self.parse(dateText) else {
            return "Couldn't read the date \"\(dateText)\". Use YYYY-MM-DD."
        }
        let sky = astrology.sky(at: date, natal: natal)
        let planets = sky.positions
            .filter { $0.planet != .northNode }
            .map { "\($0.planet.name) in \($0.sign.name)\($0.isRetrograde ? " (retrograde)" : "")" }
        var lines = [
            "Sky on \(dateText): " + planets.joined(separator: "; ") + ".",
            "Moon phase: \(sky.moonPhase.name), \(sky.moonPhase.illumination)% illuminated."
        ]
        let transits = sky.transits.prefix(5).map { "transiting \($0.title)" }
        if !transits.isEmpty {
            lines.append("Transits to the user's chart: " + transits.joined(separator: "; ") + ".")
        }
        return lines.joined(separator: "\n")
    }

    /// Noon of the given day in the user's time zone, so the Moon sign matches their calendar day.
    private static func parse(_ text: String) -> Date? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return Calendar.current.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}
