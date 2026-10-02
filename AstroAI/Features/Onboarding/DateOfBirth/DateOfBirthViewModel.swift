//
//  DateOfBirthViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class DateOfBirthViewModel {
    var birthDate: Date {
        didSet { draft.birthDate = birthDate }
    }

    /// Latest selectable birth date.
    let latestDate = Date.now

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, astrology: AstrologyServicing, router: OnboardingRouting) {
        self.draft = draft
        self.astrology = astrology
        self.router = router
        self.birthDate = draft.birthDate
    }

    var sunSign: ZodiacSign {
        astrology.sunSign(for: birthDate)
    }

    var moonPhase: MoonPhase {
        astrology.moonPhase(for: birthDate)
    }

    var illuminationText: String {
        "\(moonPhase.illumination)% Illumination"
    }

    func continueTapped() {
        router?.next(from: .dateOfBirth)
    }

    func back() {
        router?.back()
    }
}
