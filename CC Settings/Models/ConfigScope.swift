import Foundation

/// Represents where a configuration item lives — global user-level or within a specific project.
enum ConfigScope: Hashable, Identifiable {
    case global
    case project(id: String, path: String)

    var id: String {
        switch self {
        case .global:
            return "global"
        case .project(let id, _):
            return "project-\(id)"
        }
    }

    var displayName: String {
        switch self {
        case .global:
            return "Global"
        case .project(_, let path):
            return (path as NSString).lastPathComponent
        }
    }

    var icon: String {
        switch self {
        case .global:
            return "globe"
        case .project:
            return "folder"
        }
    }

    var isGlobal: Bool {
        if case .global = self { return true }
        return false
    }

    /// The base path description shown to users.
    var pathDescription: String {
        switch self {
        case .global:
            return "~/.claude/"
        case .project(_, let path):
            return "\(path)/.claude/"
        }
    }

    /// MCP-specific path description.
    var mcpPathDescription: String {
        switch self {
        case .global:
            return "~/.claude.json"
        case .project(_, let path):
            return "\(path)/.mcp.json"
        }
    }
}
