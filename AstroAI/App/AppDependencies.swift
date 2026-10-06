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
        oracleService = OnDeviceOracleService.isSupported
            ? OnDeviceOracleService(
                userService: userService,
                astrology: astrologyService,
                connections: connectionsService,
                journal: journalService,
                memory: OracleMemoryStore(storage: storage),
                quotaStore: oracleQuota
            )
            : OracleService(network: network, monitor: networkMonitor, quotaStore: oracleQuota)
        subscriptionService = SubscriptionService(userService: userService)
    }
}
