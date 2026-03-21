import Foundation

struct CLIEvent: Codable {
    let type: String
    let message: CLIMessage?
    let result: String?  // Present on "result" events with the final response text
    let subtype: String? // e.g. "init", "success"
    let sessionId: String? // Present on most events

    enum CodingKeys: String, CodingKey {
        case type, message, result, subtype
        case sessionId = "session_id"
    }

    struct CLIMessage: Codable {
        let role: String?
        let content: [ContentBlock]?
        let usage: TokenUsage?
        let model: String?
    }

    struct ContentBlock: Codable {
        let type: String
        let text: String?
    }

    struct TokenUsage: Codable {
        let inputTokens: Int
        let outputTokens: Int
        let cacheCreationInputTokens: Int?
        let cacheReadInputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
            case cacheCreationInputTokens = "cache_creation_input_tokens"
            case cacheReadInputTokens = "cache_read_input_tokens"
        }

        var totalTokens: Int { inputTokens + outputTokens }
    }

    var textContent: String? {
        message?.content?
            .filter { $0.type == "text" }
            .compactMap { $0.text }
            .joined(separator: "\n")
    }
}
