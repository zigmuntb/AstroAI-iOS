//
//  OracleViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class OracleViewModel {
    private(set) var messages: [ChatMessage]
    private(set) var isTyping = false
    private(set) var isRetrying = false
    private(set) var quota: OracleQuota
    private(set) var savedMessageIDs: Set<UUID> = []
    private(set) var copiedMessageID: UUID?
    var draft = ""

    /// Set when the last request failed because the device was offline.
    private var didFailOffline = false
    /// Question that hasn't been answered yet (used by Retry).
    private var pendingQuestion: String?

    @ObservationIgnored private let oracle: OracleServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let journal: JournalServicing
    @ObservationIgnored private let networkMonitor: NetworkMonitor
    @ObservationIgnored private weak var router: MainRouting?

    init(oracle: OracleServicing, userService: UserServicing, journal: JournalServicing, networkMonitor: NetworkMonitor, router: MainRouting) {
        self.oracle = oracle
        self.userService = userService
        self.journal = journal
        self.networkMonitor = networkMonitor
        self.router = router
        self.quota = oracle.quota
        self.messages = Self.initialTranscript
    }

    // MARK: - Display

    var isOffline: Bool { didFailOffline || !networkMonitor.isConnected }

    var suggestions: [String] { oracle.suggestions }

    var quotaText: String { "\(quota.used) of \(quota.limit) daily free inquiries used" }

    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var userName: String {
        let name = userService.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "You" : name
    }

    var userInitial: String { String(userName.prefix(1)).uppercased() }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    func timestamp(for message: ChatMessage) -> String {
        message.date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Actions

    func ask(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping else { return }
        messages.append(ChatMessage(role: .user, text: text))
        request(text)
    }

    func send() {
        guard canSend else { return }
        let text = draft
        draft = ""
        ask(text)
    }

    func retry() {
        isRetrying = true
        didFailOffline = false
        Task {
            // Give the monitor a moment, then retry the unanswered question if any.
            try? await Task.sleep(for: .seconds(1))
            isRetrying = false
            if networkMonitor.isConnected, let question = pendingQuestion {
                request(question)
            }
        }
    }

    func resetSession() {
        messages = Self.initialTranscript
        pendingQuestion = nil
        draft = ""
    }

    func save(_ message: ChatMessage) {
        guard !savedMessageIDs.contains(message.id) else { return }
        journal.add(JournalEntry(
            date: .now, kind: .oracle, context: message.transitNote ?? "AI Oracle",
            quote: message.title ?? "Oracle Reading", body: message.text, tags: ["AI Dialogue"]
        ))
        savedMessageIDs.insert(message.id)
    }

    func markCopied(_ message: ChatMessage) {
        copiedMessageID = message.id
    }

    func openJournal() {
        router?.show(.journal)
    }

    func openPaywall() {
        router?.present(.paywall)
    }

    func continueOffline() {
        router?.select(.profile)
    }

    func openProfile() {
        router?.select(.profile)
    }

    // MARK: - Private

    private func request(_ question: String) {
        pendingQuestion = question
        isTyping = true
        let history = messages
        Task {
            defer { isTyping = false }
            do {
                let answer = try await oracle.ask(question, history: history, isPremium: isPremium)
                messages.append(answer)
                pendingQuestion = nil
            } catch OracleError.limitReached {
                pendingQuestion = nil
                router?.present(.paywall)
            } catch NetworkError.offline {
                didFailOffline = true
            } catch {
                messages.append(ChatMessage(role: .oracle, text: error.localizedDescription, title: "The reading was interrupted"))
                pendingQuestion = nil
            }
            quota = oracle.quota
        }
    }

    private static var initialTranscript: [ChatMessage] {
        [
            ChatMessage(
                role: .user,
                text: "Why do I feel so pulled between needing complete solitude and wanting intense closeness lately?",
                date: Date.now.addingTimeInterval(-60)
            ),
            MockData.oracleGreeting
        ]
    }
}
