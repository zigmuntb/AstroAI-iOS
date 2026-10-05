//
//  ExploreViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class ExploreViewModel {
    enum Topic: String, CaseIterable, Identifiable {
        case all = "All Topics"
        case transits = "Current Transits"
        case houses = "Houses"
        case archetypes = "Zodiac Archetypes"
        case aspects = "Aspects & Geometry"
        case synastry = "Synastry"

        var id: String { rawValue }
    }

    private(set) var library: ExploreLibrary?
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var searchText = ""
    var selectedTopic: Topic = .all

    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(astrology: AstrologyServicing, router: MainRouting) {
        self.astrology = astrology
        self.router = router
    }

    // MARK: - Display state

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var showsFeatured: Bool {
        guard let featured = library?.featured else { return false }
        return selectedTopic == .all && matches(featured.title, featured.summary, featured.eyebrow)
    }

    var transits: [Transit] {
        guard let library, [.all, .transits].contains(selectedTopic) else { return [] }
        return library.transits.filter { matches($0.title, $0.detail, $0.kind) }
    }

    var tomes: [Article] {
        guard let library, selectedTopic != .transits else { return [] }
        return library.tomes.filter { matches($0.title, $0.summary, $0.eyebrow) }
    }

    var hasNoResults: Bool {
        library != nil && !showsFeatured && transits.isEmpty && tomes.isEmpty
    }

    private func matches(_ fields: String...) -> Bool {
        query.isEmpty || fields.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    // MARK: - Actions

    func load() async {
        guard library == nil, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            library = try await astrology.library()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func retry() async {
        library = nil
        await load()
    }

    func select(_ topic: Topic) {
        selectedTopic = topic
    }

    func openBlueprint() {
        router?.show(.natalBlueprint)
    }

    func openFeatured() {
        guard let featured = library?.featured else { return }
        router?.show(.article(featured))
    }

    func open(_ article: Article) {
        router?.show(.article(article))
    }

    func openProfile() {
        router?.select(.profile)
    }
}
