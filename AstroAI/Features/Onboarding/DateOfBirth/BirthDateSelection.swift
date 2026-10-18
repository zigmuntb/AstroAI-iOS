//
//  BirthDateSelection.swift
//  AstroAI
//
//  Valid birth dates for the onboarding wheels. The window is "today" through the
//  same calendar date 112 years earlier, and it is rebuilt from the clock so it
//  moves forward when the day changes.

import Foundation

struct BirthDateBounds: Equatable {
    static let yearSpan = 112

    let calendar: Calendar
    /// Start of the earliest allowed birth day.
    let minimum: Date
    /// Start of today. Today is allowed; tomorrow is not.
    let maximum: Date
    let monthSymbols: [String]

    init(now: Date = .now, calendar: Calendar = .current) {
        var calendar = calendar
        if calendar.locale == nil {
            calendar.locale = .autoupdatingCurrent
        }
        self.calendar = calendar

        let today = calendar.startOfDay(for: now)
        self.maximum = today
        if let earlier = calendar.date(byAdding: .year, value: -Self.yearSpan, to: today) {
            self.minimum = calendar.startOfDay(for: earlier)
        } else {
            self.minimum = today
        }

        let symbols = calendar.standaloneMonthSymbols
        self.monthSymbols = symbols.isEmpty ? calendar.monthSymbols : symbols
    }

    var minimumYear: Int { calendar.component(.year, from: minimum) }
    var maximumYear: Int { calendar.component(.year, from: maximum) }

    var years: [Int] {
        Array(minimumYear...maximumYear)
    }

    func months(in year: Int) -> [Int] {
        let month = calendar.component(.month, from: maximum)
        guard let probe = date(year: year, month: month, day: 1),
              let range = calendar.range(of: .month, in: .year, for: probe) else {
            return Array(1...12)
        }
        return Array(range)
    }

    func dayCount(year: Int, month: Int) -> Int {
        guard let probe = date(year: year, month: month, day: 1),
              let range = calendar.range(of: .day, in: .month, for: probe) else {
            return 30
        }
        return range.count
    }

    func days(in year: Int, month: Int) -> [Int] {
        Array(1...dayCount(year: year, month: month))
    }

    func monthTitle(_ month: Int) -> String {
        let index = month - 1
        guard monthSymbols.indices.contains(index) else { return String(month) }
        return monthSymbols[index]
    }

    func clamp(_ date: Date) -> Date {
        let day = calendar.startOfDay(for: date)
        if day < minimum { return minimum }
        if day > maximum { return maximum }
        return day
    }

    /// Replaces the day and keeps the month and year, then pulls the result back into range.
    func setting(day: Int, on date: Date) -> Date {
        updated(date, year: nil, month: nil, day: day)
    }

    /// Replaces the month. The day shrinks when the new month is shorter.
    func setting(month: Int, on date: Date) -> Date {
        updated(date, year: nil, month: month, day: nil)
    }

    /// Replaces the year. A February 29 rolls back to February 28 in a common year.
    func setting(year: Int, on date: Date) -> Date {
        updated(date, year: year, month: nil, day: nil)
    }

    func components(of date: Date) -> DateComponents {
        calendar.dateComponents([.year, .month, .day], from: date)
    }

    private func updated(_ date: Date, year: Int?, month: Int?, day: Int?) -> Date {
        var year = year ?? calendar.component(.year, from: date)
        var month = month ?? calendar.component(.month, from: date)
        var day = day ?? calendar.component(.day, from: date)

        year = min(max(year, minimumYear), maximumYear)
        let monthChoices = months(in: year)
        if let first = monthChoices.first, let last = monthChoices.last, !monthChoices.contains(month) {
            month = min(max(month, first), last)
        }
        day = min(max(day, 1), dayCount(year: year, month: month))

        guard let candidate = self.date(year: year, month: month, day: day) else {
            return clamp(date)
        }
        return clamp(candidate)
    }

    private func date(year: Int, month: Int, day: Int) -> Date? {
        calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}

/// Maps a birth date to a sky angle. A year moves the sky more than a month, and a month more than a day.
enum CelestialRotation {
    static let yearDegrees = 12.0
    static let monthDegrees = 6.0
    static let dayDegrees = 1.25
    /// Keeps the stored angle near zero for contemporary dates.
    static let anchorYear = 2000

    static func angle(year: Int, month: Int, day: Int) -> Double {
        Double(year - anchorYear) * yearDegrees
            + Double(month - 1) * monthDegrees
            + Double(day - 1) * dayDegrees
    }
}

/// Moves an unwrapped angle onto `target` by the shortest turn, so 350° → 10° travels +20° rather than −340°.
enum ShortestTurn {
    static func approach(from current: Double, to target: Double) -> Double {
        current + delta(from: current, to: target)
    }

    static func delta(from current: Double, to target: Double) -> Double {
        let wrapped = (target - current).truncatingRemainder(dividingBy: 360)
        if wrapped > 180 { return wrapped - 360 }
        if wrapped < -180 { return wrapped + 360 }
        return wrapped
    }
}
