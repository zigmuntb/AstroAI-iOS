//
//  ExploreCopyPolisher.swift
//  AstroAI
//
//  Rewrites Explore drafts with the on-device Apple Intelligence model.
//  The drafts already carry the meaning. A failure leaves them untouched.
//

import Foundation
import FoundationModels

protocol ExploreCopyPolishing: AnyObject {
    func polish(_ drafts: [ExploreDraft]) async -> ExplorePolishOutcome
}

/// Used when Apple Intelligence is off, busy, or rejects the rewrite.
final class UnavailableExplorePolisher: ExploreCopyPolishing {
    func polish(_ drafts: [ExploreDraft]) async -> ExplorePolishOutcome { .unavailable }
}

/// On-device rewrite. Does not use the Oracle quota or the network.
final class FoundationExplorePolisher: ExploreCopyPolishing {
    private let model = SystemLanguageModel.default

    func polish(_ drafts: [ExploreDraft]) async -> ExplorePolishOutcome {
        let drafts = Array(drafts.prefix(8)).filter { !$0.summary.isEmpty }
        guard !drafts.isEmpty else { return .unchanged }
        guard model.isAvailable else { return .unavailable }
        do {
            let session = LanguageModelSession(model: model, instructions: Self.instructions)
            let response = try await session.respond(to: Self.prompt(drafts), generating: ExplorePolishBatch.self)
            return Self.accepted(response.content.lines, drafts: drafts)
        } catch {
            return .unchanged
        }
    }

    private static let instructions = """
        You rewrite short personal recommendations for an astrology app. The reader does not know astrology.
        Keep the same practical meaning as each draft. Do not add events, dates, people, numbers, or outcomes.
        Do not mention planets, signs, houses, eclipses, or any astrology word.
        Sound like a thoughtful person who knows this individual's situation. No horoscope clichés, no "the universe", no identical openings.
        Two or three sentences. Keep the suggestion and the caution that are already in the draft.
        Do not promise what will happen. Do not give medical, legal, or financial advice.
        """

    private static func prompt(_ drafts: [ExploreDraft]) -> String {
        let body = drafts.map { "id: \($0.id)\ndraft: \($0.summary)" }.joined(separator: "\n\n")
        return """
            Rewrite each draft. Copy each id exactly. Return one line per id and no others.

            \(body)
            """
    }

    private static func accepted(_ lines: [ExplorePolishLine], drafts: [ExploreDraft]) -> ExplorePolishOutcome {
        let byID = Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, $0.summary) })
        var summaries: [String: String] = [:]
        for line in lines {
            guard let draft = byID[line.id] else { continue }
            let text = line.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard ExploreLanguage.acceptsRewrite(text, of: draft) else { continue }
            summaries[line.id] = text
        }
        let unique = ExploreLanguage.withoutRepeatedOpenings(summaries, drafts: drafts)
        return unique.isEmpty ? .unchanged : .summaries(unique)
    }
}

@Generable
nonisolated struct ExplorePolishBatch {
    @Guide(description: "One rewritten recommendation for each draft, using the same ids.")
    var lines: [ExplorePolishLine]
}

@Generable
nonisolated struct ExplorePolishLine {
    @Guide(description: "The draft id, copied exactly.")
    var id: String
    @Guide(description: "Two or three plain sentences with the same meaning as the draft. No astrology words.")
    var text: String
}
