import Foundation

/// Errors raised by `MCPConfigStore` when a config file can't be safely modified.
enum MCPConfigError: LocalizedError {
    case unreadable(URL, underlying: Error)
    case invalidJSON(URL)
    case notAnObject(URL)

    var errorDescription: String? {
        switch self {
        case .unreadable(let url, let e):
            return "Could not read \(url.path): \(e.localizedDescription). Nothing was written."
        case .invalidJSON(let url):
            return "\(url.path) is not valid JSON. Fix or restore the file; nothing was written."
        case .notAnObject(let url):
            return "\(url.path) does not contain a JSON object. Nothing was written."
        }
    }
}

/// Read-modify-write access to one `mcpServers` map: the top level of `~/.claude.json`
/// or a project's `.mcp.json` (`projectKey == nil`), or `projects[projectKey].mcpServers`
/// inside `~/.claude.json` (local scope).
///
/// Every mutation re-reads the file, refuses to continue if an existing file can't be
/// parsed, changes only the servers it was asked to, and leaves every other key (and every
/// unmodeled key on each server) untouched. URL-based so tests can point at a temp dir.
struct MCPConfigStore {
    let fileURL: URL
    var projectKey: String?
    /// `.mcp.json` is deleted when nothing is left in it; `~/.claude.json` never is.
    var deleteFileWhenEmpty = false

    static let modeledKeys = ["type", "command", "args", "env", "url", "headers", "alwaysLoad"]

    // MARK: - Reading

    func loadRawServers() throws -> [String: [String: Any]] {
        let root = try readRoot()
        return extractServers(from: root)
    }

    func loadServers() throws -> [String: MCPServerConfig] {
        var result: [String: MCPServerConfig] = [:]
        for (name, raw) in try loadRawServers() {
            result[name] = Self.parseServerConfig(name: name, serverJSON: raw)
        }
        return result
    }

    func rawServer(named name: String) throws -> [String: Any]? {
        try loadRawServers()[name]
    }

    // MARK: - Writing

    /// Applies `body` to the raw servers map and writes the file back (only if it changed).
    func update(_ body: (inout [String: [String: Any]]) throws -> Void) throws {
        var root = try readRoot()
        var servers = extractServers(from: root)
        let before = servers as NSDictionary
        try body(&servers)
        if before.isEqual(servers as NSDictionary) { return }

        if let key = projectKey {
            var projects = root["projects"] as? [String: Any] ?? [:]
            var project = projects[key] as? [String: Any] ?? [:]
            if servers.isEmpty { project.removeValue(forKey: "mcpServers") } else { project["mcpServers"] = servers }
            projects[key] = project
            root["projects"] = projects
        } else if servers.isEmpty && deleteFileWhenEmpty {
            root.removeValue(forKey: "mcpServers")
        } else {
            root["mcpServers"] = servers
        }

        if root.isEmpty && deleteFileWhenEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try JSONTextFixer.restoreIntegers(data).write(to: fileURL, options: .atomic)
    }

    /// Writes (or replaces) raw server dicts by name.
    func upsert(_ raw: [String: [String: Any]]) throws {
        try update { servers in
            for (name, dict) in raw { servers[name] = dict }
        }
    }

    func remove(_ names: [String]) throws {
        try update { servers in
            for name in names { servers.removeValue(forKey: name) }
        }
    }

    /// Writes a full set of servers: servers absent from `servers` are removed, present
    /// ones are merged onto their existing raw dict (see `merge`).
    func save(_ servers: [String: MCPServerConfig]) throws {
        try update { existing in
            for name in Array(existing.keys) where servers[name] == nil { existing.removeValue(forKey: name) }
            for (name, config) in servers {
                existing[name] = Self.merge(existing: existing[name], with: config, name: name)
            }
        }
    }

    // MARK: - Merge

    /// Overlays `config` onto the existing raw dict. Only modeled keys whose value actually
    /// changed (comparing the decoded existing dict against `config`) are touched, so
    /// unmodeled keys (oauth, headersHelper, timeout...) and untouched modeled keys survive.
    static func merge(existing: [String: Any]?, with config: MCPServerConfig, name: String) -> [String: Any] {
        let encoded = encode(config)
        guard var merged = existing else { return encoded }
        let oldEncoded = encode(parseServerConfig(name: name, serverJSON: merged))
        for key in modeledKeys {
            let newValue = encoded[key]
            let oldValue = oldEncoded[key]
            let same: Bool
            switch (newValue, oldValue) {
            case (nil, nil): same = true
            case let (n?, o?): same = (n as AnyObject).isEqual(o)
            default: same = false
            }
            if same { continue }
            if let newValue { merged[key] = newValue } else { merged.removeValue(forKey: key) }
        }
        return merged
    }

