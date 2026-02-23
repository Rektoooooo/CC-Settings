import Foundation
import SwiftUI

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    @Published var settings: ClaudeSettings = ClaudeSettings()
    @Published var localSettings: LocalSettings = LocalSettings()
    @Published var claudeMD: String = ""
    @Published var isLoading: Bool = false
    @Published var lastError: Error?

    /// Timestamp of the last save performed by the app. FileWatcher checks this to avoid
    /// reloading settings that the app itself just wrote (which would overwrite in-progress edits).
    private(set) var lastSaveTime: Date = .distantPast

    private let claudeDir: URL
    private let settingsURL: URL
    private let localSettingsURL: URL
    private let claudeMDURL: URL
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
    }

    func loadAll() {
        isLoading = true
        lastError = nil

        // Load settings.json
        if let data = try? Data(contentsOf: settingsURL) {
            let fixed = validateAndFix(jsonData: data)
            do {
                settings = try decoder.decode(ClaudeSettings.self, from: fixed)
            } catch {
                lastError = error
            }
        }

        // Load settings.local.json
        if let data = try? Data(contentsOf: localSettingsURL) {
            let fixed = validateAndFix(jsonData: data)
            do {
                localSettings = try decoder.decode(LocalSettings.self, from: fixed)
            } catch {
                lastError = error
            }
        }

        // Load CLAUDE.md
        if let content = try? String(contentsOf: claudeMDURL, encoding: .utf8) {
            claudeMD = content
        }

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
        "autoUpdates", "autoUpdatesChannel",
        "preferredNotifChannel",
        "cleanupPeriodDays",
        "attribution",
        "teammateMode",
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
        } catch {
            lastError = error
        }
    }

    func saveClaudeMD() {
        lastSaveTime = Date()
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            try claudeMD.write(to: claudeMDURL, atomically: true, encoding: .utf8)
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
        guard let config = try? decoder.decode(MCPDesktopConfig.self, from: fixed) else {
            return [:]
        }
        // Assign dictionary keys as id
        var result: [String: MCPServerConfig] = [:]
        for (key, var value) in config.mcpServers {
            value.id = key
            result[key] = value
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
    /// Claude Code encodes project paths by replacing `/`, `.`, and ` ` with `-`.
    /// This is inherently ambiguous: a hyphen in the encoded string could be a literal
    /// hyphen from the original directory name, or a separator that replaced `/`, `.`,
    /// or ` `. For example, `my-project` and `my/project` both encode to `my-project`.
    ///
    /// The algorithm resolves ambiguity by greedily matching against the actual filesystem,
    /// preferring the longest directory name that exists on disk. This works well in practice
    /// but can fail if: (1) the directory no longer exists, (2) multiple directories share
    /// the same encoded form, or (3) the path contains mixed separator types within a single
    /// component (e.g. `my.project-name`). In those edge cases the fallback joins all
    /// remaining parts with `/`.
    private func decodePath(_ encoded: String) -> String {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        let homeComponents = home.split(separator: "/").map(String.init)

        // The encoded path replaces / with -
        // Problem: directory names can also contain hyphens (e.g. "Autoskola-Trefa")
        // Solution: greedily match filesystem paths to resolve ambiguity
        var parts = encoded.split(separator: "-").map(String.init)

        // Remove leading empty component if encoded starts with "-"
        if parts.first == "" {
            parts.removeFirst()
        }

        // Try to match home directory prefix
        guard parts.count >= homeComponents.count else {
            return "/" + parts.joined(separator: "/")
        }

        var matchesHome = true
        for (i, comp) in homeComponents.enumerated() {
            let encodedComp = comp.replacingOccurrences(of: "_", with: "-")
            if parts[i] != comp && parts[i] != encodedComp {
                matchesHome = false
                break
            }
        }

        guard matchesHome else {
            return "/" + parts.joined(separator: "/")
        }

        // Greedily resolve remaining parts by checking filesystem
        let remaining = Array(parts[homeComponents.count...])
        let resolvedPath = resolvePathComponents(remaining, basePath: home, fileManager: fm)
        return resolvedPath
    }

    /// Greedily resolve encoded path components by checking which combinations exist on disk.
    /// Claude Code encodes paths by replacing /, ., and space with -
    /// So "Autoskola-Trefa" could be "Autoskola-Trefa", "Autoskola.Trefa", or "Autoskola Trefa"
    private func resolvePathComponents(_ parts: [String], basePath: String, fileManager fm: FileManager) -> String {
        guard !parts.isEmpty else { return basePath }

        // Try joining progressively more parts (greedy: longest match first)
        for joinCount in stride(from: parts.count, through: 1, by: -1) {
            let segment = Array(parts[0..<joinCount])

            // Try different separators: -, ., and space
            let candidates = [
                segment.joined(separator: "-"),
                segment.joined(separator: "."),
                segment.joined(separator: " "),
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
