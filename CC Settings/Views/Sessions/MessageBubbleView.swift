import SwiftUI

struct MessageBubbleView: View {
    let message: SessionMessage
    var previousRole: MessageRole? = nil
    @State private var toolExpanded: [String: Bool] = [:]
    @State private var thinkingExpanded: [String: Bool] = [:]

    private var roleIcon: String {
        switch message.role {
        case .user: return "person.fill"
        case .assistant: return "brain.head.profile"
        case .toolResult: return "wrench.and.screwdriver"
        }
    }

    private var roleLabel: String {
        switch message.role {
        case .user: return "User"
        case .assistant: return "Assistant"
        case .toolResult: return "Tool Result"
        }
    }

    private var roleColor: Color {
        switch message.role {
        case .user: return .themeAccent
        case .assistant: return .purple
        case .toolResult: return .green
        }
    }

    /// Whether this message contains only tool calls (no text content)
    private var isToolOnly: Bool {
        guard message.role == .assistant else { return false }
        return message.content.allSatisfy { block in
            switch block {
            case .toolUse: return true
            case .thinking: return true
            default: return false
            }
        }
    }

    /// Whether this is a continuation of the same role (consecutive assistant messages)
    private var isContinuation: Bool {
        previousRole == message.role
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header — skip for tool-only continuations to reduce noise
            if !(isToolOnly && isContinuation) {
                HStack(spacing: 6) {
                    Image(systemName: roleIcon)
                        .foregroundColor(roleColor)
                        .font(.caption)
                    Text(roleLabel)
                        .font(.caption.bold())
                        .foregroundColor(roleColor)

                    if let model = message.model {
                        Text(model)
                            .font(.caption2.monospaced())
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(3)
                    }

                    Spacer()

                    if let ts = message.timestamp {
                        Text(Self.timestampFormatter.string(from: ts))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Content blocks
            ForEach(message.content) { block in
                contentBlockView(block)
            }
        }
        .padding(isToolOnly && isContinuation ? 6 : 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(MessageBackgroundModifier(role: message.role, compact: isToolOnly && isContinuation))
    }

    @ViewBuilder
    private func contentBlockView(_ block: ContentBlock) -> some View {
        switch block {
        case .text(let text):
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyView()
            } else if message.role == .assistant {
                MarkdownPreview(markdown: text)
            } else {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
            }

        case .toolUse(let tool):
            DisclosureGroup(
                isExpanded: Binding(
                    get: { toolExpanded[tool.id] ?? false },
                    set: { toolExpanded[tool.id] = $0 }
                )
            ) {
                if !tool.input.isEmpty {
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(tool.input)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(4)
                    .frame(maxHeight: 200)
                    .padding(.top, 4)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: toolIcon(for: tool.name))
                        .foregroundColor(.orange)
                        .font(.caption)
                    Text(tool.name)
                        .font(.caption.monospaced().bold())
                        .foregroundColor(.orange)
                }
            }

        case .toolResult(let result):
            DisclosureGroup(
                isExpanded: Binding(
                    get: { toolExpanded[result.id] ?? false },
                    set: { toolExpanded[result.id] = $0 }
                )
            ) {
                ScrollView(.horizontal, showsIndicators: true) {
                    Text(result.content)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
                .frame(maxHeight: 300)
                .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .foregroundColor(.green)
                        .font(.caption)
                    Text("Result")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                    Text(formatSize(result.content.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

        case .thinking(let text):
            let blockId = "thinking-\(text.hashValue)"
            DisclosureGroup(
                isExpanded: Binding(
                    get: { thinkingExpanded[blockId] ?? false },
                    set: { thinkingExpanded[blockId] = $0 }
                )
            ) {
                Text(text)
                    .font(.body.italic())
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                    .cornerRadius(4)
                    .padding(.top, 4)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Text("Thinking")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    Text(formatSize(text.count))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Helpers

    private func toolIcon(for name: String) -> String {
        switch name {
        case "Bash": return "terminal"
        case "Read": return "doc.text"
        case "Write": return "square.and.pencil"
        case "Edit": return "pencil.line"
        case "MultiEdit": return "pencil.and.list.clipboard"
        case "Glob": return "magnifyingglass"
        case "Grep": return "text.magnifyingglass"
        case "WebFetch": return "network"
        case "WebSearch": return "globe"
        case "Task": return "person.2"
        case "NotebookEdit": return "book"
        default: return "hammer"
        }
    }

    private func formatSize(_ chars: Int) -> String {
        if chars < 1000 {
            return "\(chars) chars"
        } else if chars < 1_000_000 {
            return String(format: "%.1fK", Double(chars) / 1000)
        } else {
            return String(format: "%.1fM", Double(chars) / 1_000_000)
        }
    }
}

// MARK: - Background Modifier

private struct MessageBackgroundModifier: ViewModifier {
    let role: MessageRole
    let compact: Bool

    func body(content: Content) -> some View {
        switch role {
        case .user:
            content.glassBanner(tint: .themeAccent)
        case .assistant:
            if compact {
                content
                    .background(Color.clear)
            } else {
                content.glassContainer()
            }
        case .toolResult:
            content.glassBanner(tint: .green)
        }
    }
}
