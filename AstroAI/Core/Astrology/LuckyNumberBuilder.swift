//
//  LuckyNumberBuilder.swift
//  AstroAI
//

import Foundation

/// Five lucky numbers for the civil day.
/// The first is the personal day (birth date + today's date). The rest follow the Moon,
/// the natal chart and the name, so the set changes daily and differs between people.
enum LuckyNumberBuilder {
    static func numbers(profile: UserProfile?, chart: NatalChart?, sky: SkySnapshot) -> LuckyNumbers {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.dateComponents([.year, .month, .day], from: sky.date)
        let universal = reduce((today.year ?? 0) + (today.month ?? 1) + (today.day ?? 1))
        let life = profile.map { lifePath($0.birth.date, calendar: calendar) } ?? universal
        let personal = reduce(life + universal)

        let moon = sky.position(of: .moon)
        let moonSign = moon?.sign ?? .gemini
        let degree = max(1, min(30, Int((moon?.degreeInSign ?? 1).rounded())))
        let sunDegree = max(1, min(30, Int((sky.position(of: .sun)?.degreeInSign ?? 1).rounded())))
        let ruler = planetNumber(moonSign.ruler)

        var values: [Int] = []
        func append(_ raw: Int) {
            let number = inRange(raw)
            guard !values.contains(number) else { return }
            values.append(number)
        }

        append(personal)
        append(ruler == personal ? ruler + 9 : ruler)
        append(degree)
        if let natalMoon = chart?.placement(.moon) {
            append(planetNumber(natalMoon.sign.ruler) * 4 + (natalMoon.houseNumber ?? 1))
        }
        if let ascendant = chart?.placement(.ascendant) {
            append((ascendant.sign.index + 1) * 3 + personal)
        }
        append(personal * 9 + moonSign.index + 1)
        append(sunDegree + (today.day ?? 1) + life)
        if let name = profile?.name, let nameValue = nameNumber(name) {
            append(nameValue * 5 + (today.day ?? 1))
        }

        var salt = personal + (today.day ?? 1) + moonSign.index
        while values.count < 5 {
            salt += 7
            append(salt)
        }

        return LuckyNumbers(
            values: Array(values.prefix(5)),
            personalDay: personal,
            note: note(moon: moonSign, hasBirth: profile != nil)
        )
    }

    // MARK: - Numerology

    private static func lifePath(_ date: Date, calendar: Calendar) -> Int {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return reduce((parts.year ?? 0) + (parts.month ?? 1) + (parts.day ?? 1))
    }

    /// Pythagorean planet numbers. The Moon's ruler supplies one of the day's numbers.
    private static func planetNumber(_ planet: Planet) -> Int {
        switch planet {
        case .sun, .ascendant: 1
        case .moon: 2
        case .jupiter: 3
        case .uranus, .northNode: 4
        case .mercury: 5
        case .venus: 6
        case .neptune: 7
        case .saturn: 8
        case .mars, .pluto: 9
        }
    }

    private static func nameNumber(_ name: String) -> Int? {
        let letters = name.lowercased().filter(\.isLetter)
        let sum = letters.reduce(0) { $0 + letterValue($1) }
        guard sum > 0 else { return nil }
        return reduce(sum)
    }

    private static func letterValue(_ character: Character) -> Int {
        switch character {
        case "a", "j", "s": 1
        case "b", "k", "t": 2
        case "c", "l", "u": 3
        case "d", "m", "v": 4
        case "e", "n", "w": 5
        case "f", "o", "x": 6
        case "g", "p", "y": 7
        case "h", "q", "z": 8
        case "i", "r": 9
        default: cyrillicValue(character)
        }
    }

    /// Russian alphabet in nines, so a Cyrillic name still shifts the set.
    private static func cyrillicValue(_ character: Character) -> Int {
        let alphabet = Array("абвгдеёжзийклмнопрстуфхцчшщъыьэюя")
        guard let index = alphabet.firstIndex(of: character) else { return 0 }
        return index % 9 + 1
    }

    private static func reduce(_ value: Int) -> Int {
        var number = abs(value)
        if number == 0 { return 9 }
        while number > 9 {
            number = String(number).reduce(0) { $0 + Int(String($1))! }
        }
        return number
    }

    private static func inRange(_ raw: Int) -> Int {
        let wrapped = abs(raw) % 99
        return wrapped == 0 ? 99 : wrapped
    }

    private static func note(moon: ZodiacSign, hasBirth: Bool) -> String {
        if hasBirth {
            return "Read from your birth date and today's \(moon.name) Moon."
        }
        return "Read from today's \(moon.name) Moon."
    }
}
