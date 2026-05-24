// Sana — ThemePickerView.swift
// Let users choose an accent color for the app.
import SwiftUI

struct ThemePickerView: View {

    @ObservedObject private var theme = ThemeManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SanaTheme.Spacing.lg) {

                    // Preview card
                    VStack(spacing: 16) {
                        Text("Preview")
                            .font(SanaTheme.Font.headline())
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            HStack {
                                Label("Sana", systemImage: "leaf.fill")
                                    .font(SanaTheme.Font.headline())
                                    .foregroundStyle(theme.primaryColor)
                                Spacer()
                                Image(systemName: "flame.fill").foregroundStyle(theme.primaryColor)
                            }
                            ProgressView(value: 0.65)
                                .tint(theme.primaryColor)
                            HStack(spacing: 10) {
                                Button("Log meal") {}
                                    .buttonStyle(NourishButtonStyle())
                                    .tint(theme.primaryColor)
                                Toggle("Active", isOn: .constant(true))
                                    .tint(theme.primaryColor)
                                    .labelsHidden()
                            }
                        }
                        .padding()
                        .background(SanaTheme.Color.surface)
                        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.lg))
                    }
                    .padding()
                    .nourishCard()

                    // Preset swatches
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Colour presets")
                            .font(SanaTheme.Font.headline())

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                            GridItem(.flexible()), GridItem(.flexible())],
                                  spacing: 16) {
                            ForEach(ThemeManager.presets, id: \.hex) { preset in
                                Button {
                                    HapticService.selection()
                                    withAnimation(SanaTheme.Animation.snappy) {
                                        theme.accentHex = preset.hex
                                    }
                                } label: {
                                    VStack(spacing: 6) {
                                        ZStack {
                                            Circle()
                                                .fill(preset.preview)
                                                .frame(width: 52, height: 52)
                                                .shadow(color: preset.preview.opacity(0.4), radius: 4, y: 2)
                                            if theme.accentHex == preset.hex {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 18, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        Text(preset.name)
                                            .font(SanaTheme.Font.caption(11))
                                            .foregroundStyle(theme.accentHex == preset.hex ? .primary : .secondary)
                                            .fontWeight(theme.accentHex == preset.hex ? .semibold : .regular)
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("\(preset.name) theme\(theme.accentHex == preset.hex ? ", selected" : "")")
                            }
                        }
                    }
                    .padding()
                    .nourishCard()

                    Text("The accent colour applies to buttons, toggles, progress bars, and highlights throughout the app.")
                        .font(SanaTheme.Font.caption(12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(SanaTheme.Spacing.md)
            }
            .background(SanaTheme.Color.background)
            .navigationTitle("App theme")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(theme.primaryColor)
                }
            }
        }
    }
}
