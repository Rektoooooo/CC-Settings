import Foundation
import SwiftUI

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published var settings: ClaudeSettings = ClaudeSettings() {
        didSet {
            if !isLoadingFromDisk { isDirty = true }
        }
    }
    @Published var localSettings: LocalSettings = LocalSettings() {
        didSet {
            if !isLoadingFromDisk { isLocalDirty = true }
        }
    }
    @Published var claudeMD: String = "" {
        didSet {
            if !isLoadingFromDisk { isMDDirty = true }
        }
    }
    @Published var isLoading: Bool = false
    @Published var lastError: Error?

    /// Timestamp of the last save performed by the app. FileWatcher checks this to avoid
    /// reloading settings that the app itself just wrote (which would overwrite in-progress edits).
    private(set) var lastSaveTime: Date = .distantPast

    /// Tracks whether in-memory state has unsaved changes. Prevents loadAll() from
    /// overwriting edits that haven't been persisted yet.
    private var isDirty = false
    private var isLocalDirty = false
    private var isMDDirty = false

    /// Suppresses dirty-marking during disk loads so that assigning @Published properties
    /// from loadAll() doesn't incorrectly flag them as user edits.
    private var isLoadingFromDisk = false

    private let claudeDir: URL
    let settingsURL: URL
    let localSettingsURL: URL
    let claudeMDURL: URL
    private let projectsDir: URL
    private let commandsDir: URL
    private let skillsDir: URL
    private let pluginsDir: URL
    private let mcpConfigURL: URL

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()

    private let decoder = JSONDecoder()

    private init() {
        let home = FileManager.default.homeDirectoryForCurrentUser
        claudeDir = home.appendingPathComponent(".claude")
        settingsURL = claudeDir.appendingPathComponent("settings.json")
        localSettingsURL = claudeDir.appendingPathComponent("settings.local.json")
        claudeMDURL = claudeDir.appendingPathComponent("CLAUDE.md")
        projectsDir = claudeDir.appendingPathComponent("projects")
        commandsDir = claudeDir.appendingPathComponent("commands")
        skillsDir = claudeDir.appendingPathComponent("skills")
        pluginsDir = claudeDir.appendingPathComponent("plugins")
        mcpConfigURL = home.appendingPathComponent(".claude.json")

        // Load settings immediately so they're available before any view renders.
        // This prevents a race where onAppear fires before applicationDidFinishLaunching,
        // causing loadFromSettings() to read defaults and then save() to overwrite real values.
        loadAll()
    }

    func loadAll() {
        isLoading = true
        isLoadingFromDisk = true
        lastError = nil

        // Load settings.json — skip if we have unsaved local changes
        if isDirty {
            // Push our in-memory changes to disk instead of overwriting them
            saveSettings()
        } else if let data = try? Data(contentsOf: settingsURL) {
            let fixed = validateAndFix(jsonData: data)
            do {
                settings = try decoder.decode(ClaudeSettings.self, from: fixed)
            } catch {
                // Decode failed — do NOT touch settings; preserve current state
                lastError = error
            }
        }

        // Load settings.local.json — skip if dirty
        if isLocalDirty {
            saveLocalSettings()
        } else if let data = try? Data(contentsOf: localSettingsURL) {
            let fixed = validateAndFix(jsonData: data)
            do {
                localSettings = try decoder.decode(LocalSettings.self, from: fixed)
            } catch {
                lastError = error
            }
        }

        // Load CLAUDE.md — skip if dirty
        if isMDDirty {
            saveClaudeMD()
        } else if let content = try? String(contentsOf: claudeMDURL, encoding: .utf8) {
            claudeMD = content
        }

        isLoadingFromDisk = false
        isLoading = false
    }

    func saveSettings() {
        lastSaveTime = Date()
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            // Load existing JSON to preserve unknown keys the CLI uses
            var existingJSON: [String: Any] = [:]
            if let data = try? Data(contentsOf: settingsURL) {
                let fixed = validateAndFix(jsonData: data)
                if let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] {
                    existingJSON = json
                }
            }

            // Encode our known settings and merge on top
            let settingsData = try encoder.encode(settings)
            if let settingsJSON = try JSONSerialization.jsonObject(with: settingsData) as? [String: Any] {
                for (key, value) in settingsJSON {
                    existingJSON[key] = value
                }
                // Remove keys that our model explicitly set to nil (encoded as absent)
                for key in existingJSON.keys {
                    if settingsJSON[key] == nil, knownSettingsKeys.contains(key) {
                        existingJSON.removeValue(forKey: key)
                    }
                }
            }

            let outputData = try JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys])
            let fixedOutput = fixIntegerFormatting(outputData)
            try fixedOutput.write(to: settingsURL, options: .atomic)
            isDirty = false
            FileWatcher.shared.updateFileTracking(for: [settingsURL])
        } catch {
            lastError = error
        }
    }

    /// Keys that ClaudeSettings models — used to distinguish "intentionally nil" from "unknown".
    private let knownSettingsKeys: Set<String> = [
        "apiKeyHelper", "env", "permissions", "model", "hooks",
        "skipWebFetchPreflight", "alwaysThinkingEnabled", "thinkingBudgetTokens",
        "mainBranch", "preferredGitApp", "customGitAppPath",
        "theme", "language", "effortLevel", "outputStyle", "verbose", "prefersReducedMotion",
        "showTurnDuration", "respectGitignore", "autoCompact", "plansDirectory",
        "includeGitInstructions", "showThinkingSummaries", "showClearContextOnPlanAccept",
        "defaultShell",
        "fastMode", "fastModePerSessionOptIn", "availableModels",
        "autoMemoryEnabled", "autoMemoryDirectory",
        "voiceEnabled",
        "autoUpdates", "autoUpdatesChannel",
        "preferredNotifChannel",
        "cleanupPeriodDays",
        "attribution",
        "teammateMode",
        "disableAutoMode", "disableAllHooks",
        "claudeMdExcludes",
        "sandbox", "worktree",
        // Legacy flat sandbox fields
        "enableWeakerSandbox", "unsandboxedCommands", "allowLocalBinding",
        "allowAllUnixSockets", "allowedDomains",
        "spinnerTipsEnabled", "spinnerVerbsMode", "spinnerVerbs",
        "customTips", "excludeDefaultTips",
        "statusLineCommand",
    ]

    /// Keys that LocalSettings models — used to distinguish "intentionally nil" from "unknown".
    private let knownLocalSettingsKeys: Set<String> = [
        "permissions",
    ]

    func saveLocalSettings() {
        lastSaveTime = Date()
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            // Load existing JSON to preserve unknown keys the CLI uses
            var existingJSON: [String: Any] = [:]
            if let data = try? Data(contentsOf: localSettingsURL) {
                let fixed = validateAndFix(jsonData: data)
                if let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] {
                    existingJSON = json
                }
            }

            // Encode our known settings and merge on top
            let localData = try encoder.encode(localSettings)
            if let localJSON = try JSONSerialization.jsonObject(with: localData) as? [String: Any] {
                for (key, value) in localJSON {
                    existingJSON[key] = value
                }
                // Remove keys that our model explicitly set to nil (encoded as absent)
                for key in existingJSON.keys {
                    if localJSON[key] == nil, knownLocalSettingsKeys.contains(key) {
                        existingJSON.removeValue(forKey: key)
                    }
                }
            }

            let outputData = try JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys])
            let fixedOutput = fixIntegerFormatting(outputData)
            try fixedOutput.write(to: localSettingsURL, options: .atomic)
            isLocalDirty = false
            FileWatcher.shared.updateFileTracking(for: [localSettingsURL])
        } catch {
            lastError = error
        }
    }

    func saveClaudeMD() {
        lastSaveTime = Date()
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            try claudeMD.write(to: claudeMDURL, atomically: true, encoding: .utf8)
            isMDDirty = false
            FileWatcher.shared.updateFileTracking(for: [claudeMDURL])
        } catch {
            lastError = error
        }
    }

    // MARK: - MCP Servers

    func loadMCPServers() -> [String: MCPServerConfig] {
        guard let data = try? Data(contentsOf: mcpConfigURL) else {
            return [:]
        }
        let fixed = validateAndFix(jsonData: data)
        guard let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any],
              let serversDict = json["mcpServers"] as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: MCPServerConfig] = [:]
        for (key, serverJSON) in serversDict {
            if let serverData = try? JSONSerialization.data(withJSONObject: serverJSON),
               var config = try? decoder.decode(MCPServerConfig.self, from: serverData) {
                config.id = key
                result[key] = config
            } else {
                // Fallback: build config manually from raw JSON for maximum resilience
                var config = MCPServerConfig(id: key)
                config.type = serverJSON["type"] as? String
                config.command = serverJSON["command"] as? String
                config.url = serverJSON["url"] as? String
                if let args = serverJSON["args"] as? [Any] {
                    config.args = args.map { "\($0)" }
                }
                if let env = serverJSON["env"] as? [String: Any] {
                    config.env = env.mapValues { "\($0)" }
                }
                if let headers = serverJSON["headers"] as? [String: Any] {
                    config.headers = headers.mapValues { "\($0)" }
                }
                result[key] = config
            }
        }
        return result
    }

    func saveMCPServers(_ servers: [String: MCPServerConfig]) {
        lastSaveTime = Date()
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            // Load existing config to preserve other keys
            var existingJSON: [String: Any] = [:]
            if let data = try? Data(contentsOf: mcpConfigURL) {
                let fixed = validateAndFix(jsonData: data)
                if let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] {
                    existingJSON = json
                }
            }

            // Encode the servers
            let serversData = try encoder.encode(servers)
            if let serversJSON = try JSONSerialization.jsonObject(with: serversData) as? [String: Any] {
                existingJSON["mcpServers"] = serversJSON
            }

            let outputData = try JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys])
            try outputData.write(to: mcpConfigURL, options: .atomic)
        } catch {
            lastError = error
        }
    }

    // MARK: - Project Settings (hooks, permissions, etc.)

    /// Loads a project's `.claude/settings.json` for hooks and other project-level settings.
    func loadProjectSettings(projectPath: String) -> ClaudeSettings? {
        let settingsURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        let fixed = validateAndFix(jsonData: data)
        return try? decoder.decode(ClaudeSettings.self, from: fixed)
    }

    /// Saves project-level settings to `<project>/.claude/settings.json`, preserving unknown keys.
    func saveProjectSettings(_ settings: ClaudeSettings, projectPath: String) {
        lastSaveTime = Date()
        let claudeDir = URL(fileURLWithPath: projectPath).appendingPathComponent(".claude")
        let settingsURL = claudeDir.appendingPathComponent("settings.json")
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

            var existingJSON: [String: Any] = [:]
            if let data = try? Data(contentsOf: settingsURL) {
                let fixed = validateAndFix(jsonData: data)
                if let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] {
                    existingJSON = json
                }
            }

            let settingsData = try encoder.encode(settings)
            if let settingsJSON = try JSONSerialization.jsonObject(with: settingsData) as? [String: Any] {
                for (key, value) in settingsJSON {
                    existingJSON[key] = value
                }
                for key in existingJSON.keys {
                    if settingsJSON[key] == nil, knownSettingsKeys.contains(key) {
                        existingJSON.removeValue(forKey: key)
                    }
                }
            }

            let outputData = try JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys])
            let fixedOutput = fixIntegerFormatting(outputData)
            try fixedOutput.write(to: settingsURL, options: .atomic)
        } catch {
            lastError = error
        }
    }

    // MARK: - Project MCP Servers

    /// Loads MCP servers from a project's `.mcp.json` file.
    func loadProjectMCPServers(projectPath: String) -> [String: MCPServerConfig] {
        let mcpURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".mcp.json")
        guard let data = try? Data(contentsOf: mcpURL) else {
            return [:]
        }
        let fixed = validateAndFix(jsonData: data)
        guard let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any],
              let serversDict = json["mcpServers"] as? [String: [String: Any]] else {
            return [:]
        }

        var result: [String: MCPServerConfig] = [:]
        for (key, serverJSON) in serversDict {
            if let serverData = try? JSONSerialization.data(withJSONObject: serverJSON),
               var config = try? decoder.decode(MCPServerConfig.self, from: serverData) {
                config.id = key
                result[key] = config
            } else {
                var config = MCPServerConfig(id: key)
                config.type = serverJSON["type"] as? String
                config.command = serverJSON["command"] as? String
                config.url = serverJSON["url"] as? String
                if let args = serverJSON["args"] as? [Any] {
                    config.args = args.map { "\($0)" }
                }
                if let env = serverJSON["env"] as? [String: Any] {
                    config.env = env.mapValues { "\($0)" }
                }
                if let headers = serverJSON["headers"] as? [String: Any] {
                    config.headers = headers.mapValues { "\($0)" }
                }
                result[key] = config
            }
        }
        return result
    }

    /// Saves MCP servers to a project's `.mcp.json` file, preserving other keys.
    func saveProjectMCPServers(_ servers: [String: MCPServerConfig], projectPath: String) {
        lastSaveTime = Date()
        let mcpURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".mcp.json")
        do {
            var existingJSON: [String: Any] = [:]
            if let data = try? Data(contentsOf: mcpURL) {
                let fixed = validateAndFix(jsonData: data)
                if let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] {
                    existingJSON = json
                }
            }

            let serversData = try encoder.encode(servers)
            if let serversJSON = try JSONSerialization.jsonObject(with: serversData) as? [String: Any] {
                existingJSON["mcpServers"] = serversJSON
            }

            // Remove mcpServers key entirely if empty
            if servers.isEmpty {
                existingJSON.removeValue(forKey: "mcpServers")
            }

            // If nothing left, delete the file
            if existingJSON.isEmpty {
                try? FileManager.default.removeItem(at: mcpURL)
                return
            }

            let outputData = try JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys])
            try outputData.write(to: mcpURL, options: .atomic)
        } catch {
            lastError = error
        }
    }

    /// Loads all MCP servers from global config and all known project `.mcp.json` files.
    func loadAllScopedMCPServers() -> [ScopedMCPServer] {
        var result: [ScopedMCPServer] = []

        // Global servers from ~/.claude.json
        let globalServers = loadMCPServers()
        for (_, config) in globalServers {
            result.append(ScopedMCPServer(config: config, scope: .global))
        }

        // Project servers from each known project's .mcp.json
        let projects = loadProjects()
        for project in projects {
            let projectPath = project.originalPath
            let mcpURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".mcp.json")
            guard FileManager.default.fileExists(atPath: mcpURL.path) else { continue }

            let projectServers = loadProjectMCPServers(projectPath: projectPath)
            let scope = ConfigScope.project(id: project.id, path: projectPath)
            for (_, config) in projectServers {
                result.append(ScopedMCPServer(config: config, scope: scope))
            }
        }

        return result.sorted { $0.config.id.localizedCaseInsensitiveCompare($1.config.id) == .orderedAscending }
    }

    /// Moves an MCP server from one scope to another (copy then delete from source).
    func moveMCPServer(_ server: MCPServerConfig, from sourceScope: ConfigScope, to targetScope: ConfigScope) {
        // Add to target
        switch targetScope {
        case .global:
            var dict = loadMCPServers()
            dict[server.id] = server
            saveMCPServers(dict)
        case .project(_, let path):
            var dict = loadProjectMCPServers(projectPath: path)
            dict[server.id] = server
            saveProjectMCPServers(dict, projectPath: path)
        }

        // Remove from source
        switch sourceScope {
        case .global:
            var dict = loadMCPServers()
            dict.removeValue(forKey: server.id)
            saveMCPServers(dict)
        case .project(_, let path):
            var dict = loadProjectMCPServers(projectPath: path)
            dict.removeValue(forKey: server.id)
            saveProjectMCPServers(dict, projectPath: path)
        }
    }

    /// JSONSerialization converts Swift Int values to Double (e.g. 10000 becomes 10000.0).
    /// This post-processes the JSON text to restore whole-number doubles back to plain integers.
    private func fixIntegerFormatting(_ data: Data) -> Data {
        guard var str = String(data: data, encoding: .utf8) else { return data }
        // Match ": <digits>.0" patterns produced by JSONSerialization for integer values.
        str = str.replacingOccurrences(
            of: ":\\s*(-?\\d+)\\.0(\\s*[,\\]\\}\\n])",
            with: ": $1$2",
            options: .regularExpression
        )
        return str.data(using: .utf8) ?? data
    }

    func validateAndFix(jsonData: Data) -> Data {
        if (try? JSONSerialization.jsonObject(with: jsonData)) != nil {
            return jsonData
        }
        // Strip trailing commas before } or ].
        // NOTE: This regex can match inside JSON string values (e.g. a string containing ",]").
        // This is acceptable as a best-effort fixer — it only runs on already-invalid JSON,
        // and string values containing trailing-comma patterns are extremely rare in config files.
        if var str = String(data: jsonData, encoding: .utf8) {
            str = str.replacingOccurrences(
                of: ",\\s*([\\]}])",
                with: "$1",
                options: .regularExpression
            )
            if let fixedData = str.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: fixedData)) != nil {
                return fixedData
            }
        }
        return jsonData
    }

    func loadProjects() -> [Project] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: projectsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var projects: [Project] = []
        for dir in contents {
            guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else {
                continue
            }
            let projectId = dir.lastPathComponent
            let originalPath = decodePath(projectId)
            var sessions: [Session] = []
            var totalSize: Int64 = 0
            var lastAccessed: Date?

            // Load sessions (.jsonl files)
            if let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]) {
                for file in files where file.pathExtension == "jsonl" {
                    let attrs = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let fileSize = Int64(attrs?.fileSize ?? 0)
                    let modDate = attrs?.contentModificationDate ?? Date.distantPast
                    totalSize += fileSize
                    if lastAccessed == nil || modDate > lastAccessed! {
                        lastAccessed = modDate
                    }
                    sessions.append(Session(
                        id: UUID(),
                        filename: file.lastPathComponent,
                        size: fileSize,
                        lastModified: modDate
                    ))
                }
            }

            // Load project settings
            let projectSettingsURL = dir.appendingPathComponent("settings.json")
            var projectSettings: ClaudeSettings?
            if let data = try? Data(contentsOf: projectSettingsURL) {
                projectSettings = try? decoder.decode(ClaudeSettings.self, from: validateAndFix(jsonData: data))
            }

            // Load project CLAUDE.md — check project root first, then ~/.claude/projects/<id>/
            let rootClaudeMDURL = URL(fileURLWithPath: originalPath).appendingPathComponent("CLAUDE.md")
            let internalClaudeMDURL = dir.appendingPathComponent("CLAUDE.md")
            let claudeMDContent: String? = {
                if let content = try? String(contentsOf: rootClaudeMDURL, encoding: .utf8) {
                    return content
                }
                return try? String(contentsOf: internalClaudeMDURL, encoding: .utf8)
            }()

            projects.append(Project(
                id: projectId,
                originalPath: originalPath,
                claudeMD: claudeMDContent,
                settings: projectSettings,
                sessions: sessions,
                totalSize: totalSize,
                lastAccessed: lastAccessed
            ))
        }

        return projects.sorted { ($0.lastAccessed ?? .distantPast) > ($1.lastAccessed ?? .distantPast) }
    }

    /// Decodes a Claude Code project ID back into a filesystem path.
    ///
    /// Claude Code encodes project paths by replacing `/`, `.`, ` `, and `_` with `-`.
    /// This is inherently ambiguous: a hyphen in the encoded string could be a literal
    /// hyphen from the original directory name, or a separator that replaced `/`, `.`,
    /// ` `, or `_`. For example, `my-project` and `my/project` both encode to `my-project`.
    ///
    /// The algorithm resolves ambiguity by greedily matching against the actual filesystem,
    /// preferring the longest directory name that exists on disk. This works well in practice
    /// but can fail if: (1) the directory no longer exists, (2) multiple directories share
    /// the same encoded form, or (3) the path contains mixed separator types within a single
    /// component (e.g. `my.project-name`). In those edge cases the fallback joins all
    /// remaining parts with `/`.
    private func decodePath(_ encoded: String) -> String {
        let fm = FileManager.default
        let parts = encoded.split(separator: "-").map(String.init)

        // Resolve the full path greedily from root, handling all encoded separators
        // (/, ., space, _) uniformly via filesystem matching.
        return resolvePathComponents(parts, basePath: "/", fileManager: fm)
    }

    /// Greedily resolve encoded path components by checking which combinations exist on disk.
    /// Claude Code encodes paths by replacing /, ., space, and _ with -
    /// So "Autoskola-Trefa" could be "Autoskola-Trefa", "Autoskola.Trefa", "Autoskola Trefa", or "Autoskola_Trefa"
    private func resolvePathComponents(_ parts: [String], basePath: String, fileManager fm: FileManager) -> String {
        guard !parts.isEmpty else { return basePath }

        // Try joining progressively more parts (greedy: longest match first)
        for joinCount in stride(from: parts.count, through: 1, by: -1) {
            let segment = Array(parts[0..<joinCount])

            // Try different separators: -, ., space, and _
            let candidates = [
                segment.joined(separator: "-"),
                segment.joined(separator: "."),
                segment.joined(separator: " "),
                segment.joined(separator: "_"),
            ]

            for candidate in candidates {
                let candidatePath = (basePath as NSString).appendingPathComponent(candidate)
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: candidatePath, isDirectory: &isDir), isDir.boolValue {
                    let remainingParts = Array(parts[joinCount...])
                    if remainingParts.isEmpty {
                        return candidatePath
                    }
                    let result = resolvePathComponents(remainingParts, basePath: candidatePath, fileManager: fm)
                    if fm.fileExists(atPath: result) {
                        return result
                    }
                }
            }

            // Also try matching against actual directory listing (handles mixed separators)
            if joinCount > 1, let entries = try? fm.contentsOfDirectory(atPath: basePath) {
                let normalized = segment.joined(separator: "-").lowercased()
                for entry in entries {
                    let entryNormalized = entry
                        .replacingOccurrences(of: ".", with: "-")
                        .replacingOccurrences(of: " ", with: "-")
                        .replacingOccurrences(of: "_", with: "-")
                        .lowercased()
                    if entryNormalized == normalized {
                        let candidatePath = (basePath as NSString).appendingPathComponent(entry)
                        var isDir: ObjCBool = false
                        if fm.fileExists(atPath: candidatePath, isDirectory: &isDir), isDir.boolValue {
                            let remainingParts = Array(parts[joinCount...])
                            if remainingParts.isEmpty {
                                return candidatePath
                            }
                            let result = resolvePathComponents(remainingParts, basePath: candidatePath, fileManager: fm)
                            if fm.fileExists(atPath: result) {
                                return result
                            }
                        }
                    }
                }
            }
        }

        // Fallback: join all remaining with / (no match found)
        return (basePath as NSString).appendingPathComponent(parts.joined(separator: "/"))
    }

    // MARK: - Project CLAUDE.md

    func loadProjectClaudeMD(projectId: String) -> String? {
        let originalPath = decodePath(projectId)
        // Check project root first (where Claude Code actually reads it)
        let rootClaudeMD = URL(fileURLWithPath: originalPath).appendingPathComponent("CLAUDE.md")
        if let content = try? String(contentsOf: rootClaudeMD, encoding: .utf8) {
            return content
        }
        // Fall back to ~/.claude/projects/<id>/CLAUDE.md
        let internalClaudeMD = projectsDir.appendingPathComponent(projectId).appendingPathComponent("CLAUDE.md")
        return try? String(contentsOf: internalClaudeMD, encoding: .utf8)
    }

    func saveProjectClaudeMD(_ content: String, projectId: String) {
        lastSaveTime = Date()
        let originalPath = decodePath(projectId)
        // Save to project root (where Claude Code reads it)
        let rootClaudeMD = URL(fileURLWithPath: originalPath).appendingPathComponent("CLAUDE.md")
        do {
            try content.write(to: rootClaudeMD, atomically: true, encoding: .utf8)
        } catch {
            // If project root isn't writable, save to ~/.claude/projects/<id>/
            let projectDir = projectsDir.appendingPathComponent(projectId)
            try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
            let internalClaudeMD = projectDir.appendingPathComponent("CLAUDE.md")
            try? content.write(to: internalClaudeMD, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Path Helpers

    func projectOriginalPath(for projectId: String) -> String {
        return decodePath(projectId)
    }

    // MARK: - File Loading Helpers

    func loadFilesFromClaudeDir() -> [ClaudeFile] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: claudeDir,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> ClaudeFile? in
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else {
                return nil
            }
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let ext = url.pathExtension.lowercased()
            let allowedExtensions = ["md", "markdown", "json", "txt", "pdf", "log", "conf", "config", ""]
            let name = url.lastPathComponent

            guard allowedExtensions.contains(ext) || name.hasPrefix("CLAUDE") else {
                return nil
            }

            return ClaudeFile(
                id: url.path,
                name: name,
                path: url,
                type: FileType.detect(from: url),
                size: Int64(attrs?.fileSize ?? 0),
                modificationDate: attrs?.contentModificationDate
            )
        }
    }

    func loadFilesFromFolder(_ name: String) -> [ClaudeFile] {
        let fm = FileManager.default
        let folderURL = claudeDir.appendingPathComponent(name)
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> ClaudeFile? in
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey])
            let isDir = attrs?.isDirectory ?? false

            // Symlink detection
            let symlinkAttrs = try? URL(fileURLWithPath: url.path, isDirectory: false)
                .resourceValues(forKeys: [.isSymbolicLinkKey])
            let isSymlink = symlinkAttrs?.isSymbolicLink ?? false
            var symlinkTarget: String? = nil
            var isBrokenSymlink = false

            if isSymlink {
                if let target = try? fm.destinationOfSymbolicLink(atPath: url.path) {
                    symlinkTarget = target
                    // Check if target exists
                    let resolvedTarget: String
                    if target.hasPrefix("/") {
                        resolvedTarget = target
                    } else {
                        resolvedTarget = (url.deletingLastPathComponent().path as NSString).appendingPathComponent(target)
                    }
                    isBrokenSymlink = !fm.fileExists(atPath: resolvedTarget)
                }
            }

            // Directory item count
            var directoryItemCount = 0
            if isDir {
                directoryItemCount = (try? fm.contentsOfDirectory(atPath: url.path))?.count ?? 0
            }

            return ClaudeFile(
                id: url.path,
                name: url.lastPathComponent,
                path: url,
                type: FileType.detect(from: url),
                size: Int64(attrs?.fileSize ?? 0),
                modificationDate: attrs?.contentModificationDate,
                isSymlink: isSymlink,
                symlinkTarget: symlinkTarget,
                isBrokenSymlink: isBrokenSymlink,
                isDirectory: isDir,
                directoryItemCount: directoryItemCount
            )
        }
    }

    func loadFilesForProject(_ projectId: String) -> [ClaudeFile] {
        let fm = FileManager.default
        var files: [ClaudeFile] = []
        var seenPaths = Set<String>()
        let projectDir = projectsDir.appendingPathComponent(projectId)
        let originalPath = decodePath(projectId)
        let projectRoot = URL(fileURLWithPath: originalPath)

        // Helper to add a file if it exists and hasn't been added
        func addFileIfExists(_ url: URL, displayName: String? = nil) {
            guard fm.fileExists(atPath: url.path) else { return }
            guard !seenPaths.contains(url.path) else { return }
            seenPaths.insert(url.path)
            let attrs = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            files.append(ClaudeFile(
                id: url.path,
                name: displayName ?? url.lastPathComponent,
                path: url,
                type: FileType.detect(from: url),
                size: Int64(attrs?.fileSize ?? 0),
                modificationDate: attrs?.contentModificationDate
            ))
        }

        // Helper to scan a directory for config files
        func scanDirectory(_ dir: URL) {
            guard let contents = try? fm.contentsOfDirectory(
                at: dir,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else { return }

            let allowedExtensions: Set<String> = ["md", "markdown", "json", "txt", "pdf", "log", "conf", "config"]
            for url in contents {
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else { continue }
                guard url.pathExtension.lowercased() != "jsonl" else { continue }
                let ext = url.pathExtension.lowercased()
                let name = url.lastPathComponent
                guard allowedExtensions.contains(ext) || name.hasPrefix("CLAUDE") else { continue }
                addFileIfExists(url)
            }
        }

        // 1. Check well-known files by explicit path (most reliable)
        addFileIfExists(projectRoot.appendingPathComponent("CLAUDE.md"))
        addFileIfExists(projectRoot.appendingPathComponent(".claude").appendingPathComponent("settings.json"), displayName: "settings.json (project)")
        addFileIfExists(projectRoot.appendingPathComponent(".claude").appendingPathComponent("settings.local.json"), displayName: "settings.local.json (project)")
        addFileIfExists(projectDir.appendingPathComponent("settings.json"), displayName: "settings.json (internal)")
        addFileIfExists(projectDir.appendingPathComponent("settings.local.json"), displayName: "settings.local.json (internal)")
        addFileIfExists(projectDir.appendingPathComponent("CLAUDE.md"), displayName: "CLAUDE.md (internal)")

        // 2. Scan project root .claude/ folder for other files
        scanDirectory(projectRoot.appendingPathComponent(".claude"))

        // 3. Scan ~/.claude/projects/<id>/ for other config files
        scanDirectory(projectDir)

        return files
    }
}
