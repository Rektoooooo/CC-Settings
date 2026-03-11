import Foundation

/// An MCP server config paired with the scope it was loaded from.
struct ScopedMCPServer: Identifiable, Hashable {
    let config: MCPServerConfig
    let scope: ConfigScope

    /// Unique ID combining scope and server name to avoid collisions across scopes.
    var id: String {
        "\(scope.id):\(config.id)"
    }

    static func == (lhs: ScopedMCPServer, rhs: ScopedMCPServer) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
