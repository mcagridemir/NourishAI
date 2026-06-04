// Sana — CoachView.swift
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

                // Error banner
                if let errorMsg = vm.error {
                    ErrorBanner(message: errorMsg, retry: nil) {
                        HapticService.dismiss()
                        vm.error = nil
                    }
                    .padding(.horizontal, SanaTheme.Spacing.lg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Pending plan offer banner
                if let _ = vm.pendingPlanResponse {
                    pendingPlanCard
                }

                // Saved plan confirmation toast
                if let banner = vm.savedPlanBanner {
                    HStack(spacing: 10) {
                        Image(systemName: "calendar.badge.checkmark")
                            .foregroundStyle(SanaTheme.Color.primary)
                            .accessibilityHidden(true)  // decorative
                        Text(banner)
                            .font(SanaTheme.Font.caption(13))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button { HapticService.dismiss(); vm.savedPlanBanner = nil } label: {
                            Image(systemName: "xmark")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                // Expand tap area to 44×44 without changing layout
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Dismiss")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(SanaTheme.Color.primaryLight)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Divider()
                inputBar
            }
            .background(SanaTheme.Color.background)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 10) {
                        // Gradient avatar with online dot
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                ))
                                .frame(width: 32, height: 32)
                                .overlay(Image(systemName: "sparkles").font(.system(size: 14, weight: .semibold)).foregroundStyle(.white))
                            Circle()
                                .fill(Color(hex: "#34D399") ?? .green)
                                .frame(width: 9, height: 9)
                                .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 1.5))
                                .offset(x: 2, y: 2)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sana Coach")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                            Text("Online · knows your context")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(SanaTheme.Color.primary)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        HapticService.destructive()
                        vm.clearHistory()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(SanaTheme.Color.primary)
                    .accessibilityLabel("New conversation")
                }
            }
            .animation(SanaTheme.Animation.smooth, value: vm.savedPlanBanner != nil)
            .animation(SanaTheme.Animation.smooth, value: vm.pendingPlanResponse != nil)
        }
    }

    // MARK: - Pending plan card

    private var pendingPlanCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(SanaTheme.Color.primary)
                        .font(.system(size: 14, weight: .semibold))
                        .accessibilityHidden(true)
                    Text("Meal plan ready")
                        .font(SanaTheme.Font.headline(13))
                }
                Text("I've built a personalised weekly plan. Save it to Meal Plan?")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button("Dismiss") { HapticService.dismiss(); vm.dismissPendingPlan() }
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(.secondary)
                Button {
                    vm.confirmSavePlan()
                } label: {
                    if vm.isSavingPlan {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Text("Save")
                            .font(SanaTheme.Font.caption(12))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(SanaTheme.Color.primary)
                            .clipShape(Capsule())
                    }
                }
                .disabled(vm.isSavingPlan)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(SanaTheme.Color.primaryLight)
    }

    // MARK: - Messages

    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if vm.messages.isEmpty {
                        WelcomeBubble(user: user) { suggestion in
                            vm.inputText = suggestion
                            Task { await vm.sendMessage() }
                        }
                    }
                    ForEach(vm.messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }
                    if vm.isStreaming {
                        if vm.streamingBuffer.isEmpty {
                            ThinkingBubble()
                                .id("thinking")
                                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .leading)))
                        } else {
                            ChatBubble(message: ChatMessage(role: .assistant, content: vm.streamingBuffer), isLive: true)
                                .id("streaming")
                                .transition(.opacity)
                        }
                    }
                }
                .padding(SanaTheme.Spacing.md)
                .padding(.bottom, 8)
                .animation(SanaTheme.Animation.smooth, value: vm.streamingBuffer.isEmpty && vm.isStreaming)
            }
            .onChange(of: vm.messages.count) { _, _ in
                withAnimation {
                    if let id = vm.messages.last?.id {
                        proxy.scrollTo(id, anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.isStreaming) { _, streaming in
                withAnimation(SanaTheme.Animation.smooth) {
                    if streaming {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    }
                }
            }
            .onChange(of: vm.streamingBuffer) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
        }
    }

    // MARK: - Input bar (design spec: attachment button + pill container with mic + send)

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Attachment / plus button
            Button { } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(SanaTheme.Color.elevated)
                    .clipShape(Circle())
            }
            .accessibilityLabel("Attach")

            // Input pill: text field + mic + send
            HStack(spacing: 4) {
                TextField("Ask your coach anything…", text: $vm.inputText, axis: .vertical)
                    .font(.system(size: 15))
                    .lineLimit(1...5)
                    .padding(.leading, 4)

                if !vm.isStreaming {
                    Button { } label: {
                        Image(systemName: "mic")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Voice input")
                }

                // Send / Stop circle button
                Button {
                    Task { await vm.sendMessage() }
                } label: {
                    Image(systemName: vm.isStreaming ? "stop.fill" : "arrow.up")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(
                            (vm.canSend || vm.isStreaming)
                                ? SanaTheme.Color.primary
                                : SanaTheme.Color.hairlineStrong
                        )
                        .clipShape(Circle())
                        .animation(SanaTheme.Animation.snappy, value: vm.canSend)
                }
                .disabled(!vm.canSend && !vm.isStreaming)
                .accessibilityLabel(vm.isStreaming ? "Stop response" : "Send message")
            }
            .padding(.vertical, 4)
            .padding(.leading, 16)
            .padding(.trailing, 4)
            .frame(maxWidth: .infinity)
            .background(SanaTheme.Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(SanaTheme.Color.hairlineStrong, lineWidth: 0.5))
        }
        .padding(.horizontal, SanaTheme.Spacing.md)
        .padding(.top, 8)
        .padding(.bottom, 22)
        .background(SanaTheme.Color.background)
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
                    .fill(LinearGradient(
                        colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 30, height: 30)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                Group {
                    if isLive {
                        StreamingTextView(text: message.content, isStreaming: true)
                    } else if message.isAssistant {
                        MarkdownTextView(text: message.content)
                    } else {
                        Text(message.content)
                            .font(SanaTheme.Font.body())
                            .textSelection(.enabled)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(message.isUser ? SanaTheme.Color.primary : SanaTheme.Color.surface)
                .foregroundStyle(message.isUser ? .white : .primary)
                .clipShape(BubbleShape(isUser: message.isUser))

                Text(message.createdAt.formatted(.dateTime.hour().minute()))
                    .font(SanaTheme.Font.caption(10))
                    .foregroundStyle(.tertiary)
            }

            if message.isAssistant { Spacer(minLength: 60) }
        }
    }
}

