import Foundation
import SwiftUI

@MainActor
class ConfigurationManager: ObservableObject {
    static let shared = ConfigurationManager()

    /// Errors raised before a write so a damaged file is never overwritten.
    enum WriteError: LocalizedError {
        case unreadable(URL, underlying: Error)
        case malformedJSON(URL)
        case notAnObject(URL)
        case settingsDecodeFailed

        var errorDescription: String? {
            switch self {
            case .unreadable(let url, let err):
                return "Could not read \(url.lastPathComponent): \(err.localizedDescription). Nothing was saved."
            case .malformedJSON(let url):
                return "\(url.lastPathComponent) is not valid JSON. Fix it by hand; nothing was saved."
            case .notAnObject(let url):
                return "\(url.lastPathComponent) does not contain a JSON object. Nothing was saved."
            case .settingsDecodeFailed:
                return "settings.json could not be fully read, so a full save was refused to avoid overwriting data."
            }
        }
    }

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
    /// Message from the last failed MCP read/write, shown by the MCP view. Nil when the last one succeeded.
    @Published var lastMCPError: String?

    /// True when settings.json exists but could not be decoded into `ClaudeSettings`.
    /// While set, the in-memory `settings` are defaults, so every whole-object write is
    /// refused (field-level dotted writes still go through — they never use the model).
    @Published private(set) var settingsDecodeFailed: Bool = false

    /// Bumped by FileWatcher whenever an external change is detected on disk.
    /// Views that hold their own @State (MCP, sessions, stats, git, themes,
    /// profiles, storage badges, …) observe this to re-run their loaders so the
    /// UI reflects current files instead of a stale onAppear snapshot.
    @Published var externalChangeToken: Int = 0

    /// Files FileWatcher snapshots (mtime+size) to decide whether a reload is warranted.
    var changeWatchFiles: [URL] {
        [settingsURL, localSettingsURL, claudeMDURL, mcpConfigURL,
         claudeDir.appendingPathComponent("stats-cache.json")]
    }
    /// Directories FileWatcher signatures (entry names + mtimes) for the same purpose.
    var changeWatchDirs: [URL] {
        ["projects", "commands", "skills", "agents", "rules", "themes", "profiles", "plugins"]
            .map { claudeDir.appendingPathComponent($0) }
    }

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

