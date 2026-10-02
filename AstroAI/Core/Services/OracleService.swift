//
//  OracleService.swift
//  AstroAI
//

import Foundation

enum OracleError: LocalizedError {
    case limitReached

    var errorDescription: String? {
        switch self {
        case .limitReached: "You've used all free inquiries for today."
        }
    }
}

protocol OracleServicing: AnyObject {
    var quota: OracleQuota { get }
    var suggestions: [String] { get }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) async throws -> ChatMessage
}

/// AI astrologer dialogue. The real implementation will call an AI proxy
/// (Supabase edge function) through `NetworkManager`.
final class OracleService: OracleServicing {
    private let network: NetworkManaging
    private let monitor: NetworkMonitoring
    private var usedToday = 2
    private let dailyLimit = 3

    init(network: NetworkManaging, monitor: NetworkMonitoring) {
        self.network = network
        self.monitor = monitor
    }

    var quota: OracleQuota { OracleQuota(used: usedToday, limit: dailyLimit) }
    var suggestions: [String] { MockData.oracleSuggestions }

    func ask(_ question: String, history: [ChatMessage], isPremium: Bool) async throws -> ChatMessage {
        guard monitor.isConnected else { throw NetworkError.offline }
        guard isPremium || quota.remaining > 0 else { throw OracleError.limitReached }

        try await Task.sleep(for: .seconds(1))
        usedToday += 1
        return MockData.oracleAnswer(to: question)
    }
}
