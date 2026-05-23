// NourishAI — CoachViewModel.swift
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

    private let user: User
    private var streamTask: Task<Void, Never>?

    init(user: User) {
        self.user = user
        self.messages = user.chatMessages
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
        let userMsg = ChatMessage(role: .user, content: text)
        userMsg.user = user
        messages.append(userMsg)
        user.chatMessages.append(userMsg)
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
                    let assistantMsg = ChatMessage(role: .assistant, content: streamingBuffer)
                    assistantMsg.user = user
                    messages.append(assistantMsg)
                    user.chatMessages.append(assistantMsg)
                }
            } catch {
                self.error = error.localizedDescription
            }
            isStreaming = false
            streamingBuffer = ""
        }
        await streamTask?.value
    }

    func clearHistory() {
        messages.removeAll()
        inputText = ""
        streamTask?.cancel()
        isStreaming = false
    }
}
