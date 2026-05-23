// NourishAI — MainTabView.swift

import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) private var context
    
    let user: User
    @State private var selectedTab: Tab = .dashboard

    enum Tab: Int, CaseIterable {
        case dashboard, log, coach, plan, insights

        var title: String {
            switch self {
            case .dashboard: return "Home"
            case .log:       return "Log Meal"
            case .coach:     return "Coach"
            case .plan:      return "Meal Plan"
            case .insights:  return "Insights"
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
        TabView(selection: $selectedTab) {
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
        .tint(NourishTheme.Color.primary)
    }
}
