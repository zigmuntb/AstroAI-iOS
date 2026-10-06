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

    var errorDescription: String? {
        switch self {
        case .limitReached: "You've used all free inquiries for today."
        case .modelUnavailable: "The Oracle is resting right now. Make sure Apple Intelligence is enabled and try again."
        case .unsupportedLanguage: "The Oracle doesn't speak this language yet. Try asking in English."
        case .busy: "The Oracle is still contemplating. Please try again in a moment."
        case .generationFailed: "The connection to the stars was lost. Please try again."
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

/// AI astrologer dialogue. The real implementation will call an AI proxy
/// (Supabase edge function) through `NetworkManager`.
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
            quotaStore.recordUse()
            continuation.yield(MockData.oracleAnswer(to: question))
        }
    }

    func resetSession() {}
}
