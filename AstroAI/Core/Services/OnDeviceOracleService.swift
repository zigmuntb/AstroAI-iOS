//
//  OnDeviceOracleService.swift
//  AstroAI
//

import Foundation
import FoundationModels
import OSLog

private let logger = Logger(subsystem: "com.BogdanArsenkin.AstroAI", category: "Oracle")

/// AI astrologer dialogue powered by the on-device Apple Intelligence model.
/// Works offline; requires an Apple Intelligence capable device.
final class OnDeviceOracleService: OracleServicing {
    private let model = SystemLanguageModel.default
    private var session: LanguageModelSession
    private var usedToday = 0
    private let dailyLimit = 3

    /// How many recent messages are carried over when the context window overflows.
    private let carriedOverMessages = 4

    /// The model may still be downloading or Apple Intelligence may be turned off;
    /// that is checked per request, so only device eligibility matters here.
    static var isSupported: Bool {
        if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability { return false }
        return true
    }

    init() {
        session = Self.makeSession(history: [])
        session.prewarm()
    }

    var quota: OracleQuota { OracleQuota(used: usedToday, limit: dailyLimit) }
    var suggestions: [String] { MockData.oracleSuggestions }
    var requiresNetwork: Bool { false }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error> {
        .run { [self] continuation in
            guard isPremium || quota.remaining > 0 else { throw OracleError.limitReached }
            guard model.isAvailable else { throw OracleError.modelUnavailable }

            let id = UUID()
            let date = Date()
            let emit = { (text: String) in
                _ = continuation.yield(ChatMessage(id: id, role: .oracle, text: text, date: date))
            }

            do {
                try await streamAnswer(to: question, emit: emit)
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                session = Self.makeSession(history: Array(history.suffix(carriedOverMessages)))
                try await streamAnswer(to: question, emit: emit)
            } catch LanguageModelSession.GenerationError.guardrailViolation {
                continuation.yield(ChatMessage(
                    id: id,
                    role: .oracle,
                    text: "The stars are silent on this one. Let's turn to another question about your path.",
                    title: "A veiled answer",
                    date: date
                ))
                return
            }

            usedToday += 1
        }
    }

    func resetSession() {
        session = Self.makeSession(history: [])
    }

    private func streamAnswer(to question: String, emit: (String) -> Void) async throws {
        do {
            for try await snapshot in session.streamResponse(to: question) {
                emit(snapshot.content.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        } catch let error as LanguageModelSession.GenerationError {
            logger.error("Generation failed: \(String(reflecting: error), privacy: .public)")
            throw Self.map(error)
        }
    }

    private static func map(_ error: LanguageModelSession.GenerationError) -> Error {
        switch error {
        case .assetsUnavailable: OracleError.modelUnavailable
        case .unsupportedLanguageOrLocale: OracleError.unsupportedLanguage
        case .rateLimited, .concurrentRequests: OracleError.busy
        case .exceededContextWindowSize, .guardrailViolation: error
        default: OracleError.generationFailed
        }
    }

    private static func makeSession(history: [ChatMessage]) -> LanguageModelSession {
        let recap = history
            .map { "\($0.role == .user ? "User" : "Oracle"): \($0.text)" }
            .joined(separator: "\n")

        var instructions = """
            You are the AstroAI Oracle — a warm, poetic but grounded astrologer.
            You help the user reflect on their feelings, relationships and life path through the lens of astrology.
            Answer in 2–4 short paragraphs, in the same language the user writes in.
            Do not use markdown headings or lists.
            Never give medical, legal or financial advice; gently suggest a professional instead.
            """
        if !recap.isEmpty {
            instructions += "\n\nRecent conversation:\n\(recap)"
        }
        return LanguageModelSession(instructions: instructions)
    }
}
