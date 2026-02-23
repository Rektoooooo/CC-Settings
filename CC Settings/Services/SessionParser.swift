import Foundation

struct SessionParser {

    // MARK: - Full Parse

    static func parseSession(at url: URL) -> [SessionMessage] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }

        var messages: [SessionMessage] = []
        let lines = content.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            guard let typeStr = json["type"] as? String else { continue }

            if typeStr == "tool_result" {
                // Top-level tool result
                let toolUseId = json["tool_use_id"] as? String ?? UUID().uuidString
                let resultContent = extractToolResultContent(json["content"])

                messages.append(SessionMessage(
                    id: UUID(),
                    role: .toolResult,
                    content: [.toolResult(ToolResultBlock(id: toolUseId, content: resultContent))],
                    timestamp: parseTimestamp(json["timestamp"]),
                    model: nil
                ))
                continue
            }

            guard let role = MessageRole(rawValue: typeStr) else { continue }
            guard let messageObj = json["message"] as? [String: Any] else { continue }

            let model = messageObj["model"] as? String
            let timestamp = parseTimestamp(json["timestamp"])
            let contentBlocks = parseContent(messageObj["content"])

            messages.append(SessionMessage(
                id: UUID(),
                role: role,
                content: contentBlocks,
                timestamp: timestamp,
                model: model
            ))
        }

        return messages
    }

    // MARK: - Quick Metadata

    static func sessionMetadata(at url: URL) -> SessionMetadata {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return SessionMetadata(messageCount: 0, firstTimestamp: nil, lastTimestamp: nil, modelsUsed: [], toolsUsed: [])
        }

        let lines = content.components(separatedBy: "\n")
        var messageCount = 0
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var modelsUsed: Set<String> = []
        var toolsUsed: Set<String> = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            messageCount += 1

            if let ts = parseTimestamp(json["timestamp"]) {
                if firstTimestamp == nil { firstTimestamp = ts }
                lastTimestamp = ts
            }

            if let msg = json["message"] as? [String: Any] {
                if let model = msg["model"] as? String {
                    modelsUsed.insert(model)
                }
                // Extract tool names from content blocks
                if let contentArray = msg["content"] as? [[String: Any]] {
                    for block in contentArray {
                        if block["type"] as? String == "tool_use",
                           let toolName = block["name"] as? String {
                            toolsUsed.insert(toolName)
                        }
                    }
                }
            }
        }

        return SessionMetadata(
            messageCount: messageCount,
            firstTimestamp: firstTimestamp,
            lastTimestamp: lastTimestamp,
            modelsUsed: modelsUsed,
            toolsUsed: toolsUsed
        )
    }

    // MARK: - Token Usage

    struct TokenUsage {
        var inputTokens: Int = 0
        var outputTokens: Int = 0
        var cacheReadTokens: Int = 0
        var cacheCreationTokens: Int = 0
    }

    // MARK: - Combined Single-Pass Scan

    struct SessionScanResult {
        var metadata: SessionMetadata
        var tokens: TokenUsage
    }

    /// Single-pass scan that extracts both metadata and token usage from a JSONL file.
    static func scanSession(at url: URL) -> SessionScanResult {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return SessionScanResult(
                metadata: SessionMetadata(messageCount: 0, firstTimestamp: nil, lastTimestamp: nil, modelsUsed: [], toolsUsed: []),
                tokens: TokenUsage()
            )
        }

        let lines = content.components(separatedBy: "\n")
        var messageCount = 0
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var modelsUsed: Set<String> = []
        var toolsUsed: Set<String> = []
        var tokens = TokenUsage()

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let lineData = trimmed.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else {
                continue
            }

            messageCount += 1

            if let ts = parseTimestamp(json["timestamp"]) {
                if firstTimestamp == nil { firstTimestamp = ts }
                lastTimestamp = ts
            }

            if let msg = json["message"] as? [String: Any] {
                if let model = msg["model"] as? String {
                    modelsUsed.insert(model)
                }
                if let contentArray = msg["content"] as? [[String: Any]] {
                    for block in contentArray {
                        if block["type"] as? String == "tool_use",
                           let toolName = block["name"] as? String {
                            toolsUsed.insert(toolName)
                        }
                    }
                }
                if let usageDict = msg["usage"] as? [String: Any] {
                    if let input = usageDict["input_tokens"] as? Int {
                        tokens.inputTokens += input
                    }
                    if let output = usageDict["output_tokens"] as? Int {
                        tokens.outputTokens += output
                    }
                    if let cacheRead = usageDict["cache_read_input_tokens"] as? Int {
                        tokens.cacheReadTokens += cacheRead
                    }
                    if let cacheCreation = usageDict["cache_creation_input_tokens"] as? Int {
                        tokens.cacheCreationTokens += cacheCreation
                    }
                }
            }
        }

        return SessionScanResult(
            metadata: SessionMetadata(
                messageCount: messageCount,
                firstTimestamp: firstTimestamp,
                lastTimestamp: lastTimestamp,
                modelsUsed: modelsUsed,
                toolsUsed: toolsUsed
            ),
            tokens: tokens
        )
    }

    // MARK: - Content Parsing

    private static func parseContent(_ content: Any?) -> [ContentBlock] {
        guard let content = content else { return [] }

        // Content can be a plain string
        if let str = content as? String {
            return [.text(str)]
        }

        // Or an array of content blocks
        guard let blocks = content as? [[String: Any]] else { return [] }

        var result: [ContentBlock] = []
        for block in blocks {
            guard let type = block["type"] as? String else { continue }

            switch type {
            case "text":
                if let text = block["text"] as? String {
                    result.append(.text(text))
                }
            case "tool_use":
                let id = block["id"] as? String ?? UUID().uuidString
                let name = block["name"] as? String ?? "Unknown"
                var inputStr = ""
                if let input = block["input"] {
                    if let inputData = try? JSONSerialization.data(withJSONObject: input, options: [.prettyPrinted, .sortedKeys]),
                       let str = String(data: inputData, encoding: .utf8) {
                        inputStr = str
                    }
                }
                result.append(.toolUse(ToolUseBlock(id: id, name: name, input: inputStr)))
            case "tool_result":
                let id = block["tool_use_id"] as? String ?? UUID().uuidString
                let resultContent = extractToolResultContent(block["content"])
                result.append(.toolResult(ToolResultBlock(id: id, content: resultContent)))
            case "thinking":
                if let thinking = block["thinking"] as? String {
                    result.append(.thinking(thinking))
                }
            default:
                break
            }
        }

        return result
    }

    private static func extractToolResultContent(_ content: Any?) -> String {
        guard let content = content else { return "" }

        if let str = content as? String {
            return str
        }

        if let arr = content as? [[String: Any]] {
            return arr.compactMap { block -> String? in
                if let text = block["text"] as? String { return text }
                return nil
            }.joined(separator: "\n")
        }

        if let data = try? JSONSerialization.data(withJSONObject: content, options: .prettyPrinted),
           let str = String(data: data, encoding: .utf8) {
            return str
        }

        return ""
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        guard let value = value else { return nil }

        if let str = value as? String {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: str) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: str)
        }

        if let num = value as? Double {
            return Date(timeIntervalSince1970: num)
        }

        if let num = value as? Int {
            return Date(timeIntervalSince1970: Double(num))
        }

        return nil
    }
}
