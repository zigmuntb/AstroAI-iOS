//
//  SettingsViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class SettingsViewModel {
    struct Option: Identifiable {
        var id: String { value }
        let value: String
        var caption: String? = nil
    }

    /// Every change is persisted immediately.
    var prefs: Preferences {
        didSet {
            guard prefs != oldValue else { return }
            preferences.save(prefs)
        }
    }

    var isConfirmingPurge = false

    let houseSystems = ["Placidus", "Whole Sign", "Koch", "Equal House", "Campanus"]
    let zodiacOptions = [
        Option(value: "Tropical", caption: "Western Solstitial"),
        Option(value: "Sidereal", caption: "Fagan / Bradley")
    ]
    let nodeOptions = [Option(value: "True"), Option(value: "Mean")]

    var houseDescription: String {
        switch prefs.houseSystem {
        case "Whole Sign": "Whole Sign assigns each 30° zodiac constellation to an entire house starting at the Ascendant degree."
        case "Koch": "Koch calculation relies on diurnal motion measured at the horizon latitude; favors precise mundane transit timings."
        case "Equal House": "Equal House divides the chart into exactly twelve 30° segments originating from the exact Ascendant degree."
        case "Campanus": "Campanus slices the prime vertical circle; emphasizes spatial planetary position over ecliptic longitude."
        default: "Placidus divides semi-diurnal arcs proportionately. Standard for western modern synthesis and psychological transits."
        }
    }

    private(set) var isPremium = false

    var membershipTitle: String { isPremium ? "AstroAI Sanctuary Edition" : "AstroAI Seeker Edition" }
    var membershipBadge: String { isPremium ? "Renews Sep 2025" : "Free Tier" }
    var membershipText: String {
        isPremium
            ? "Full Swiss Ephemeris DE431 mathematical access, unlimited synastry overlays, and sovereign offline natal synthesis."
            : "Core natal synthesis and daily transits. Upgrade for unlimited synastry overlays and chart-aware AI dialogue."
    }
    var membershipFooter: String { isPremium ? "Device License: 04 of 05" : "Device License: 01 of 01" }
    var membershipAction: String { isPremium ? "Manage Subscription" : "Explore Sanctuary" }

    @ObservationIgnored private let preferences: PreferencesServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(preferences: PreferencesServicing, userService: UserServicing, router: MainRouting) {
        self.preferences = preferences
        self.userService = userService
        self.router = router
        prefs = preferences.load()
        refresh()
    }

    func refresh() {
        isPremium = userService.profile?.isPremium ?? false
    }

    // MARK: - Actions

    func selectHouseSystem(_ system: String) { prefs.houseSystem = system }
    func selectZodiac(_ zodiac: String) { prefs.zodiac = zodiac }
    func selectLunarNode(_ node: String) { prefs.lunarNode = node }
    func toggleQuietWindow() { prefs.quietWindow.toggle() }

    func requestPurge() {
        isConfirmingPurge = true
    }

    func confirmPurge() {
        isConfirmingPurge = false
        router?.signOut()
    }

    func manageSubscription() {
        router?.present(.paywall)
    }

    func back() {
        router?.pop()
    }
}
