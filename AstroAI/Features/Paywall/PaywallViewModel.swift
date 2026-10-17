//
//  PaywallViewModel.swift
//  AstroAI
//

import Foundation
import Observation

@Observable
final class PaywallViewModel {
    struct Feature: Identifiable {
        var id: String { title }
        let icon: String
        let title: String
        let text: String
    }

    struct AlertContent: Identifiable {
        var id: String { title + message }
        let title: String
        let message: String
    }

    let features = [
        Feature(icon: "brain.head.profile", title: "Unlimited AI Dialogue",
                text: "Converse freely with an astrologer tuned directly to your exact natal degrees and house cusps."),
        Feature(icon: "square.on.square", title: "Complete Natal Blueprint",
                text: "Unravel deep house rulerships, planetary essential dignities, and karmic lunar nodal paths."),
        Feature(icon: "circle.circle", title: "Multilateral Synastry",
                text: "Overlay boundless partner, family, and friend charts to inspect composite friction and harmony."),
        Feature(icon: "clock.arrow.circlepath", title: "Ephemeris Transit Forecasts",
                text: "Chronological map of major life cycles: calculate upcoming Saturn returns, solar eclipses, and nodal shifts.")
    ]

    private(set) var plans: [SubscriptionPlan] = []
    var selectedPlanID: String?
    private(set) var isLoading = false
    private(set) var isPurchasing = false
    var alert: AlertContent?

    @ObservationIgnored private let subscriptions: SubscriptionServicing
    @ObservationIgnored private weak var router: MainRouting?

    init(subscriptions: SubscriptionServicing, router: MainRouting) {
        self.subscriptions = subscriptions
        self.router = router
    }

    // MARK: - Display state

    var selectedPlan: SubscriptionPlan? {
        plans.first { $0.id == selectedPlanID }
    }

    var ctaTitle: String {
        guard let plan = selectedPlan else { return "Subscribe" }
        if let trial = plan.trial { return "Begin \(trial) Free Trial" }
        return "Subscribe for \(plan.price) \(plan.period)"
    }

    var termsText: String {
        guard let plan = selectedPlan else { return "" }
        let period = plan.period.replacingOccurrences(of: "/ ", with: "")
        let cancel = "Cancel anytime in Settings › Apple ID › Subscriptions."
        if let trial = plan.trial {
            return "After the \(trial) free trial, renews at \(plan.price)/\(period) until canceled. \(cancel)"
        }
        let cadence = period == "month" ? "monthly" : "every \(period)"
        return "Billed \(cadence) at \(plan.price) until canceled. \(cancel)"
    }

    var isBusy: Bool { isLoading || isPurchasing }

    // MARK: - Actions

    func load() async {
        guard plans.isEmpty, !isLoading else { return }
        isLoading = true
        do {
            plans = try await subscriptions.plans()
            // Annual (the plan with a badge) is the default choice.
            selectedPlanID = (plans.first { $0.badge != nil } ?? plans.first)?.id
        } catch {
            alert = AlertContent(title: "Plans Unavailable", message: error.localizedDescription)
        }
        isLoading = false
    }

    func select(_ plan: SubscriptionPlan) {
        selectedPlanID = plan.id
    }

    func purchase() async {
        guard let plan = selectedPlan, !isPurchasing else { return }
        isPurchasing = true
        do {
            let purchased = try await subscriptions.purchase(plan)
            isPurchasing = false
            if purchased { router?.dismissSheet() }
        } catch {
            isPurchasing = false
            alert = AlertContent(title: "Purchase Failed", message: error.localizedDescription)
        }
    }

    func restore() async {
        guard !isPurchasing else { return }
        isPurchasing = true
        do {
            let restored = try await subscriptions.restore()
            isPurchasing = false
            if restored {
                router?.dismissSheet()
            } else {
                alert = AlertContent(title: "Nothing to Restore", message: "No previous AstroAI subscription was found for this Apple ID.")
            }
        } catch {
            isPurchasing = false
            alert = AlertContent(title: "Restore Failed", message: error.localizedDescription)
        }
    }

    func close() {
        router?.dismissSheet()
    }
}
