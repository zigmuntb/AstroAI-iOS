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
    }
}

struct AppCoordinatorView: View {
    let coordinator: AppCoordinator

    var body: some View {
        Group {
            switch coordinator.flow {
            case .onboarding(let onboarding):
                OnboardingCoordinatorView(coordinator: onboarding)
            case .main(let main):
                MainCoordinatorView(coordinator: main)
            }
        }
        .preferredColorScheme(.light)
        .tint(AppColor.primaryContainer)
    }
}
