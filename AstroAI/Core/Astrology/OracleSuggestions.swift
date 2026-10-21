//
//  OracleSuggestions.swift
//  AstroAI
//

import Foundation

/// A few everyday questions. The chart chooses which situations to offer, not the wording.
enum OracleSuggestions {
    static func make(chart: NatalChart?, sky: SkySnapshot?, interests: Set<Interest>) -> [String] {
        var questions: [String] = []
        let transit = sky.map { EverydayVoice.supportedTransit(chart: chart, sky: $0) } ?? nil

        if interests.contains(.love) || transit?.natal == .venus || transit?.natal == .moon {
            questions.append("Why might someone close to me seem distant today?")
        }
        if interests.contains(.career) || transit?.natal == .saturn || transit?.natal == .sun || transit?.natal == .mars {
            questions.append("What should I focus on at work today?")
        }
        if interests.contains(.emotions) || transit?.natal == .moon {
            questions.append("Why am I feeling this way today?")
        }
        if interests.contains(.friendship) {
            questions.append("Should I reach out to a friend I've been meaning to talk to?")
        }
        if interests.contains(.dailyGuidance) || interests.contains(.growth) || interests.contains(.selfDiscovery) {
            questions.append("What can I do to feel more confident today?")
        }

        questions.append(contentsOf: [
            "Is today a good day to talk about something important?",
            "How should I approach a difficult conversation?",
            "Is this a good day to make an important decision?",
            "What should I focus on today?",
            "Why do I keep overthinking this?"
        ])

        var seen = Set<String>()
        return Array(questions.filter { seen.insert($0).inserted }.prefix(3))
    }
}
