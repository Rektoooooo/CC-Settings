import Foundation

struct MCPDesktopConfig: Codable {
    var mcpServers: [String: MCPServerConfig]

    init(mcpServers: [String: MCPServerConfig] = [:]) {
        self.mcpServers = mcpServers
    }
}

enum MCPTransportType: String, Codable, CaseIterable {
    case stdio
    case sse

    var displayName: String {
        switch self {
        case .stdio: return "Standard I/O"
        case .sse: return "SSE"
        }
    }

    var icon: String {
        switch self {
        case .stdio: return "terminal"
        case .sse: return "network"
        }
    }
}

struct MCPServerConfig: Codable, Equatable, Identifiable, Hashable {
    /// Server name, used as the Identifiable/Hashable key.
    /// Excluded from CodingKeys because it is assigned at runtime from the dictionary key
    /// when decoding `[String: MCPServerConfig]` (see `loadMCPServers`). This is safe because
    /// dictionary keys are unique by definition, so no hash collisions can occur for servers
    /// loaded from the same config file.
    var id: String
    var type: String?
    var command: String?
    var args: [String]?
    var env: [String: String]?
    var url: String?

    var transportType: MCPTransportType {
        if let t = type {
            return t == "sse" ? .sse : .stdio
        }
        if url != nil && command == nil {
            return .sse
        }
        return .stdio
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    enum CodingKeys: String, CodingKey {
        case type
        case command
        case args
        case env
        case url
    }

    init(id: String, type: String? = nil, command: String? = nil, args: [String]? = nil, env: [String: String]? = nil, url: String? = nil) {
        self.id = id
        self.type = type
        self.command = command
        self.args = args
        self.env = env
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.args = try container.decodeIfPresent([String].self, forKey: .args)
        self.env = try container.decodeIfPresent([String: String].self, forKey: .env)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(url, forKey: .url)
    }
}
