import Foundation

/// Discovers the tools/actions an MCP server exposes by speaking the MCP
/// `tools/list` JSON-RPC handshake. stdio servers are launched through a login
/// shell (to inherit the user's PATH); http/sse servers are queried over HTTP.
///
/// Heavy work runs off the main actor; published state updates land on the main
/// actor, mirroring StatsService's pattern.
@MainActor
final class MCPDiscoveryService: ObservableObject {
    static let shared = MCPDiscoveryService()

    enum DiscoveryState: Equatable {
        case idle
        case loading
        case loaded([MCPTool], live: Bool)
        case failed(String)
    }

    /// Keyed by server id (server name).
    @Published private(set) var state: [String: DiscoveryState] = [:]

    private init() {}

    func currentState(for serverID: String) -> DiscoveryState {
        state[serverID] ?? .idle
    }

    /// Run discovery for a server, updating `state`. If discovery fails, falls
    /// back to the tools the user has previously used (from stats-cache.json).
    func discover(_ server: MCPServerConfig) async {
        let serverID = server.id
        state[serverID] = .loading

        let result: Result<[MCPTool], DiscoveryError> = await Task.detached(priority: .userInitiated) {
            await Self.fetchTools(for: server)
        }.value

        switch result {
        case .success(let tools):
            state[serverID] = .loaded(Self.sorted(tools), live: true)
        case .failure(let error):
            let fallback = usageDerivedTools(for: serverID)
            if fallback.isEmpty {
                state[serverID] = .failed(error.message)
            } else {
                state[serverID] = .loaded(Self.sorted(fallback), live: false)
            }
        }
    }

