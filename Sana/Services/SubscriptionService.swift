// Sana — SubscriptionService.swift
import Foundation
import StoreKit
internal import Combine

@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    @Published var products: [Product] = []
    @Published var isPremium = false
    @Published var activeTransactionID: String?
    @Published var isLoading = false
    @Published var error: String?

    private let monthlyProductId = "com.sana.premium.monthly"
    private let yearlyProductId  = "com.sana.premium.yearly"
    private var updateTask: Task<Void, Never>?

    private init() {
        updateTask = Task { await listenForTransactions() }
        Task { await loadProducts() }
    }

    deinit { updateTask?.cancel() }

    // MARK: - Load products from App Store Connect

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            products = try await Product.products(for: [monthlyProductId, yearlyProductId])
                .sorted { $0.price < $1.price }
            await checkCurrentEntitlement()
        } catch {
            self.error = String(format: NSLocalizedString("Failed to load products: %@", comment: ""), error.localizedDescription)
        }
    }

    // MARK: - Purchase

    func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            // Re-derive premium from the authoritative current entitlements
            // rather than judging from this single transaction.
            await checkCurrentEntitlement()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    // MARK: - Restore

    func restorePurchases() async throws {
        try await AppStore.sync()
        await checkCurrentEntitlement()
    }

    // MARK: - Entitlement check

    func checkCurrentEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                if [monthlyProductId, yearlyProductId].contains(transaction.productID) {
                    let active = transaction.revocationDate == nil
                    isPremium = active
                    activeTransactionID = active ? String(transaction.originalID) : nil
                    return
                }
            }
        }
        isPremium = false
        activeTransactionID = nil
    }

    var monthlyProduct: Product? { products.first { $0.id == monthlyProductId } }
    var yearlyProduct:  Product? { products.first { $0.id == yearlyProductId  } }

    var yearlySavingsPct: Int? {
        guard let m = monthlyProduct, let y = yearlyProduct else { return nil }
        return Self.yearlySavingsPercent(monthlyPrice: m.price, yearlyPrice: y.price)
    }

    /// Pure savings calculation, extracted so it can be unit-tested without StoreKit `Product`s.
    nonisolated static func yearlySavingsPercent(monthlyPrice: Decimal, yearlyPrice: Decimal) -> Int? {
        let annualMonthly = monthlyPrice * 12
        guard annualMonthly > 0 else { return nil }
        // Note: convert via doubleValue, not Int(_: NSDecimalNumber) — a high-precision
        // Decimal (e.g. 33.2164…) makes NSDecimalNumber.intValue return 0, which would
        // render "0% savings" on the paywall for realistic prices like 4.99 / 39.99.
        let pct = (annualMonthly - yearlyPrice) / annualMonthly * 100
        return Int((pct as NSDecimalNumber).doubleValue)
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                // Renewals, revocations and expirations all change entitlement
                // state — re-derive from the source of truth.
                await checkCurrentEntitlement()
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw SubscriptionError.failedVerification
        case .verified(let value): return value
        }
    }
}

enum SubscriptionError: LocalizedError {
    case failedVerification
    var errorDescription: String? { NSLocalizedString("Purchase verification failed.", comment: "") }
}
