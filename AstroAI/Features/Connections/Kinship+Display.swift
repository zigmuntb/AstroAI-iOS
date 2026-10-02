//
//  Kinship+Display.swift
//  AstroAI
//

import Foundation

extension Kinship {
    /// Short title used in the kinship grid.
    var title: String {
        switch self {
        case .romantic: "Romantic"
        case .creative: "Creative Kin"
        case .friendship: "Deep Friendship"
        case .family: "Family & Ancestry"
        }
    }

    var caption: String {
        switch self {
        case .romantic: "Venusian & Mars chords"
        case .creative: "Mercurial synergy"
        case .friendship: "11th House resonance"
        case .family: "4th House roots"
        }
    }

    /// Relationship label, e.g. "Romantic Partnership".
    var relationLabel: String {
        switch self {
        case .romantic: "Romantic Partnership"
        case .creative: "Creative Collaboration"
        case .friendship: "Deep Friendship"
        case .family: "Family & Ancestry"
        }
    }

    var icon: String {
        switch self {
        case .romantic: "heart"
        case .creative: "brain.head.profile"
        case .friendship: "infinity"
        case .family: "house"
        }
    }
}

extension Connection {
    var sunSign: ZodiacSign { .sunSign(on: birth.date) }
}
