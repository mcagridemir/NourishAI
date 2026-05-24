// Sana — StreamingTextView.swift
import SwiftUI

// MARK: - Markdown renderer (block + inline)

struct MarkdownTextView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
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

    private var blocks: [Block] {
        var result = [Block]()
        var lastWasGap = false
        for line in text.components(separatedBy: "\n") {
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
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(SanaTheme.Color.primary.opacity(0.6))
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
    let retry: (() -> Void)?

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.primary)
            Spacer()
            if let retry {
                Button("Retry", action: retry)
                    .font(SanaTheme.Font.caption())
                    .foregroundStyle(SanaTheme.Color.primary)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
    }
}