/// Design spec: user 22/22/6/22, assistant 6/22/22/22 (top-leading, top-trailing, bottom-trailing, bottom-leading)
struct BubbleShape: Shape {
    let isUser: Bool
    func path(in rect: CGRect) -> Path {
        if isUser {
            UnevenRoundedRectangle(
                topLeadingRadius: 22, bottomLeadingRadius: 22,
                bottomTrailingRadius: 6, topTrailingRadius: 22
            ).path(in: rect)
        } else {
            UnevenRoundedRectangle(
                topLeadingRadius: 6, bottomLeadingRadius: 22,
                bottomTrailingRadius: 22, topTrailingRadius: 22
            ).path(in: rect)
        }
    }
}

// MARK: - Thinking indicator

struct ThinkingBubble: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Circle()
                .fill(LinearGradient(
                    colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 30, height: 30)
                .overlay(
                    Image(systemName: "sparkles")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .accessibilityHidden(true)

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 7, height: 7)
                        .offset(y: animating ? -5 : 3)
                        .animation(
                            .easeInOut(duration: 0.45)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(SanaTheme.Color.surface)
            .clipShape(BubbleShape(isUser: false))

            Spacer(minLength: 60)
        }
        .accessibilityLabel("Sana is thinking")
        .onAppear { animating = true }
    }
}

