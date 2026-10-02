//
//  AstrologyService.swift
//  AstroAI
//

import Foundation

struct MoonPhase: Hashable {
    let name: String
    /// 0...100
    let illumination: Int
}

protocol AstrologyServicing {
    func sunSign(for date: Date) -> ZodiacSign
    func moonPhase(for date: Date) -> MoonPhase
    func natalChart(for birth: BirthData) async throws -> NatalChart
    func dailyReading(for profile: UserProfile?) async throws -> DailyReading
    func library() async throws -> ExploreLibrary
}

/// Astronomy helpers are computed locally; readings come from mock data until
/// the backend (Supabase edge function + ephemeris) is connected.
final class AstrologyService: AstrologyServicing {
    private let network: NetworkManaging

    init(network: NetworkManaging) {
        self.network = network
    }

    func sunSign(for date: Date) -> ZodiacSign {
        .sunSign(on: date)
    }

    func moonPhase(for date: Date) -> MoonPhase {
        // Days since a known new moon (Jan 6, 2000 18:14 UTC), modulo synodic month.
        let synodicMonth = 29.530588853
        let knownNewMoon = Date(timeIntervalSince1970: 947_182_440)
        let days = date.timeIntervalSince(knownNewMoon) / 86_400
        let age = days.truncatingRemainder(dividingBy: synodicMonth)
        let normalized = (age < 0 ? age + synodicMonth : age) / synodicMonth
        let illumination = Int(((1 - cos(normalized * 2 * .pi)) / 2 * 100).rounded())

        let name: String
        switch normalized {
        case ..<0.03, 0.97...: name = "New Moon"
        case ..<0.22: name = "Waxing Crescent"
        case ..<0.28: name = "First Quarter"
        case ..<0.47: name = "Waxing Gibbous"
        case ..<0.53: name = "Full Moon"
        case ..<0.72: name = "Waning Gibbous"
        case ..<0.78: name = "Last Quarter"
        default: name = "Waning Crescent"
        }
        return MoonPhase(name: name, illumination: illumination)
    }

    func natalChart(for birth: BirthData) async throws -> NatalChart {
        try await Task.sleep(for: .milliseconds(300))
        return MockData.natalChart
    }

    func dailyReading(for profile: UserProfile?) async throws -> DailyReading {
        try await Task.sleep(for: .milliseconds(300))
        let phase = moonPhase(for: .now)
        return MockData.dailyReading(moonPhase: phase)
    }

    func library() async throws -> ExploreLibrary {
        try await Task.sleep(for: .milliseconds(300))
        return MockData.library
    }
}
