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
    /// Instructions for the current session, so a new question can start a fresh transcript without rebuilding the chart.
    private var sessionInstructions: String?
    /// Data the current session was built with. `guidanceID` changes when Today's recommendation changes.
    private var sessionSnapshot: (profile: UserProfile?, connections: [Connection], day: Date, options: ChartOptions, guidanceID: String)?
    /// Keeps the tool lookups alive for the session.
    private var toolbox: OracleToolbox?

    /// How many recent messages are carried over when the context window overflows.
    private let carriedOverMessages = OraclePrompt.carriedOverMessages

    /// Apple Intelligence can answer, or its model is still downloading.
    /// A phone that cannot run it, or one where it is turned off, uses the downloadable model instead.
    static var isSupported: Bool {
        supports(SystemLanguageModel.default.availability)
    }

    static func supports(_ availability: SystemLanguageModel.Availability) -> Bool {
        switch availability {
        case .available:
            return true
        case .unavailable(let reason):
            switch reason {
            case .modelNotReady:
                return true
            case .deviceNotEligible, .appleIntelligenceNotEnabled:
                return false
            @unknown default:
                return true
            }
        }
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

            let facts = await OraclePrompt.skyFacts(profile: userService.profile, astrology: astrology)
            let prior = OraclePrompt.priorTurns(from: history, question: question)
            let otherDay = await OraclePrompt.otherDay(in: question, profile: userService.profile, astrology: astrology, today: facts.sky.date)
            let prompt = OraclePrompt.turn(
                question,
                model: .appleIntelligence,
                reading: facts.reading,
                otherDay: otherDay,
                profile: userService.profile,
                now: facts.sky.date,
                history: prior
            )
            let id = UUID()
            let date = Date()
            var answer = ""
            let emit = { (text: String) in
                answer = text
                _ = continuation.yield(ChatMessage(id: id, role: .oracle, text: text, date: date))
            }

            do {
                try await streamAnswer(to: prompt, in: activeSession(question: question, history: prior, facts: facts), emit: emit)
            } catch LanguageModelSession.GenerationError.exceededContextWindowSize {
                let carried = OraclePrompt.continuesConversation(question, history: prior) ? prior : []
                let session = await makeSession(history: carried, facts: facts)
                try await streamAnswer(to: prompt, in: session, emit: emit)
            } catch LanguageModelSession.GenerationError.guardrailViolation {
                continuation.yield(ChatMessage(
                    id: id,
                    role: .oracle,
                    text: OraclePrompt.unavailableReply,
                    date: date
                ))
                return
            }

            if !isPremium { quotaStore.recordUse() }
            memory.record(question: question, answer: answer)
        }
    }

    func resetSession() {
        session = nil
        sessionInstructions = nil
        sessionSnapshot = nil
        toolbox = nil
    }

    // MARK: - Session

    /// A follow-up stays in the current session. A new question gets a new transcript so the previous reply cannot be copied.
    private func activeSession(question: String, history: [ChatMessage], facts: OraclePrompt.SkyFacts) async -> LanguageModelSession {
        let continuing = OraclePrompt.continuesConversation(question, history: history)
        let sameFacts = sessionSnapshot?.profile == userService.profile
            && sessionSnapshot?.connections == connections.connections()
            && sessionSnapshot?.options == astrology.chartOptions
            && sessionSnapshot?.guidanceID == facts.guidanceID
            && Calendar.current.isDateInToday(sessionSnapshot?.day ?? .distantPast)
        if continuing, let session, sameFacts {
            return session
        }
        if !continuing, sameFacts, let sessionInstructions, let toolbox {
            let session = LanguageModelSession(tools: toolbox.tools, instructions: sessionInstructions)
            self.session = session
            return session
        }
        let carried = continuing ? Array(history.suffix(carriedOverMessages)) : []
        return await makeSession(history: carried, facts: facts)
    }

    private func makeSession(history: [ChatMessage], facts: OraclePrompt.SkyFacts) async -> LanguageModelSession {
        let material = await OraclePrompt.make(
            userService: userService,
            astrology: astrology,
            connections: connections,
            journal: journal,
            memory: memory,
            history: history,
            model: .appleIntelligence,
            facts: facts
        )
        let session = LanguageModelSession(tools: material.toolbox.tools, instructions: material.instructions)
        self.session = session
        self.sessionInstructions = material.instructions
        self.toolbox = material.toolbox
        sessionSnapshot = (material.profile, material.connections, material.date, material.options, material.guidanceID)
        return session
    }

    // MARK: - Generation

    private func streamAnswer(to question: String, in session: LanguageModelSession, emit: (String) -> Void) async throws {
        do {
            for try await snapshot in session.streamResponse(to: question) {
                emit(OraclePrompt.deliver(snapshot.content))
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
