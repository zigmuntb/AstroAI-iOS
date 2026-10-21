//
//  AnnualProfection.swift
//  AstroAI
//

import Foundation

/// The year you are in, counted as one house per year from the rising sign.
struct YearAhead: Hashable {
    let eyebrow: String
    let trailing: String
    let title: String
    let lordLine: String
    let theme: String
    let refrain: String
    /// Set when the birthday, and the next house, are close.
    let turningLine: String?
    let basis: String
}

enum AnnualProfection {
    static func reading(chart: NatalChart, born: Date, now: Date = .now) -> YearAhead? {
        guard let root = rootSign(of: chart) else { return nil }
        let calendar = Calendar.current
        let age = max(calendar.dateComponents([.year], from: born, to: now).year ?? 0, 0)
        let house = (age % 12) + 1
        let sign = ZodiacSign.allCases[(root.sign.index + house - 1) % 12]
        let lord = sign.ruler
        let nextBirthday = nextBirthday(after: now, born: born, calendar: calendar)
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: nextBirthday)
        ).day ?? 0

        let nextHouse = (house % 12) + 1
        let nextSign = ZodiacSign.allCases[(sign.index + 1) % 12]
        let turning: String? = (1...21).contains(days)
            ? "On \(stamp(nextBirthday)) the year moves to the \(AstrologyLexicon.ordinal(nextHouse)) house: \(AstrologyLexicon.houseTheme(nextHouse)). \(nextSign.ruler.name) leads that next year."
            : nil

        let eyebrow: String
        let trailing: String
        if days == 0 {
            eyebrow = "A new year"
            trailing = "Began today"
        } else if days <= 21 {
            eyebrow = "Your year turns"
            trailing = stamp(nextBirthday)
        } else {
            eyebrow = "Year ahead"
            trailing = "Until \(stamp(nextBirthday))"
        }

        return YearAhead(
            eyebrow: eyebrow,
            trailing: trailing,
            title: "\(AstrologyLexicon.ordinal(house)) house in \(sign.name)",
            lordLine: lordLine(lord, chart: chart),
            theme: "This year is about \(AstrologyLexicon.houseTheme(house)). \(lord.name) sets the pace.",
            refrain: refrain(for: house),
            turningLine: turning,
            basis: root.basis
        )
    }

    // MARK: - Pieces

    private static func rootSign(of chart: NatalChart) -> (sign: ZodiacSign, basis: String)? {
        if chart.isTimeKnown, chart.hasLocation, let rising = chart.placement(.ascendant) {
            return (rising.sign, "Counted in whole signs from your rising sign.")
        }
        if let sun = chart.placement(.sun) {
            return (sun.sign, "Counted in whole signs from your Sun, because the birth time is not exact.")
        }
        return nil
    }

    private static func lordLine(_ lord: Planet, chart: NatalChart) -> String {
        guard let placement = chart.placement(lord) else { return lord.name }
        var line = "This year leans on \(lord.meaning), in a \(placement.sign.qualities) style."
        if chart.hasLocation, chart.isTimeKnown, let house = placement.houseNumber {
            line += " That shows up around \(AstrologyLexicon.houseTheme(house))."
        }
        return line
    }

    private static func refrain(for house: Int) -> String {
        switch house {
        case 1: "Don't act like a version of yourself you haven't figured out yet."
        case 2: "Don't spend money to prove what you're worth."
        case 3: "Don't fill every quiet moment with more information."
        case 4: "Don't decide the family's future after one hard evening."
        case 5: "Don't turn fun into a project."
        case 6: "Don't plan the whole day before your body agrees."
        case 7: "Don't try to settle the relationship in one talk."
        case 8: "Don't force an ending that is still teaching you something."
        case 9: "Don't treat a belief as if it were lived experience."
        case 10: "Don't chase a title that isn't the actual work."
        case 11: "Don't confuse a crowd with the people who are actually yours."
        default: "Don't explain the time alone while you are still in it."
        }
    }

    private static func nextBirthday(after now: Date, born: Date, calendar: Calendar) -> Date {
        let parts = calendar.dateComponents([.month, .day], from: born)
        let year = calendar.component(.year, from: now)
        var components = DateComponents(year: year, month: parts.month, day: parts.day)
        var next = calendar.date(from: components)
        if next == nil, parts.month == 2, parts.day == 29 {
            components.day = 28
            next = calendar.date(from: components)
        }
        let candidate = next ?? now
        guard calendar.startOfDay(for: candidate) < calendar.startOfDay(for: now) else { return candidate }
        components.year = year + 1
        if let later = calendar.date(from: components) { return later }
        components.day = 28
        return calendar.date(from: components) ?? candidate
    }

    private static func stamp(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }
}
