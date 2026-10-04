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
    /// IANA identifier, e.g. "Europe/Kyiv". Needed to convert the local birth time to UTC
    /// with historical daylight-saving rules.
    var timeZoneIdentifier: String? = nil

    var title: String { "\(city), \(region)" }

    /// Profiles saved before `timeZoneIdentifier` existed only reference the built-in city list.
    var resolvedTimeZone: TimeZone? {
        let identifier = timeZoneIdentifier ?? MockData.places.first { $0.id == id }?.timeZoneIdentifier
        return identifier.flatMap(TimeZone.init(identifier:))
    }

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
    /// `true` when `time` is a stand-in (morning / noon / evening) rather than the real birth time.
    var isTimeApproximate: Bool? = nil

    var isTimeKnown: Bool { time != nil && isTimeApproximate != true }

    /// Birth moment in absolute time. The date and time pickers store wall-clock values in the
    /// device calendar; they are reinterpreted in the birthplace's time zone.
    var moment: Date {
        let device = Calendar.current
        let day = device.dateComponents([.year, .month, .day], from: date)
        let clock = time.map { device.dateComponents([.hour, .minute], from: $0) } ?? DateComponents(hour: 12, minute: 0)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place?.resolvedTimeZone ?? .current
        let components = DateComponents(year: day.year, month: day.month, day: day.day, hour: clock.hour, minute: clock.minute)
        return calendar.date(from: components) ?? date
    }
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
    var personal: PersonalContext? = nil
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
