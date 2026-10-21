//
//  Intention+Display.swift
//  AstroAI
//

import Foundation

extension Intention {
    var title: String {
        switch self {
        case .understandMyself: "Understand myself better"
        case .navigateRelationship: "Navigate a relationship"
        case .clarityDuringChange: "Find clarity during change"
        case .exploreStrengths: "Explore my strengths"
        case .dailyHabits: "Build better daily habits"
        case .discoverChart: "Simply discover my birth chart"
        }
    }

    var subtitle: String {
        switch self {
        case .understandMyself: "See your patterns in plain language."
        case .navigateRelationship: "Get a calmer read on a relationship."
        case .clarityDuringChange: "A steadier view when life is shifting."
        case .exploreStrengths: "Notice what you already do well."
        case .dailyHabits: "Small, practical ideas for the day."
        case .discoverChart: "Look at the astrology when you are curious."
        }
    }

    var symbol: String {
        switch self {
        case .understandMyself: "brain.head.profile"
        case .navigateRelationship: "heart"
        case .clarityDuringChange: "safari"
        case .exploreStrengths: "sun.max"
        case .dailyHabits: "moon"
        case .discoverChart: "book"
        }
    }
}
