//
//  JournalService.swift
//  AstroAI
//

import Foundation

/// A repeat the journal can see once a few entries share a Moon or a transit.
struct JournalPattern: Hashable, Identifiable {
    var id: String { title }
    let title: String
    let detail: String
}

protocol JournalServicing {
    var prompt: JournalPrompt { get }
    /// "Scorpio Moon · Waxing Crescent", from the sky right now.
    var skyLine: String { get }

    func entries() -> [JournalEntry]
    func patterns() -> [JournalPattern]
    func add(_ entry: JournalEntry)
}

struct JournalPrompt: Hashable {
    let context: String
    let question: String
    let note: String
}

/// Personal journal stored on device. Will sync to Supabase later.
final class JournalService: JournalServicing {
    private let storage: StorageManaging
    private let astrology: AstrologyServicing
    private let userService: UserServicing

    init(storage: StorageManaging, astrology: AstrologyServicing, userService: UserServicing) {
        self.storage = storage
        self.astrology = astrology
        self.userService = userService
    }

    var prompt: JournalPrompt { astrology.journalPrompt(for: userService.profile) }

    var skyLine: String {
        let sky = astrology.sky(at: .now, natal: nil)
        let sign = sky.position(of: .moon)?.sign.name ?? "Moon"
        return "\(sign) Moon · \(sky.moonPhase.name)"
    }

    func entries() -> [JournalEntry] {
        (storage.load([JournalEntry].self, for: .journal) ?? []).sorted { $0.date > $1.date }
    }

    func patterns() -> [JournalPattern] {
        let cutoff = Date.now.addingTimeInterval(-30 * 86_400)
        let recent = entries().filter { $0.date >= cutoff && $0.sky != nil }
        var patterns: [JournalPattern] = []
        let byMoon = Dictionary(grouping: recent) { $0.sky?.moonSign ?? "" }
        for (sign, group) in byMoon where group.count >= 2 && !sign.isEmpty {
            patterns.append(JournalPattern(title: "Moon in \(sign)", detail: moonDetail(group)))
        }
        let byTransit = Dictionary(grouping: recent.filter { !($0.sky?.transit ?? "").isEmpty }) { $0.sky?.transit ?? "" }
        for (transit, group) in byTransit where group.count >= 2 {
            patterns.append(JournalPattern(title: transit, detail: "\(group.count) entries share this transit."))
        }
        return Array(patterns.prefix(3))
    }

    func add(_ entry: JournalEntry) {
        var entry = entry
        if entry.sky == nil { entry.sky = currentSky() }
        let saved = storage.load([JournalEntry].self, for: .journal) ?? []
        storage.save(saved + [entry], for: .journal)
    }

    private func currentSky() -> JournalSky {
        let chart = userService.profile.map { NatalChartCalculator.chart(for: $0.birth, options: astrology.chartOptions) }
        let sky = astrology.sky(at: .now, natal: chart)
        return JournalSky(
            moonPhase: sky.moonPhase.name,
            moonSign: sky.position(of: .moon)?.sign.name ?? "",
            transit: sky.keyTransit?.title
        )
    }

    private func moonDetail(_ group: [JournalEntry]) -> String {
        var counts: [String: Int] = [:]
        for entry in group {
            let words = Set((Self.words(in: entry.quote) + Self.words(in: entry.body)).filter { $0.count >= 4 && !Self.stopwords.contains($0) })
            for word in words { counts[word, default: 0] += 1 }
        }
        if let repeated = counts.filter({ $0.value >= 2 }).max(by: { $0.value < $1.value }) {
            return "You mentioned \(repeated.key) in \(repeated.value) of \(group.count) reflections under this Moon."
        }
        return "\(group.count) reflections landed under this Moon."
    }

    private static func words(in text: String) -> [String] {
        text.lowercased().split { !$0.isLetter }.map(String.init)
    }

    private static let stopwords: Set<String> = [
        "that", "this", "with", "from", "your", "you", "about", "have", "been", "were", "they", "their",
        "what", "when", "feel", "feels", "feeling", "like", "just", "into", "over", "than", "then", "them",
        "because", "today", "tonight", "really", "something", "would", "could", "should", "there", "more",
        "only", "under", "after", "before", "again", "still", "moon", "chart", "transit", "want", "need",
        "know", "think", "going", "being", "very", "much", "some", "will", "dont", "can't", "cant"
    ]
}
