//
//  AddConnectionViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class AddConnectionViewModel {
    var name = ""
    var kinship: Kinship = .romantic
    var birthDate: Date
    var birthTime: Date
    var isTimeApproximate = false
    var placeQuery = "" {
        didSet {
            guard placeQuery != oldValue else { return }
            placeQueryChanged()
        }
    }

    private(set) var placeResults: [BirthPlace] = []
    private(set) var selectedPlace: BirthPlace?
    private(set) var isSearching = false

    @ObservationIgnored private let connections: ConnectionsServicing
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private let locationService: LocationServicing
    @ObservationIgnored private weak var router: MainRouting?
    @ObservationIgnored private let onSave: () -> Void
    @ObservationIgnored private var searchTask: Task<Void, Never>?

    init(connections: ConnectionsServicing, astrology: AstrologyServicing, locationService: LocationServicing, router: MainRouting, onSave: @escaping () -> Void) {
        self.connections = connections
        self.astrology = astrology
        self.locationService = locationService
        self.router = router
        self.onSave = onSave

        let calendar = Calendar.current
        birthDate = calendar.date(from: DateComponents(year: 1992, month: 3, day: 14)) ?? .now
        birthTime = calendar.date(from: DateComponents(year: 1992, month: 3, day: 14, hour: 12)) ?? .now
    }

    // MARK: - Derived state

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var canSave: Bool { !trimmedName.isEmpty && selectedPlace != nil }

    var sunSign: ZodiacSign { astrology.sunSign(for: birthDate) }

    var archetypeTitle: String {
        let first = trimmedName.split(separator: " ").first.map(String.init)
        return "\(first ?? "Their")'s Celestial Core"
    }

    var archetypeText: String {
        "\(sunSign.element) solar core — a \(sunSign.name) Sun weaving into your own natal geometry."
    }

    var showsNoResults: Bool {
        selectedPlace == nil && !isSearching && placeQuery.trimmingCharacters(in: .whitespaces).count >= 2 && placeResults.isEmpty
    }

    // MARK: - Actions

    func select(_ place: BirthPlace) {
        selectedPlace = place
        placeResults = []
        placeQuery = place.title
    }

    func close() {
        searchTask?.cancel()
        router?.dismissSheet()
    }

    func save() {
        guard canSave, let place = selectedPlace else { return }
        let connection = Connection(
            name: trimmedName,
            kinship: kinship,
            birth: BirthData(date: birthDate, time: isTimeApproximate ? nil : birthTime, place: place)
        )
        connections.add(connection)
        onSave()
        router?.dismissSheet()
    }

    // MARK: - Place search

    private func placeQueryChanged() {
        if let selectedPlace, selectedPlace.title == placeQuery { return }
        selectedPlace = nil
        searchTask?.cancel()

        let query = placeQuery
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.search(query)
        }
    }

    private func search(_ query: String) async {
        isSearching = true
        let results = (try? await locationService.searchPlaces(query)) ?? []
        guard !Task.isCancelled else { return }
        placeResults = results
        isSearching = false
    }
}
