//
//  LocationService.swift
//  AstroAI
//

import Foundation
import MapKit

protocol LocationServicing {
    func searchPlaces(_ query: String) async throws -> [BirthPlace]
}

/// Birthplace lookup through MapKit: coordinates plus the place's IANA time zone, which the
/// chart needs to convert the local birth time to UTC. Falls back to a small built-in list
/// when MapKit is unreachable.
final class LocationService: LocationServicing {
    func searchPlaces(_ query: String) async throws -> [BirthPlace] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        do {
            let places = try await searchMapKit(trimmed)
            if !places.isEmpty { return places }
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Offline or rate-limited: use the built-in list below.
        }
        return MockData.places.filter {
            $0.city.localizedCaseInsensitiveContains(trimmed) || $0.region.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func searchMapKit(_ query: String) async throws -> [BirthPlace] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        let response = try await MKLocalSearch(request: request).start()
        try Task.checkCancellation()

        var seen = Set<String>()
        return response.mapItems.compactMap { item -> BirthPlace? in
            let coordinate = item.location.coordinate
            guard let city = item.addressRepresentations?.cityName ?? item.name else { return nil }
            let region = Self.region(of: item, city: city)
            let timeZone = item.timeZone ?? .current
            let place = BirthPlace(
                city: city,
                region: region,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timeZone: Self.describe(timeZone),
                timeZoneIdentifier: timeZone.identifier
            )
            return seen.insert(place.id).inserted ? place : nil
        }
    }

    /// "Kyiv, Ukraine" → "Ukraine"; keeps the state for US cities ("California, United States").
    private static func region(of item: MKMapItem, city: String) -> String {
        let context = item.addressRepresentations?.cityWithContext ?? ""
        let parts = context.components(separatedBy: ", ").filter { $0 != city }
        if !parts.isEmpty { return parts.joined(separator: ", ") }
        return item.addressRepresentations?.regionName ?? ""
    }

    /// "Eastern European Time (UTC+2)"
    private static func describe(_ timeZone: TimeZone) -> String {
        let name = timeZone.localizedName(for: .standard, locale: Locale(identifier: "en_US")) ?? timeZone.identifier
        let hours = Double(timeZone.secondsFromGMT(for: .now) - Int(timeZone.daylightSavingTimeOffset(for: .now))) / 3600
        let offset = hours == hours.rounded() ? String(Int(hours)) : String(format: "%.1f", hours)
        return "\(name) (UTC\(hours >= 0 ? "+" : "")\(offset))"
    }
}
