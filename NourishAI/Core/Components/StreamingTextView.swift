// NourishAI — StreamingTextView.swift
import SwiftUI

struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            Text(text)
                .font(NourishTheme.Font.body())
                .textSelection(.enabled)
            if isStreaming {
                TypingIndicator()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(NourishTheme.Color.primary.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .scaleEffect(phase == i ? 1.3 : 0.8)
                    .animation(.easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15), value: phase)
            }
        }
        .onAppear { phase = 1 }
    }
}

struct LoadingCard: View {
    let message: String
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(NourishTheme.Color.primary)
            Text(message)
                .font(NourishTheme.Font.body())
                .foregroundStyle(.secondary)
        }
        .padding()
        .nourishCard()
    }
}

struct ErrorBanner: View {
    let message: String
    let retry: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(NourishTheme.Font.body(14))
                .foregroundStyle(.primary)
            Spacer()
            if let retry {
                Button("Retry", action: retry)
                    .font(NourishTheme.Font.caption())
                    .foregroundStyle(NourishTheme.Color.primary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
    }
}
