//
//  IntentionsViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class IntentionsViewModel {
    let options = Intention.allCases

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, router: OnboardingRouting) {
        self.draft = draft
        self.router = router
    }

    var selectedCountText: String { "\(draft.intentions.count) Selected" }
    var canContinue: Bool { !draft.intentions.isEmpty }

    func isSelected(_ intention: Intention) -> Bool {
        draft.intentions.contains(intention)
    }

    func toggle(_ intention: Intention) {
        if draft.intentions.contains(intention) {
            draft.intentions.remove(intention)
        } else {
            draft.intentions.insert(intention)
        }
    }

    func next() {
        guard canContinue else { return }
        router?.next(from: .intentions)
    }

    func back() {
        router?.back()
    }
}