    /// Tools previously used with this server, parsed from `~/.claude/stats-cache.json`.
    /// Used as a fallback when live discovery is unavailable.
    func usageDerivedTools(for serverID: String) -> [MCPTool] {
        let prefix = "mcp__\(serverID)__"
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/stats-cache.json")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let toolsUsed = json["toolsUsed"] as? [[String: Any]] else {
            return []
        }
        var names: Set<String> = []
        for entry in toolsUsed {
            guard let name = entry["name"] as? String, name.hasPrefix(prefix) else { continue }
            names.insert(String(name.dropFirst(prefix.count)))
        }
        return names.map { MCPTool(name: $0, description: nil) }
    }

    // MARK: - Sorting

    private static func sorted(_ tools: [MCPTool]) -> [MCPTool] {
        tools.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Transport dispatch (off-main)

    private static func fetchTools(for server: MCPServerConfig) async -> Result<[MCPTool], DiscoveryError> {
        switch server.transportType {
        case .stdio:
            return fetchToolsStdio(server)
        case .http, .sse:
            return await fetchToolsHTTP(server)
        }
    }

    // MARK: - JSON-RPC payloads

    private static func initializeRequest(id: Int) -> [String: Any] {
        [
            "jsonrpc": "2.0",
            "id": id,
            "method": "initialize",
            "params": [
                "protocolVersion": "2025-06-18",
                "capabilities": [:],
                "clientInfo": ["name": "CC Settings", "version": "1.0"]
            ]
        ]
    }

    private static let initializedNotification: [String: Any] = [
        "jsonrpc": "2.0",
        "method": "notifications/initialized"
    ]

    private static func toolsListRequest(id: Int) -> [String: Any] {
        ["jsonrpc": "2.0", "id": id, "method": "tools/list", "params": [:]]
    }

    private static func encodeLine(_ object: [String: Any]) -> Data? {
        guard var data = try? JSONSerialization.data(withJSONObject: object) else { return nil }
        data.append(0x0A) // newline
        return data
    }

    /// Map a decoded `tools/list` result object to `[MCPTool]`.
    private static func parseToolsResult(_ json: [String: Any]) -> [MCPTool]? {
        guard let result = json["result"] as? [String: Any],
              let tools = result["tools"] as? [[String: Any]] else { return nil }
        return tools.compactMap { tool in
            guard let name = tool["name"] as? String else { return nil }
            return MCPTool(name: name, description: tool["description"] as? String)
        }
    }

    // MARK: - stdio transport

    private static func fetchToolsStdio(_ server: MCPServerConfig) -> Result<[MCPTool], DiscoveryError> {
        guard let command = server.command, !command.isEmpty else {
            return .failure(.init(message: "No command configured"))
        }

        // Build a shell command line so PATH is resolved by a login shell.
        let parts = ([command] + (server.args ?? [])).map(shellQuote)
        let shellCommand = parts.joined(separator: " ")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-lc", shellCommand]

        var environment = ProcessInfo.processInfo.environment
        for (key, value) in server.env ?? [:] { environment[key] = value }
        process.environment = environment

        let stdin = Pipe()
        let stdout = Pipe()
        let stderr = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            return .failure(.init(message: "Failed to launch: \(error.localizedDescription)"))
        }

        // Send handshake + tools/list, then close stdin so the server can exit.
        let toolsListID = 2
        for message in [initializeRequest(id: 1), initializedNotification, toolsListRequest(id: toolsListID)] {
            if let line = encodeLine(message) {
                stdin.fileHandleForWriting.write(line)
            }
        }
        try? stdin.fileHandleForWriting.close()

        // Read all stdout with a hard timeout to avoid hanging on a stuck server.
        let outputData = readToEnd(stdout.fileHandleForReading, process: process, timeout: 15)
        try? stderr.fileHandleForReading.close()
        if process.isRunning { process.terminate() }

        guard let output = String(data: outputData, encoding: .utf8) else {
            return .failure(.init(message: "No readable output"))
        }

        // stdio transport is newline-delimited JSON-RPC; find the tools/list reply.
        for line in output.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any] else { continue }
            if (json["id"] as? Int) == toolsListID, let tools = parseToolsResult(json) {
                return .success(tools)
            }
        }
        return .failure(.init(message: "Server did not return a tool list"))
    }

    /// Reads a file handle to EOF, abandoning the read after `timeout` seconds.
    private static func readToEnd(_ handle: FileHandle, process: Process, timeout: TimeInterval) -> Data {
        final class Box: @unchecked Sendable {
            let lock = NSLock()
            var data = Data()
            var done = false
        }
        let box = Box()
        let semaphore = DispatchSemaphore(value: 0)

        DispatchQueue.global(qos: .userInitiated).async {
            let data = handle.readDataToEndOfFile()
            box.lock.lock()
            box.data = data
            box.done = true
            box.lock.unlock()
            semaphore.signal()
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            if process.isRunning { process.terminate() }
            // Give the reader a brief moment to unblock after termination.
            _ = semaphore.wait(timeout: .now() + 1)
        }

        box.lock.lock()
        defer { box.lock.unlock() }
        return box.data
    }

    /// Single-quote a shell argument safely.
    private static func shellQuote(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - http / sse transport

    private static func fetchToolsHTTP(_ server: MCPServerConfig) async -> Result<[MCPTool], DiscoveryError> {
        guard let urlString = server.url, let url = URL(string: urlString) else {
            return .failure(.init(message: "No URL configured"))
        }

        var sessionID: String?

        // initialize
        let initResult = await postJSONRPC(url: url, headers: server.headers, body: initializeRequest(id: 1), sessionID: nil)
        switch initResult {
        case .failure(let error):
            return .failure(error)
        case .success(let (_, responseSessionID)):
            sessionID = responseSessionID
        }

        // tools/list
        let listResult = await postJSONRPC(url: url, headers: server.headers, body: toolsListRequest(id: 2), sessionID: sessionID)
        switch listResult {
        case .failure(let error):
            return .failure(error)
        case .success(let (json, _)):
            if let tools = parseToolsResult(json) {
                return .success(tools)
            }
            return .failure(.init(message: "Server did not return a tool list"))
        }
    }

    /// POST a single JSON-RPC message. Handles both `application/json` and
    /// `text/event-stream` (SSE) responses. Returns the decoded JSON-RPC object
    /// plus any `Mcp-Session-Id` response header.
    private static func postJSONRPC(
        url: URL,
        headers: [String: String]?,
        body: [String: Any],
        sessionID: String?
    ) async -> Result<([String: Any], String?), DiscoveryError> {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json, text/event-stream", forHTTPHeaderField: "Accept")
        for (key, value) in headers ?? [:] { request.setValue(value, forHTTPHeaderField: key) }
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "Mcp-Session-Id") }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let http = response as? HTTPURLResponse
            let responseSessionID = http?.value(forHTTPHeaderField: "Mcp-Session-Id")
            let contentType = http?.value(forHTTPHeaderField: "Content-Type") ?? ""

            if let code = http?.statusCode, code >= 400 {
                return .failure(.init(message: "HTTP \(code)"))
            }

            let json: [String: Any]?
            if contentType.contains("text/event-stream") {
                json = extractSSEJSON(data)
            } else {
                json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            guard let json else {
                return .failure(.init(message: "Unparseable response"))
            }
            return .success((json, responseSessionID))
        } catch {
            return .failure(.init(message: error.localizedDescription))
        }
    }

    /// Pull the last JSON-RPC object out of an SSE response body (`data:` lines).
    private static func extractSSEJSON(_ data: Data) -> [String: Any]? {
        guard let text = String(data: data, encoding: .utf8) else { return nil }
        var result: [String: Any]?
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("data:") else { continue }
            let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if let payloadData = payload.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {
                result = json
            }
        }
        return result
    }

    struct DiscoveryError: Error {
        let message: String
    }
}
