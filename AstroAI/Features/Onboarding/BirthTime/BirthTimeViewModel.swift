//
//  BirthTimeViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class BirthTimeViewModel {
    /// Traditional baselines used when the exact birth time is unknown.
    enum Approximation: Int, CaseIterable, Identifiable {
        case morning = 6
        case solarNoon = 12
        case evening = 18

        var id: Int { rawValue }
        var hour: Int { rawValue }

        var title: String {
            switch self {
            case .morning: "Morning"
            case .solarNoon: "Solar Noon"
            case .evening: "Evening"
            }
        }
    }

    /// Exact time chosen in the picker.
    var exactTime: Date {
        didSet { syncDraft() }
    }

    var isTimeUnknown = false {
        didSet { syncDraft() }
    }

    var approximation: Approximation = .morning {
        didSet { syncDraft() }
    }

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private weak var router: OnboardingRouting?
    @ObservationIgnored private let calendar = Calendar.current

    init(draft: OnboardingDraft, router: OnboardingRouting) {
        self.draft = draft
        self.router = router
        self.exactTime = draft.birthTime ?? Calendar.current.date(from: DateComponents(hour: 12, minute: 0)) ?? .now
    }

    /// Time shown in the "Selected Meridian Time" badge.
    var displayTime: String {
        isTimeUnknown ? "Approx. \(label(for: approximation))" : Self.formatter.string(from: exactTime)
    }

    func label(for approximation: Approximation) -> String {
        Self.formatter.string(from: date(for: approximation))
    }

    func select(_ approximation: Approximation) {
        self.approximation = approximation
    }

    func continueTapped() {
        syncDraft()
        router?.next(from: .birthTime)
    }

    func back() {
        router?.back()
    }

    // The draft always holds the effective time: exact, or the chosen approximation.
    private func syncDraft() {
        draft.birthTime = isTimeUnknown ? date(for: approximation) : exactTime
    }

    private func date(for approximation: Approximation) -> Date {
        calendar.date(from: DateComponents(hour: approximation.hour, minute: 0)) ?? exactTime
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()
}
