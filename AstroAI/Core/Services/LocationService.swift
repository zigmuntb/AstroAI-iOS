//
//  LocationService.swift
//  AstroAI
//

import Foundation

protocol LocationServicing {
    func searchPlaces(_ query: String) async throws -> [BirthPlace]
}

/// Birthplace lookup. Backed by a small local list for now; can be swapped
/// for MapKit / a geocoding API without touching the UI.
final class LocationService: LocationServicing {
    func searchPlaces(_ query: String) async throws -> [BirthPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }
        try await Task.sleep(for: .milliseconds(150))
        return MockData.places.filter {
            $0.city.localizedCaseInsensitiveContains(trimmed) || $0.region.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
