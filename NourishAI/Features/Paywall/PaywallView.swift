// NourishAI — PaywallView.swift
import SwiftUI
import StoreKit

struct PaywallView: View {

    @EnvironmentObject private var subscription: SubscriptionService
    @Environment(\.dismiss) private var dismiss
    @State private var isRestoring = false
    @State private var error: String?
    @State private var selectedProduct: String?

    let features = [
        ("Unlimited meal analyses", "camera.fill", "No daily limits — scan every meal"),
        ("AI meal planner", "calendar.badge.plus", "Personalised 7-day plans"),
        ("Grocery list generation", "cart.fill", "Smart shopping lists from your plan"),
        ("Deficiency alerts", "bell.badge.fill", "Get notified about nutritional gaps"),
        ("HealthKit deep sync", "heart.fill", "Full integration with Apple Health"),
        ("Advanced insights", "chart.line.uptrend.xyaxis", "Weekly nutrition trends & reports")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NourishTheme.Spacing.lg) {
                    heroSection
                    featuresSection
                    pricingSection
                    footerSection
                }
                .padding(NourishTheme.Spacing.md)
                .padding(.bottom, 40)
            }
            .background(NourishTheme.Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(NourishTheme.Color.primaryLight).frame(width: 90, height: 90)
                Image(systemName: "sparkles").font(.system(size: 40)).foregroundStyle(NourishTheme.Color.primary)
            }
            Text("Unlock NourishAI Premium")
                .font(NourishTheme.Font.title(26))
                .multilineTextAlignment(.center)
            Text("Everything you need to eat better, feel great, and hit your health goals.")
                .font(NourishTheme.Font.body())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 14) {
                    ZStack {
                        Circle().fill(NourishTheme.Color.primaryLight).frame(width: 40, height: 40)
                        Image(systemName: feature.1).foregroundStyle(NourishTheme.Color.primary).font(.system(size: 16))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.0).font(NourishTheme.Font.headline(14))
                        Text(feature.2).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(NourishTheme.Color.primary)
                }
                .padding(12)
                .background(NourishTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
            }
        }
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if subscription.isLoading {
                ProgressView().tint(NourishTheme.Color.primary)
            } else {
                if let yearly = subscription.yearlyProduct {
                    PricingCard(
                        title: "Yearly",
                        price: yearly.displayPrice,
                        subtitle: "Best value",
                        badge: subscription.yearlySavingsPct.map { "Save \($0)%" },
                        isSelected: selectedProduct == yearly.id,
                        isRecommended: true
                    ) { selectedProduct = yearly.id }
                }
                if let monthly = subscription.monthlyProduct {
                    PricingCard(
                        title: "Monthly",
                        price: monthly.displayPrice + "/month",
                        subtitle: "Cancel anytime",
                        badge: nil,
                        isSelected: selectedProduct == monthly.id,
                        isRecommended: false
                    ) { selectedProduct = monthly.id }
                }
            }

            if let error { ErrorBanner(message: error, retry: nil) }

            Button {
                Task { await purchase() }
            } label: {
                HStack {
                    if subscription.isLoading { ProgressView().tint(.white) }
                    Text("Start free trial").font(NourishTheme.Font.headline())
                }
            }
            .buttonStyle(NourishButtonStyle())
            .disabled(selectedProduct == nil || subscription.isLoading)
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button("Restore purchases") {
                Task { await restore() }
            }
            .font(NourishTheme.Font.caption())
            .foregroundStyle(NourishTheme.Color.primary)

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled. Cancel anytime in Settings.")
                .font(NourishTheme.Font.caption(10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Actions

    private func purchase() async {
        guard let id = selectedProduct,
              let product = subscription.products.first(where: { $0.id == id }) else { return }
        do {
            try await subscription.purchase(product)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func restore() async {
        isRestoring = true
        do {
            try await subscription.restorePurchases()
            if subscription.isPremium { dismiss() }
        } catch {
            self.error = error.localizedDescription
        }
        isRestoring = false
    }
}

private struct PricingCard: View {
    let title: String; let price: String; let subtitle: String
    let badge: String?; let isSelected: Bool; let isRecommended: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title).font(NourishTheme.Font.headline())
                        if let badge {
                            Text(badge).font(NourishTheme.Font.caption(10)).padding(.horizontal, 8).padding(.vertical, 3)
                                .background(NourishTheme.Color.primary).foregroundStyle(.white).clipShape(Capsule())
                        }
                    }
                    Text(subtitle).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price).font(NourishTheme.Font.headline(17)).foregroundStyle(NourishTheme.Color.primary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? NourishTheme.Color.primary : .secondary)
                    .padding(.leading, 8)
            }
            .padding()
            .background(NourishTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg)
                .stroke(isSelected ? NourishTheme.Color.primary : Color.clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
