//
//  Interest+Display.swift
//  AstroAI
//

import Foundation

extension Interest {
    var title: String {
        switch self {
        case .love: "Love & relationships"
        case .career: "Career & ambition"
        case .selfDiscovery: "Self-discovery"
        case .emotions: "Emotional patterns"
        case .growth: "Personal growth"
        case .dailyGuidance: "Daily guidance"
        case .friendship: "Friendship & compatibility"
        }
    }

    var subtitle: String {
        switch self {
        case .love: "Synastry chords & 7th house alignments"
        case .career: "Midheaven vocation & Saturnian cycles"
        case .selfDiscovery: "Primal solar identity & rising mask"
        case .emotions: "Lunar rhythms & sub-conscious tides"
        case .growth: "Jupiterian expansion & nodal destiny"
        case .dailyGuidance: "Hour-by-hour aspect micro-transits"
        case .friendship: "11th house community & collective bonds"
        }
    }

    var symbol: String {
        switch self {
        case .love: "heart"
        case .career: "safari"
        case .selfDiscovery: "brain.head.profile"
        case .emotions: "drop"
        case .growth: "leaf"
        case .dailyGuidance: "sunrise"
        case .friendship: "person.2"
        }
    }
}
