// NourishAI — NourishAIApp.swift
import SwiftUI
import SwiftData

@main
struct NourishAIApp: App {

    @StateObject private var subscription = SubscriptionService.shared
    @StateObject private var healthKit = HealthKitService.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(AppContainer.shared.modelContainer)
                .environmentObject(subscription)
                .environmentObject(healthKit)
        }
    }
}
