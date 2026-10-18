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
        case .creative: "Creative"
        case .friendship: "Deep Friendship"
        case .family: "Family"
        }
    }

    var caption: String {
        switch self {
        case .romantic: "Love and desire"
        case .creative: "How you think together"
        case .friendship: "Friends and shared plans"
        case .family: "Home and family"
        }
    }

    /// Relationship label, e.g. "Romantic Partnership".
    var relationLabel: String {
        switch self {
        case .romantic: "Romantic Partnership"
        case .creative: "Creative Collaboration"
        case .friendship: "Deep Friendship"
        case .family: "Family"
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
