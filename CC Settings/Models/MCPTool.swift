import Foundation

/// A single tool/action exposed by an MCP server (e.g. "browser_navigate").
struct MCPTool: Identifiable, Hashable {
    var name: String
    var description: String?

    var id: String { name }
}