// MARK: - Welcome bubble

private struct WelcomeBubble: View {
    let user: User
    let onSelectSuggestion: (String) -> Void

    private var firstName: String {
        user.name.components(separatedBy: " ").first ?? user.name
    }

    private var suggestions: [String] {
        let hour = Calendar.current.component(.hour, from: Date())
        var pool: [String] = []

        // Time-of-day meal suggestion
        if hour < 10 {
            pool.append(NSLocalizedString("What's a great breakfast for my goals today?", comment: ""))
        } else if hour < 14 {
            pool.append(NSLocalizedString("Suggest a healthy lunch for me right now", comment: ""))
        } else if hour < 19 {
            pool.append(NSLocalizedString("What should I have for dinner tonight?", comment: ""))
        } else {
            pool.append(NSLocalizedString("What's a light snack before bed?", comment: ""))
        }

        // Goal-based prompt
        switch user.primaryGoal {
        case .loseWeight:
            pool.append(NSLocalizedString("How do I stay in a deficit without feeling hungry?", comment: ""))
        case .buildMuscle:
            pool.append(NSLocalizedString("What should I eat to maximise muscle growth today?", comment: ""))
        case .improveEnergy:
            pool.append(NSLocalizedString("Which foods give me sustained energy throughout the day?", comment: ""))
        case .manageCondition:
            pool.append(NSLocalizedString("Give me nutrition advice for my health conditions", comment: ""))
        default:
            pool.append(NSLocalizedString("What should I eat to hit my protein goal today?", comment: ""))
        }

        // Hydration nudge
        if user.todayWaterMl < user.dailyWaterGoalMl / 2 {
            pool.append(NSLocalizedString("Tips to drink more water throughout the day", comment: ""))
        } else {
            pool.append(NSLocalizedString("Am I missing any key nutrients this week?", comment: ""))
        }

        // Streak or first-meal prompt
        if user.currentStreak >= 7 {
            pool.append(String(format: NSLocalizedString("I'm on a %d-day streak! What's next for me?", comment: ""), user.currentStreak))
        } else if user.todayMealCount == 0 {
            pool.append(NSLocalizedString("What should I log for my first meal today?", comment: ""))
        } else {
            pool.append(NSLocalizedString("Create a meal plan for me this week", comment: ""))
        }

        return Array(pool.prefix(4))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Gradient avatar
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(LinearGradient(
                        colors: [SanaTheme.Color.primary, SanaTheme.Color.primaryDeep],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 64, height: 64)
                    .overlay(Image(systemName: "sparkles").font(.system(size: 28, weight: .semibold)).foregroundStyle(.white))
                Circle()
                    .fill(Color(hex: "#34D399") ?? .green)
                    .frame(width: 16, height: 16)
                    .overlay(Circle().stroke(Color(UIColor.systemBackground), lineWidth: 2))
                    .offset(x: 3, y: 3)
            }
            Text("Hi \(firstName)! I'm your Sana coach.")
                .font(SanaTheme.Font.headline())
                .multilineTextAlignment(.center)
            Text("Ask me anything about your nutrition, get meal suggestions, or learn how to hit your health goals.")
                .font(SanaTheme.Font.body(14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Context awareness banner
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(SanaTheme.Color.primary)
                Text("Coach knows your **last 7 days** of meals, your goals, and your activity.")
                    .font(SanaTheme.Font.caption(12))
                    .foregroundStyle(SanaTheme.Color.primaryDeep)
            }
            .padding(12)
            .background(SanaTheme.Color.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))

            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { s in
                    HStack {
                        Text(s)
                            .font(SanaTheme.Font.body(13))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    .padding(12)
                    .background(SanaTheme.Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: SanaTheme.Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: SanaTheme.Radius.md).stroke(Color.primary.opacity(0.06), lineWidth: 0.5))
                    .onTapGesture { HapticService.selection(); onSelectSuggestion(s) }
                }
            }
        }
        .padding()
        .nourishCard()
    }
}
