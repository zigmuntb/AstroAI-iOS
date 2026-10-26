//
//  LocalModelOracleService.swift
//  AstroAI
//

import Foundation
import FoundationModels
import HuggingFace
import MLX
import MLXHuggingFace
import MLXLLM
import MLXLMCommon
import OSLog
import Tokenizers

nonisolated private let logger = Logger(subsystem: "com.BogdanArsenkin.AstroAI", category: "Oracle")

/// Shown when the on-device fallback model still has to be downloaded.
struct OracleModelInstall: Equatable {
    /// Rough download size, for example "about 400 MB".
    let sizeDescription: String
    /// Apple Intelligence can run on this phone, but the user has not turned it on.
    let appleIntelligenceIsOff: Bool
}

/// Oracle when Apple Intelligence is off or the phone cannot run it.
///
/// Downloads a small open model once, then answers fully on device.
final class LocalModelOracleService: OracleServicing {
    private let userService: UserServicing
    private let astrology: AstrologyServicing
    private let connections: ConnectionsServicing
    private let journal: JournalServicing
    private let memory: OracleMemoryStoring
    private let quotaStore: OracleQuotaStoring
    private let storage: StorageManaging
    private let engine = LocalOracleEngine()

    init(
        userService: UserServicing,
        astrology: AstrologyServicing,
        connections: ConnectionsServicing,
        journal: JournalServicing,
        memory: OracleMemoryStoring,
        quotaStore: OracleQuotaStoring,
        storage: StorageManaging
    ) {
        self.userService = userService
        self.astrology = astrology
        self.connections = connections
        self.journal = journal
        self.memory = memory
        self.quotaStore = quotaStore
        self.storage = storage
    }

    var quota: OracleQuota { quotaStore.quota }

    /// Network is required only for the one-time download.
    var requiresNetwork: Bool { modelInstall != nil }

    var modelInstall: OracleModelInstall? {
        guard storage.load(String.self, for: .localOracleModel) == nil else { return nil }
        let turnedOff = SystemLanguageModel.default.availability == .unavailable(.appleIntelligenceNotEnabled)
        return OracleModelInstall(sizeDescription: LocalOracleModel.sizeDescription, appleIntelligenceIsOff: turnedOff)
    }

    func installModel() -> AsyncThrowingStream<Double, Error> {
        let engine = engine
        let storage = storage
        return .run { continuation in
            do {
                let name = try await engine.prepare { continuation.yield($0) }
                storage.save(name, for: .localOracleModel)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                logger.error("Model install failed: \(String(reflecting: error), privacy: .public)")
                throw OracleError.installFailed
            }
        }
    }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error> {
        .run { [self] continuation in
            guard isPremium || quota.remaining > 0 else { throw OracleError.limitReached }
            guard modelInstall == nil else { throw OracleError.installFailed }

            let facts = await OraclePrompt.skyFacts(profile: userService.profile, astrology: astrology)
            let prior = OraclePrompt.priorTurns(from: history, question: question)
            let otherDay = await OraclePrompt.otherDay(in: question, profile: userService.profile, astrology: astrology, today: facts.sky.date)
            let prepared = await prompt(history: prior, facts: facts)
            let id = UUID()
            let date = Date()
            var answer = ""

            do {
                let asked = OraclePrompt.turn(
                    question,
                    model: .qwen,
                    reading: facts.reading,
                    otherDay: otherDay,
                    profile: userService.profile,
                    now: facts.sky.date,
                    history: prior
                )
                let continuing = OraclePrompt.continuesConversation(question, history: prior)
                for try await text in await engine.reply(instructions: prepared, question: asked, continuing: continuing) {
                    answer = text
                    continuation.yield(ChatMessage(id: id, role: .oracle, text: text, date: date))
                }
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if !(await engine.isReady) {
                    storage.remove(.localOracleModel)
                }
                logger.error("Local generation failed: \(String(reflecting: error), privacy: .public)")
                throw OracleError.generationFailed
            }

            guard !answer.isEmpty else { throw OracleError.generationFailed }
            if !isPremium { quotaStore.recordUse() }
            memory.record(question: question, answer: answer)
        }
    }

    func resetSession() {
        Task { await engine.reset() }
    }

    /// Reuses the live session when the chart context and Today's recommendation have not changed.
    private func prompt(history: [ChatMessage], facts: OraclePrompt.SkyFacts) async -> String {
        let key = SessionKey(
            profile: userService.profile,
            connections: connections.connections(),
            day: Calendar.current.startOfDay(for: facts.sky.date),
            options: astrology.chartOptions,
            guidanceID: facts.guidanceID
        )
        if await engine.matches(key) {
            return await engine.currentInstructions
        }
        let carried = await engine.hasSession ? Array(history.suffix(OraclePrompt.carriedOverMessages)) : []
        let material = await OraclePrompt.make(
            userService: userService,
            astrology: astrology,
            connections: connections,
            journal: journal,
            memory: memory,
            history: carried,
            model: .qwen,
            facts: facts
        )
        await engine.note(key)
        return material.instructions
    }
}

