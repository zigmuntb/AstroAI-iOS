//
//  UserProfile.swift
//  AstroAI
//

import Foundation

struct BirthPlace: Codable, Hashable, Identifiable {
    var id: String { "\(city)-\(region)" }
    let city: String
    let region: String
    let latitude: Double
    let longitude: Double
    let timeZone: String

    var title: String { "\(city), \(region)" }

    var coordinates: String {
        let lat = String(format: "%.4f° %@", abs(latitude), latitude >= 0 ? "N" : "S")
        let lon = String(format: "%.4f° %@", abs(longitude), longitude >= 0 ? "E" : "W")
        return "\(lat), \(lon)"
    }
}

struct BirthData: Codable, Hashable {
    var date: Date
    /// `nil` when the user doesn't know the exact birth time.
    var time: Date?
    var place: BirthPlace?
}

enum Interest: String, CaseIterable, Codable, Identifiable {
    case love, career, selfDiscovery, emotions, growth, dailyGuidance, friendship
    var id: String { rawValue }
}

enum Intention: String, CaseIterable, Codable, Identifiable {
    case understandMyself, navigateRelationship, clarityDuringChange, exploreStrengths, dailyHabits, discoverChart
    var id: String { rawValue }
}

struct UserProfile: Codable, Hashable {
    var name: String
    var birth: BirthData
    var interests: Set<Interest>
    var intentions: Set<Intention>
    var isPremium: Bool = false
}

extension UserProfile {
    static let nameMinLength = 2
    static let nameMaxLength = 40

    /// Trimmed name if it satisfies the length rules, otherwise `nil`.
    static func validatedName(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (nameMinLength...nameMaxLength).contains(trimmed.count) else { return nil }
        return trimmed
    }
}
