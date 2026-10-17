//
//  WelcomeViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class WelcomeViewModel {
    var selectedPlanet: Planet?

    @ObservationIgnored private weak var router: OnboardingRouting?

    init(router: OnboardingRouting) {
        self.router = router
    }

    func begin() {
        router?.next(from: nil)
    }

    func signIn() {
        // Supabase auth will be plugged in here.
        router?.next(from: nil)
    }

    func select(_ planet: Planet) {
        selectedPlanet = selectedPlanet == planet ? nil : planet
    }
}
