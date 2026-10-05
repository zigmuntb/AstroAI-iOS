//
//  MainCoordinator.swift
//  AstroAI
//

import SwiftUI

enum AppTab: Hashable, CaseIterable {
    case today, explore, oracle, synastry, profile

    var title: String {
        switch self {
        case .today: "Today"
        case .explore: "Explore"
        case .oracle: "Oracle"
        case .synastry: "Synastry"
        case .profile: "Profile"
        }
    }

    var icon: String {
        switch self {
        case .today: "sun.max"
        case .explore: "globe"
        case .oracle: "questionmark.bubble"
        case .synastry: "circle.circle"
        case .profile: "person.crop.circle"
        }
    }
}

enum AppRoute: Hashable {
    case natalBlueprint
    case synastry(Connection)
    case journal
    case settings
}

enum AppSheet: String, Identifiable {
    case paywall
    case addConnection
    case editProfile

    var id: String { rawValue }
}

protocol MainRouting: AnyObject {
    func show(_ route: AppRoute)
    func pop()
    func present(_ sheet: AppSheet)
    func dismissSheet()
    func select(_ tab: AppTab)
    func askOracle(_ question: String)
    func signOut()
}

/// Owns the tab bar, one navigation path per tab and modal sheets.
/// Builds every screen of the main app and injects its dependencies.
@Observable
final class MainCoordinator: MainRouting {
    var selectedTab: AppTab = .today
    var paths: [AppTab: [AppRoute]] = [:]
    var sheet: AppSheet?
    @ObservationIgnored var onSignOut: (() -> Void)?

    @ObservationIgnored private let dependencies: AppDependencies

    // Tab root view models live as long as the coordinator, so tabs keep their state.
    @ObservationIgnored private lazy var todayViewModel = TodayViewModel(
        astrology: dependencies.astrologyService, userService: dependencies.userService,
        journal: dependencies.journalService, router: self
    )
    @ObservationIgnored private lazy var exploreViewModel = ExploreViewModel(
        astrology: dependencies.astrologyService, userService: dependencies.userService, router: self
    )
    @ObservationIgnored private lazy var oracleViewModel = OracleViewModel(
        oracle: dependencies.oracleService, userService: dependencies.userService, astrology: dependencies.astrologyService,
        journal: dependencies.journalService, networkMonitor: dependencies.networkMonitor, router: self
    )
    @ObservationIgnored private lazy var connectionsViewModel = ConnectionsViewModel(
        connections: dependencies.connectionsService, router: self
    )
    @ObservationIgnored private lazy var profileViewModel = ProfileViewModel(
        userService: dependencies.userService, astrology: dependencies.astrologyService,
        journal: dependencies.journalService, router: self
    )

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    /// Read from the observable user service, so every top bar updates after an edit.
    var avatar: AvatarContent {
        AvatarContent(
            imageData: dependencies.userService.avatarData,
            name: dependencies.userService.profile?.name ?? ""
        )
    }

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        Binding(
            get: { self.paths[tab] ?? [] },
            set: { self.paths[tab] = $0 }
        )
    }

    // MARK: - MainRouting

    func show(_ route: AppRoute) {
        paths[selectedTab, default: []].append(route)
    }

    func pop() {
        guard paths[selectedTab]?.isEmpty == false else { return }
        paths[selectedTab]?.removeLast()
    }

    func present(_ sheet: AppSheet) {
        self.sheet = sheet
    }

    func dismissSheet() {
        sheet = nil
    }

    /// Refreshes screens whose data may change inside a sheet (e.g. premium status after the paywall).
    func sheetDismissed() {
        profileViewModel.refresh()
        Task {
            await todayViewModel.reload()
            await oracleViewModel.loadSky()
        }
    }

    func select(_ tab: AppTab) {
        selectedTab = tab
    }

    /// Recomputes the week's sky and the natal wheel. Called when Explore becomes visible,
    /// so a birth-data or zodiac change shows up without restarting the app.
    func reloadExplore() async {
        await exploreViewModel.load()
    }

    func askOracle(_ question: String) {
        selectedTab = .oracle
        paths[.oracle] = []
        oracleViewModel.ask(question)
    }

    func signOut() {
        TarotCardStore.clear()
        dependencies.userService.signOut()
        onSignOut?()
    }

    // MARK: - Factory

    @ViewBuilder
    func buildRoot(_ tab: AppTab) -> some View {
        switch tab {
        case .today: TodayView(viewModel: todayViewModel)
        case .explore: ExploreView(viewModel: exploreViewModel)
        case .oracle: OracleView(viewModel: oracleViewModel)
        case .synastry: ConnectionsView(viewModel: connectionsViewModel)
        case .profile: ProfileView(viewModel: profileViewModel)
        }
    }

    @ViewBuilder
    func build(_ route: AppRoute) -> some View {
        switch route {
        case .natalBlueprint:
            NatalBlueprintView(viewModel: NatalBlueprintViewModel(
                astrology: dependencies.astrologyService, userService: dependencies.userService, router: self
            ))
        case .synastry(let connection):
            SynastryView(viewModel: SynastryViewModel(
                connection: connection, connections: dependencies.connectionsService,
                astrology: dependencies.astrologyService, userService: dependencies.userService, router: self
            ))
        case .journal:
            JournalView(viewModel: JournalViewModel(journal: dependencies.journalService, router: self))
        case .settings:
            SettingsView(viewModel: SettingsViewModel(
                preferences: dependencies.preferencesService, userService: dependencies.userService, router: self
            ))
        }
    }

    @ViewBuilder
    func build(_ sheet: AppSheet) -> some View {
        switch sheet {
        case .paywall:
            PaywallView(viewModel: PaywallViewModel(
                subscriptions: dependencies.subscriptionService, router: self
            ))
        case .editProfile:
            EditProfileView(viewModel: EditProfileViewModel(
                userService: dependencies.userService, router: self
            ))
        case .addConnection:
            AddConnectionView(viewModel: AddConnectionViewModel(
                connections: dependencies.connectionsService, astrology: dependencies.astrologyService,
                locationService: dependencies.locationService, router: self,
                onSave: { [weak self] in self?.connectionsViewModel.reload() }
            ))
        }
    }
}

struct MainCoordinatorView: View {
    @Bindable var coordinator: MainCoordinator

    var body: some View {
        TabView(selection: $coordinator.selectedTab) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Tab(tab.title, systemImage: tab.icon, value: tab) {
                    NavigationStack(path: coordinator.path(for: tab)) {
                        coordinator.buildRoot(tab)
                            .navigationDestination(for: AppRoute.self) { route in
                                coordinator.build(route)
                            }
                    }
                }
            }
        }
        .environment(\.userAvatar, coordinator.avatar)
        .onChange(of: coordinator.selectedTab) { _, tab in
            guard tab == .explore else { return }
            Task { await coordinator.reloadExplore() }
        }
        .sheet(item: $coordinator.sheet, onDismiss: coordinator.sheetDismissed) { sheet in
            coordinator.build(sheet)
        }
    }
}
