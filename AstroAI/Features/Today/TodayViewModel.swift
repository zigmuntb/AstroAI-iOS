//
//  TodayViewModel.swift
//  AstroAI
//

import Foundation
import Observation
import UIKit

@Observable
final class TodayViewModel {
    private(set) var reading: DailyReading?
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var selectedMood: String?
    private(set) var isSaved = false

    var isTarotComposerPresented = false
    var isTarotPlaygroundPresented = false
    var tarotDraft = ""
    private(set) var tarotImageData: Data?
    private(set) var tarotDescription = ""
    private(set) var tarotError: String?
    /// Scene sent to Image Playground. Kept apart from the text field so editing the draft cannot change a card already being drawn.
    private(set) var tarotConcept = ""
    private var pendingDescription = ""
    private var shouldOpenPlayground = false

    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let journal: JournalServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(astrology: AstrologyServicing, userService: UserServicing, journal: JournalServicing, router: MainRouting) {
        self.astrology = astrology
        self.userService = userService
        self.journal = journal
        self.router = router
        if let card = TarotCardStore.load(), UIImage(data: card.data) != nil {
            tarotImageData = card.data
            tarotDescription = card.description
        }
    }

    // MARK: - Display

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        let salutation: String
        switch hour {
        case 5..<12: salutation = "Good morning"
        case 12..<18: salutation = "Good afternoon"
        default: salutation = "Good evening"
        }
        let name = userService.profile?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "\(salutation)." : "\(salutation), \(name)."
    }

    var dateLine: String {
        (reading?.date ?? .now).formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased()
    }

    var moonLine: String {
        guard let reading else { return "" }
        return "\(reading.moonPhase) \(reading.moonSign.glyph)"
    }

    var isMoodRecorded: Bool { selectedMood != nil }

    var shareText: String {
        guard let reading else { return "" }
        return "“\(reading.synthesisTitle)” \(reading.synthesisText) — AstroAI Daily Synthesis, \(dateLine.capitalized)"
    }

    // MARK: - Actions

    func load() async {
        guard reading == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            reading = try await astrology.dailyReading(for: userService.profile)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func retry() async {
        await reload()
    }

    func reload() async {
        reading = nil
        await load()
    }

    func selectMood(_ mood: String) {
        selectedMood = mood
    }

    func toggleSave() {
        guard !isSaved, let reading else { return }
        journal.add(JournalEntry(
            date: .now, kind: .bookmark, context: reading.ephemerisTitle,
            quote: reading.synthesisTitle, body: reading.synthesisText, tags: [reading.transitLine]
        ))
        isSaved = true
    }

    func ask(_ question: String) {
        router?.askOracle(question)
    }

    func openTransitMap() {
        router?.select(.explore)
    }

    func openProfile() {
        router?.select(.profile)
    }

    // MARK: - Tarot

    var canDrawTarot: Bool {
        !tarotDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func beginTarot() {
        tarotDraft = tarotDescription
        tarotError = nil
        isTarotComposerPresented = true
    }

    func drawTarotCard() {
        let description = String(
            tarotDraft.trimmingCharacters(in: .whitespacesAndNewlines).prefix(TarotCardStore.descriptionLimit)
        )
        guard !description.isEmpty else { return }
        pendingDescription = description
        tarotConcept = """
            A single vertical illustrated tarot card with an ornate border and symbolic imagery, \
            no letters and no numbers. Scene: \(description)
            """
        tarotDraft = description
        shouldOpenPlayground = true
        isTarotComposerPresented = false
    }

    /// Called when the description sheet finishes dismissing, so Image Playground is not presented over it.
    func tarotComposerDismissed() {
        guard shouldOpenPlayground else { return }
        shouldOpenPlayground = false
        isTarotPlaygroundPresented = true
    }

    func saveTarotCard(from url: URL) {
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            guard UIImage(data: data) != nil else { throw TarotCardStoreError.unreadable }
            try TarotCardStore.save(data, description: pendingDescription)
            tarotImageData = data
            tarotDescription = pendingDescription
            tarotError = nil
        } catch {
            tarotError = error.localizedDescription
        }
    }
}
