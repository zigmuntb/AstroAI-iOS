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
            ? "On \(stamp(nextBirthday)) the year moves into the \(AstrologyLexicon.ordinal(nextHouse)) house of \(AstrologyLexicon.houseTheme(nextHouse)), carried by \(nextSign.ruler.name)."
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
            theme: "This year gathers around \(AstrologyLexicon.houseTheme(house)). \(lord.name) is the time-lord.",
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
        if let house = placement.houseNumber {
            return "\(lord.name) in \(placement.sign.name), your \(AstrologyLexicon.ordinal(house)) house"
        }
        return "\(lord.name) in \(placement.sign.name)"
    }

    private static func refrain(for house: Int) -> String {
        switch house {
        case 1: "Don't perform a self you haven't met yet."
        case 2: "Don't spend to prove what you are worth."
        case 3: "Don't fill the quiet with more information."
        case 4: "Don't decide the family's future from a single hard evening."
        case 5: "Don't turn pleasure into a project."
        case 6: "Don't optimize the day until the body has agreed."
        case 7: "Don't settle the relationship in one conversation."
        case 8: "Don't force an ending that is still telling you something."
        case 9: "Don't make a belief do the work of an experience."
        case 10: "Don't chase a title that isn't the work."
        case 11: "Don't confuse a crowd with the people who are actually yours."
        default: "Don't explain the retreat while you are still inside it."
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
