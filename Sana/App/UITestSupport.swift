// Sana — UITestSupport.swift
//
// Test-only launch hooks. This whole file is compiled out of release builds
// (`#if DEBUG`), so none of this scaffolding ships in the App Store binary.
#if DEBUG
import Foundation
import SwiftData

enum UITestSupport {

    /// Active only when the XCUITest runner launches the app with "-uitest".
    static var isActive: Bool {
        ProcessInfo.processInfo.arguments.contains("-uitest")
    }

    /// Seed a single User so the app lands on the dashboard (skipping the
    /// Firebase auth + onboarding flow) for deterministic UI smoke tests.
    @MainActor
    static func seedIfNeeded(context: ModelContext, existing: [User]) {
        guard isActive, existing.isEmpty else { return }
        context.insert(User(name: "Test User"))
    }
}
#endif
