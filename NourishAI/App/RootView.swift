// NourishAI — RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {

    @Query private var users: [User]
    @Environment(\.modelContext) private var context

    var body: some View {
        if users.isEmpty {
            OnboardingFlowView()
        } else {
            MainTabView(user: users[0])
        }
    }
}
