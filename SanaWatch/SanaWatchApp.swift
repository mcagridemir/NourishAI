// Sana — SanaWatchApp.swift
// watchOS companion app — add this file to the SanaWatch target only.
import SwiftUI

@main
struct SanaWatchApp: App {
    var body: some Scene {
        WindowGroup {
            WatchDashboardView()
        }
    }
}
