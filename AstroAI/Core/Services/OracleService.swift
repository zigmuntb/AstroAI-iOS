//
//  OracleService.swift
//  AstroAI
//

import Foundation

enum OracleError: LocalizedError {
    case limitReached
    case modelUnavailable
    case unsupportedLanguage
    case busy
    case generationFailed
    case installFailed

    var errorDescription: String? {
        switch self {
        case .limitReached: "You've used today's free questions."
        case .modelUnavailable: "The Oracle isn't available right now. Turn on Apple Intelligence and try again."
        case .unsupportedLanguage: "This language isn't supported yet. Try asking in English."
        case .busy: "The Oracle is still answering. Try again in a moment."
        case .generationFailed: "The answer didn't come through. Please try again."
        case .installFailed: "The on-device Oracle couldn't be installed. Check your connection and try again."
        }
    }
}

protocol OracleServicing: AnyObject {
    var quota: OracleQuota { get }
    var requiresNetwork: Bool { get }

    /// Streams snapshots of the answer as it is generated. Every snapshot carries
    /// the same message `id` and the full text produced so far.
    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error>
    func resetSession()

    /// Set when a free on-device model still has to be downloaded. Nil once the Oracle can answer.
    var modelInstall: OracleModelInstall? { get }
    func installModel() -> AsyncThrowingStream<Double, Error>
}

extension OracleServicing {
    var modelInstall: OracleModelInstall? { nil }

    func installModel() -> AsyncThrowingStream<Double, Error> {
        .run { _ in }
    }
}

extension AsyncThrowingStream where Failure == Error {
    /// Runs `body` in a task that is cancelled when the consumer stops listening.
    static func run(_ body: @escaping (Continuation) async throws -> Void) -> Self {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await body(continuation)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

/// Uses Apple Intelligence when it can answer.
/// When it is turned off, or the phone cannot run it, offers the downloadable on-device model.
final class AvailableOracleService: OracleServicing {
    private let onDevice: OracleServicing
    private let local: OracleServicing

    init(onDevice: OracleServicing, local: OracleServicing) {
        self.onDevice = onDevice
        self.local = local
    }

    private var current: OracleServicing {
        OnDeviceOracleService.isSupported ? onDevice : local
    }

    var quota: OracleQuota { current.quota }
    var requiresNetwork: Bool { current.requiresNetwork }
    var modelInstall: OracleModelInstall? { current.modelInstall }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error> {
        current.ask(question, history: history, isPremium: isPremium)
    }

    func resetSession() {
        onDevice.resetSession()
        local.resetSession()
    }

    func installModel() -> AsyncThrowingStream<Double, Error> {
        local.installModel()
    }
}

/// Network stub kept for a future online Oracle. Phones without Apple Intelligence use `LocalModelOracleService`.
final class OracleService: OracleServicing {
    private let network: NetworkManaging
    private let monitor: NetworkMonitoring
    private let quotaStore: OracleQuotaStoring

    init(network: NetworkManaging, monitor: NetworkMonitoring, quotaStore: OracleQuotaStoring) {
        self.network = network
        self.monitor = monitor
        self.quotaStore = quotaStore
    }

    var quota: OracleQuota { quotaStore.quota }
    var requiresNetwork: Bool { true }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) -> AsyncThrowingStream<ChatMessage, Error> {
        .run { [self] continuation in
            guard monitor.isConnected else { throw NetworkError.offline }
            guard isPremium || quota.remaining > 0 else { throw OracleError.limitReached }

            try await Task.sleep(for: .seconds(1))
            if !isPremium { quotaStore.recordUse() }
            continuation.yield(MockData.oracleAnswer(to: question))
        }
    }

    func resetSession() {}
}
