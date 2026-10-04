//
//  TransitText.swift
//  AstroAI
//

import Foundation

extension NatalTransit {
    var verb: String {
        switch kind {
        case .conjunction: "meets"
        case .sextile: "gently supports"
        case .square: "challenges"
        case .trine: "harmonizes with"
        case .opposition: "faces"
        }
    }

    /// "Transiting Venus meets your natal Neptune, touching your dreams, intuition and longing for transcendence."
    var sentence: String {
        "Transiting \(transiting.name) \(verb) your natal \(natal.name), touching your \(natal.meaning)."
    }

    /// "Transit ♀ Venus ☌ Natal ♆ Neptune • 0° 06' orb"
    var note: String {
        "Transit \(transiting.glyph) \(transiting.name) \(kind.glyph) Natal \(natal.glyph) \(natal.name) • \(NatalChartCalculator.formatDegrees(orb)) orb"
    }

    var orbBadge: String {
        if orb < 1 { return "Exacting Orb" }
        return isApplying ? "Applying" : "Separating"
    }
}

extension SkySnapshot {
    /// The most meaningful transit right now: the Moon moves too fast to headline.
    var keyTransit: NatalTransit? {
        transits.first { $0.transiting != .moon } ?? transits.first
    }
}
