//
//  AppDependencies.swift
//  AstroAI
//

import Foundation

/// Backend configuration. Fill in once the Supabase project is created.
enum AppConfig {
    static let apiBaseURL = URL(string: "https://example.supabase.co")!
    static let apiKey = ""
}

/// Dependency container. Creates every manager and service once and hands them
/// to coordinators, which inject them into view models.
final class AppDependencies {
    let network: NetworkManaging
    let storage: StorageManaging
    let imageStorage: ImageStorageManaging
    let networkMonitor: NetworkMonitor

    let userService: UserServicing
    let astrologyService: AstrologyServicing
    let locationService: LocationServicing
    let oracleService: OracleServicing
    let connectionsService: ConnectionsServicing
    let journalService: JournalServicing
    let subscriptionService: SubscriptionServicing
    let preferencesService: PreferencesServicing
    let attunement: AttunementScheduling

    init() {
        network = NetworkManager(baseURL: AppConfig.apiBaseURL, defaultHeaders: ["apikey": AppConfig.apiKey])
        storage = StorageManager()
        imageStorage = ImageStorageManager()
        networkMonitor = NetworkMonitor()

        userService = UserService(storage: storage, imageStorage: imageStorage)
        preferencesService = PreferencesService(storage: storage)
        astrologyService = AstrologyService(network: network, preferences: preferencesService)
        locationService = LocationService()
        connectionsService = ConnectionsService(storage: storage, astrology: astrologyService, userService: userService)
        journalService = JournalService(storage: storage, astrology: astrologyService, userService: userService)
        let oracleQuota = OracleQuotaStore(storage: storage)
        let oracleMemory = OracleMemoryStore(storage: storage)
        oracleService = AvailableOracleService(
            onDevice: OnDeviceOracleService(
                userService: userService,
                astrology: astrologyService,
                connections: connectionsService,
                journal: journalService,
                memory: oracleMemory,
                quotaStore: oracleQuota
            ),
            local: LocalModelOracleService(
                userService: userService,
                astrology: astrologyService,
                connections: connectionsService,
                journal: journalService,
                memory: oracleMemory,
                quotaStore: oracleQuota,
                storage: storage
            )
        )
        let subscriptions = SubscriptionService(userService: userService)
        subscriptions.start()
        subscriptionService = subscriptions
        attunement = AttunementScheduler(
            astrology: astrologyService,
            userService: userService,
            preferences: preferencesService
        )
    }
}
