import Foundation

enum ChatMessageType: Codable, Equatable {
    case text
    case graph // For executable code/graphs
}

struct ChatMessage: Identifiable, Codable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: String
    let type: ChatMessageType
    let timestamp: Date
    
    init(id: UUID = UUID(), role: MessageRole, content: String, type: ChatMessageType = .text, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.type = type
        self.timestamp = timestamp
    }
}

enum MessageRole: String, Codable, Equatable {
    case user
    case assistant
}
