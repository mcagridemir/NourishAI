// Sana — CoachViewModel.swift
import Foundation
import SwiftUI
internal import Combine

@MainActor
final class CoachViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var inputText = ""
    @Published var isStreaming = false
    @Published var streamingBuffer = ""
    @Published var error: String?
    @Published var showPaywall = false
    @Published var showingVoiceInput = false

    /// Non-nil when a meal plan was auto-saved from a coach conversation.
    @Published var savedPlanBanner: String?
    /// Non-nil when coach generated a plan the user hasn't confirmed saving yet.
    @Published var pendingPlanResponse: MealPlanResponse?
    @Published var isSavingPlan = false

    private let user: User
    private var streamTask: Task<Void, Never>?

    // Keywords that signal the user wants a meal plan from the coach.
    private let planKeywords = [
        "meal plan", "weekly plan", "plan my week", "plan my meals",
        "plan for the week", "make me a plan", "create a plan",
        "yemek planı", "haftalık plan", "plan yap"
    ]

    init(user: User) {
        self.user = user
        self.messages = (user.chatMessages ?? [])
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(40)
            .map { $0 }
    }

    var canSend: Bool { !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming }

    func sendMessage() async {
        guard canSend else {
            if isStreaming { streamTask?.cancel() }
            return
        }
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        inputText = ""
        HapticService.selection()
        let userMsg = ChatMessage(role: .user, content: text)
        userMsg.user = user
        messages.append(userMsg)
        isStreaming = true
        streamingBuffer = ""
        error = nil
        streamTask = Task {
            do {
                let stream = await ClaudeService.shared.streamChat(messages: messages, context: user.nutritionContext)
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    streamingBuffer += chunk
                }
                if !streamingBuffer.isEmpty {
                    HapticService.impact(.light)
                    let assistantMsg = ChatMessage(role: .assistant, content: streamingBuffer)
                    assistantMsg.user = user
                    messages.append(assistantMsg)

                    // Detect meal plan intent → generate structured plan in background
                    let lower = text.lowercased()
                    if planKeywords.contains(where: { lower.contains($0) }) {
                        Task { await generateAndOfferPlan() }
                    }
                }
            } catch {
                if !(error is CancellationError) {
                    if case ClaudeError.quotaExceeded = error {
                        self.showPaywall = true
                    } else {
                        self.error = error.localizedDescription
                    }
                }
            }
            isStreaming = false
            streamingBuffer = ""
        }
        await streamTask?.value
    }

    /// Generate a structured plan and store it as a pending offer.
    private func generateAndOfferPlan() async {
        guard pendingPlanResponse == nil else { return }
        do {
            let response = try await ClaudeService.shared.generateMealPlan(context: user.nutritionContext)
            pendingPlanResponse = response
        } catch {
            // Silent — the chat text response is what matters; plan generation is bonus
            #if DEBUG
            print("⚠️ Background plan generation failed: \(error)")
            #endif
        }
    }

    /// Save the pending plan to the user's SwiftData model.
    func confirmSavePlan() {
        guard let response = pendingPlanResponse else { return }
        isSavingPlan = true
        let monday = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: .now)
        ) ?? .now
        (user.mealPlans ?? []).forEach { $0.isActive = false }
        let plan = MealPlan(weekStartDate: monday, title: "Coach Plan")
        plan.user = user
        for dayResp in response.days {
            let date = Calendar.current.date(byAdding: .day, value: dayResp.dayIndex, to: monday) ?? monday
            let day  = MealPlanDay(date: date, dayIndex: dayResp.dayIndex)
            day.meals = [
                PlannedMeal(from: dayResp.breakfast, mealType: .breakfast),
                PlannedMeal(from: dayResp.lunch,     mealType: .lunch),
                PlannedMeal(from: dayResp.dinner,    mealType: .dinner)
            ] + dayResp.snacks.map { PlannedMeal(from: $0, mealType: .snack) }
            day.plan = plan
        }
        pendingPlanResponse = nil
        isSavingPlan = false
        HapticService.notification(.success)
        savedPlanBanner = String(localized: "Meal plan saved! Switch to the Meal Plan tab to view it. 🗓")
    }

    func dismissPendingPlan() { pendingPlanResponse = nil }

    func clearHistory() {
        streamTask?.cancel()
        isStreaming = false
        streamingBuffer = ""
        messages.removeAll()
        user.chatMessages = []   // also erase from SwiftData so next launch starts fresh
        inputText = ""
        pendingPlanResponse = nil
        savedPlanBanner = nil
        error = nil
    }
}
