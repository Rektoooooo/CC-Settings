import Foundation

/// Which file an MCP server is persisted in. Claude Code has three MCP scopes;
/// `ConfigScope` (shared with hooks/commands/skills/…) only models two, so the
/// backing store is tracked here instead of polluting that shared enum.
enum MCPStorage: Hashable {
    /// ~/.claude.json → top-level `mcpServers` (Claude Code "user" scope).
    case userGlobal
    /// <project>/.mcp.json → `mcpServers` (Claude Code "project"/shared scope).
    case projectShared(path: String)
    /// ~/.claude.json → `projects[path].mcpServers` (Claude Code "local" scope).
    /// `path` is the RAW key as stored in ~/.claude.json so saves write it back exactly.
    case projectLocal(path: String)

    /// Short discriminator used in IDs.
    var tag: String {
        switch self {
        case .userGlobal: return "user"
        case .projectShared: return "shared"
        case .projectLocal: return "local"
        }
    }

    /// Badge label shown in the UI.
    var label: String {
        switch self {
        case .userGlobal: return "User"
        case .projectShared: return "Project"
        case .projectLocal: return "Local"
        }
    }

    /// The file an item lives in, for display.
    var pathDescription: String {
        switch self {
        case .userGlobal: return "~/.claude.json"
        case .projectShared(let p): return "\(p)/.mcp.json"
        case .projectLocal: return "~/.claude.json (local)"
        }
    }
}

/// An MCP server config paired with the scope it was loaded from.
struct ScopedMCPServer: Identifiable, Hashable {
    let config: MCPServerConfig
    let scope: ConfigScope
    /// Where the server is persisted. Defaults to `.userGlobal` for back-compat;
    /// `loadAllScopedMCPServers` sets the real value per server.
    var storage: MCPStorage = .userGlobal

    /// Unique ID combining scope, storage, and server name to avoid collisions
    /// across scopes (e.g. a "playwright" server both local and shared on one project).
    var id: String {
        "\(scope.id):\(storage.tag):\(config.id)"
    }

    static func == (lhs: ScopedMCPServer, rhs: ScopedMCPServer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
