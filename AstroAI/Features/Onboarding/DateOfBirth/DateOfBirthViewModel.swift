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

    /// Latest selectable moment for the original system date picker.
    let latestDate = Date.now

    private(set) var bounds: BirthDateBounds

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private let astrology: AstrologyServicing
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, astrology: AstrologyServicing, router: OnboardingRouting) {
        self.draft = draft
        self.astrology = astrology
        self.router = router
        let bounds = BirthDateBounds()
        self.bounds = bounds
        let clamped = bounds.clamp(draft.birthDate)
        self.birthDate = clamped
        // didSet does not run during init.
        draft.birthDate = clamped
    }

    var day: Int {
        get { bounds.calendar.component(.day, from: birthDate) }
        set { apply(bounds.setting(day: newValue, on: birthDate)) }
    }

    var month: Int {
        get { bounds.calendar.component(.month, from: birthDate) }
        set { apply(bounds.setting(month: newValue, on: birthDate)) }
    }

    var year: Int {
        get { bounds.calendar.component(.year, from: birthDate) }
        set { apply(bounds.setting(year: newValue, on: birthDate)) }
    }

    var selectableDays: [Int] {
        bounds.days(in: year, month: month)
    }

    var selectableMonths: [Int] {
        bounds.months(in: year)
    }

    var selectableYears: [Int] {
        bounds.years
    }

    var skyAngle: Double {
        CelestialRotation.angle(year: year, month: month, day: day)
    }

    func monthTitle(_ month: Int) -> String {
        bounds.monthTitle(month)
    }

    /// Rebuilds the 112-year window from the current date and pulls the selection back inside it.
    func refreshBounds(now: Date = .now, calendar: Calendar = .current) {
        bounds = BirthDateBounds(now: now, calendar: calendar)
        apply(bounds.clamp(birthDate))
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
        apply(bounds.clamp(birthDate))
        router?.next(from: .dateOfBirth)
    }

    func back() {
        router?.back()
    }

    private func apply(_ date: Date) {
        let next = bounds.clamp(date)
        guard !bounds.calendar.isDate(next, inSameDayAs: birthDate) else { return }
        birthDate = next
    }
}
