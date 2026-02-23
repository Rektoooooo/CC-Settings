import Foundation

// MARK: - Message Role

enum MessageRole: String {
    case user = "human"
    case assistant = "assistant"
    case toolResult = "tool_result"
}

// MARK: - Content Blocks

enum ContentBlock: Identifiable {
    case text(String)
    case toolUse(ToolUseBlock)
    case toolResult(ToolResultBlock)
    case thinking(String)

    var id: String {
        switch self {
        case .text(let str):
            return "text-\(str.hashValue)"
        case .toolUse(let block):
            return block.id
        case .toolResult(let block):
            return block.id
        case .thinking(let str):
            return "thinking-\(str.hashValue)"
        }
    }
}

struct ToolUseBlock: Identifiable {
    let id: String
    let name: String
    let input: String
}

struct ToolResultBlock: Identifiable {
    let id: String
    let content: String
}

// MARK: - Session Message

struct SessionMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: [ContentBlock]
    let timestamp: Date?
    let model: String?
}

// MARK: - Session Metadata

struct SessionMetadata {
    let messageCount: Int
    let firstTimestamp: Date?
    let lastTimestamp: Date?
    let modelsUsed: Set<String>
    let toolsUsed: Set<String>
}
