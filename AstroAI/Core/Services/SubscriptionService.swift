//
//  SubscriptionService.swift
//  AstroAI
//

import Foundation

protocol SubscriptionServicing {
    func plans() async throws -> [SubscriptionPlan]
    func purchase(_ plan: SubscriptionPlan) async throws
    func restore() async throws -> Bool
}

/// Paywall purchases. Placeholder until StoreKit 2 products are configured.
final class SubscriptionService: SubscriptionServicing {
    private let userService: UserServicing

    init(userService: UserServicing) {
        self.userService = userService
    }

    func plans() async throws -> [SubscriptionPlan] {
        MockData.plans
    }

    func purchase(_ plan: SubscriptionPlan) async throws {
        try await Task.sleep(for: .milliseconds(600))
        userService.setPremium(true)
    }

    func restore() async throws -> Bool {
        try await Task.sleep(for: .milliseconds(400))
        return userService.profile?.isPremium ?? false
    }
}
