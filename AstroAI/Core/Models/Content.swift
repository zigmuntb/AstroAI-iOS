//
//  Content.swift
//  AstroAI
//

import Foundation

// MARK: - Today

struct DailyReading: Codable, Hashable {
    let date: Date
    let moonPhase: String
    let moonSign: ZodiacSign
    let moonIllumination: Int
    let atmosphere: String
    let ephemerisTitle: String
    let ephemerisText: String
    let transitLine: String
    let orb: String
    let synthesisTitle: String
    let synthesisText: String
    let imageCaption: String
    let areas: [LifeArea]
    let tendencies: [Tendency]
    /// Paired daily leans. `value` runs from 0 (entirely `left`) to 100 (entirely `right`).
    let dials: [LifeDial]
    let luckyNumbers: LuckyNumbers
    let moods: [String]
    let oracleQuestions: [String]
}

struct LifeArea: Codable, Hashable, Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let text: String
}

struct Tendency: Codable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let value: String
    /// 0...1
    let level: Double
}

/// One axis of the day: two opposite pulls that share a single 0...100 scale.
struct LifeDial: Codable, Hashable, Identifiable {
    let id: String
    let left: String
    let right: String
    let leftIcon: String
    let rightIcon: String
    /// 0 is entirely `left`. 100 is entirely `right`. The two scores add up to 100.
    let value: Int
    let note: String
}

/// Five numbers for the civil day. The first is the personal day and is shown apart from the rest.
struct LuckyNumbers: Codable, Hashable {
    let values: [Int]
    let personalDay: Int
    let note: String
}

// MARK: - Explore

struct Transit: Codable, Hashable, Identifiable {
    var id: String { title }
    let glyph: String
    let kind: String
    let date: String
    let title: String
    let detail: String
}

struct Article: Codable, Hashable, Identifiable {
    var id: String { title }
    let glyph: String
    let eyebrow: String
    let meta: String
    let title: String
    let summary: String
}

struct ExploreLibrary: Codable, Hashable {
    let featured: Article
    let weekRange: String
    let transits: [Transit]
    let tomes: [Article]
}

// MARK: - Oracle

struct ChatMessage: Codable, Hashable, Identifiable {
    enum Role: String, Codable { case user, oracle }

    var id = UUID()
    let role: Role
    let text: String
    var title: String? = nil
    var transitNote: String? = nil
    var date = Date()
}

struct OracleQuota: Codable, Hashable {
    let used: Int
    let limit: Int
    var remaining: Int { max(limit - used, 0) }
}

// MARK: - Connections

enum Kinship: String, CaseIterable, Codable, Identifiable {
    case romantic, creative, friendship, family
    var id: String { rawValue }
}

struct Connection: Codable, Hashable, Identifiable {
    var id = UUID()
    let name: String
    let kinship: Kinship
    let birth: BirthData
}

struct SynastryReport: Codable, Hashable {
    let title: String
    let subtitle: String
    let harmony: String
    let quote: String
    let summary: String
    let dimensions: [SynastryDimension]
    let questions: [String]
}

struct SynastryDimension: Codable, Hashable, Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let badge: String
    let text: String
}

// MARK: - Journal

struct JournalEntry: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable { case reflection, oracle, bookmark }

    var id = UUID()
    let date: Date
    let kind: Kind
    let context: String
    let quote: String
    let body: String
    let tags: [String]
}

// MARK: - Subscription

struct SubscriptionPlan: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let price: String
    let period: String
    var badge: String? = nil
}

// MARK: - Settings

struct Preferences: Codable, Hashable {
    var houseSystem = "Placidus"
    var zodiac = "Tropical"
    var lunarNode = "True"
    var morningAttunement = true
    var exactAspects = true
    var lunarPhases = false
    var quietWindow = true
}
