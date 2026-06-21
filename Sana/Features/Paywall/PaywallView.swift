// Sana — PaywallView.swift
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
                VStack(spacing: 0) {
                    heroSection
                    VStack(spacing: SanaTheme.Spacing.lg) {
                        socialProofRow
                        featuresSection
                        pricingSection
                        footerSection
                    }
                    .padding(SanaTheme.Spacing.md)
                    .padding(.bottom, 40)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(SanaTheme.Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(Text("Close"))
                }
            }
        }
    }

    // MARK: - Sections

    private var heroSection: some View {
        ZStack(alignment: .topTrailing) {
            // Decorative blobs
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 200, height: 200)
                .offset(x: 60, y: -40)
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 120, height: 120)
                .offset(x: -70, y: 100)

            VStack(alignment: .leading, spacing: 0) {
                // PREMIUM badge
                HStack(spacing: 6) {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .bold))
                    Text("PREMIUM")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.6)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(.white.opacity(0.18))
                .clipShape(Capsule())

                Text("Get the\nbest of you.")
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .kerning(-1.2)
                    .lineSpacing(2)
                    .padding(.top, 36)

                Text("Unlock unlimited AI coaching, personalized meal plans, and deep insights.")
                    .font(.system(size: 15))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(3)
                    .padding(.top, 14)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 72)
            .padding(.bottom, 32)
        }
        .background(
            LinearGradient(
                colors: [SanaTheme.Color.primaryDeep, SanaTheme.Color.primary, SanaTheme.Color.accent.opacity(0.9)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        )
    }

    private var socialProofRow: some View {
        HStack(spacing: 0) {
            SocialProofCell(headline: "4.9", stars: true, sub: "2.1k ratings")
            Divider().frame(height: 44).opacity(0.15)
            SocialProofCell(headline: "87%", sub: "Hit weekly\nprotein goals")
            Divider().frame(height: 44).opacity(0.15)
            SocialProofCell(headline: "2.4×", sub: "More likely\nto stick with it")
        }
        .padding(.vertical, 14)
        .background(SanaTheme.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
        .padding(.top, 8)
    }

    private var featuresSection: some View {
        VStack(spacing: 10) {
            ForEach(features, id: \.0) { feature in
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(SanaTheme.Color.primaryLight).frame(width: 40, height: 40)
                        Image(systemName: feature.1)
                            .foregroundStyle(SanaTheme.Color.primary)
                            .font(.system(size: 16, weight: .semibold))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(feature.0)).font(SanaTheme.Font.headline(14))
                        Text(LocalizedStringKey(feature.2)).font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(SanaTheme.Color.primary)
                        .font(.system(size: 16))
                }
                .padding(12)
                .background(SanaTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md)
                    .stroke(SanaTheme.Color.hairline, lineWidth: 0.5))
            }
        }
    }

    private var pricingSection: some View {
        VStack(spacing: 12) {
            if subscription.isLoading {
                ProgressView().tint(SanaTheme.Color.primary)
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
                HStack(spacing: 8) {
                    if subscription.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                        Text("Start free trial").font(SanaTheme.Font.headline())
                    }
                }
            }
            .buttonStyle(NourishButtonStyle())
            .disabled(selectedProduct == nil || subscription.isLoading)
            .onAppear {
                if selectedProduct == nil, let yearly = subscription.yearlyProduct {
                    selectedProduct = yearly.id
                }
            }
            .onChange(of: subscription.yearlyProduct) { _, product in
                if selectedProduct == nil, let product { selectedProduct = product.id }
            }
        }
    }

    private var footerSection: some View {
        VStack(spacing: 8) {
            Button {
                Task { await restore() }
            } label: {
                if isRestoring {
                    ProgressView().scaleEffect(0.75).tint(SanaTheme.Color.primary)
                } else {
                    Text("Restore purchases")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(SanaTheme.Color.primary)
                }
            }
            .disabled(isRestoring)

            Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled. Cancel anytime in Settings.")
                .font(SanaTheme.Font.caption(10))
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
            HapticService.notification(.success)
            dismiss()
        } catch {
            HapticService.notification(.error)
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

private struct SocialProofCell: View {
    let headline: String
    var stars: Bool = false
    let sub: String

    var body: some View {
        VStack(spacing: 4) {
            if stars {
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(SanaTheme.Color.accent)
                    }
                }
            }
            Text(headline)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .kerning(-0.3)
            Text(LocalizedStringKey(sub))
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(1)
        }
        .frame(maxWidth: .infinity)
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
                    HStack(spacing: 6) {
                        Text(LocalizedStringKey(title)).font(SanaTheme.Font.headline())
                        if let badge {
                            Text(badge)
                                .font(SanaTheme.Font.caption(10))
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(SanaTheme.Color.primary)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                    }
                    Text(LocalizedStringKey(subtitle)).font(SanaTheme.Font.caption()).foregroundStyle(.secondary)
                }
                Spacer()
                Text(price)
                    .font(SanaTheme.Font.headline(17))
                    .foregroundStyle(SanaTheme.Color.primary)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? SanaTheme.Color.primary : .secondary)
                    .padding(.leading, 8)
            }
            .padding()
            .background(isRecommended ? SanaTheme.Color.primaryLight : SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
            .overlay(
                RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                    .stroke(
                        isSelected ? SanaTheme.Color.primary :
                        isRecommended ? SanaTheme.Color.primary.opacity(0.3) : SanaTheme.Color.hairline,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
