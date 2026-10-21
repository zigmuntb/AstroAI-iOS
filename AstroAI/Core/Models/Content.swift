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
    /// One small thing worth doing. Empty when the reading has nothing specific to add.
    var focus: String = ""
    /// One thing to approach carefully.
    var caution: String = ""
    /// One question to sit with.
    var reflection: String = ""
}

struct LifeArea: Codable, Hashable, Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let text: String
    /// Plain-language astrology for this area. Nil when there is nothing reliable to add.
    var detail: String? = nil
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
    var id: String { "\(title)-\(date)" }
    let glyph: String
    let kind: String
    let date: String
    let title: String
    let detail: String
}

/// The coming week's sky, plus the personal life-cycle forecast Sanctuary unlocks.
struct ExploreLibrary: Codable, Hashable {
    let weekRange: String
    let transits: [Transit]
    /// Saturn returns, solar eclipses and nodal sign changes, earliest first.
    var lifeCycles: [Transit] = []
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
    /// Midpoint chart of the two people. Nil only for older sample data.
    var composite: CompositeReading? = nil
}

/// The relationship as its own chart: midpoints, and whether that chart leans to friction or harmony.
struct CompositeReading: Codable, Hashable {
    let harmony: String
    let summary: String
    let points: [CompositePoint]
}

struct CompositePoint: Codable, Hashable, Identifiable {
    var id: String { name }
    let glyph: String
    let name: String
    let placement: String
}

struct SynastryDimension: Codable, Hashable, Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let badge: String
    let text: String
}

// MARK: - Journal

/// The sky at the moment a journal entry was written.
struct JournalSky: Codable, Hashable {
    var moonPhase: String
    var moonSign: String
    var transit: String?

    var caption: String {
        if moonSign.isEmpty { return moonPhase }
        return "\(moonPhase) · a \(moonSign) mood"
    }
}

struct JournalEntry: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable { case reflection, oracle, bookmark }

    var id = UUID()
    let date: Date
    let kind: Kind
    let context: String
    let quote: String
    let body: String
    let tags: [String]
    /// Nil for entries saved before the sky was kept with the page.
    var sky: JournalSky? = nil
}

// MARK: - Subscription

struct SubscriptionPlan: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let price: String
    let period: String
    var badge: String? = nil
    /// Spoken trial length, such as "1-week". Nil when the plan has no free trial.
    var trial: String? = nil
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
