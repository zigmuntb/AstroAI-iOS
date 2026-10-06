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
    /// Oracle message that is still being generated.
    private(set) var streamingMessageID: UUID?
    private(set) var isRetrying = false
    private(set) var quota: OracleQuota
    private(set) var savedMessageIDs: Set<UUID> = []
    private(set) var copiedMessageID: UUID?
    var draft = ""

    /// Set when the last request failed because the device was offline.
    private var didFailOffline = false
    /// Question that hasn't been answered yet (used by Retry).
    private var pendingQuestion: String?
    @ObservationIgnored private var requestTask: Task<Void, Never>?

    private(set) var chart: NatalChart?
    private(set) var sky: SkySnapshot?

    @ObservationIgnored private let oracle: OracleServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let journal: JournalServicing
    @ObservationIgnored private let networkMonitor: NetworkMonitor
    @ObservationIgnored private weak var router: MainRouting?

    init(oracle: OracleServicing, userService: UserServicing, astrology: AstrologyServicing, journal: JournalServicing, networkMonitor: NetworkMonitor, router: MainRouting) {
        self.oracle = oracle
        self.userService = userService
        self.astrology = astrology
        self.journal = journal
        self.networkMonitor = networkMonitor
        self.router = router
        self.quota = oracle.quota
        self.messages = [Self.greeting(name: userService.profile?.name, chart: nil, sky: nil)]
    }

    // MARK: - Display

    var isOffline: Bool { oracle.requiresNetwork && (didFailOffline || !networkMonitor.isConnected) }

    var syncLine: String {
        guard let sun = chart?.placement(.sun), let moon = chart?.placement(.moon) else {
            return "Synced with today's sky"
        }
        return "Synced with \(sun.sign.name) Sun ☉, \(moon.sign.name) Moon ☽"
    }

    var transitLine: String {
        if let transit = sky?.keyTransit {
            return "Active Transit: \(transit.glyphLine) \(transit.title) (\(NatalChartCalculator.formatDegrees(transit.orb)))"
        }
        guard let moon = sky?.position(of: .moon) else { return "Reading the sky…" }
        return "Current Sky: ☽ Moon in \(moon.sign.name) (\(NatalChartCalculator.formatDegrees(moon.degreeInSign)))"
    }

    var transitBadge: String {
        sky?.keyTransit?.orbBadge ?? sky?.moonPhase.name ?? ""
    }

    var suggestions: [String] {
        OracleSuggestions.make(chart: chart, sky: sky, interests: userService.profile?.interests ?? [])
    }

    var quotaText: String { "\(quota.used) of \(quota.limit) daily free inquiries used" }

    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var userName: String {
        let name = userService.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "You" : name
    }

    var userInitial: String { String(userName.prefix(1)).uppercased() }

    var showsTypingIndicator: Bool { isTyping && streamingMessageID == nil }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
    }

    func timestamp(for message: ChatMessage) -> String {
        message.date.formatted(date: .omitted, time: .shortened)
    }

    // MARK: - Actions

    /// Recomputes the natal chart and today's sky; replaces the greeting while the chat is untouched.
    func loadSky() async {
        let isUntouched = messages.count == 1 && messages.first?.role == .oracle && !isTyping
        if let birth = userService.profile?.birth {
            chart = try? await astrology.natalChart(for: birth)
        } else {
            chart = nil
        }
        sky = astrology.sky(at: .now, natal: chart)
        quota = oracle.quota
        if isUntouched {
            messages = [greeting]
        }
    }

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
        requestTask?.cancel()
        requestTask = nil
        isTyping = false
        streamingMessageID = nil
        oracle.resetSession()
        messages = [greeting]
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
        requestTask = Task {
            do {
                for try await answer in oracle.ask(question, history: history, isPremium: isPremium) {
                    guard !Task.isCancelled else { return }
                    if let index = messages.firstIndex(where: { $0.id == answer.id }) {
                        messages[index] = answer
                    } else {
                        streamingMessageID = answer.id
                        messages.append(answer)
                    }
                }
                guard !Task.isCancelled else { return }
                pendingQuestion = nil
            } catch is CancellationError {
                return
            } catch OracleError.limitReached {
                pendingQuestion = nil
                router?.present(.paywall)
            } catch NetworkError.offline {
                didFailOffline = true
            } catch {
                guard !Task.isCancelled else { return }
                messages.append(ChatMessage(role: .oracle, text: error.localizedDescription, title: "The reading was interrupted"))
                pendingQuestion = nil
            }
            isTyping = false
            streamingMessageID = nil
            quota = oracle.quota
        }
    }

    private var greeting: ChatMessage {
        Self.greeting(name: userService.profile?.name, chart: chart, sky: sky)
    }

    private static func greeting(name: String?, chart: NatalChart?, sky: SkySnapshot?) -> ChatMessage {
        let welcome = name.map { "Welcome, \($0)." } ?? "Welcome."
        guard let chart, let sun = chart.placement(.sun), let moon = chart.placement(.moon) else {
            return ChatMessage(
                role: .oracle,
                text: "\(welcome) Ask me anything about love, work, or the path you're on, and I'll read it through your chart and today's sky.",
                title: "The Oracle is listening"
            )
        }

        var text = "\(welcome) Your \(sun.sign.name) Sun gives you a \(sun.sign.qualities) core, while your \(moon.sign.name) Moon needs \(moon.sign.archetype.lowercased()) to feel safe."
        if let rising = chart.placement(.ascendant) {
            text += " With \(rising.sign.name) rising, others first meet your \(rising.sign.qualities) side."
        }
        if let transit = sky?.keyTransit {
            text += "\n\nRight now: \(transit.sentence)"
        }
        text += "\n\nWhat would you like to explore?"

        return ChatMessage(
            role: .oracle,
            text: text,
            title: "\(sun.sign.name) Sun, \(moon.sign.name) Moon",
            transitNote: sky?.keyTransit?.note
        )
    }
}
