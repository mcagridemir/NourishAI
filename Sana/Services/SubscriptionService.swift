// Sana — SubscriptionService.swift
import Foundation
import StoreKit
internal import Combine

@MainActor
final class SubscriptionService: ObservableObject {

    static let shared = SubscriptionService()

    @Published var products: [Product] = []
    @Published var isPremium = false
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
            self.error = "Failed to load products: \(error.localizedDescription)"
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
            await updatePremiumStatus(transaction)
            await transaction.finish()
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
                    isPremium = transaction.revocationDate == nil
                    return
                }
            }
        }
        isPremium = false
    }

    var monthlyProduct: Product? { products.first { $0.id == monthlyProductId } }
    var yearlyProduct:  Product? { products.first { $0.id == yearlyProductId  } }

    var yearlySavingsPct: Int? {
        guard let m = monthlyProduct, let y = yearlyProduct else { return nil }
        let annualMonthly = m.price * 12
        guard annualMonthly > 0 else { return nil }
        return Int(((annualMonthly - y.price) / annualMonthly * 100) as NSDecimalNumber)
    }

    // MARK: - Private

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await updatePremiumStatus(transaction)
                await transaction.finish()
            }
        }
    }

    private func updatePremiumStatus(_ transaction: Transaction) async {
        isPremium = [monthlyProductId, yearlyProductId].contains(transaction.productID)
                    && transaction.revocationDate == nil
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
    var errorDescription: String? { "Purchase verification failed." }
}
