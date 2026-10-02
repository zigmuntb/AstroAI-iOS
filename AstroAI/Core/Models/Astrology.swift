//
//  Astrology.swift
//  AstroAI
//

import Foundation

enum ZodiacSign: String, CaseIterable, Codable, Identifiable {
    case aries, taurus, gemini, cancer, leo, virgo, libra, scorpio, sagittarius, capricorn, aquarius, pisces

    var id: String { rawValue }
    var name: String { rawValue.capitalized }

    var glyph: String {
        switch self {
        case .aries: "♈"
        case .taurus: "♉"
        case .gemini: "♊"
        case .cancer: "♋"
        case .leo: "♌"
        case .virgo: "♍"
        case .libra: "♎"
        case .scorpio: "♏"
        case .sagittarius: "♐"
        case .capricorn: "♑"
        case .aquarius: "♒"
        case .pisces: "♓"
        }
    }
}

extension ZodiacSign {
    /// Tropical sun sign by calendar date.
    static func sunSign(on date: Date) -> ZodiacSign {
        let parts = Calendar(identifier: .gregorian).dateComponents([.month, .day], from: date)
        let value = (parts.month ?? 1) * 100 + (parts.day ?? 1)
        switch value {
        case 321...419: return .aries
        case 420...520: return .taurus
        case 521...620: return .gemini
        case 621...722: return .cancer
        case 723...822: return .leo
        case 823...922: return .virgo
        case 923...1022: return .libra
        case 1023...1121: return .scorpio
        case 1122...1221: return .sagittarius
        case 120...218: return .aquarius
        case 219...320: return .pisces
        default: return .capricorn
        }
    }

    var element: String {
        switch self {
        case .aries, .leo, .sagittarius: "Fire"
        case .taurus, .virgo, .capricorn: "Earth"
        case .gemini, .libra, .aquarius: "Air"
        case .cancer, .scorpio, .pisces: "Water"
        }
    }
}

enum Planet: String, CaseIterable, Codable, Identifiable {
    case sun, moon, ascendant, mercury, venus, mars, jupiter, saturn, uranus, neptune, pluto, northNode

    var id: String { rawValue }

    var name: String {
        switch self {
        case .ascendant: "Rising"
        case .northNode: "Nodal Axis"
        default: rawValue.capitalized
        }
    }

    var glyph: String {
        switch self {
        case .sun: "☉"
        case .moon: "☽"
        case .ascendant: "↑"
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .jupiter: "♃"
        case .saturn: "♄"
        case .uranus: "♅"
        case .neptune: "♆"
        case .pluto: "♇"
        case .northNode: "☊"
        }
    }
}

enum AspectKind: String, Codable {
    case conjunction, sextile, square, trine, opposition

    var name: String { rawValue.capitalized }

    var degrees: Int {
        switch self {
        case .conjunction: 0
        case .sextile: 60
        case .square: 90
        case .trine: 120
        case .opposition: 180
        }
    }

    var glyph: String {
        switch self {
        case .conjunction: "☌"
        case .sextile: "⚹"
        case .square: "□"
        case .trine: "△"
        case .opposition: "☍"
        }
    }
}

struct PlanetPlacement: Identifiable, Codable, Hashable {
    var id: Planet { planet }
    let planet: Planet
    let sign: ZodiacSign
    /// Degree inside the sign, e.g. "2° 14'".
    let degree: String
    let house: String
    let title: String
    let summary: String
    var detail: String = ""
    var aspectNote: String = ""
    /// Absolute ecliptic longitude 0..<360, used for drawing the wheel.
    var longitude: Double = 0
}

struct NatalChart: Codable, Hashable {
    let placements: [PlanetPlacement]
    let synthesis: String
    let tension: String
    let elements: [ChartShare]
    let modalities: [ChartShare]
    let accuracy: Int

    func placement(_ planet: Planet) -> PlanetPlacement? {
        placements.first { $0.planet == planet }
    }

    var bigThree: [PlanetPlacement] {
        [Planet.sun, .moon, .ascendant].compactMap(placement)
    }

    var otherPlacements: [PlanetPlacement] {
        placements.filter { ![Planet.sun, .moon, .ascendant].contains($0.planet) }
    }
}

struct ChartShare: Codable, Hashable, Identifiable {
    var id: String { name }
    let name: String
    let keyword: String
    let percent: Int
}
