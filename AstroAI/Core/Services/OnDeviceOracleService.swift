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
    private let userService: UserServicing
    private let astrology: AstrologyServicing
    private let connections: ConnectionsServicing
    private let journal: JournalServicing
    private let memory: OracleMemoryStoring
    private let quotaStore: OracleQuotaStoring

    /// Created lazily so it always carries the latest profile, chart, sky and connections.
    private var session: LanguageModelSession?
    /// Data the current session was built with.
    private var sessionSnapshot: (profile: UserProfile?, connections: [Connection], day: Date, options: ChartOptions)?
    /// Keeps the tool lookups alive for the session.
    private var toolbox: OracleToolbox?

    /// How many recent messages are carried over when the context window overflows.
    private let carriedOverMessages = OraclePrompt.carriedOverMessages

    /// The model may still be downloading or Apple Intelligence may be turned off;
    /// that is checked per request, so only device eligibility matters here.
    static var isSupported: Bool {
        if case .unavailable(.deviceNotEligible) = SystemLanguageModel.default.availability { return false }
        return true
    }

    init(
        userService: UserServicing,
        astrology: AstrologyServicing,
        connections: ConnectionsServicing,
        journal: JournalServicing,
        memory: OracleMemoryStoring,
        quotaStore: OracleQuotaStoring
    ) {
        self.userService = userService
        self.astrology = astrology
        self.connections = connections
        self.journal = journal
        self.memory = memory
        self.quotaStore = quotaStore
    }

    var quota: OracleQuota { quotaStore.quota }
    var requiresNetwork: Bool { false }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error> {
        .run { [self] continuation in
            guard isPremium || quota.remaining > 0 else { throw OracleError.limitReached }
            guard model.isAvailable else { throw OracleError.modelUnavailable }

            let history = history.last?.text == question ? Array(history.dropLast()) : history
            let id = UUID()
            let date = Date()
            var answer = ""
            let emit = { (text: String) in
                answer = text
                _ = continuation.yield(ChatMessage(id: id, role: .oracle, text: text, date: date))
            }

            do {
                try await streamAnswer(to: question, in: activeSession(history: history), emit: emit)
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                let session = await makeSession(history: Array(history.suffix(carriedOverMessages)))
                try await streamAnswer(to: question, in: session, emit: emit)
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

            quotaStore.recordUse()
            memory.record(question: question, answer: answer)
        }
    }

    func resetSession() {
        session = nil
        sessionSnapshot = nil
        toolbox = nil
    }

    // MARK: - Session

    /// Reuses the current session unless the user's data changed since it was created.
    private func activeSession(history: [ChatMessage]) async -> LanguageModelSession {
        if let session, let sessionSnapshot,
           sessionSnapshot.profile == userService.profile,
           sessionSnapshot.connections == connections.connections(),
           sessionSnapshot.options == astrology.chartOptions,
           Calendar.current.isDateInToday(sessionSnapshot.day) {
            return session
        }
        return await makeSession(history: session == nil ? [] : Array(history.suffix(carriedOverMessages)))
    }

    private func makeSession(history: [ChatMessage]) async -> LanguageModelSession {
        let material = await OraclePrompt.make(
            userService: userService,
            astrology: astrology,
            connections: connections,
            journal: journal,
            memory: memory,
            history: history,
            offersTools: true
        )
        let session = LanguageModelSession(tools: material.toolbox.tools, instructions: material.instructions)
        self.session = session
        self.toolbox = material.toolbox
        sessionSnapshot = (material.profile, material.connections, material.date, material.options)
        return session
    }

    // MARK: - Generation

    private func streamAnswer(to question: String, in session: LanguageModelSession, emit: (String) -> Void) async throws {
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
}
