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
        case .love: "Conversations, closeness, and what a relationship needs."
        case .career: "Focus, priorities, and decisions about work."
        case .selfDiscovery: "How you tend to show up, in ordinary language."
        case .emotions: "Mood, patience, and what helps you feel steady."
        case .growth: "What you might be ready to practice next."
        case .dailyGuidance: "A short take on the day, and one thing to do."
        case .friendship: "Friends, family, and how you get along."
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
