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
        case .understandMyself: "Explore psychological roots and unconscious patterns."
        case .navigateRelationship: "Understand relational geometry and communication styles."
        case .clarityDuringChange: "Ground during major planetary transits and transitions."
        case .exploreStrengths: "Unpack vocational dignities and natural creative channels."
        case .dailyHabits: "Align somatic rhythm with diurnal lunar cycles."
        case .discoverChart: "Learn foundational astrology at your own pace."
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