    static func encode(_ config: MCPServerConfig) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(config),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return dict
    }

    static func parseServerConfig(name: String, serverJSON: [String: Any]) -> MCPServerConfig {
        if let data = try? JSONSerialization.data(withJSONObject: serverJSON),
           var config = try? JSONDecoder().decode(MCPServerConfig.self, from: data) {
            config.id = name
            return config
        }
        var config = MCPServerConfig(id: name)
        config.type = serverJSON["type"] as? String
        config.command = serverJSON["command"] as? String
        config.url = serverJSON["url"] as? String
        if let args = serverJSON["args"] as? [Any] { config.args = args.map { "\($0)" } }
        if let env = serverJSON["env"] as? [String: Any] { config.env = env.mapValues { "\($0)" } }
        if let headers = serverJSON["headers"] as? [String: Any] { config.headers = headers.mapValues { "\($0)" } }
        return config
    }

    // MARK: - Transfer

    /// Copies a server (full raw dict, optionally overlaid with an edited config) from
    /// `source` to `target` under `newName`, writes the target FIRST, then removes the
    /// original from the source. If the target write throws, the source is untouched.
    static func transfer(name: String, from source: MCPConfigStore, to target: MCPConfigStore,
                         as newName: String? = nil, edited: MCPServerConfig? = nil) throws {
        let finalName = newName ?? name
        var raw: [String: Any]
        if let existing = try source.rawServer(named: name) {
            raw = existing
        } else if let edited {
            raw = encode(edited)
        } else {
            return
        }
        if let edited {
            raw = merge(existing: raw, with: edited, name: finalName)
        }
        try target.upsert([finalName: raw])
        let sameLocation = source.fileURL == target.fileURL && source.projectKey == target.projectKey
        if !(sameLocation && finalName == name) {
            try source.remove([name])
        }
    }

    // MARK: - Private

    private func readRoot() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data: Data
        do { data = try Data(contentsOf: fileURL) } catch { throw MCPConfigError.unreadable(fileURL, underlying: error) }
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let object = JSONTextFixer.parse(data) else { throw MCPConfigError.invalidJSON(fileURL) }
        guard let root = object as? [String: Any] else { throw MCPConfigError.notAnObject(fileURL) }
        return root
    }

    private func extractServers(from root: [String: Any]) -> [String: [String: Any]] {
        let container: [String: Any]
        if let key = projectKey {
            container = (root["projects"] as? [String: Any])?[key] as? [String: Any] ?? [:]
        } else {
            container = root
        }
        return container["mcpServers"] as? [String: [String: Any]] ?? [:]
    }
}

// MARK: - JSON text helpers

enum JSONTextFixer {
    /// Strict parse, falling back to stripping trailing commas outside of strings.
    static func parse(_ data: Data) -> Any? {
        if let object = try? JSONSerialization.jsonObject(with: data) { return object }
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        guard let fixed = stripTrailingCommas(text).data(using: .utf8) else { return nil }
        return try? JSONSerialization.jsonObject(with: fixed)
    }

    /// Restores `10000.0` to `10000` for number tokens only. String literals are skipped,
    /// so a value like "ver: 1.0," is never altered.
    static func restoreIntegers(_ data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8) else { return data }
        let chars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        var i = 0
        var inString = false
        while i < chars.count {
            let c = chars[i]
            if inString {
                out.append(c)
                if c == "\\", i + 1 < chars.count { out.append(chars[i + 1]); i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true; out.append(c); i += 1; continue }
            if c == ".", i + 1 < chars.count, chars[i + 1] == "0",
               let prev = out.last, ("0"..."9").contains(prev) {
                let next: Unicode.Scalar? = i + 2 < chars.count ? chars[i + 2] : nil
                let continues = next.map { ("0"..."9").contains($0) || $0 == "e" || $0 == "E" } ?? false
                if !continues { i += 2; continue }
            }
            out.append(c)
            i += 1
        }
        return String(out).data(using: .utf8) ?? data
    }

    private static func stripTrailingCommas(_ text: String) -> String {
        let chars = Array(text.unicodeScalars)
        var out = String.UnicodeScalarView()
        var inString = false
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inString {
                out.append(c)
                if c == "\\", i + 1 < chars.count { out.append(chars[i + 1]); i += 2; continue }
                if c == "\"" { inString = false }
                i += 1
                continue
            }
            if c == "\"" { inString = true; out.append(c); i += 1; continue }
            if c == "," {
                var j = i + 1
                while j < chars.count, chars[j] == " " || chars[j] == "\n" || chars[j] == "\r" || chars[j] == "\t" { j += 1 }
                if j < chars.count, chars[j] == "}" || chars[j] == "]" { i += 1; continue }
            }
            out.append(c)
            i += 1
        }
        return String(out)
    }
}
