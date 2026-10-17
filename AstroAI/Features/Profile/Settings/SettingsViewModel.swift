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
            Task { await refreshNotifications() }
        }
    }

    var isConfirmingPurge = false
    private(set) var notificationNote: String?

    let houseSystems = HouseSystem.allCases.map(\.rawValue)
    let zodiacOptions = [
        Option(value: "Tropical", caption: "Western Solstitial"),
        Option(value: "Sidereal", caption: "Fagan / Bradley")
    ]
    let nodeOptions = [Option(value: "True"), Option(value: "Mean")]

    var houseDescription: String {
        switch prefs.houseSystem {
        case "Whole Sign": "Whole Sign assigns each 30° zodiac constellation to an entire house starting at the Ascendant degree."
        case "Equal House": "Equal House divides the chart into exactly twelve 30° segments originating from the exact Ascendant degree."
        default: "Placidus divides semi-diurnal arcs proportionately. Standard for western modern synthesis and psychological transits."
        }
    }

    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var membershipTitle: String { isPremium ? "AstroAI Sanctuary Edition" : "AstroAI Seeker Edition" }
    var membershipBadge: String { isPremium ? (subscriptions.renewalDescription ?? "Sanctuary") : "Free Tier" }
    var membershipText: String {
        isPremium
            ? "Full on-device ephemeris, unlimited synastry overlays, and sovereign offline natal synthesis."
            : "Core natal synthesis and daily transits. Upgrade for unlimited synastry overlays and chart-aware AI dialogue."
    }
    var membershipAction: String { isPremium ? "Manage Subscription" : "Explore Sanctuary" }

    @ObservationIgnored private let preferences: PreferencesServicing
    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private let subscriptions: SubscriptionServicing
    @ObservationIgnored private let attunement: AttunementScheduling
    @ObservationIgnored private weak var router: MainRouting?

    init(
        preferences: PreferencesServicing,
        userService: UserServicing,
        subscriptions: SubscriptionServicing,
        attunement: AttunementScheduling,
        router: MainRouting
    ) {
        self.preferences = preferences
        self.userService = userService
        self.subscriptions = subscriptions
        self.attunement = attunement
        self.router = router
        prefs = preferences.load()
    }

    // MARK: - Actions

    func selectHouseSystem(_ system: String) { prefs.houseSystem = system }
    func selectZodiac(_ zodiac: String) { prefs.zodiac = zodiac }
    func selectLunarNode(_ node: String) { prefs.lunarNode = node }
    func toggleQuietWindow() { prefs.quietWindow.toggle() }

    func refreshNotifications() async {
        notificationNote = await attunement.sync()
    }

    func requestPurge() {
        isConfirmingPurge = true
    }

    func confirmPurge() {
        isConfirmingPurge = false
        router?.signOut()
    }

    func manageSubscription() {
        if isPremium {
            Task { await subscriptions.showManageSubscriptions() }
        } else {
            router?.present(.paywall)
        }
    }

    func back() {
        router?.pop()
    }
}
