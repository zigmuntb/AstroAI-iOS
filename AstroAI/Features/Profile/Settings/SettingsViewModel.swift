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
        Option(value: "Tropical", caption: "Western"),
        Option(value: "Sidereal", caption: "Fagan / Bradley")
    ]
    let nodeOptions = [Option(value: "True"), Option(value: "Mean")]

    var houseDescription: String {
        switch prefs.houseSystem {
        case "Whole Sign": "Whole Sign gives each sign one whole house, starting from the rising sign."
        case "Equal House": "Equal House splits the chart into twelve equal 30° houses, starting from the rising sign."
        default: "Placidus sizes the houses by the time it takes the sky to turn. This is the usual system in modern Western astrology."
        }
    }

    var isPremium: Bool { userService.profile?.isPremium ?? false }

    var membershipTitle: String { isPremium ? "AstroAI Sanctuary Edition" : "AstroAI Seeker Edition" }
    var membershipBadge: String { isPremium ? (subscriptions.renewalDescription ?? "Sanctuary") : "Free Tier" }
    var membershipText: String {
        isPremium
            ? "The full chart, unlimited comparisons, and readings that stay on this phone."
            : "Your birth chart and today's sky. Upgrade for more people and unlimited Oracle chats."
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
