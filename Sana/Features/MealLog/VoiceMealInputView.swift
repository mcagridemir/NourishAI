// Sana — VoiceMealInputView.swift
// Dictate a meal name by voice; on confirm hands the text to manual-entry.
import SwiftUI

struct VoiceMealInputView: View {

    let onDone: (String) -> Void
    @StateObject private var voice = VoiceInputService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var permissionDenied = false
    @State private var pulseScale = 1.0

    var body: some View {
        NavigationStack {
            VStack(spacing: SanaTheme.Spacing.xl) {
                Spacer()

                // Animated mic button
                ZStack {
                    if voice.isListening {
                        Circle()
                            .fill(SanaTheme.Color.primary.opacity(0.15))
                            .frame(width: 140, height: 140)
                            .scaleEffect(pulseScale)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseScale)
                            .onAppear { pulseScale = 1.25 }
                            .onDisappear { pulseScale = 1.0 }
                    }
                    Button {
                        HapticService.impact(.medium)
                        if voice.isListening { voice.stopListening() } else { startListening() }
                    } label: {
                        ZStack {
                            Circle()
                                .fill(voice.isListening ? SanaTheme.Color.primary : SanaTheme.Color.primaryLight)
                                .frame(width: 100, height: 100)
                            Image(systemName: voice.isListening ? "mic.fill" : "mic")
                                .font(.system(size: 40))
                                .foregroundStyle(voice.isListening ? .white : SanaTheme.Color.primary)
                        }
                    }
                    .accessibilityLabel(Text(voice.isListening ? "Stop recording" : "Start recording"))
                    .shadow(color: SanaTheme.Color.primary.opacity(0.3), radius: voice.isListening ? 12 : 4)
                }
                .animation(SanaTheme.Animation.smooth, value: voice.isListening)

                Text(voice.isListening ? "Listening…" : "Tap to speak")
                    .font(SanaTheme.Font.headline(18))
                    .foregroundStyle(voice.isListening ? SanaTheme.Color.primary : .secondary)

                // Live transcript
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: SanaTheme.Radius.lg)
                        .fill(SanaTheme.Color.surface)
                        .frame(minHeight: 80)
                    if voice.transcript.isEmpty {
                        Text("Say something like:\n\"Grilled salmon with salad\"\n\"Oatmeal with berries\"")
                            .font(SanaTheme.Font.body(14))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding()
                    } else {
                        Text(voice.transcript)
                            .font(SanaTheme.Font.headline(16))
                            .multilineTextAlignment(.center)
                            .padding()
                    }
                }
                .padding(.horizontal, SanaTheme.Spacing.md)

                // Actions
                if !voice.transcript.isEmpty {
                    VStack(spacing: 12) {
                        Button("Use this") {
                            HapticService.notification(.success)
                            voice.stopListening()
                            onDone(voice.transcript)
                            dismiss()
                        }
                        .buttonStyle(NourishButtonStyle())
                        .padding(.horizontal, 40)

                        Button("Try again") {
                            voice.transcript = ""
                            startListening()
                        }
                        .font(SanaTheme.Font.body(14))
                        .foregroundStyle(.secondary)
                    }
                }

                if let error = voice.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(.orange)
                }

                if permissionDenied {
                    VStack(spacing: 8) {
                        Label("Microphone access required", systemImage: "mic.slash.fill")
                            .font(SanaTheme.Font.body(14))
                            .foregroundStyle(.orange)
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(SanaTheme.Font.caption())
                        .foregroundStyle(SanaTheme.Color.primary)
                    }
                }

                Spacer()
            }
            .navigationTitle("Voice log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        voice.stopListening()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onDisappear { voice.stopListening() }
    }

    private func startListening() {
        Task {
            let granted = await voice.requestPermission()
            if granted {
                voice.startListening()
            } else {
                permissionDenied = true
            }
        }
    }
}
