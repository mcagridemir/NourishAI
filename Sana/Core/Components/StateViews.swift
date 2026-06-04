// Sana — StateViews.swift
// Shared full-screen empty state and error state components.
import SwiftUI

// MARK: - Empty state

struct SanaEmptyView: View {
    let icon: String
    var iconColor: Color = SanaTheme.Color.primary
    let title: String
    let subtitle: String
    var features: [String] = []          // optional bullet list
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: SanaTheme.Spacing.xl) {
            // Icon blob
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: icon)
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(iconColor)
            }
            .accessibilityHidden(true)

            // Text
            VStack(spacing: SanaTheme.Spacing.sm) {
                Text(title)
                    .font(SanaTheme.Font.headline(20))
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(SanaTheme.Font.body(15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Feature bullets (optional)
            if !features.isEmpty {
                VStack(alignment: .leading, spacing: SanaTheme.Spacing.sm) {
                    ForEach(features, id: \.self) { feature in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(iconColor)
                                .accessibilityHidden(true)
                            Text(feature)
                                .font(SanaTheme.Font.body(14))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(SanaTheme.Spacing.lg)
                .background(iconColor.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
            }

            // CTA button
            if let label = actionLabel, let action {
                Button(label, action: action)
                    .buttonStyle(NourishButtonStyle())
                    .padding(.horizontal, SanaTheme.Spacing.xl)
            }
        }
        .padding(SanaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error state

struct SanaErrorView: View {
    let message: String
    var retryLabel: String = "Try again"
    var retry: (() -> Void)?

    var body: some View {
        VStack(spacing: SanaTheme.Spacing.xl) {
            // Icon blob
            ZStack {
                Circle()
                    .fill(SanaTheme.Color.warning.opacity(0.10))
                    .frame(width: 100, height: 100)
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(SanaTheme.Color.warning)
            }
            .accessibilityHidden(true)

            VStack(spacing: SanaTheme.Spacing.sm) {
                Text("Something went wrong")
                    .font(SanaTheme.Font.headline(20))
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(SanaTheme.Font.body(14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let retry {
                Button(retryLabel, action: retry)
                    .buttonStyle(NourishButtonStyle())
                    .padding(.horizontal, SanaTheme.Spacing.xl)
            }
        }
        .padding(SanaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Generating / skeleton state

struct SanaLoadingView: View {
    var message: String = "Loading…"
    var subtitle: String? = nil

    var body: some View {
        VStack(spacing: SanaTheme.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(SanaTheme.Color.primaryLight)
                    .frame(width: 100, height: 100)
                ProgressView()
                    .tint(SanaTheme.Color.primary)
                    .scaleEffect(1.4)
            }
            VStack(spacing: SanaTheme.Spacing.xs) {
                Text(message)
                    .font(SanaTheme.Font.headline())
                    .foregroundStyle(SanaTheme.Color.primary)
                if let subtitle {
                    Text(subtitle)
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(SanaTheme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
