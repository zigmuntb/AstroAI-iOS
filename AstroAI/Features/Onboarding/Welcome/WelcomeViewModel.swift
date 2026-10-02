//
//  WelcomeViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class WelcomeViewModel {
    struct Feature: Identifiable {
        var id: String { title }
        let eyebrow: String
        let title: String
        let caption: String
    }

    let features = [
        Feature(eyebrow: "Planetary", title: "Swiss", caption: "Ephemeris"),
        Feature(eyebrow: "Cognition", title: "Adaptive", caption: "Deep Synthesis"),
        Feature(eyebrow: "Integrity", title: "Private", caption: "On-Device Key")
    ]

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