/// Identity of the data baked into the current chat session.
private struct SessionKey: Equatable {
    let profile: UserProfile?
    let connections: [Connection]
    /// Start of the local day. A new day rebuilds the session so today's sky is current.
    let day: Date
    let options: ChartOptions
    /// Today's primary recommendation. A new priority rebuilds the session instead of keeping yesterday's.
    let guidanceID: String
}

/// Qwen weights small enough for phones that cannot run Apple Intelligence.
private enum LocalOracleModel {
    nonisolated static var configuration: ModelConfiguration {
        fitsLargerModel ? LLMRegistry.qwen3_1_7b_4bit : LLMRegistry.qwen3_0_6b_4bit
    }

    nonisolated static var sizeDescription: String {
        fitsLargerModel ? "about 1 GB" : "about 400 MB"
    }

    /// iPhone 14 and 15 have 6 GB. Earlier phones that still run the app have 4 GB.
    nonisolated private static var fitsLargerModel: Bool {
        ProcessInfo.processInfo.physicalMemory >= 5_500_000_000
    }
}

/// Owns the weights and the chat session. Kept off the main actor so generation does not freeze the UI.
private actor LocalOracleEngine {
    private var container: ModelContainer?
    private var session: ChatSession?
    private var instructions = ""
    private var sessionKey: SessionKey?
    private var loadedName: String?

    var isReady: Bool { container != nil }
    var hasSession: Bool { session != nil }
    var currentInstructions: String { instructions }

    func matches(_ key: SessionKey) -> Bool {
        session != nil && sessionKey == key
    }

    func note(_ key: SessionKey) {
        guard sessionKey != key else { return }
        session = nil
        instructions = ""
        sessionKey = key
    }

    func reset() {
        session = nil
        instructions = ""
        sessionKey = nil
    }

    /// Downloads the weights if needed and loads them. Returns the model id to remember.
    func prepare(progress: @escaping @Sendable (Double) -> Void) async throws -> String {
        if let loadedName, container != nil {
            progress(1)
            return loadedName
        }
        Memory.cacheLimit = 20 * 1024 * 1024
        let (loaded, name) = try await loadPreferred(progress: progress)
        container = loaded
        loadedName = name
        progress(1)
        return name
    }

    func reply(instructions: String, question: String, continuing: Bool) -> AsyncThrowingStream<String, Error> {
        let stream = AsyncThrowingStream<String, Error> { continuation in
            let task = Task {
                do {
                    let session = try await self.chatSession(instructions: instructions, continuing: continuing)
                    var raw = ""
                    for try await chunk in session.streamResponse(to: question) {
                        try Task.checkCancellation()
                        raw += chunk
                        let visible = OraclePrompt.deliver(Self.visibleAnswer(raw))
                        if !visible.isEmpty {
                            continuation.yield(visible)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        return stream
    }

    private func chatSession(instructions: String, continuing: Bool) async throws -> ChatSession {
        if continuing, let session, self.instructions == instructions { return session }
        if container == nil {
            _ = try await prepare { _ in }
        }
        guard let container else { throw OracleError.installFailed }
        let thinkingOff: [String: any Sendable] = ["enable_thinking": false]
        let session = ChatSession(
            container,
            instructions: instructions,
            generateParameters: GenerateParameters(
                maxTokens: 420,
                temperature: 0.7,
                topP: 0.9,
                repetitionPenalty: 1.08,
                repetitionContextSize: 64
            ),
            additionalContext: thinkingOff
        )
        self.session = session
        self.instructions = instructions
        return session
    }

    private func loadPreferred(progress: @escaping @Sendable (Double) -> Void) async throws -> (ModelContainer, String) {
        let preferred = LocalOracleModel.configuration
        do {
            return (try await load(preferred, progress: progress), preferred.name)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            guard preferred.name != LLMRegistry.qwen3_0_6b_4bit.name else { throw error }
            logger.error("Larger local model failed, using the smaller one: \(String(reflecting: error), privacy: .public)")
            let fallback = LLMRegistry.qwen3_0_6b_4bit
            return (try await load(fallback, progress: progress), fallback.name)
        }
    }

    private func load(_ configuration: ModelConfiguration, progress: @escaping @Sendable (Double) -> Void) async throws -> ModelContainer {
        try await #huggingFaceLoadModelContainer(
            configuration: configuration,
            progressHandler: { update in
                progress(update.fractionCompleted)
            }
        )
    }

    /// Hides Qwen's optional thinking block so the chat only shows the reading.
    private static func visibleAnswer(_ raw: String) -> String {
        var text = raw
        if let end = text.range(of: "</think>") {
            text = String(text[end.upperBound...])
        } else if text.contains("<think>") {
            return ""
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
