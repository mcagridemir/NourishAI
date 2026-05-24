// NourishAI — ThemeManager.swift
// Global accent color theming via @AppStorage. Propagates via .tint() at the root.
import SwiftUI
internal import Combine

final class ThemeManager: ObservableObject {

    static let shared = ThemeManager()

    // Stored as a hex string e.g. "#2D9E75"
    @AppStorage("theme.accentHex") var accentHex: String = "#2D9E75" {
        didSet { objectWillChange.send() }
    }

    var primaryColor: Color {
        Color(hex: accentHex) ?? Color("PrimaryGreen")
    }

    /// Preset palettes
    static let presets: [(name: String, hex: String, preview: Color)] = [
        ("Forest",   "#2D9E75", Color(hex: "#2D9E75") ?? .green),
        ("Ocean",    "#1A7FB5", Color(hex: "#1A7FB5") ?? .blue),
        ("Sunset",   "#E86C3A", Color(hex: "#E86C3A") ?? .orange),
        ("Berry",    "#7C3ABE", Color(hex: "#7C3ABE") ?? .purple),
        ("Rose",     "#C0395F", Color(hex: "#C0395F") ?? .red),
        ("Slate",    "#485B74", Color(hex: "#485B74") ?? .gray),
        ("Gold",     "#C89A1E", Color(hex: "#C89A1E") ?? .yellow),
        ("Teal",     "#1E8A8A", Color(hex: "#1E8A8A") ?? .teal)
    ]

    private init() {}
}

// MARK: - Color hex init

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h = String(h.dropFirst()) }
        guard h.count == 6, let value = UInt64(h, radix: 16) else { return nil }
        self.init(
            red:   Double((value & 0xFF0000) >> 16) / 255,
            green: Double((value & 0x00FF00) >> 8)  / 255,
            blue:  Double( value & 0x0000FF)         / 255
        )
    }
}
