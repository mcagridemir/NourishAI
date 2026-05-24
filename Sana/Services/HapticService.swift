// Sana — HapticService.swift
internal import UIKit

/// Thin wrapper around UIKit feedback generators.
/// All methods are `@MainActor` — haptic APIs must be called on the main thread.
@MainActor
enum HapticService {

    // MARK: - Core

    /// Physical impact — use for taps on cards, buttons that start an action.
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let gen = UIImpactFeedbackGenerator(style: style)
        gen.prepare()
        gen.impactOccurred()
    }

    /// System-level outcome — success / warning / error.
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let gen = UINotificationFeedbackGenerator()
        gen.prepare()
        gen.notificationOccurred(type)
    }

    /// Discrete selection change — picker, tab switch, chip toggle.
    static func selection() {
        let gen = UISelectionFeedbackGenerator()
        gen.prepare()
        gen.selectionChanged()
    }

    // MARK: - Semantic convenience

    /// User navigates to next step / page forward.
    static func stepForward()   { selection() }

    /// User dismisses or cancels something.
    static func dismiss()       { impact(.light) }

    /// User expands or collapses a section.
    static func toggle()        { impact(.light) }

    /// User initiates a significant async operation (generate, analyse…).
    static func startAction()   { impact(.medium) }

    /// Destructive action — clear history, delete, reset.
    static func destructive()   { notification(.warning) }
}
