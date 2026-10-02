//
//  BirthplaceViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class BirthplaceViewModel {
    struct ResultRow: Identifiable {
        let place: BirthPlace
        let isSelected: Bool
        let showsDivider: Bool
        var id: String { place.id }
    }

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var results: [BirthPlace] = []
    private(set) var selectedPlace: BirthPlace?
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private let locationService: LocationServicing
    @ObservationIgnored private weak var router: OnboardingRouting?
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(draft: OnboardingDraft, locationService: LocationServicing, router: OnboardingRouting) {
        self.draft = draft
        self.locationService = locationService
        self.router = router
        self.selectedPlace = draft.birthPlace
        if let place = draft.birthPlace {
            query = place.city
            results = [place]
        }
    }

    var canContinue: Bool { selectedPlace != nil }

    /// Hint shown when there is nothing to list.
    var emptyHint: String? {
        guard results.isEmpty, !isSearching else { return nil }
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        if trimmed.count < 2 {
            return "Start typing your birth city — at least two letters."
        }
        return errorMessage ?? "No places match “\(trimmed)”. Try a nearby larger city."
    }

    /// Rows are built from one snapshot of `results`, so the view never indexes a changing array.
    var resultRows: [ResultRow] {
        let places = results
        return places.indices.map { index in
            let isSelected = places[index] == selectedPlace
            let previousSelected = index > 0 && places[index - 1] == selectedPlace
            return ResultRow(
                place: places[index],
                isSelected: isSelected,
                showsDivider: index > 0 && !isSelected && !previousSelected
            )
        }
    }

    func select(_ place: BirthPlace) {
        selectedPlace = place
        draft.birthPlace = place
    }

    func clearQuery() {
        query = ""
    }

    func continueTapped() {
        guard canContinue else { return }
        router?.next(from: .birthplace)
    }

    /// Continue without a birthplace; the chart falls back to a location-free calculation.
    func skipPlace() {
        selectedPlace = nil
        draft.birthPlace = nil
        router?.next(from: .birthplace)
    }

    func back() {
        searchTask?.cancel()
        router?.back()
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let text = query
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.search(text)
        }
    }

    private func search(_ text: String) async {
        isSearching = true
        errorMessage = nil
        defer { isSearching = false }
        do {
            let places = try await locationService.searchPlaces(text)
            guard !Task.isCancelled else { return }
            results = places
        } catch is CancellationError {
            return
        } catch {
            results = []
            errorMessage = "Location lookup is unavailable right now."
        }
    }
}
