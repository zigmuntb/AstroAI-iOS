//
//  SubscriptionService.swift
//  AstroAI
//

import Observation
import StoreKit
import UIKit

protocol SubscriptionServicing: AnyObject {
    /// "Renews Oct 17, 2026" or "Ends Oct 17, 2026" while Sanctuary is active.
    var renewalDescription: String? { get }

    func start()
    func plans() async throws -> [SubscriptionPlan]
    /// `true` when Sanctuary was unlocked. `false` when the person canceled the sheet.
    func purchase(_ plan: SubscriptionPlan) async throws -> Bool
    func restore() async throws -> Bool
    func showManageSubscriptions() async
}

enum SubscriptionError: LocalizedError {
    case productsUnavailable
    case productMissing
    case pending
    case unverified
    case failed

    var errorDescription: String? {
        switch self {
        case .productsUnavailable:
            "Subscriptions aren't available right now. Check your connection and try again."
        case .productMissing:
            "This plan is no longer available."
        case .pending:
            "This purchase is waiting for approval. Sanctuary unlocks when it completes."
        case .unverified:
            "The App Store couldn't verify this purchase."
        case .failed:
            "The purchase didn't go through."
        }
    }
}

/// Sanctuary through StoreKit 2. Product identifiers must match App Store Connect:
/// `com.BogdanArsenkin.AstroAI.sanctuary.annual` and `.monthly`.
@Observable
final class SubscriptionService: SubscriptionServicing {
    nonisolated static let annualID = "com.BogdanArsenkin.AstroAI.sanctuary.annual"
    nonisolated static let monthlyID = "com.BogdanArsenkin.AstroAI.sanctuary.monthly"
    nonisolated static let productIDs = [annualID, monthlyID]

    private(set) var renewalDescription: String?

    @ObservationIgnored private let userService: UserServicing
    @ObservationIgnored private var products: [String: Product] = [:]
    @ObservationIgnored private var updates: Task<Void, Never>?

    init(userService: UserServicing) {
        self.userService = userService
    }

    func start() {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            await self?.refreshEntitlements()
            await self?.listenForUpdates()
        }
    }

    // MARK: - Catalog

    func plans() async throws -> [SubscriptionPlan] {
        let loaded = try await Product.products(for: Self.productIDs)
        guard !loaded.isEmpty else { throw SubscriptionError.productsUnavailable }
        products = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        let annual = loaded.first { $0.id == Self.annualID }
        let monthly = loaded.first { $0.id == Self.monthlyID }
        return loaded
            .sorted { Self.rank($0) < Self.rank($1) }
            .map { Self.plan(from: $0, annual: annual, monthly: monthly) }
    }

    func purchase(_ plan: SubscriptionPlan) async throws -> Bool {
        let product = try await product(for: plan.id)
        switch try await product.purchase() {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return userService.profile?.isPremium ?? false
        case .userCancelled:
            return false
        case .pending:
            throw SubscriptionError.pending
        @unknown default:
            throw SubscriptionError.failed
        }
    }

    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlements()
        return userService.profile?.isPremium ?? false
    }

    func showManageSubscriptions() async {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else { return }
        try? await AppStore.showManageSubscriptions(in: scene)
        await refreshEntitlements()
    }

    // MARK: - Entitlements

    private func listenForUpdates() async {
        for await result in Transaction.updates {
            guard let transaction = try? Self.verified(result) else { continue }
            await transaction.finish()
            await refreshEntitlements()
        }
    }

    private func refreshEntitlements() async {
        var best: Transaction?
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result) else { continue }
            guard Self.productIDs.contains(transaction.productID) else { continue }
            guard transaction.revocationDate == nil else { continue }
            if best == nil || (transaction.expirationDate ?? .distantFuture) > (best?.expirationDate ?? .distantFuture) {
                best = transaction
            }
        }
        if let best {
            renewalDescription = await renewalLine(for: best)
            userService.setPremium(true)
        } else {
            renewalDescription = nil
            userService.setPremium(false)
        }
    }

    private func renewalLine(for transaction: Transaction) async -> String? {
        guard let expiration = transaction.expirationDate else { return "Sanctuary" }
        let formatted = expiration.formatted(.dateTime.month(.abbreviated).day().year())
        var willRenew = true
        if let product = try? await product(for: transaction.productID),
           let statuses = try? await product.subscription?.status {
            for status in statuses {
                guard case .verified(let renewal) = status.renewalInfo else { continue }
                guard case .verified(let current) = status.transaction, current.id == transaction.id else { continue }
                willRenew = renewal.willAutoRenew
            }
        }
        return willRenew ? "Renews \(formatted)" : "Ends \(formatted)"
    }

    private func product(for id: String) async throws -> Product {
        if let cached = products[id] { return cached }
        let loaded = try await Product.products(for: [id])
        guard let product = loaded.first else { throw SubscriptionError.productMissing }
        products[id] = product
        return product
    }

    nonisolated private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw SubscriptionError.unverified
        }
    }

    // MARK: - Display

    nonisolated private static func rank(_ product: Product) -> Int {
        switch product.subscription?.subscriptionPeriod.unit {
        case .year: 0
        case .month: 1
        default: 2
        }
    }

    nonisolated private static func plan(from product: Product, annual: Product?, monthly: Product?) -> SubscriptionPlan {
        let period = product.subscription?.subscriptionPeriod
        let trial = product.subscription?.introductoryOffer.flatMap { offer -> String? in
            offer.paymentMode == .freeTrial ? length(offer.period) : nil
        }
        var notes: [String] = []
        if let trial { notes.append("\(trial) Free Trial") }
        if product.id == annualID, let annual, let monthly, let saved = savingsPercent(annual: annual, monthly: monthly) {
            notes.append("Save \(saved)%")
        }
        let subtitle: String
        if product.id == annualID, let period, period.unit == .year, period.value == 1 {
            let perMonth = (product.price / 12).formatted(product.priceFormatStyle)
            subtitle = "\(perMonth) / month, billed annually"
        } else {
            subtitle = product.description
        }
        return SubscriptionPlan(
            id: product.id,
            title: product.displayName,
            subtitle: subtitle,
            price: product.displayPrice,
            period: period.map(unitSuffix) ?? "",
            badge: notes.isEmpty ? nil : notes.joined(separator: " • "),
            trial: trial
        )
    }

    nonisolated private static func savingsPercent(annual: Product, monthly: Product) -> Int? {
        let fullYear = monthly.price * 12
        guard fullYear > annual.price else { return nil }
        let saved = (fullYear - annual.price) / fullYear * 100
        let percent = Int(NSDecimalNumber(decimal: saved).doubleValue.rounded())
        return percent > 0 ? percent : nil
    }

    /// "1-week", used in the trial badge and the renewal sentence.
    nonisolated private static func length(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day: return value == 1 ? "1-day" : "\(value)-day"
        case .week: return value == 1 ? "1-week" : "\(value)-week"
        case .month: return value == 1 ? "1-month" : "\(value)-month"
        case .year: return value == 1 ? "1-year" : "\(value)-year"
        @unknown default: return "free"
        }
    }

    nonisolated private static func unitSuffix(_ period: Product.SubscriptionPeriod) -> String {
        let value = period.value
        switch period.unit {
        case .day: return value == 1 ? "/ day" : "/ \(value) days"
        case .week: return value == 1 ? "/ week" : "/ \(value) weeks"
        case .month: return value == 1 ? "/ month" : "/ \(value) months"
        case .year: return value == 1 ? "/ year" : "/ \(value) years"
        @unknown default: return ""
        }
    }
}
