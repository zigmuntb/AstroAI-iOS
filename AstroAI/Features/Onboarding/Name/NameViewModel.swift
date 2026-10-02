//
//  NameViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class NameViewModel {
    var name: String {
        didSet {
            if name.count > UserProfile.nameMaxLength {
                name = String(name.prefix(UserProfile.nameMaxLength))
            }
            draft.name = name
        }
    }

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, router: OnboardingRouting) {
        self.draft = draft
        self.router = router
        name = draft.name
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canContinue: Bool { UserProfile.validatedName(name) != nil }

    /// Live preview of how the Today screen will greet the user.
    var greetingPreview: String {
        canContinue ? "Good morning, \(trimmedName)." : "Good morning."
    }

    var counterText: String { "\(name.count)/\(UserProfile.nameMaxLength)" }

    func continueTapped() {
        guard canContinue else { return }
        draft.name = trimmedName
        router?.next(from: .name)
    }

    func back() {
        router?.back()
    }
}
