//
//  AstrologyService.swift
//  AstroAI
//

import Foundation

struct MoonPhase: Hashable {
    let name: String
    /// 0...100
    let illumination: Int
}

protocol AstrologyServicing {
    var chartOptions: ChartOptions { get }

    func sunSign(for date: Date) -> ZodiacSign
    func moonPhase(for date: Date) -> MoonPhase
    func natalChart(for birth: BirthData) async throws -> NatalChart
    func sky(at date: Date, natal: NatalChart?) -> SkySnapshot
    func synastry(of user: UserProfile, with connection: Connection) async throws -> SynastryReport
    func journalPrompt(for profile: UserProfile?) -> JournalPrompt
    func dailyReading(for profile: UserProfile?) async throws -> DailyReading
    func library() async throws -> ExploreLibrary
}

/// Charts, transits, daily readings and synastry are computed on-device.
final class AstrologyService: AstrologyServicing {
    private let network: NetworkManaging
    private let preferences: PreferencesServicing

    init(network: NetworkManaging, preferences: PreferencesServicing) {
        self.network = network
        self.preferences = preferences
    }

    var chartOptions: ChartOptions { ChartOptions(preferences.load()) }

    func sunSign(for date: Date) -> ZodiacSign {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = 12
        let noon = Calendar.current.date(from: components) ?? date
        return Ephemeris.position(of: .sun, at: noon)?.sign ?? .sunSign(on: date)
    }

    func moonPhase(for date: Date) -> MoonPhase {
        TransitCalculator.moonPhase(at: date)
    }

    func natalChart(for birth: BirthData) async throws -> NatalChart {
        NatalChartCalculator.chart(for: birth, options: chartOptions)
    }

    func sky(at date: Date, natal: NatalChart?) -> SkySnapshot {
        TransitCalculator.sky(at: date, natal: natal, options: chartOptions)
    }

    func synastry(of user: UserProfile, with connection: Connection) async throws -> SynastryReport {
        let userChart = NatalChartCalculator.chart(for: user.birth, options: chartOptions)
        let otherChart = NatalChartCalculator.chart(for: connection.birth, options: chartOptions)
        return SynastryCalculator.report(user: userChart, other: otherChart, userName: user.name, connection: connection)
    }

    func journalPrompt(for profile: UserProfile?) -> JournalPrompt {
        let chart = profile.map { NatalChartCalculator.chart(for: $0.birth, options: chartOptions) }
        return DailyReadingBuilder.journalPrompt(chart: chart, sky: sky(at: .now, natal: chart))
    }

    func dailyReading(for profile: UserProfile?) async throws -> DailyReading {
        let chart = profile.map { NatalChartCalculator.chart(for: $0.birth, options: chartOptions) }
        return DailyReadingBuilder.reading(profile: profile, chart: chart, sky: sky(at: .now, natal: chart))
    }

    func library() async throws -> ExploreLibrary {
        let mock = MockData.library
        return ExploreLibrary(
            featured: mock.featured,
            weekRange: Self.weekRange(),
            transits: weekSkyEvents(),
            tomes: mock.tomes
        )
    }

    private static func weekRange() -> String {
        let start = Date.now
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let format = Date.FormatStyle(date: .abbreviated, time: .omitted).locale(Locale(identifier: "en_US_POSIX"))
        return "\(start.formatted(format)) — \(end.formatted(format))"
    }

    /// Moon ingresses and lunations over the next week, for the Explore calendar.
    private func weekSkyEvents() -> [Transit] {
        let calendar = Calendar.current
        var events: [Transit] = []
        var previousMoon: ZodiacSign?
        var previousPhase: String?
        for day in 0..<8 {
            guard let date = calendar.date(byAdding: .day, value: day, to: calendar.startOfDay(for: .now)) else { continue }
            let noon = date.addingTimeInterval(12 * 3600)
            let sky = TransitCalculator.sky(at: noon, natal: nil, options: chartOptions)
            let moon = sky.position(of: .moon)?.sign
            if let moon, moon != previousMoon {
                events.append(Transit(
                    glyph: moon.glyph,
                    kind: "Lunar Ingress",
                    date: noon.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(Locale(identifier: "en_US_POSIX"))),
                    title: "Moon enters \(moon.name)",
                    detail: "The day's mood shifts toward \(moon.qualities) themes."
                ))
                previousMoon = moon
            }
            if sky.moonPhase.name != previousPhase, ["New Moon", "Full Moon", "First Quarter", "Last Quarter"].contains(sky.moonPhase.name) {
                events.append(Transit(
                    glyph: "☽",
                    kind: sky.moonPhase.name,
                    date: noon.formatted(.dateTime.month(.abbreviated).day().locale(Locale(identifier: "en_US_POSIX"))),
                    title: "\(sky.moonPhase.name) in \(moon?.name ?? "the sky")",
                    detail: "\(sky.moonPhase.illumination)% illuminated"
                ))
                previousPhase = sky.moonPhase.name
            }
        }
        return Array(events.prefix(4))
    }
}
