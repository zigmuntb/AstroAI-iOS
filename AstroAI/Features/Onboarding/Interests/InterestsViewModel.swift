//
//  InterestsViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class InterestsViewModel {
    let options = Interest.allCases

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, router: OnboardingRouting) {
        self.draft = draft
        self.router = router
    }

    var selectedCountText: String { "\(draft.interests.count) selected" }
    var canContinue: Bool { !draft.interests.isEmpty }

    func isSelected(_ interest: Interest) -> Bool {
        draft.interests.contains(interest)
    }

    func toggle(_ interest: Interest) {
        if draft.interests.contains(interest) {
            draft.interests.remove(interest)
        } else {
            draft.interests.insert(interest)
        }
    }

    func next() {
        guard canContinue else { return }
        router?.next(from: .interests)
    }

    func back() {
        router?.back()
    }
}
