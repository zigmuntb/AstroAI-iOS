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
        case .sun: "core identity and vitality"
        case .moon: "emotional needs and inner security"
        case .ascendant: "first impression and approach to life"
        case .mercury: "mind and way of communicating"
        case .venus: "way of loving and sense of beauty"
        case .mars: "drive, desire and courage"
        case .jupiter: "faith, growth and good fortune"
        case .saturn: "discipline, limits and long-term mastery"
        case .uranus: "need for freedom and originality"
        case .neptune: "dreams, intuition and longing for transcendence"
        case .pluto: "power to transform and regenerate"
        case .northNode: "evolutionary direction"
        }
    }

    /// Closing words of a placement title, e.g. "at the Core".
    var titleSuffix: String {
        switch self {
        case .sun: "at the Core"
        case .moon: "in the Heart"
        case .ascendant: "on the Threshold"
        case .mercury: "in the Mind"
        case .venus: "in Love"
        case .mars: "in Action"
        case .jupiter: "in Growth"
        case .saturn: "in Mastery"
        case .uranus: "in Awakening"
        case .neptune: "in Dreams"
        case .pluto: "in Rebirth"
        case .northNode: "as Destiny"
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
        case .aries: "bold, direct and pioneering"
        case .taurus: "steady, sensual and patient"
        case .gemini: "curious, quick and versatile"
        case .cancer: "protective, intuitive and nurturing"
        case .leo: "warm, expressive and generous"
        case .virgo: "precise, devoted and discerning"
        case .libra: "graceful, fair-minded and relational"
        case .scorpio: "intense, private and transformative"
        case .sagittarius: "adventurous, candid and philosophical"
        case .capricorn: "ambitious, disciplined and enduring"
        case .aquarius: "original, independent and visionary"
        case .pisces: "empathic, imaginative and fluid"
        }
    }

    var archetype: String {
        switch self {
        case .aries: "Courage & Initiative"
        case .taurus: "Steadiness & Sensual Grounding"
        case .gemini: "Curiosity & Quicksilver Wit"
        case .cancer: "Nurture & Emotional Memory"
        case .leo: "Radiance & Creative Heart"
        case .virgo: "Precision & Devoted Craft"
        case .libra: "Harmony & Relational Grace"
        case .scorpio: "Depth & Transformation"
        case .sagittarius: "Expansion & Searching Spirit"
        case .capricorn: "Ambition & Enduring Structure"
        case .aquarius: "Originality & Collective Vision"
        case .pisces: "Empathy & Boundless Imagination"
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
    static let elementKeywords = ["Fire": "Vitality", "Earth": "Pragmatism", "Air": "Intellect", "Water": "Intuition"]
    static let modalityKeywords = ["Cardinal": "Initiating", "Fixed": "Enduring", "Mutable": "Adaptable"]

    static func houseTheme(_ house: Int) -> String {
        switch house {
        case 1: "self-image, body and personal presence"
        case 2: "money, possessions and self-worth"
        case 3: "communication, learning and siblings"
        case 4: "home, roots and family"
        case 5: "creativity, romance and joy"
        case 6: "work, health and daily rituals"
        case 7: "partnership and close relationships"
        case 8: "intimacy, shared resources and transformation"
        case 9: "philosophy, travel and higher learning"
        case 10: "career, reputation and public life"
        case 11: "friendship, community and future hopes"
        default: "solitude, the unconscious and spiritual retreat"
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
        /// Domicile, Exalted, Detriment, Fall or Peregrine.
        let name: String
        let text: String
    }

    /// Essential dignity of a classical planet. Peregrine means no special strength or weakness.
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
            return EssentialDignity(name: "Domicile", text: "In its own sign, \(planet.name) works with natural ease and authority here.")
        }
        if exaltation[planet] == sign {
            return EssentialDignity(name: "Exalted", text: "Exalted in \(sign.name), \(planet.name) expresses its finest qualities.")
        }
        if domicile[planet]?.contains(sign.opposite) == true {
            return EssentialDignity(name: "Detriment", text: "In detriment here, \(planet.name) has to work in unfamiliar ways, which builds unusual skill.")
        }
        if exaltation[planet] == sign.opposite {
            return EssentialDignity(name: "Fall", text: "In fall here, \(planet.name) matures slowly and asks for self-compassion.")
        }
        return EssentialDignity(
            name: "Peregrine",
            text: "Peregrine in \(sign.name), \(planet.name) borrows the sign's manner without the authority of rulership."
        )
    }

    /// Essential dignity note, if the planet is in a sign of strength or challenge.
    static func dignity(of planet: Planet, in sign: ZodiacSign) -> String? {
        let status = dignityStatus(of: planet, in: sign)
        return status.name == "Peregrine" ? nil : status.text
    }

    static func aspectSentence(_ kind: AspectKind, _ first: Planet, _ second: Planet) -> String {
        let pair = "your \(first.meaning) and your \(second.meaning)"
        return switch kind {
        case .conjunction: "\(pair.capitalizedFirst) are fused into one force."
        case .sextile: "\(pair.capitalizedFirst) support each other through easy opportunities."
        case .square: "\(pair.capitalizedFirst) pull against each other, building strength through friction."
        case .trine: "\(pair.capitalizedFirst) flow together with natural ease."
        case .opposition: "\(pair.capitalizedFirst) seek balance across a polarity."
        }
    }
}

private extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
