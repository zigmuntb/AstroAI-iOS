//
//  AppCoordinator.swift
//  AstroAI
//

import SwiftUI

/// Root coordinator. Decides which flow is on screen: onboarding or the main tab app.
@Observable
final class AppCoordinator {
    enum Flow {
        case onboarding(OnboardingCoordinator)
        case main(MainCoordinator)
    }

    private(set) var flow: Flow
    @ObservationIgnored private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        flow = .onboarding(OnboardingCoordinator(dependencies: dependencies))

        if dependencies.userService.hasCompletedOnboarding {
            showMain()
        } else {
            showOnboarding()
        }
    }

    private func showOnboarding() {
        let coordinator = OnboardingCoordinator(dependencies: dependencies)
        coordinator.onFinish = { [weak self] in self?.showMain() }
        withAnimation { flow = .onboarding(coordinator) }
    }

    private func showMain() {
        let coordinator = MainCoordinator(dependencies: dependencies)
        coordinator.onSignOut = { [weak self] in self?.showOnboarding() }
        withAnimation { flow = .main(coordinator) }
        dependencies.attunement.refresh()
    }

    func attune() {
        guard case .main = flow else { return }
        dependencies.attunement.refresh()
    }
}

struct AppCoordinatorView: View {
    let coordinator: AppCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var showsLaunchAnimation = true

    var body: some View {
        ZStack {
            Group {
                switch coordinator.flow {
                case .onboarding(let onboarding):
                    OnboardingCoordinatorView(coordinator: onboarding)
                case .main(let main):
                    MainCoordinatorView(coordinator: main)
                }
            }

            if showsLaunchAnimation {
                LaunchAnimationView {
                    showsLaunchAnimation = false
                }
                .zIndex(1)
            }
        }
        .tint(AppColor.primary)
        .dismissKeyboardOnTap()
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, !showsLaunchAnimation else { return }
            coordinator.attune()
        }
        .onChange(of: showsLaunchAnimation) { _, showing in
            guard !showing, scenePhase == .active else { return }
            coordinator.attune()
        }
    }
}
