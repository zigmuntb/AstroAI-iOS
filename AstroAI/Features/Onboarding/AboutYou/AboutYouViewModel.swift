//
//  AboutYouViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class AboutYouViewModel {
    var context: PersonalContext {
        didSet { draft.personal = context }
    }

    @ObservationIgnored private let draft: OnboardingDraft
    @ObservationIgnored private weak var router: OnboardingRouting?

    init(draft: OnboardingDraft, router: OnboardingRouting) {
        self.draft = draft
        self.router = router
        self.context = draft.personal
    }

    var answeredCountText: String {
        let answers: [Bool] = [
            context.relationship != nil, context.lifeStage != nil, context.pronouns != nil,
            !(context.currentFocus ?? "").isEmpty, context.tone != nil || context.length != nil
        ]
        return "\(answers.filter { $0 }.count) of \(answers.count) shared"
    }

    var continueTitle: String { context.isEmpty ? "Skip for now" : "Continue" }

    func next() {
        router?.next(from: .aboutYou)
    }

    func back() {
        router?.back()
    }
}
