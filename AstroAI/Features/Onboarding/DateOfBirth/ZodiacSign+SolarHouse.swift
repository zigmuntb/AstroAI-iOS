//
//  ZodiacSign+SolarHouse.swift
//  AstroAI
//

import Foundation

/// Natural (whole-sign) house of each sign, shown on the date of birth step.
extension ZodiacSign {
    var solarHouseName: String {
        let names = ["First", "Second", "Third", "Fourth", "Fifth", "Sixth",
                     "Seventh", "Eighth", "Ninth", "Tenth", "Eleventh", "Twelfth"]
        let index = ZodiacSign.allCases.firstIndex(of: self) ?? 0
        return "\(names[index]) House"
    }

    var solarHouseTheme: String {
        switch self {
        case .aries: "Self & Initiative"
        case .taurus: "Value & Resources"
        case .gemini: "Mind & Communication"
        case .cancer: "Home & Roots"
        case .leo: "Creativity & Joy"
        case .virgo: "Craft & Ritual"
        case .libra: "Partnership & Balance"
        case .scorpio: "Depth & Transformation"
        case .sagittarius: "Expansion & Philosophy"
        case .capricorn: "Vocation & Legacy"
        case .aquarius: "Community & Vision"
        case .pisces: "Dreams & Solitude"
        }
    }
}
