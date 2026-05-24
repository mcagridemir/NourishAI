// NourishAI — WeeklyReportView.swift
import SwiftUI

struct WeeklyReportView: View {

    let user: User
    @State private var report: WeeklyReport?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss

    private var stats: WeeklyStats { user.weeklyStats }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: NourishTheme.Spacing.lg) {
                    if isLoading {
                        loadingView
                    } else if let report {
                        reportContent(report)
                    } else if let errorMessage {
                        ErrorBanner(message: errorMessage, retry: { Task { await generate() } })
                    } else {
                        previewCard
                    }
                }
                .padding(NourishTheme.Spacing.md)
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Weekly Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await generate() }
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 60)
            ProgressView().scaleEffect(1.4).tint(NourishTheme.Color.primary)
            Text("Analysing your week…")
                .font(NourishTheme.Font.headline())
                .foregroundStyle(NourishTheme.Color.primary)
            Text("Claude is reviewing your nutrition data")
                .font(NourishTheme.Font.body(13))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Stats preview before report loads

    private var previewCard: some View {
        VStack(spacing: 12) {
            statsGrid
        }
    }

    // MARK: - Full report

    @ViewBuilder
    private func reportContent(_ report: WeeklyReport) -> some View {
        // Headline + score
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                Text(report.headline)
                    .font(NourishTheme.Font.headline(18))
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 16)
                HealthScoreBadge(score: report.overallScore, size: 56)
            }
        }
        .padding()
        .nourishCard()

        // Stats grid
        statsGrid

        // Highlights
        reportSection(
            title: "This week's wins",
            icon: "checkmark.seal.fill",
            color: NourishTheme.Color.primary,
            items: report.highlights
        )

        // Improvements
        reportSection(
            title: "Room to improve",
            icon: "arrow.up.circle.fill",
            color: .orange,
            items: report.improvements
        )

        // Nutrient spotlight
        VStack(alignment: .leading, spacing: 10) {
            Label("Nutrient spotlight", systemImage: "bolt.circle.fill")
                .font(NourishTheme.Font.headline())
                .foregroundStyle(.indigo)
            Text(report.nutrientSpotlight)
                .font(NourishTheme.Font.body(14))
        }
        .padding()
        .background(Color.indigo.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))

        // Next week challenge
        VStack(alignment: .leading, spacing: 10) {
            Label("Next week's challenge", systemImage: "flag.fill")
                .font(NourishTheme.Font.headline())
                .foregroundStyle(NourishTheme.Color.accent)
            Text(report.nextWeekChallenge)
                .font(NourishTheme.Font.body(14))
        }
        .padding()
        .background(NourishTheme.Color.accent.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.lg))

        // Regenerate
        Button("Regenerate report") { Task { await generate() } }
            .buttonStyle(NourishButtonStyle(isPrimary: false))
            .padding(.bottom, NourishTheme.Spacing.md)
    }

    private var statsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            weekStatCard(label: "Avg calories", value: "\(stats.avgCalories)", unit: "kcal", color: .orange)
            weekStatCard(label: "Meals logged", value: "\(stats.mealCount)", unit: "meals", color: NourishTheme.Color.primary)
            weekStatCard(label: "Avg protein",  value: "\(stats.avgProtein)g", unit: "/ day", color: .blue)
            weekStatCard(label: "Health score", value: "\(stats.avgHealthScore)", unit: "/ 100", color: .green)
        }
    }

    private func weekStatCard(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(NourishTheme.Font.numeric)
                .foregroundStyle(color)
            Text(unit).font(NourishTheme.Font.caption(11)).foregroundStyle(.secondary)
            Text(label).font(NourishTheme.Font.caption()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(color.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }

    private func reportSection(title: String, icon: String, color: Color, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(NourishTheme.Font.headline())
                .foregroundStyle(color)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(color).frame(width: 6, height: 6).padding(.top, 6)
                    Text(item).font(NourishTheme.Font.body(14))
                }
            }
        }
        .padding()
        .nourishCard()
    }

    // MARK: - Generate

    private func generate() async {
        isLoading = true
        errorMessage = nil
        do {
            report = try await ClaudeService.shared.generateWeeklyReport(
                context: user.nutritionContext,
                stats: stats
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
