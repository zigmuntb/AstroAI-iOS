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
    /// Free-tier counter and the upgrade prompt. Hidden once the account has a paid subscription.
    private(set) var showsFreeQuota: Bool
    /// Set when a free on-device model still has to be downloaded.
    private(set) var modelInstall: OracleModelInstall?
    /// Download progress while the on-device model is being installed, from 0 to 1.
    private(set) var installProgress: Double?
    private(set) var installError: String?
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
        self.showsFreeQuota = !(userService.profile?.isPremium ?? false)
        self.modelInstall = oracle.modelInstall
        self.messages = [Self.greeting(name: userService.profile?.name, chart: nil, sky: nil)]
    }

    // MARK: - Display

    var isOffline: Bool { oracle.requiresNetwork && (didFailOffline || !networkMonitor.isConnected) }

    var syncLine: String {
        "Ask about your day, a relationship, work, or a decision."
    }

    var transitLine: String {
        guard let sky else { return "Today's reading is on its way." }
        let copy = EverydayVoice.day(profile: userService.profile, chart: chart, sky: sky)
        return copy.atmosphere
    }

    /// Explained astrology for the collapsed detail under the introduction.
    var astrologyDetail: String {
        guard let sky else { return "" }
        return EverydayVoice.day(profile: userService.profile, chart: chart, sky: sky).astrologyText
    }

    var transitBadge: String {
        ""
    }

    var suggestions: [String] {
        OracleSuggestions.make(chart: chart, sky: sky, interests: userService.profile?.interests ?? [])
    }

    var quotaText: String { "\(quota.used) of \(quota.limit) free questions used today" }

    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var userName: String {
        let name = userService.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "You" : name
    }

    var userInitial: String { String(userName.prefix(1)).uppercased() }

    var showsTypingIndicator: Bool { isTyping && streamingMessageID == nil }

    var canSend: Bool {
        modelInstall == nil && installProgress == nil
            && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isTyping
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
        refreshAccess()
        modelInstall = oracle.modelInstall
        if isUntouched {
            messages = [greeting]
        }
    }

    func ask(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isTyping, modelInstall == nil, installProgress == nil else { return }
        messages.append(ChatMessage(role: .user, text: text))
        request(text)
    }

    func installModel() {
        guard modelInstall != nil, installProgress == nil else { return }
        installError = nil
        installProgress = 0
        Task {
            do {
                for try await progress in oracle.installModel() {
                    installProgress = progress
                }
                installProgress = nil
                modelInstall = oracle.modelInstall
            } catch is CancellationError {
                installProgress = nil
            } catch {
                installProgress = nil
                installError = error.localizedDescription
                modelInstall = oracle.modelInstall
            }
        }
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
            refreshAccess()
            modelInstall = oracle.modelInstall
        }
    }

    /// Keeps the free-tier banner in step with the stored subscription. Premium accounts never see it.
    private func refreshAccess() {
        quota = oracle.quota
        showsFreeQuota = !isPremium
    }

    private var greeting: ChatMessage {
        Self.greeting(name: userService.profile?.name, chart: chart, sky: sky)
    }

    private static func greeting(name: String?, chart: NatalChart?, sky: SkySnapshot?) -> ChatMessage {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let welcome = trimmed.isEmpty ? "You can ask in ordinary words." : "\(trimmed), you can ask in ordinary words."
        var detail = ""
        if let chart, let sun = chart.placement(.sun) {
            detail = "Your Sun is in \(sun.sign.name). The Sun is associated with how you go after things. \(sun.sign.name) is often described as \(sun.sign.qualities)."
            if chart.isTimeKnown, let moon = chart.placement(.moon) {
                detail += " Your Moon is in \(moon.sign.name). The Moon is associated with what helps you feel safe. \(moon.sign.name) is often described as \(moon.sign.qualities)."
            } else {
                detail += " The Moon sign needs an exact birth time, so it is left out."
            }
            if chart.hasLocation, chart.isTimeKnown, let rising = chart.placement(.ascendant) {
                detail += " Your rising sign is \(rising.sign.name), which describes a first impression."
            } else if !chart.hasLocation || !chart.isTimeKnown {
                detail += " Birth time or birthplace is not exact enough for a rising sign, so that part is left out."
            }
            if let sky, let transit = EverydayVoice.supportedTransit(chart: chart, sky: sky) {
                detail += " \(transit.sentence) That is an interpretation of today's sky, not a fact about what will happen."
            }
        }
        return ChatMessage(
            role: .oracle,
            text: "\(welcome) Try a relationship, work, a mood, or a decision. I'll answer that first. The astrology, when there is any, stays optional.",
            title: "What's on your mind?",
            transitNote: detail.isEmpty ? nil : detail
        )
    }
}
