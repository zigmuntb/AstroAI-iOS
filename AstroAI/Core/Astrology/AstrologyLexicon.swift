//
//  AstrologyLexicon.swift
//  AstroAI
//

import Foundation

/// Building blocks for chart interpretations: what each planet, sign, house and aspect means.
extension Planet {
    /// What this placement describes in a person, e.g. "emotional needs and inner security".
    var meaning: String {
        switch self {
        case .sun: "core self and energy"
        case .moon: "feelings and need for safety"
        case .ascendant: "first impression"
        case .mercury: "thinking and talking"
        case .venus: "love and taste"
        case .mars: "drive and courage"
        case .jupiter: "growth and luck"
        case .saturn: "discipline and long-term goals"
        case .uranus: "freedom and originality"
        case .neptune: "dreams and intuition"
        case .pluto: "deep change"
        case .northNode: "direction of growth"
        }
    }

    /// Closing words of a placement title, e.g. "· who you are".
    var titleSuffix: String {
        switch self {
        case .sun: "· who you are"
        case .moon: "· your feelings"
        case .ascendant: "· first impression"
        case .mercury: "· how you think"
        case .venus: "· how you love"
        case .mars: "· how you act"
        case .jupiter: "· how you grow"
        case .saturn: "· what you build"
        case .uranus: "· where you break the pattern"
        case .neptune: "· dreams"
        case .pluto: "· deep change"
        case .northNode: "· where you're headed"
        }
    }

    /// Personal points weigh more in element / modality balance and get wider aspect orbs.
    var isLuminaryOrAngle: Bool { [.sun, .moon, .ascendant].contains(self) }
}

extension ZodiacSign {
    var index: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    var opposite: ZodiacSign { Self.allCases[(index + 6) % 12] }

    var qualities: String {
        switch self {
        case .aries: "bold, direct, and ready to start"
        case .taurus: "steady, sensual, and patient"
        case .gemini: "curious, quick, and changeable"
        case .cancer: "caring, protective, and intuitive"
        case .leo: "warm, expressive, and generous"
        case .virgo: "careful, helpful, and precise"
        case .libra: "fair, polite, and focused on people"
        case .scorpio: "intense, private, and hard to fool"
        case .sagittarius: "honest, adventurous, and big-picture"
        case .capricorn: "ambitious, disciplined, and patient"
        case .aquarius: "independent, original, and a bit detached"
        case .pisces: "sensitive, imaginative, and changeable"
        }
    }

    var archetype: String {
        switch self {
        case .aries: "Bold and direct"
        case .taurus: "Steady and sensual"
        case .gemini: "Curious and quick"
        case .cancer: "Caring and protective"
        case .leo: "Warm and expressive"
        case .virgo: "Careful and useful"
        case .libra: "Fair and relational"
        case .scorpio: "Intense and private"
        case .sagittarius: "Honest and adventurous"
        case .capricorn: "Ambitious and steady"
        case .aquarius: "Independent and original"
        case .pisces: "Sensitive and imaginative"
        }
    }

    var modality: String {
        switch self {
        case .aries, .cancer, .libra, .capricorn: "Cardinal"
        case .taurus, .leo, .scorpio, .aquarius: "Fixed"
        case .gemini, .virgo, .sagittarius, .pisces: "Mutable"
        }
    }

    /// Traditional ruler, used for the chart ruler.
    var ruler: Planet {
        switch self {
        case .aries, .scorpio: .mars
        case .taurus, .libra: .venus
        case .gemini, .virgo: .mercury
        case .cancer: .moon
        case .leo: .sun
        case .sagittarius, .pisces: .jupiter
        case .capricorn, .aquarius: .saturn
        }
    }
}

enum AstrologyLexicon {
    static let elementKeywords = ["Fire": "Energy", "Earth": "Practicality", "Air": "Thinking", "Water": "Feeling"]
    static let modalityKeywords = ["Cardinal": "Starts things", "Fixed": "Stays steady", "Mutable": "Adapts"]

    static func houseTheme(_ house: Int) -> String {
        switch house {
        case 1: "self-image, body and personal presence"
        case 2: "money, possessions and self-worth"
        case 3: "communication, learning and siblings"
        case 4: "home, roots and family"
        case 5: "creativity, romance and joy"
        case 6: "work, health and daily rituals"
        case 7: "partnership and close relationships"
        case 8: "intimacy, shared money, and deep change"
        case 9: "beliefs, travel, and learning"
        case 10: "career, reputation, and public life"
        case 11: "friends, community, and future hopes"
        default: "time alone, hidden feelings, and rest"
        }
    }

    static func roman(_ number: Int) -> String {
        ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"][(number - 1) % 12]
    }

    static func ordinal(_ number: Int) -> String {
        switch number {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(number)th"
        }
    }

    struct EssentialDignity {
        /// Home sign, Exalted, Unfamiliar, Fall, or Neutral.
        let name: String
        let text: String
    }

    /// Essential dignity of a classical planet. Neutral means no extra strength or weakness.
    static func dignityStatus(of planet: Planet, in sign: ZodiacSign) -> EssentialDignity {
        let domicile: [Planet: [ZodiacSign]] = [
            .sun: [.leo], .moon: [.cancer], .mercury: [.gemini, .virgo], .venus: [.taurus, .libra],
            .mars: [.aries, .scorpio], .jupiter: [.sagittarius, .pisces], .saturn: [.capricorn, .aquarius]
        ]
        let exaltation: [Planet: ZodiacSign] = [
            .sun: .aries, .moon: .taurus, .mercury: .virgo, .venus: .pisces,
            .mars: .capricorn, .jupiter: .cancer, .saturn: .libra
        ]
        if domicile[planet]?.contains(sign) == true {
            return EssentialDignity(name: "Home sign", text: "\(planet.name) is in its own sign, so this part of you works easily and with confidence.")
        }
        if exaltation[planet] == sign {
            return EssentialDignity(name: "Exalted", text: "\(planet.name) is exalted in \(sign.name). That means it is at its best here.")
        }
        if domicile[planet]?.contains(sign.opposite) == true {
            return EssentialDignity(name: "Unfamiliar", text: "\(planet.name) is in an unfamiliar sign. It takes more effort, and that effort can become a skill.")
        }
        if exaltation[planet] == sign.opposite {
            return EssentialDignity(name: "Fall", text: "\(planet.name) is in fall in \(sign.name). It develops slowly. Be patient with this part of yourself.")
        }
        return EssentialDignity(
            name: "Neutral",
            text: "\(planet.name) in \(sign.name) has no extra strength and no extra weakness. It simply uses the sign's style."
        )
    }

    /// Essential dignity note, if the planet is in a sign of strength or challenge.
    static func dignity(of planet: Planet, in sign: ZodiacSign) -> String? {
        let status = dignityStatus(of: planet, in: sign)
        return status.name == "Neutral" ? nil : status.text
    }

    static func aspectSentence(_ kind: AspectKind, _ first: Planet, _ second: Planet) -> String {
        let pair = "your \(first.meaning) and your \(second.meaning)"
        return switch kind {
        case .conjunction: "\(pair.capitalizedFirst) act as one."
        case .sextile: "\(pair.capitalizedFirst) help each other when you take a small step."
        case .square: "\(pair.capitalizedFirst) pull in different directions. The friction can make you stronger if you don't ignore it."
        case .trine: "\(pair.capitalizedFirst) work together easily."
        case .opposition: "\(pair.capitalizedFirst) sit on opposite sides. The task is to use both."
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
