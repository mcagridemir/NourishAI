// Sana — StreamingTextView.swift
import SwiftUI

// MARK: - Markdown renderer (block + inline)

struct MarkdownTextView: View {
    let text: String
    @State private var cachedBlocks: [Block] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(cachedBlocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
        .onAppear { cachedBlocks = parseBlocks(text) }
        .onChange(of: text) { _, new in cachedBlocks = parseBlocks(new) }
    }

    @ViewBuilder
    private func blockView(_ block: Block) -> some View {
        switch block.kind {
        case .h1:
            Text(inline(block.content))
                .font(SanaTheme.Font.title(20))
                .padding(.top, 2)
        case .h2:
            Text(inline(block.content))
                .font(SanaTheme.Font.headline(17))
                .padding(.top, 2)
        case .h3:
            Text(inline(block.content))
                .font(SanaTheme.Font.headline(15))
        case .bullet:
            HStack(alignment: .top, spacing: 6) {
                Text("•").font(SanaTheme.Font.body())
                Text(inline(block.content)).font(SanaTheme.Font.body())
            }
        case .paragraph:
            Text(inline(block.content)).font(SanaTheme.Font.body())
        case .gap:
            Color.clear.frame(height: 2)
        }
    }

    private func inline(_ raw: String) -> AttributedString {
        (try? AttributedString(markdown: raw)) ?? AttributedString(raw)
    }

    // MARK: - Block parsing

    private struct Block {
        enum Kind { case h1, h2, h3, bullet, paragraph, gap }
        let kind: Kind
        let content: String
        init(_ kind: Kind, _ content: String = "") { self.kind = kind; self.content = content }
    }

    private func parseBlocks(_ raw: String) -> [Block] {
        var result = [Block]()
        var lastWasGap = false
        for line in raw.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            if t.isEmpty {
                if !lastWasGap { result.append(Block(.gap)) }
                lastWasGap = true
            } else if t.hasPrefix("### ") {
                result.append(Block(.h3, String(t.dropFirst(4)))); lastWasGap = false
            } else if t.hasPrefix("## ") {
                result.append(Block(.h2, String(t.dropFirst(3)))); lastWasGap = false
            } else if t.hasPrefix("# ") {
                result.append(Block(.h1, String(t.dropFirst(2)))); lastWasGap = false
            } else if t.hasPrefix("- ") || t.hasPrefix("* ") {
                result.append(Block(.bullet, String(t.dropFirst(2)))); lastWasGap = false
            } else {
                result.append(Block(.paragraph, t)); lastWasGap = false
            }
        }
        return result
    }
}

// MARK: - Streaming wrapper

struct StreamingTextView: View {
    let text: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MarkdownTextView(text: text)
            if isStreaming {
                TypingIndicator()
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(SanaTheme.Color.primary.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .scaleEffect(animating ? 1.3 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(i) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}

struct LoadingCard: View {
    let message: String
    var body: some View {
        HStack(spacing: 12) {
            ProgressView().tint(SanaTheme.Color.primary)
            Text(message)
                .font(SanaTheme.Font.body())
                .foregroundStyle(.secondary)
        }
        .padding()
        .nourishCard()
    }
}

struct ErrorBanner: View {
    let message: String
    var retry: (() -> Void)? = nil
    var dismiss: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(message)
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            if let retry {
                Button("Retry", action: retry)
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
            if let dismiss {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Dismiss error")
            }
        }
        .padding(.horizontal, SanaTheme.Spacing.lg)
        .padding(.vertical, SanaTheme.Spacing.sm)
        .background(Color.orange.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
        .accessibilityElement(children: .combine)
    }
}
