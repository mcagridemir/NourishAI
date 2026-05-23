//
//  ChatMessage.swift
//  NourishAI
//
//  Created by cagri.demir on 23.05.2026.
//

import Foundation
import SwiftData

@Model
final class ChatMessage {
    var id: UUID
    var createdAt: Date
    var role: ChatRole
    var content: String
    var isStreaming: Bool      // true while Claude is still responding
    var attachedMealId: UUID?  // if message relates to a meal analysis

    @Relationship(inverse: \User.chatMessages)
    var user: User?

    var isUser: Bool { role == .user }
    var isAssistant: Bool { role == .assistant }

    init(role: ChatRole, content: String, attachedMealId: UUID? = nil) {
        self.id = UUID()
        self.createdAt = .now
        self.role = role
        self.content = content
        self.isStreaming = false
        self.attachedMealId = attachedMealId
    }

    func toAPIDict() -> [String: Any] {
        ["role": role.rawValue, "content": content]
    }
}

enum ChatRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
}
