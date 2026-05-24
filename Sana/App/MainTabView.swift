// Sana — MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @Environment(\.horizontalSizeClass) private var hSizeClass

    let user: User

    enum Tab: Int, CaseIterable {
        case dashboard, log, coach, plan, insights

        var title: String {
            switch self {
            case .dashboard: return String(localized: "Home")
            case .log:       return String(localized: "Log Meal")
            case .coach:     return String(localized: "Coach")
            case .plan:      return String(localized: "Meal Plan")
            case .insights:  return String(localized: "Insights")
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "house.fill"
            case .log:       return "camera.fill"
            case .coach:     return "bubble.left.and.bubble.right.fill"
            case .plan:      return "calendar"
            case .insights:  return "chart.bar.fill"
            }
        }
    }

    var body: some View {
        if hSizeClass == .regular {
            // iPad / large-screen: NavigationSplitView sidebar
            iPadLayout
        } else {
            // iPhone: standard tab bar
            phoneLayout
        }
    }

    // MARK: - iPhone layout
    private var phoneLayout: some View {
        TabView(selection: $router.selectedTab) {
            DashboardView(user: user)
                .tabItem { Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon) }
                .tag(Tab.dashboard)

            MealLogView(user: user, context: context)
                .tabItem { Label(Tab.log.title, systemImage: Tab.log.icon) }
                .tag(Tab.log)

            CoachView(user: user)
                .tabItem { Label(Tab.coach.title, systemImage: Tab.coach.icon) }
                .tag(Tab.coach)

            MealPlanView(user: user)
                .tabItem { Label(Tab.plan.title, systemImage: Tab.plan.icon) }
                .tag(Tab.plan)

            InsightsView(user: user)
                .tabItem { Label(Tab.insights.title, systemImage: Tab.insights.icon) }
                .tag(Tab.insights)
        }
        .tint(SanaTheme.Color.primary)
    }

    // MARK: - iPad layout
    @ViewBuilder
    private var iPadLayout: some View {
        NavigationSplitView {
            // Sidebar list
            List(Tab.allCases, id: \.self, selection: Binding(
                get: { router.selectedTab },
                set: { if let t = $0 { router.selectedTab = t } }
            )) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Sana")
            .listStyle(.sidebar)
        } detail: {
            switch router.selectedTab {
            case .dashboard: DashboardView(user: user)
            case .log:       MealLogView(user: user, context: context)
            case .coach:     CoachView(user: user)
            case .plan:      MealPlanView(user: user)
            case .insights:  InsightsView(user: user)
            }
        }
        .tint(SanaTheme.Color.primary)
    }
}

// Register the URL scheme in Info.plist:
// CFBundleURLTypes → item 0 → CFBundleURLSchemes → sana
