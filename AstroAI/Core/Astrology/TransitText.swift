//
//  TransitText.swift
//  AstroAI
//

import Foundation

extension NatalTransit {
    var verb: String {
        switch kind {
        case .conjunction: "meets"
        case .sextile: "supports"
        case .square: "challenges"
        case .trine: "flows with"
        case .opposition: "opposes"
        }
    }

    /// "Venus in the sky meets your natal Neptune. This is about your dreams and intuition."
    var sentence: String {
        "\(transiting.name) in the sky \(verb) your natal \(natal.name). This is about your \(natal.meaning)."
    }

    /// "Transit ♀ Venus ☌ Natal ♆ Neptune • 0° 06' orb"
    var note: String {
        "Transit \(transiting.glyph) \(transiting.name) \(kind.glyph) Natal \(natal.glyph) \(natal.name) • \(NatalChartCalculator.formatDegrees(orb)) orb"
    }

    var orbBadge: String {
        if orb < 1 { return "Exact" }
        return isApplying ? "Getting closer" : "Moving apart"
    }
}

extension SkySnapshot {
    /// The most meaningful transit right now: the Moon moves too fast to headline.
    var keyTransit: NatalTransit? {
        transits.first { $0.transiting != .moon } ?? transits.first
    }
}
