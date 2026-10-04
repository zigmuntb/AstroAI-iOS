//
//  OnboardingCoordinator.swift
//  AstroAI
//

import SwiftUI

enum OnboardingRoute: Hashable {
    case dateOfBirth
    case birthTime
    case birthplace
    case interests
    case intentions
    case aboutYou
    case name
    case preparation
    case reveal
}

protocol OnboardingRouting: AnyObject {
    func next(from route: OnboardingRoute?)
    func back()
    func finish()
}

/// Data collected across onboarding steps. Shared by all onboarding view models.
@Observable
final class OnboardingDraft {
    var birthDate = Calendar.current.date(from: DateComponents(year: 1994, month: 11, day: 24)) ?? .now
    var birthTime: Date? = Calendar.current.date(from: DateComponents(hour: 3, minute: 14))
    var isBirthTimeApproximate = false
    var birthPlace: BirthPlace?
    var name = ""
    var interests: Set<Interest> = []
    var intentions: Set<Intention> = []
    var personal = PersonalContext()
    var chart: NatalChart?

    var birthData: BirthData {
        BirthData(date: birthDate, time: birthTime, place: birthPlace, isTimeApproximate: isBirthTimeApproximate)
    }

    func makeProfile() -> UserProfile {
        UserProfile(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            birth: birthData,
            interests: interests,
            intentions: intentions,
            personal: personal.isEmpty ? nil : personal
        )
    }
}

@Observable
final class OnboardingCoordinator: OnboardingRouting {
    var path: [OnboardingRoute] = []
    @ObservationIgnored var onFinish: (() -> Void)?

    @ObservationIgnored let draft = OnboardingDraft()
    @ObservationIgnored private let dependencies: AppDependencies

    /// Steps that show the "Step N of M" progress header.
    static let steps: [OnboardingRoute] = [.dateOfBirth, .birthTime, .birthplace, .interests, .intentions, .aboutYou, .name, .reveal]

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
    }

    // MARK: - OnboardingRouting

    func next(from route: OnboardingRoute?) {
        let order: [OnboardingRoute] = [.dateOfBirth, .birthTime, .birthplace, .interests, .intentions, .aboutYou, .name, .preparation, .reveal]
        guard let route else {
            path.append(.dateOfBirth)
            return
        }
        guard let index = order.firstIndex(of: route), index + 1 < order.count else { return }
        let nextRoute = order[index + 1]

        if nextRoute == .reveal {
            // Preparation is a transient screen, replace it so "back" skips it.
            path.removeLast()
        }
        path.append(nextRoute)
    }

    func back() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }

    func finish() {
        onFinish?()
    }

    // MARK: - Factory

    func makeWelcome() -> some View {
        WelcomeView(viewModel: WelcomeViewModel(router: self))
    }

    @ViewBuilder
    func build(_ route: OnboardingRoute) -> some View {
        switch route {
        case .dateOfBirth:
            DateOfBirthView(viewModel: DateOfBirthViewModel(draft: draft, astrology: dependencies.astrologyService, router: self))
        case .birthTime:
            BirthTimeView(viewModel: BirthTimeViewModel(draft: draft, router: self))
        case .birthplace:
            BirthplaceView(viewModel: BirthplaceViewModel(draft: draft, locationService: dependencies.locationService, router: self))
        case .interests:
            InterestsView(viewModel: InterestsViewModel(draft: draft, router: self))
        case .intentions:
            IntentionsView(viewModel: IntentionsViewModel(draft: draft, router: self))
        case .aboutYou:
            AboutYouView(viewModel: AboutYouViewModel(draft: draft, router: self))
        case .name:
            NameView(viewModel: NameViewModel(draft: draft, router: self))
        case .preparation:
            ChartPreparationView(viewModel: ChartPreparationViewModel(draft: draft, astrology: dependencies.astrologyService, router: self))
        case .reveal:
            ChartRevealView(viewModel: ChartRevealViewModel(draft: draft, userService: dependencies.userService, router: self))
        }
    }
}

struct OnboardingCoordinatorView: View {
    @Bindable var coordinator: OnboardingCoordinator

    var body: some View {
        NavigationStack(path: $coordinator.path) {
            coordinator.makeWelcome()
                .navigationDestination(for: OnboardingRoute.self) { route in
                    coordinator.build(route)
                        .navigationBarBackButtonHidden()
                }
        }
    }
}
