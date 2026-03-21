import Foundation

struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    let model: String?
    let tokensIn: Int?
    let tokensOut: Int?
    var isComplete: Bool

    enum MessageRole: String {
        case user
        case assistant
    }

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        model: String? = nil,
        tokensIn: Int? = nil,
        tokensOut: Int? = nil,
        isComplete: Bool = true
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.model = model
        self.tokensIn = tokensIn
        self.tokensOut = tokensOut
        self.isComplete = isComplete
    }
}
