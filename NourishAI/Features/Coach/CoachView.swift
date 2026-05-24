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

                // Pending plan offer banner
                if let _ = vm.pendingPlanResponse {
                    pendingPlanCard
                }

                // Saved plan confirmation toast
                if let banner = vm.savedPlanBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(NourishTheme.Color.primary)
                        Text(banner)
                            .font(NourishTheme.Font.caption(13))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button { vm.savedPlanBanner = nil } label: {
                            Image(systemName: "xmark").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(NourishTheme.Color.primaryLight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

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
            .animation(NourishTheme.Animation.smooth, value: vm.savedPlanBanner != nil)
            .animation(NourishTheme.Animation.smooth, value: vm.pendingPlanResponse != nil)
        }
    }

    // MARK: - Pending plan card

    private var pendingPlanCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(NourishTheme.Color.primary)
                        .font(.system(size: 14, weight: .semibold))
                    Text("Meal plan ready")
                        .font(NourishTheme.Font.headline(13))
                }
                Text("I've built a personalised weekly plan. Save it to Meal Plan?")
                    .font(NourishTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Dismiss") { vm.dismissPendingPlan() }
                    .font(NourishTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
                Button {
                    vm.confirmSavePlan()
                } label: {
                    if vm.isSavingPlan {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Text("Save")
                            .font(NourishTheme.Font.caption(12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(NourishTheme.Color.primary)
                            .clipShape(Capsule())
                    }
                }
                .disabled(vm.isSavingPlan)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(NourishTheme.Color.primaryLight)
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.messages.isEmpty {
                        WelcomeBubble(name: user.name.components(separatedBy: " ").first ?? user.name) { suggestion in
                            vm.inputText = suggestion
                        }
                    }
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
                Group {
                    if isLive {
                        StreamingTextView(text: message.content, isStreaming: true)
                    } else if message.isAssistant {
                        MarkdownTextView(text: message.content)
                    } else {
                        Text(message.content)
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
    let onSelectSuggestion: (String) -> Void
    let suggestions = [
        "Create a meal plan for me this week",
        "What should I eat to hit my protein goal today?",
        "Am I missing any key nutrients this week?",
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
                        .onTapGesture { onSelectSuggestion(s) }
                }
            }
        }
        .padding()
        .nourishCard()
    }
}
