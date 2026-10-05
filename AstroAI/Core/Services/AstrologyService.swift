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
        let now = Date.now
        return ExploreLibrary(weekRange: Self.weekRange(around: now), transits: weekSkyEvents(from: now))
    }

    /// Seven civil days starting today, e.g. "Oct 5 — Oct 11".
    private static func weekRange(around now: Date) -> String {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        let style = Date.FormatStyle().month(.abbreviated).day().locale(Locale(identifier: "en_US_POSIX"))
        return "\(start.formatted(style)) — \(end.formatted(style))"
    }

    /// Moon sign changes and the four lunar phases across the seven days shown in the header.
    /// Times are the actual crossings, not a noon sample of the day the event falls on.
    private func weekSkyEvents(from now: Date) -> [Transit] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start.addingTimeInterval(7 * 86_400)
        let step: TimeInterval = 6 * 3_600

        var events: [(date: Date, transit: Transit)] = []
        var cursor = start
        var previous = skySample(at: cursor)

        while cursor < end {
            let nextDate = min(cursor.addingTimeInterval(step), end)
            let next = skySample(at: nextDate)

            if next.moonSign != previous.moonSign {
                let when = refine(from: cursor, to: nextDate) { $0.moonSign == next.moonSign }
                if when >= start, when < end {
                    let sign = skySample(at: when).moonSign
                    events.append((when, Transit(
                        glyph: sign.glyph,
                        kind: "Lunar Ingress",
                        date: Self.eventStamp(when),
                        title: "Moon enters \(sign.name)",
                        detail: "The mood shifts toward \(sign.qualities) themes."
                    )))
                }
            }

            let traveled = Self.forward(from: previous.elongation, to: next.elongation)
            if traveled < 180 {
                for phase in LunarPhaseEvent.allCases {
                    let until = Self.forward(from: previous.elongation, to: phase.elongation)
                    guard until > 1e-6, until <= traveled + 1e-6 else { continue }
                    let when = refine(from: cursor, to: nextDate) {
                        Self.forward(from: $0.elongation, to: phase.elongation) >= 180
                    }
                    guard when >= start, when < end else { continue }
                    let sky = skySample(at: when)
                    events.append((when, Transit(
                        glyph: "☽",
                        kind: phase.title,
                        date: Self.eventStamp(when),
                        title: "\(phase.title) in \(sky.moonSign.name)",
                        detail: "\(NatalChartCalculator.formatDegrees(sky.degreeInSign)) \(sky.moonSign.glyph) · \(phase.detail)"
                    )))
                }
            }

            cursor = nextDate
            previous = next
        }

        return events.sorted { $0.date < $1.date }.map(\.transit)
    }

    private struct SkySample {
        let moonSign: ZodiacSign
        let degreeInSign: Double
        let elongation: Double
    }

    private func skySample(at date: Date) -> SkySample {
        let positions = NatalChartCalculator.positions(at: date, options: chartOptions)
        let sun = positions.first { $0.planet == .sun }?.longitude ?? 0
        let moon = positions.first { $0.planet == .moon }?.longitude ?? 0
        return SkySample(
            moonSign: ZodiacSign.containing(moon),
            degreeInSign: moon.truncatingRemainder(dividingBy: 30),
            elongation: Self.forward(from: sun, to: moon)
        )
    }

    /// Bisect until `hasPassed` becomes true. Sixteen steps on a six-hour span land within a second.
    private func refine(from start: Date, to end: Date, hasPassed: (SkySample) -> Bool) -> Date {
        var lo = start.timeIntervalSinceReferenceDate
        var hi = end.timeIntervalSinceReferenceDate
        for _ in 0..<16 {
            let mid = (lo + hi) / 2
            if hasPassed(skySample(at: Date(timeIntervalSinceReferenceDate: mid))) {
                hi = mid
            } else {
                lo = mid
            }
        }
        return Date(timeIntervalSinceReferenceDate: hi)
    }

    /// Degrees traveled forward along the ecliptic, in `0..<360`.
    private static func forward(from start: Double, to end: Double) -> Double {
        let value = (end - start).truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func eventStamp(_ date: Date) -> String {
        let locale = Locale(identifier: "en_US_POSIX")
        let day = date.formatted(Date.FormatStyle().month(.abbreviated).day().locale(locale))
        let time = date.formatted(Date.FormatStyle().hour().minute().locale(locale))
        return "\(day) · \(time)"
    }
}

/// Exact lunar phase, measured by the Moon's elongation from the Sun.
private enum LunarPhaseEvent: CaseIterable {
    case newMoon, firstQuarter, fullMoon, lastQuarter

    var elongation: Double {
        switch self {
        case .newMoon: 0
        case .firstQuarter: 90
        case .fullMoon: 180
        case .lastQuarter: 270
        }
    }

    var title: String {
        switch self {
        case .newMoon: "New Moon"
        case .firstQuarter: "First Quarter"
        case .fullMoon: "Full Moon"
        case .lastQuarter: "Last Quarter"
        }
    }

    var detail: String {
        switch self {
        case .newMoon: "Sun and Moon meet."
        case .firstQuarter, .lastQuarter: "The Moon squares the Sun."
        case .fullMoon: "The Moon opposes the Sun."
        }
    }
}
