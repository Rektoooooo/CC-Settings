import Foundation

enum MCPTransportType: String, Codable, CaseIterable {
    case stdio
    case sse
    case http

    var displayName: String {
        switch self {
        case .stdio: return "Standard I/O"
        case .sse: return "SSE"
        case .http: return "HTTP"
        }
    }

    var icon: String {
        switch self {
        case .stdio: return "terminal"
        case .sse: return "network"
        case .http: return "globe"
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
    var headers: [String: String]?

    var transportType: MCPTransportType {
        if let t = type {
            switch t {
            case "sse": return .sse
            case "http": return .http
            default: return .stdio
            }
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
        case headers
    }

    init(id: String, type: String? = nil, command: String? = nil, args: [String]? = nil, env: [String: String]? = nil, url: String? = nil, headers: [String: String]? = nil) {
        self.id = id
        self.type = type
        self.command = command
        self.args = args
        self.env = env
        self.url = url
        self.headers = headers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = ""
        self.type = try container.decodeIfPresent(String.self, forKey: .type)
        self.command = try container.decodeIfPresent(String.self, forKey: .command)
        self.url = try container.decodeIfPresent(String.self, forKey: .url)

        // args: coerce non-string values to strings
        if let stringArgs = try? container.decodeIfPresent([String].self, forKey: .args) {
            self.args = stringArgs
        } else if let rawArgs = try? container.decodeIfPresent([AnyCodable].self, forKey: .args) {
            self.args = rawArgs.map(\.stringValue)
        } else {
            self.args = nil
        }

        // env: coerce non-string values to strings
        if let stringEnv = try? container.decodeIfPresent([String: String].self, forKey: .env) {
            self.env = stringEnv
        } else if let rawEnv = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .env) {
            self.env = rawEnv.mapValues(\.stringValue)
        } else {
            self.env = nil
        }

        // headers: coerce non-string values to strings
        if let stringHeaders = try? container.decodeIfPresent([String: String].self, forKey: .headers) {
            self.headers = stringHeaders
        } else if let rawHeaders = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .headers) {
            self.headers = rawHeaders.mapValues(\.stringValue)
        } else {
            self.headers = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(type, forKey: .type)
        try container.encodeIfPresent(command, forKey: .command)
        try container.encodeIfPresent(args, forKey: .args)
        try container.encodeIfPresent(env, forKey: .env)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(headers, forKey: .headers)
    }
}

// MARK: - AnyCodable Helper

/// Decodes any JSON primitive and provides a string representation.
private struct AnyCodable: Decodable {
    let stringValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            stringValue = str
        } else if let int = try? container.decode(Int.self) {
            stringValue = String(int)
        } else if let double = try? container.decode(Double.self) {
            stringValue = String(double)
        } else if let bool = try? container.decode(Bool.self) {
            stringValue = String(bool)
        } else {
            stringValue = ""
        }
    }
}
