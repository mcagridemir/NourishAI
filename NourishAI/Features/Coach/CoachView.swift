// NourishAI — CoachView.swift
import SwiftUI
import SwiftData

struct CoachView: View {

    @Bindable var user: User
    @StateObject private var vm: CoachViewModel
    @Environment(\.modelContext) private var context

    init(user: User) {
        self.user = user
        _vm = StateObject(wrappedValue: CoachViewModel(user: user))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                messagesScrollView
                Divider()
                inputBar
            }
            .background(NourishTheme.Color.background)
            .navigationTitle("Nutrition coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { vm.clearHistory() } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(NourishTheme.Color.primary)
                }
            }
        }
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.messages.isEmpty { WelcomeBubble(name: user.name.components(separatedBy: " ").first ?? user.name) }
                    ForEach(vm.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if vm.isStreaming {
                        ChatBubble(message: ChatMessage(role: .assistant, content: vm.streamingBuffer), isLive: true)
                            .id("streaming")
                    }
                }
                .padding(NourishTheme.Spacing.md)
                .padding(.bottom, 8)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation { proxy.scrollTo(vm.messages.last?.id.uuidString ?? "streaming", anchor: .bottom) }
            }
            .onChange(of: vm.streamingBuffer) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask your coach…", text: $vm.inputText, axis: .vertical)
                .font(NourishTheme.Font.body())
                .lineLimit(1...5)
                .padding(12)
                .background(NourishTheme.Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.xl))

            Button {
                Task { await vm.sendMessage() }
            } label: {
                Image(systemName: vm.isStreaming ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(vm.canSend ? NourishTheme.Color.primary : Color.secondary)
            }
            .disabled(!vm.canSend && !vm.isStreaming)
            .animation(NourishTheme.Animation.snappy, value: vm.isStreaming)
        }
        .padding(.horizontal, NourishTheme.Spacing.md)
        .padding(.vertical, 10)
        .background(NourishTheme.Color.background)
    }
}

// MARK: - Chat bubble

struct ChatBubble: View {
    let message: ChatMessage
    var isLive: Bool = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 60) }
            if message.isAssistant {
                Circle()
                    .fill(NourishTheme.Color.primaryLight)
                    .frame(width: 30, height: 30)
                    .overlay(Text("N").font(NourishTheme.Font.caption(12)).foregroundStyle(NourishTheme.Color.primary))
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if isLive {
                        StreamingTextView(text: message.content, isStreaming: true)
                    } else {
                        Text(try! AttributedString(markdown: message.content))
                            .font(NourishTheme.Font.body())
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? NourishTheme.Color.primary : NourishTheme.Color.surface)
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(BubbleShape(isUser: message.isUser))

                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(NourishTheme.Font.caption(10))
                    .foregroundStyle(.tertiary)
            }

            if message.isAssistant { Spacer(minLength: 60) }
        }
    }
}

struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 18
        let tail: CGFloat = 6
        var path = Path()
        if isUser {
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height),
                                cornerSize: CGSize(width: r, height: r))
        } else {
            path.addRoundedRect(in: CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height),
                                cornerSize: CGSize(width: r, height: r))
        }
        return path
    }
}

// MARK: - Welcome bubble

private struct WelcomeBubble: View {
    let name: String
    let suggestions = [
        "What should I eat to hit my protein goal today?",
        "Am I missing any key nutrients this week?",
        "Can you suggest a quick healthy dinner?",
        "How can I reduce my sugar intake?"
    ]

    var body: some View {
        VStack(spacing: 16) {
            Circle()
                .fill(NourishTheme.Color.primaryLight)
                .frame(width: 60, height: 60)
                .overlay(Text("N").font(NourishTheme.Font.title(28)).foregroundStyle(NourishTheme.Color.primary))
            Text("Hi \(name)! I'm your NourishAI coach.")
                .font(NourishTheme.Font.headline())
                .multilineTextAlignment(.center)
            Text("Ask me anything about your nutrition, get meal suggestions, or learn how to hit your health goals.")
                .font(NourishTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    Text(s)
                        .font(NourishTheme.Font.body(13))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(NourishTheme.Color.primaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: NourishTheme.Radius.md))
                        .onTapGesture { /* sets input */ }
                }
            }
        }
        .padding()
        .nourishCard()
    }
}