    /// - Parameter homeDirectory: Overrides the home directory so tests can run against a
    ///   temporary folder and never touch the real `~/.claude`.
    init(homeDirectory: URL? = nil) {
        let home = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
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

    /// Reload all config from disk. When `force` is true (e.g. FileWatcher detected
    /// an external change), dirty flags are cleared so disk state always wins.
    func loadAll(force: Bool = false) {
        if force {
            isDirty = false
            isLocalDirty = false
            isMDDirty = false
        }

        isLoading = true
        isLoadingFromDisk = true
        lastError = nil

        // Load settings.json — skip if we have unsaved local changes
        if isDirty {
            // Don't overwrite in-memory edits, but also don't save here —
            // saving during a reload can push stale/default values to disk.
            // The next explicit user action will trigger saveSettings().
        } else if let data = try? Data(contentsOf: settingsURL) {
            let fixed = validateAndFix(jsonData: data)
            do {
                settings = try decoder.decode(ClaudeSettings.self, from: fixed)
                settingsDecodeFailed = false
                print("[CC Settings] Loaded settings: model=\(settings.model), hooks=\(settings.hooks != nil ? "yes" : "nil"), effort=\(settings.effortLevel ?? "nil")")
            } catch {
                // Decode failed — do NOT touch settings; preserve current state
                settingsDecodeFailed = true
                lastError = error
                print("[CC Settings] DECODE FAILED: \(error)")
            }
        }

        // Load settings.local.json — skip if dirty
        if isLocalDirty {
            // Don't save during reload — wait for explicit user action.
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
            // Don't save during reload — wait for explicit user action.
        } else if let content = try? String(contentsOf: claudeMDURL, encoding: .utf8) {
            claudeMD = content
        }

        isLoadingFromDisk = false
        isLoading = false
    }

    // MARK: - Field-Level Save

    /// Writes a single setting to the JSON file, modifying only the targeted key.
    /// Use dot-separated key paths for nested values (e.g., "attribution.commit", "env.API_KEY").
    /// Pass nil to remove the key.
    func saveField(_ keyPath: String, value: Any?, to url: URL? = nil) {
        saveFields([(keyPath: keyPath, value: value)], to: url)
    }

    /// Claude Code treats an absent `alwaysThinkingEnabled` as "on", so turning thinking on
    /// removes the key and only "off" is written (`false`).
    func saveThinkingEnabled(_ enabled: Bool) {
        saveField("alwaysThinkingEnabled", value: enabled ? nil : false)
    }

    /// `skipDangerousModePermissionPrompt` is a top-level key in Claude Code. Older builds of
    /// this app wrote it under `permissions`, where the CLI never reads it, so a toggle also
    /// retires that stray copy.
    func saveSkipDangerousModePrompt(_ skip: Bool) {
        saveFields([
            (keyPath: "skipDangerousModePermissionPrompt", value: skip ? true : nil),
            (keyPath: "permissions.skipDangerousModePermissionPrompt", value: nil)
        ])
    }

    // MARK: - Global config (~/.claude.json)

    /// `autoUpdates` lives in the global config, not settings.json. Absent means on.
    func globalAutoUpdatesEnabled() -> Bool {
        let store = MCPConfigStore(fileURL: mcpConfigURL)
        return ((try? store.readRootValue("autoUpdates")) as? Bool) ?? true
    }

    /// Read-modify-write of just `autoUpdates` in `~/.claude.json`: `false` when off, key
    /// removed when on (the CLI default), every other key untouched.
    func saveGlobalAutoUpdates(_ enabled: Bool) {
        do {
            try MCPConfigStore(fileURL: mcpConfigURL).setRootValue("autoUpdates", to: enabled ? nil : false)
        } catch {
            lastError = error
        }
    }

    /// Writes multiple fields atomically in a single read-modify-write cycle.
    /// Key paths are split on "." — use `applyEdits` for keys that may contain dots.
    func saveFields(_ fields: [(keyPath: String, value: Any?)], to url: URL? = nil) {
        applyEdits(fields.map { (path: $0.keyPath.split(separator: ".").map(String.init), value: $0.value) }, to: url)
    }

    /// Reads `url` for a read-modify-write. A missing file yields `[:]` (it will be created);
    /// a file that exists but cannot be read or parsed throws, so the caller aborts instead
    /// of overwriting it with a partial object.
    func readJSONObjectForWrite(at url: URL) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [:] }
        let data: Data
        do { data = try Data(contentsOf: url) } catch { throw WriteError.unreadable(url, underlying: error) }
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        let fixed = validateAndFix(jsonData: data)
        guard let obj = try? JSONSerialization.jsonObject(with: fixed) else { throw WriteError.malformedJSON(url) }
        guard let dict = obj as? [String: Any] else { throw WriteError.notAnObject(url) }
        return dict
    }

    /// Core read-modify-write. Each edit is a key path given as components, so keys that
    /// contain dots (env var names, path-keyed maps) stay addressable.
    func applyEdits(_ edits: [(path: [String], value: Any?)], to url: URL? = nil) {
        let targetURL = url ?? settingsURL
        do {
            try FileManager.default.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            var existingJSON = try readJSONObjectForWrite(at: targetURL)
            for edit in edits {
                setNestedValue(&existingJSON, keyPath: edit.path, value: edit.value)
            }
            try writeJSONObject(existingJSON, to: targetURL)

            if targetURL == settingsURL {
                isDirty = false
                isLoadingFromDisk = true
                if let reloadData = try? Data(contentsOf: settingsURL) {
                    let fixed = validateAndFix(jsonData: reloadData)
                    if let decoded = try? decoder.decode(ClaudeSettings.self, from: fixed) {
                        settings = decoded
                        settingsDecodeFailed = false
                    }
                }
                isLoadingFromDisk = false
            }
        } catch {
            lastError = error
        }
    }

    private func writeJSONObject(_ object: [String: Any], to url: URL) throws {
        let outputData = try JSONSerialization.data(
            withJSONObject: object,
            options: [.prettyPrinted, .sortedKeys]
        )
        try fixIntegerFormatting(outputData).write(to: url, options: .atomic)
        lastSaveTime = Date()
        FileWatcher.shared.updateFileTracking(for: [url])
    }

    /// Writes only `hooks.<event>` (the encoded groups, or removes it when empty) and drops
    /// the `hooks` object if that leaves it empty. Other events, and any event this app does
    /// not know, are never touched.
    func saveHookGroups(_ groups: [HookGroup], event: String, to url: URL? = nil) {
        var value: Any?
        if !groups.isEmpty {
            do {
                let data = try encoder.encode(groups)
                value = try JSONSerialization.jsonObject(with: data)
            } catch {
                lastError = error
                return
            }
        }
        applyEdits([(path: ["hooks", event], value: value)], to: url)
    }

    /// Applies env changes as per-variable edits (`env.KEY`) instead of replacing the whole
    /// `env` object: sets/updates the given pairs and removes the listed keys.
    func saveEnvChanges(set: [String: String], remove: [String], to url: URL? = nil) {
        var edits: [(path: [String], value: Any?)] = []
        for key in remove.sorted() { edits.append((path: ["env", key], value: nil)) }
        for (key, value) in set.sorted(by: { $0.key < $1.key }) { edits.append((path: ["env", key], value: value)) }
        guard !edits.isEmpty else { return }
        applyEdits(edits, to: url)
    }

    /// Writes a Codable value at a top-level key. Pass nil to remove the key.
    func saveEncodedField<T: Encodable>(_ key: String, value: T?) {
        if let value = value {
            do {
                let data = try encoder.encode(value)
                let jsonObj = try JSONSerialization.jsonObject(with: data)
                saveField(key, value: jsonObj)
            } catch {
                lastError = error
            }
        } else {
            saveField(key, value: nil)
        }
    }

    /// Sets (or, for nil, removes) the value at `keyPath`, creating intermediate objects only
    /// when there is something to write. A removal that empties its parent object also removes
    /// the parent, so `permissions: {}` / `hooks: {}` are never left behind.
    private func setNestedValue(_ dict: inout [String: Any], keyPath: [String], value: Any?) {
        guard let first = keyPath.first else { return }

        if keyPath.count == 1 {
            if let value = value {
                dict[first] = value
            } else {
                dict.removeValue(forKey: first)
            }
            return
        }

        guard var nested = dict[first] as? [String: Any] else {
            // Nothing to remove under a missing (or non-object) parent.
            guard value != nil else { return }
            var created: [String: Any] = [:]
            setNestedValue(&created, keyPath: Array(keyPath.dropFirst()), value: value)
            dict[first] = created
            return
        }
        setNestedValue(&nested, keyPath: Array(keyPath.dropFirst()), value: value)
        if value == nil && nested.isEmpty {
            dict.removeValue(forKey: first)
        } else {
            dict[first] = nested
        }
    }

    // MARK: - Raw Write

    /// Writes raw JSON bytes directly to settings.json and reloads.
    /// Used by ProfileManager to restore a profile snapshot (preserving unknown CLI keys).
    func writeRawSettingsAndReload(_ rawJSON: Data) {
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            try rawJSON.write(to: settingsURL, options: .atomic)
            lastSaveTime = Date()
            isDirty = false
            FileWatcher.shared.updateFileTracking(for: [settingsURL])
            loadAll(force: true)
        } catch {
            lastError = error
        }
    }

    /// Whole-object save. Prefer `saveField`/`saveFields`; this exists for callers that hold a
    /// full `ClaudeSettings`. It still never rewrites the file wholesale: it compares `settings`
    /// against what the file decodes to right now and writes only the top-level keys that
    /// differ. Refused while `settingsDecodeFailed`, because the in-memory model is then defaults.
    func saveSettings() {
        guard !settingsDecodeFailed else {
            lastError = WriteError.settingsDecodeFailed
            return
        }
        writeSettingsDiff(settings, to: settingsURL)
        isDirty = false
    }

    /// Writes only the top-level keys where `new` differs from the decode of the file on disk.
    /// Aborts (without writing) if the file is unreadable, malformed, or does not decode.
    @discardableResult
    private func writeSettingsDiff(_ new: ClaudeSettings, to url: URL) -> Bool {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            var existingJSON = try readJSONObjectForWrite(at: url)

            let baseline = try decoder.decode(
                ClaudeSettings.self,
                from: try JSONSerialization.data(withJSONObject: existingJSON)
            )
            let oldEncoded = try encodedDictionary(baseline)
            let newEncoded = try encodedDictionary(new)

            for key in Set(oldEncoded.keys).union(newEncoded.keys) {
                let oldValue = oldEncoded[key]
                let newValue = newEncoded[key]
                if let oldValue, let newValue, (oldValue as AnyObject).isEqual(newValue) { continue }
                if oldValue == nil && newValue == nil { continue }
                if let newValue { existingJSON[key] = newValue } else { existingJSON.removeValue(forKey: key) }
            }
            try writeJSONObject(existingJSON, to: url)
            return true
        } catch {
            lastError = error
            return false
        }
    }

    private func encodedDictionary(_ settings: ClaudeSettings) throws -> [String: Any] {
        let data = try encoder.encode(settings)
        return (try JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    /// Keys that ClaudeSettings models — used to distinguish "intentionally nil" from "unknown".
    private let knownSettingsKeys: Set<String> = [
        "apiKeyHelper", "env", "permissions", "model", "hooks",
        "skipWebFetchPreflight", "alwaysThinkingEnabled",
        "mainBranch", "preferredGitApp", "customGitAppPath",
        "theme", "language", "effortLevel", "outputStyle", "verbose", "prefersReducedMotion",
        "skillOverrides", "prUrlTemplate",
        "showTurnDuration", "respectGitignore", "autoCompactEnabled", "plansDirectory",
        "includeGitInstructions", "showThinkingSummaries", "showClearContextOnPlanAccept",
        "defaultShell",
        "fastMode", "fastModePerSessionOptIn", "availableModels",
        "autoMemoryEnabled", "autoMemoryDirectory",
        "voiceEnabled",
        "autoUpdatesChannel",
        "preferredNotifChannel",
        "cleanupPeriodDays",
        "attribution",
        "teammateMode",
        "disableAutoMode", "autoMode", "disableAllHooks",
        "claudeMdExcludes",
        "sandbox", "worktree",
        // Legacy flat sandbox fields
        "enableWeakerSandbox", "unsandboxedCommands", "allowLocalBinding",
        "allowAllUnixSockets", "allowedDomains",
        "spinnerTipsEnabled", "spinnerVerbsMode", "spinnerVerbs",
        "customTips", "excludeDefaultTips", "spinnerTipsOverride",
        "statusLine", "statusLineCommand",
        // Workflows / skills
        "disableWorkflows", "workflowKeywordTriggerEnabled", "disableBundledSkills",
        "workflowSizeGuideline",
        // Behavior
        "autoCompactWindow", "precomputeCompactionEnabled", "todoFeatureEnabled",
        "askUserQuestionTimeout", "awaySummaryEnabled", "promptSuggestionEnabled",
        "emojiCompletionEnabled", "fileCheckpointingEnabled", "feedbackSurveyRate",
        "fileSuggestion", "autoContinueAtUsageLimit",
        "bashOutputMaxChars",
        // Time & locale
        "timeFormat", "timeZone",
        // Terminal & accessibility
        "axScreenReader", "autoScrollEnabled", "wheelScrollAccelerationEnabled",
        "terminalProgressBarEnabled", "showMessageTimestamps", "syntaxHighlightingDisabled",
        "hideVimModeIndicator", "vimInsertModeRemaps", "spellcheck",
        // Model
        "enforceAvailableModels", "advisorModel", "fallbackModel", "promptCacheTtl",
        // Agent view / remote control
        "disableAgentView", "subagentStatusLine", "disableRemoteControl",
        "remoteControlAtStartup", "agentPushNotifEnabled",
        "crossSessionInbound", "dialogExpiry",
        // Artifact
        "enableArtifact", "disableArtifact",
        // Enterprise / managed
        "pluginSuggestionMarketplaces", "allowAllClaudeAiMcps", "disableClaudeAiConnectors",
        "channelsEnabled", "allowedMcpServers", "strictKnownMarketplaces",
        "blockedMarketplaces", "disableSideloadFlags", "disableSkillShellExecution",
        "disableDeepLinkRegistration",
    ]

    /// Keys that LocalSettings models — used to distinguish "intentionally nil" from "unknown".
    private let knownLocalSettingsKeys: Set<String> = [
        "permissions",
    ]

    func saveLocalSettings() {
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
            lastSaveTime = Date()
            isLocalDirty = false
            FileWatcher.shared.updateFileTracking(for: [localSettingsURL])
        } catch {
            lastError = error
        }
    }

    func saveClaudeMD() {
        do {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
            try claudeMD.write(to: claudeMDURL, atomically: true, encoding: .utf8)
            lastSaveTime = Date()
            isMDDirty = false
            FileWatcher.shared.updateFileTracking(for: [claudeMDURL])
        } catch {
            lastError = error
        }
    }

    // MARK: - CLAUDE.md Backups

    private var claudeMDBackupsDir: URL {
        claudeDir.appendingPathComponent("claude-md-backups")
    }

    /// Backs up the given CLAUDE.md content before a template replaces it.
    /// Returns the backup file URL, or nil if content was empty.
    @discardableResult
    func backupClaudeMD(content: String, scope: String) -> URL? {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let fm = FileManager.default
        do {
            try fm.createDirectory(at: claudeMDBackupsDir, withIntermediateDirectories: true)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            let timestamp = formatter.string(from: Date())
            let safeName = scope.replacingOccurrences(of: "/", with: "-")
            let filename = "\(timestamp)_\(safeName).md"
            let url = claudeMDBackupsDir.appendingPathComponent(filename)
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            lastError = error
            return nil
        }
    }

    struct ClaudeMDBackup: Identifiable {
        let id: URL
        let date: Date
        let scope: String
        let url: URL
    }

    func listClaudeMDBackups() -> [ClaudeMDBackup] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: claudeMDBackupsDir, includingPropertiesForKeys: [.contentModificationDateKey])
            .filter({ $0.pathExtension == "md" })
        else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"

        return files.compactMap { url in
            let name = url.deletingPathExtension().lastPathComponent
            let parts = name.split(separator: "_", maxSplits: 2)
            guard parts.count >= 3 else { return nil }
            let dateStr = "\(parts[0])_\(parts[1])"
            let scope = String(parts[2])
            guard let date = formatter.date(from: dateStr) else { return nil }
            return ClaudeMDBackup(id: url, date: date, scope: scope, url: url)
        }
        .sorted { $0.date > $1.date }
    }

    // MARK: - MCP Servers

    /// Store for one MCP location. All MCP reads/writes go through `MCPConfigStore`, which
    /// re-reads the file on every write, refuses to touch a file it can't parse, and only
    /// changes the servers it is asked to.
    private func mcpStore(for storage: MCPStorage) -> MCPConfigStore {
        switch storage {
        case .userGlobal:
            return MCPConfigStore(fileURL: mcpConfigURL)
        case .projectShared(let path):
            return MCPConfigStore(fileURL: URL(fileURLWithPath: path).appendingPathComponent(".mcp.json"),
                                  deleteFileWhenEmpty: true)
        case .projectLocal(let key):
            return MCPConfigStore(fileURL: mcpConfigURL, projectKey: key)
        }
    }

    /// Runs a throwing MCP write. On failure nothing is written, `lastError` is set and
    /// `lastMCPError` carries a message the MCP view shows to the user.
    @discardableResult
    private func performMCPWrite(touching storages: [MCPStorage], _ body: () throws -> Void) -> Bool {
        do {
            try body()
            lastSaveTime = Date()
            FileWatcher.shared.updateFileTracking(for: storages.map { mcpStore(for: $0).fileURL })
            lastMCPError = nil
            return true
        } catch {
            lastError = error
            lastMCPError = error.localizedDescription
            return false
        }
    }

    private func loadMCPServersReporting(_ storage: MCPStorage) -> [String: MCPServerConfig] {
        do {
            return try mcpStore(for: storage).loadServers()
        } catch {
            lastError = error
            lastMCPError = error.localizedDescription
            return [:]
        }
    }

    func loadMCPServers() -> [String: MCPServerConfig] {
        loadMCPServersReporting(.userGlobal)
    }

    @discardableResult
    func saveMCPServers(_ servers: [String: MCPServerConfig]) -> Bool {
        saveMCPServers(servers, for: .userGlobal)
    }

    // MARK: - Targeted MCP operations (read-modify-write)

    /// The server's full raw JSON object as stored on disk (every key, modeled or not).
    func rawMCPServer(named name: String, in storage: MCPStorage) -> [String: Any]? {
        try? mcpStore(for: storage).rawServer(named: name)
    }

    /// Adds or edits one server. When the server moves between locations or is renamed, the
    /// full raw dict is carried over (so unknown keys survive), the target is written first,
    /// and only then is the original removed.
    @discardableResult
    func saveMCPServer(_ server: MCPServerConfig, replacing oldName: String?, from original: MCPStorage?, to target: MCPStorage) -> Bool {
        performMCPWrite(touching: [target] + (original.map { [$0] } ?? [])) {
            let targetStore = mcpStore(for: target)
            if let oldName, let original {
                try MCPConfigStore.transfer(name: oldName, from: mcpStore(for: original), to: targetStore,
                                            as: server.id, edited: server)
            } else {
                try targetStore.update { servers in
                    servers[server.id] = MCPConfigStore.merge(existing: servers[server.id], with: server, name: server.id)
                }
            }
        }
    }

    @discardableResult
    func deleteMCPServer(named name: String, from storage: MCPStorage) -> Bool {
        performMCPWrite(touching: [storage]) { try mcpStore(for: storage).remove([name]) }
    }

    // MARK: - Project Settings (hooks, permissions, etc.)

    /// Loads a project's `.claude/settings.json` for hooks and other project-level settings.
    /// Returns the raw JSON dictionary from a project's settings.json.
    /// Used for override detection — checking whether a key is present in the project file.
    func loadProjectRawJSON(projectPath: String) -> [String: Any] {
        let url = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: url) else { return [:] }
        let fixed = validateAndFix(jsonData: data)
        guard let json = try? JSONSerialization.jsonObject(with: fixed) as? [String: Any] else { return [:] }
        return json
    }

    func loadProjectSettings(projectPath: String) -> ClaudeSettings? {
        let settingsURL = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        let fixed = validateAndFix(jsonData: data)
        return try? decoder.decode(ClaudeSettings.self, from: fixed)
    }

    /// Saves project-level settings to `<project>/.claude/settings.json`. Only the top-level
    /// keys that differ from what the file currently decodes to are written, so absent keys are
    /// never filled with defaults, and a project file that is malformed or fails to decode is
    /// left untouched (the error is surfaced via `lastError`).
    func saveProjectSettings(_ settings: ClaudeSettings, projectPath: String) {
        let url = URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
        writeSettingsDiff(settings, to: url)
    }

    /// URL of `<project>/.claude/settings.local.json` (personal, not checked in).
    func projectLocalSettingsURL(projectPath: String) -> URL {
        URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.local.json")
    }

    /// Raw JSON of a project's `settings.local.json`, or `[:]` when missing/unreadable.
    func loadProjectLocalRawJSON(projectPath: String) -> [String: Any] {
        guard let data = try? Data(contentsOf: projectLocalSettingsURL(projectPath: projectPath)) else { return [:] }
        let fixed = validateAndFix(jsonData: data)
        return (try? JSONSerialization.jsonObject(with: fixed) as? [String: Any]) ?? [:]
    }

    /// URL of `<project>/.claude/settings.json`.
    func projectSettingsURL(projectPath: String) -> URL {
        URL(fileURLWithPath: projectPath)
            .appendingPathComponent(".claude")
            .appendingPathComponent("settings.json")
    }

    // MARK: - Project MCP Servers

    /// Loads MCP servers from a project's `.mcp.json` file.
    func loadProjectMCPServers(projectPath: String) -> [String: MCPServerConfig] {
        loadMCPServersReporting(.projectShared(path: projectPath))
    }

    /// Saves MCP servers to a project's `.mcp.json` file, merging per server and preserving other keys.
    @discardableResult
    func saveProjectMCPServers(_ servers: [String: MCPServerConfig], projectPath: String) -> Bool {
        saveMCPServers(servers, for: .projectShared(path: projectPath))
    }

    /// Loads all MCP servers from global config and all known project `.mcp.json` files.
    func loadAllScopedMCPServers() -> [ScopedMCPServer] {
        var result: [ScopedMCPServer] = []

        // Global ("user") servers from ~/.claude.json top-level mcpServers
        let globalServers = loadMCPServers()
        for (_, config) in globalServers {
            result.append(ScopedMCPServer(config: config, scope: .global, storage: .userGlobal))
        }

        let projects = loadProjects()
        let projectsByPath = Dictionary(projects.map { ($0.originalPath, $0) }, uniquingKeysWith: { a, _ in a })

        // Project ("shared") servers from each known project's .mcp.json
        for project in projects {
            let projectPath = project.originalPath
            let mcpURL = URL(fileURLWithPath: projectPath).appendingPathComponent(".mcp.json")
            guard FileManager.default.fileExists(atPath: mcpURL.path) else { continue }

            let projectServers = loadProjectMCPServers(projectPath: projectPath)
            let scope = ConfigScope.project(id: project.id, path: projectPath)
            for (_, config) in projectServers {
                result.append(ScopedMCPServer(config: config, scope: scope, storage: .projectShared(path: projectPath)))
            }
        }

        // Local servers stored inline in ~/.claude.json under projects[path].mcpServers
        if let data = try? Data(contentsOf: mcpConfigURL),
           let json = try? JSONSerialization.jsonObject(with: validateAndFix(jsonData: data)) as? [String: Any],
           let projectsJSON = json["projects"] as? [String: Any] {
            for (rawPath, value) in projectsJSON {
                guard let pdict = value as? [String: Any],
                      let serversDict = pdict["mcpServers"] as? [String: [String: Any]],
                      !serversDict.isEmpty else { continue }
                let decodedPath = rawPath.removingPercentEncoding ?? rawPath
                // Group with the matching known project if we have one; else stand alone.
                let scopeId = projectsByPath[decodedPath]?.id ?? decodedPath
                let scope = ConfigScope.project(id: scopeId, path: decodedPath)
                for (name, serverJSON) in serversDict {
                    let config = parseServerConfig(name: name, serverJSON: serverJSON)
                    result.append(ScopedMCPServer(config: config, scope: scope, storage: .projectLocal(path: rawPath)))
                }
            }
        }

        return result.sorted { $0.config.id.localizedCaseInsensitiveCompare($1.config.id) == .orderedAscending }
    }

    // MARK: - MCP storage routing (user / project-shared / project-local)

    /// Parse a raw MCP server JSON object into a config (decode, with a resilient fallback).
    private func parseServerConfig(name: String, serverJSON: [String: Any]) -> MCPServerConfig {
        MCPConfigStore.parseServerConfig(name: name, serverJSON: serverJSON)
    }

    /// Loads MCP servers for a given storage location.
    func loadMCPServers(for storage: MCPStorage) -> [String: MCPServerConfig] {
        loadMCPServersReporting(storage)
    }

    /// Saves a full set of MCP servers to a storage location (per-server merge; servers
    /// missing from `servers` are removed). Prefer `saveMCPServer`/`deleteMCPServer`.
    @discardableResult
    func saveMCPServers(_ servers: [String: MCPServerConfig], for storage: MCPStorage) -> Bool {
        performMCPWrite(touching: [storage]) { try mcpStore(for: storage).save(servers) }
    }

    /// Loads local-scope servers from ~/.claude.json `projects[projectKey].mcpServers`.
    func loadLocalMCPServers(projectKey: String) -> [String: MCPServerConfig] {
        loadMCPServersReporting(.projectLocal(path: projectKey))
    }

    /// Saves local-scope servers back to ~/.claude.json `projects[projectKey].mcpServers`.
    @discardableResult
    func saveLocalMCPServers(_ servers: [String: MCPServerConfig], projectKey: String) -> Bool {
        saveMCPServers(servers, for: .projectLocal(path: projectKey))
    }

    /// Moves an MCP server between storage locations: copies the full raw server dict to
    /// the target (so unmodeled keys such as oauth survive), writes the target first, then
    /// removes the source.
    @discardableResult
    func moveMCPServer(_ server: MCPServerConfig, from sourceStorage: MCPStorage, to targetStorage: MCPStorage) -> Bool {
        guard sourceStorage != targetStorage else { return true }
        return performMCPWrite(touching: [sourceStorage, targetStorage]) {
            try MCPConfigStore.transfer(name: server.id, from: mcpStore(for: sourceStorage), to: mcpStore(for: targetStorage))
        }
    }

    /// JSONSerialization converts Swift Int values to Double (e.g. 10000 becomes 10000.0).
    /// This post-processes the JSON text to restore whole-number doubles back to plain integers.
    private func fixIntegerFormatting(_ data: Data) -> Data {
        // String-aware (see JSONTextFixer): number tokens only, never string contents.
        JSONTextFixer.restoreIntegers(data)
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

            // Load project settings from the project's real .claude/settings.json
            // (matches loadProjectSettings). Reading dir/settings.json — i.e.
            // ~/.claude/projects/<id>/settings.json — always missed the file, so
            // Project.settings was always nil and the hasSettings filter was dead.
            let projectSettingsURL = URL(fileURLWithPath: originalPath)
                .appendingPathComponent(".claude")
                .appendingPathComponent("settings.json")
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
        let originalPath = decodePath(projectId)
        // Save to project root (where Claude Code reads it)
        let rootClaudeMD = URL(fileURLWithPath: originalPath).appendingPathComponent("CLAUDE.md")
        do {
            try content.write(to: rootClaudeMD, atomically: true, encoding: .utf8)
            lastSaveTime = Date()
        } catch {
            // If project root isn't writable, save to ~/.claude/projects/<id>/
            let projectDir = projectsDir.appendingPathComponent(projectId)
            try? FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
            let internalClaudeMD = projectDir.appendingPathComponent("CLAUDE.md")
            try? content.write(to: internalClaudeMD, atomically: true, encoding: .utf8)
            lastSaveTime = Date()
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
        // Don't skip hidden files — folders like backups/ contain only dotfiles
        // (`.claude.json.backup.*`) that would otherwise render as an empty list.
        guard let contents = try? fm.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey, .isSymbolicLinkKey],
            options: []
        ) else {
            return []
        }

        return contents.compactMap { url -> ClaudeFile? in
            guard url.lastPathComponent != ".DS_Store" else { return nil }
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

    // MARK: - Themes

    /// Reads all `*.json` files under `~/.claude/themes/`, parsed as `ThemeFile`.
    /// Unknown JSON keys are preserved in `ThemeFile.unknownFields` so saves
    /// don't drop schema-novel data.
    func loadThemes() -> [ThemeFile] {
        let themesDir = claudeDir.appendingPathComponent("themes")
        guard let urls = try? FileManager.default.contentsOfDirectory(at: themesDir, includingPropertiesForKeys: nil) else {
            return []
        }
        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { ThemeFile.load(from: $0) }
            .sorted { $0.id.lowercased() < $1.id.lowercased() }
    }

    /// Writes a theme to disk and registers it with FileWatcher so external
    /// edits are tracked. Atomic; will create `~/.claude/themes/` if missing.
    func saveTheme(_ theme: ThemeFile) throws {
        try FileManager.default.createDirectory(
            at: theme.url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try theme.serialize()
        try data.write(to: theme.url, options: [.atomic])
        FileWatcher.shared.updateFileTracking(for: [theme.url])
    }

    /// Deletes a theme file. Returns whether the file existed at deletion time.
    @discardableResult
    func deleteTheme(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            lastError = error
            return false
        }
    }

    /// Returns the URL where a new theme with the requested basename would live.
    /// Disambiguates by appending `-2`, `-3`, … when the name is taken.
    func themeURL(forNewName name: String) -> URL {
        let themesDir = claudeDir.appendingPathComponent("themes")
        let baseSlug = sanitizeThemeName(name)
        var candidate = themesDir.appendingPathComponent("\(baseSlug).json")
        var counter = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = themesDir.appendingPathComponent("\(baseSlug)-\(counter).json")
            counter += 1
        }
        return candidate
    }

    private func sanitizeThemeName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = trimmed.isEmpty ? "untitled" : trimmed
        // Strip path separators and reserved characters; keep alnum, dash, underscore, dot
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        return String(cleaned.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" })
    }
}
