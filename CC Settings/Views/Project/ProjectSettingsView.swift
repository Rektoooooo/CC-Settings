import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    let projectId: String

    // Resolved project path
    @State private var projectPath: String = ""
    @State private var rawProjectJSON: [String: Any] = [:]
    @State private var isLoaded = false

    // Model
    @State private var model: String = ""
    @State private var effortLevel: String = ""
    @State private var maxEffortLevel: String = ""
    @State private var outputStyle: String = ""

    // Behavior
    @State private var respectGitignore: Bool = true
    @State private var includeGitInstructions: Bool = true
    @State private var defaultShell: String = "bash"
    @State private var plansDirectory: String = ""

    // Memory
    @State private var autoMemoryEnabled: Bool = true
    @State private var autoMemoryDirectory: String = ""
    @State private var localProjectJSON: [String: Any] = [:]

    // Environment
    @State private var envVars: [ProjectEnvEntry] = []

    // Permissions
    @State private var permDefaultMode: String = "default"
    @State private var permAllow: String = ""
    @State private var permDeny: String = ""
    @State private var permAsk: String = ""

    // Sandbox
    @State private var sandboxEnabled: Bool = false
    @State private var sandboxAllowWrite: String = ""
    @State private var sandboxDenyWrite: String = ""

    // Worktree
    @State private var worktreeSparsePaths: String = ""
    @State private var worktreeSymlinkDirs: String = ""

    private var projectSettingsURL: URL {
        URL(fileURLWithPath: projectPath).appendingPathComponent(".claude/settings.json")
    }

    private var projectDisplayName: String {
        ProjectPathResolver.displayName(path: projectPath, id: projectId)
    }

    /// False until `loadProjectData` has run, and for projects whose folder could not be located.
    private var isEditable: Bool { ProjectPathResolver.isResolved(projectPath) }

    var body: some View {
        Form {
            headerSection
            Group {
                modelSection
                behaviorSection
                memorySection
                environmentSection
                permissionsSection
                sandboxSection
                worktreeSection
            }
            .disabled(!isEditable)
        }
        .formStyle(.grouped)
        .onAppear { loadProjectData() }
        .onChange(of: configManager.settings) {
            guard isLoaded else { return }
            loadProjectData()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "folder.fill")
                    .foregroundColor(.accentColor)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text(projectDisplayName)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(ProjectPathResolver.displayPath(projectPath, id: projectId))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            if !isEditable {
                Label(ProjectPathResolver.unresolvedExplanation, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            Text("Override global settings for this project. Inherited settings use the global value.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Model

    @ViewBuilder
    private var modelSection: some View {
        Section("Model") {
            OverridableSettingRow(
                title: "Model",
                globalSummary: displayName(for: configManager.settings.model),
                isOverridden: isOverridden("model"),
                onToggleOverride: { enabled in
                    if enabled {
                        model = configManager.settings.model
                        // Never write "model": "" — with no global model there is nothing to
                        // copy yet; the override is written once a model is picked.
                        if !model.isEmpty { saveProjectField("model", value: model) }
                    } else {
                        saveProjectField("model", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                HierarchicalModelPicker(selectedModelId: $model)
                    .onChange(of: model) {
                        guard isLoaded, isOverridden("model") || !model.isEmpty else { return }
                        saveProjectField("model", value: model.isEmpty ? nil : model)
                    }
            }

            OverridableSettingRow(
                title: "Effort Level",
                globalSummary: configManager.settings.effortLevel ?? "Not set",
                isOverridden: isOverridden("effortLevel"),
                onToggleOverride: { enabled in
                    if enabled {
                        let inherited = configManager.settings.effortLevel ?? ""
                        effortLevel = EffortLevels.selectable.contains(inherited) ? inherited : ""
                        saveProjectField("effortLevel", value: effortLevel.isEmpty ? nil : effortLevel)
                    } else {
                        saveProjectField("effortLevel", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Picker("", selection: $effortLevel) {
                    Text("Normal").tag("")
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                    Text("Xhigh").tag("xhigh")
                }
                .pickerStyle(.segmented)
                .onChange(of: effortLevel) {
                    guard isLoaded, isOverridden("effortLevel") else { return }
                    saveProjectField("effortLevel", value: effortLevel.isEmpty ? nil : effortLevel)
                }
                Label("Applies to new Claude Code sessions.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let bad = rawProjectJSON["effortLevel"] as? String,
                   !EffortLevels.selectable.contains(bad) {
                    HStack {
                        Label("effortLevel \"\(bad)\" in this project is not valid — Claude Code ignores it.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Button("Clear") {
                            saveProjectField("effortLevel", value: nil)
                            effortLevel = ""
                            reloadRawJSON()
                        }
                    }
                }
            }

            OverridableSettingRow(
                title: "Max Effort Cap",
                description: "Caps the effort any session in this project can use; the lowest cap across scopes wins.",
                globalSummary: (configManager.rawSettingsObject()["maxEffortLevel"] as? String) ?? "Not set",
                isOverridden: isOverridden("maxEffortLevel"),
                onToggleOverride: { enabled in
                    if !enabled { configManager.saveMaxEffortLevel(nil, to: projectSettingsURL) }
                    reloadRawJSON()
                }
            ) {
                Picker("", selection: $maxEffortLevel) {
                    Text("None").tag("")
                    ForEach(EffortLevels.cap, id: \.self) { level in
                        Text(level.capitalized).tag(level)
                    }
                }
                .onChange(of: maxEffortLevel) {
                    guard isLoaded else { return }
                    configManager.saveMaxEffortLevel(maxEffortLevel.isEmpty ? nil : maxEffortLevel, to: projectSettingsURL)
                    reloadRawJSON()
                }
            }

            OverridableSettingRow(
                title: "Output Style",
                globalSummary: configManager.settings.outputStyle ?? "Not set",
                isOverridden: isOverridden("outputStyle"),
                onToggleOverride: { enabled in
                    if enabled {
                        outputStyle = configManager.settings.outputStyle ?? ""
                        saveProjectField("outputStyle", value: outputStyle.isEmpty ? nil : outputStyle)
                    } else {
                        saveProjectField("outputStyle", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                TextField("Output style", text: $outputStyle)
                    .textFieldStyle(.roundedBorder)
                    .commitOnFocusLoss(of: outputStyle) {
                        guard isOverridden("outputStyle") else { return }
                        let trimmed = outputStyle.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveProjectField("outputStyle", value: trimmed.isEmpty ? nil : trimmed)
                    }
            }
        }
    }

    // MARK: - Behavior

    @ViewBuilder
    private var behaviorSection: some View {
        Section("Behavior") {
            OverridableSettingRow(
                title: "Respect .gitignore",
                globalSummary: (configManager.settings.respectGitignore ?? true) ? "Enabled" : "Disabled",
                isOverridden: isOverridden("respectGitignore"),
                onToggleOverride: { enabled in
                    if enabled {
                        respectGitignore = configManager.settings.respectGitignore ?? true
                        saveProjectField("respectGitignore", value: respectGitignore ? nil : false)
                    } else {
                        saveProjectField("respectGitignore", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Toggle("", isOn: $respectGitignore)
                    .labelsHidden()
                    .onChange(of: respectGitignore) {
                        guard isLoaded, isOverridden("respectGitignore") else { return }
                        saveProjectField("respectGitignore", value: respectGitignore ? nil : false)
                    }
            }

            OverridableSettingRow(
                title: "Include Git Instructions",
                globalSummary: (configManager.settings.includeGitInstructions ?? true) ? "Enabled" : "Disabled",
                isOverridden: isOverridden("includeGitInstructions"),
                onToggleOverride: { enabled in
                    if enabled {
                        includeGitInstructions = configManager.settings.includeGitInstructions ?? true
                        saveProjectField("includeGitInstructions", value: includeGitInstructions ? nil : false)
                    } else {
                        saveProjectField("includeGitInstructions", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Toggle("", isOn: $includeGitInstructions)
                    .labelsHidden()
                    .onChange(of: includeGitInstructions) {
                        guard isLoaded, isOverridden("includeGitInstructions") else { return }
                        saveProjectField("includeGitInstructions", value: includeGitInstructions ? nil : false)
                    }
            }

            OverridableSettingRow(
                title: "Default Shell",
                globalSummary: configManager.settings.defaultShell ?? "Not set (bash)",
                isOverridden: isOverridden("defaultShell"),
                onToggleOverride: { enabled in
                    if enabled {
                        defaultShell = configManager.settings.defaultShell ?? "bash"
                        saveProjectField("defaultShell", value: defaultShell == "bash" ? nil : defaultShell)
                    } else {
                        saveProjectField("defaultShell", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Picker("", selection: $defaultShell) {
                    Text("Bash").tag("bash")
                    Text("Zsh").tag("zsh")
                    Text("Fish").tag("fish")
                }
                .pickerStyle(.segmented)
                .onChange(of: defaultShell) {
                    guard isLoaded, isOverridden("defaultShell") else { return }
                    saveProjectField("defaultShell", value: defaultShell == "bash" ? nil : defaultShell)
                }
            }

            OverridableSettingRow(
                title: "Plans Directory",
                globalSummary: configManager.settings.plansDirectory ?? "Not set",
                isOverridden: isOverridden("plansDirectory"),
                onToggleOverride: { enabled in
                    if enabled {
                        plansDirectory = configManager.settings.plansDirectory ?? ""
                        saveProjectField("plansDirectory", value: plansDirectory.isEmpty ? nil : plansDirectory)
                    } else {
                        saveProjectField("plansDirectory", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                TextField("Plans directory path", text: $plansDirectory)
                    .textFieldStyle(.roundedBorder)
                    .commitOnFocusLoss(of: plansDirectory) {
                        guard isOverridden("plansDirectory") else { return }
                        let trimmed = plansDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveProjectField("plansDirectory", value: trimmed.isEmpty ? nil : trimmed)
                    }
            }
        }
    }

    // MARK: - Memory

    @ViewBuilder
    private var memorySection: some View {
        Section("Memory") {
            OverridableSettingRow(
                title: "Auto Memory",
                globalSummary: (configManager.settings.autoMemoryEnabled ?? true) ? "Enabled" : "Disabled",
                isOverridden: isOverridden("autoMemoryEnabled"),
                onToggleOverride: { enabled in
                    if enabled {
                        autoMemoryEnabled = configManager.settings.autoMemoryEnabled ?? true
                        // An override stores the explicit value, true or false.
                        saveProjectField("autoMemoryEnabled", value: autoMemoryEnabled)
                    } else {
                        saveProjectField("autoMemoryEnabled", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Toggle("", isOn: $autoMemoryEnabled)
                    .labelsHidden()
                    .onChange(of: autoMemoryEnabled) {
                        guard isLoaded, isOverridden("autoMemoryEnabled") else { return }
                        saveProjectField("autoMemoryEnabled", value: autoMemoryEnabled)
                    }
            }

            // Claude Code ignores autoMemoryDirectory in checked-in .claude/settings.json (it
            // could redirect memory writes anywhere), so a project override lives in the
            // personal settings.local.json instead.
            if isOverridden("autoMemoryDirectory") {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ignored in checked-in settings.json")
                            .font(.caption.bold())
                        Text("Claude Code only honours autoMemoryDirectory from user or local settings. Move it to settings.local.json for it to take effect.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button("Move to settings.local.json") { moveAutoMemoryDirectoryToLocal() }
                            .controlSize(.small)
                    }
                }
            }

            OverridableSettingRow(
                title: "Memory Directory (local)",
                globalSummary: configManager.settings.autoMemoryDirectory ?? "Not set",
                isOverridden: localProjectJSON.keys.contains("autoMemoryDirectory"),
                onToggleOverride: { enabled in
                    if enabled {
                        autoMemoryDirectory = configManager.settings.autoMemoryDirectory ?? ""
                        saveLocalProjectField("autoMemoryDirectory", value: autoMemoryDirectory.isEmpty ? nil : autoMemoryDirectory)
                    } else {
                        saveLocalProjectField("autoMemoryDirectory", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                TextField("Memory directory", text: $autoMemoryDirectory)
                    .textFieldStyle(.roundedBorder)
                    .commitOnFocusLoss(of: autoMemoryDirectory) {
                        guard localProjectJSON.keys.contains("autoMemoryDirectory") else { return }
                        let trimmed = autoMemoryDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveLocalProjectField("autoMemoryDirectory", value: trimmed.isEmpty ? nil : trimmed)
                    }
            }
        }
    }

    // MARK: - Environment

    @ViewBuilder
    private var environmentSection: some View {
        Section("Environment Variables") {
            OverridableSettingRow(
                title: "Environment",
                globalSummary: "\(configManager.settings.env.count) global variable(s)",
                isOverridden: isOverridden("env"),
                onToggleOverride: { enabled in
                    if enabled {
                        envVars = [ProjectEnvEntry()]
                        saveProjectEnv()
                    } else {
                        saveProjectField("env", value: nil)
                        envVars = []
                    }
                    reloadRawJSON()
                }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($envVars) { $entry in
                        HStack(spacing: 8) {
                            TextField("Key", text: $entry.key)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: 200)
                            TextField("Value", text: $entry.value)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            Button {
                                envVars.removeAll { $0.id == entry.id }
                                saveProjectEnv()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button {
                        envVars.append(ProjectEnvEntry())
                    } label: {
                        Label("Add Variable", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderless)
                }
                .onSubmit { saveProjectEnv() }
            }
        }
    }

    // MARK: - Permissions

    @ViewBuilder
    private var permissionsSection: some View {
        Section("Permissions") {
            OverridableSettingRow(
                title: "Permissions",
                description: "Override allow/deny/ask tool lists for this project.",
                globalSummary: "Using global permissions",
                isOverridden: isOverridden("permissions"),
                onToggleOverride: { enabled in
                    if enabled {
                        let p = configManager.settings.permissions
                        permAllow = (p.allow ?? []).joined(separator: ", ")
                        permDeny = (p.deny ?? []).joined(separator: ", ")
                        permAsk = (p.ask ?? []).joined(separator: ", ")
                        permDefaultMode = p.defaultMode ?? "default"
                        saveProjectPermissions()
                    } else {
                        saveProjectField("permissions", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Default Mode", selection: $permDefaultMode) {
                        // `auto` can't be granted from checked-in repo settings; only offer it
                        // when a value is already stored so it still loads.
                        ForEach(DefaultPermissionMode.allCases.filter { $0 != .auto || permDefaultMode == "auto" }) { mode in
                            Text(mode.displayName).tag(mode.rawValue)
                        }
                    }
                    .onChange(of: permDefaultMode) {
                        guard isLoaded, isOverridden("permissions") else { return }
                        saveProjectPermissions()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Allow").font(.caption.bold())
                        TextField("Bash, Read, Write", text: $permAllow)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .commitOnFocusLoss(of: permAllow) { saveProjectPermissions() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deny").font(.caption.bold())
                        TextField("Edit, Bash(rm *)", text: $permDeny)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .commitOnFocusLoss(of: permDeny) { saveProjectPermissions() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask").font(.caption.bold())
                        TextField("Edit, Write", text: $permAsk)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .commitOnFocusLoss(of: permAsk) { saveProjectPermissions() }
                    }
                }
            }
        }
    }

    // MARK: - Sandbox

    @ViewBuilder
    private var sandboxSection: some View {
        Section("Sandbox") {
            OverridableSettingRow(
                title: "Sandbox",
                globalSummary: (configManager.settings.sandbox?.enabled ?? false) ? "Enabled" : "Disabled",
                isOverridden: isOverridden("sandbox"),
                onToggleOverride: { enabled in
                    if enabled {
                        sandboxEnabled = configManager.settings.sandbox?.enabled ?? false
                        sandboxAllowWrite = (configManager.settings.sandbox?.filesystem?.allowWrite ?? []).joined(separator: ", ")
                        sandboxDenyWrite = (configManager.settings.sandbox?.filesystem?.denyWrite ?? []).joined(separator: ", ")
                        saveProjectSandbox()
                    } else {
                        saveProjectField("sandbox", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable Sandbox", isOn: $sandboxEnabled)
                        .onChange(of: sandboxEnabled) {
                            guard isLoaded, isOverridden("sandbox") else { return }
                            saveProjectSandbox()
                        }

                    TextField("Allow Write (comma-separated)", text: $sandboxAllowWrite)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .commitOnFocusLoss(of: sandboxAllowWrite) { saveProjectSandbox() }

                    TextField("Deny Write (comma-separated)", text: $sandboxDenyWrite)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .commitOnFocusLoss(of: sandboxDenyWrite) { saveProjectSandbox() }
                }
            }
        }
    }

    // MARK: - Worktree

    @ViewBuilder
    private var worktreeSection: some View {
        Section("Worktree") {
            OverridableSettingRow(
                title: "Worktree",
                globalSummary: "Using global worktree config",
                isOverridden: isOverridden("worktree"),
                onToggleOverride: { enabled in
                    if enabled {
                        worktreeSparsePaths = (configManager.settings.worktree?.sparsePaths ?? []).joined(separator: ", ")
                        worktreeSymlinkDirs = (configManager.settings.worktree?.symlinkDirectories ?? []).joined(separator: ", ")
                        saveProjectWorktree()
                    } else {
                        saveProjectField("worktree", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Sparse Paths").font(.caption.bold())
                        TextField("src, docs, tests", text: $worktreeSparsePaths)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .commitOnFocusLoss(of: worktreeSparsePaths) { saveProjectWorktree() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Symlink Directories").font(.caption.bold())
                        TextField("node_modules, .venv", text: $worktreeSymlinkDirs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .commitOnFocusLoss(of: worktreeSymlinkDirs) { saveProjectWorktree() }
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    private func loadProjectData() {
        isLoaded = false
        projectPath = configManager.projectOriginalPath(for: projectId)
        rawProjectJSON = configManager.loadProjectRawJSON(projectPath: projectPath)
        let ps = configManager.loadProjectSettings(projectPath: projectPath) ?? ClaudeSettings()

        // Model
        model = rawProjectJSON.keys.contains("model") ? ps.model : configManager.settings.model
        effortLevel = rawProjectJSON.keys.contains("effortLevel") ? (ps.effortLevel ?? "") : (configManager.settings.effortLevel ?? "")
        maxEffortLevel = rawProjectJSON["maxEffortLevel"] as? String ?? ""
        outputStyle = rawProjectJSON.keys.contains("outputStyle") ? (ps.outputStyle ?? "") : (configManager.settings.outputStyle ?? "")

        // Behavior
        respectGitignore = rawProjectJSON.keys.contains("respectGitignore") ? (ps.respectGitignore ?? true) : (configManager.settings.respectGitignore ?? true)
        includeGitInstructions = rawProjectJSON.keys.contains("includeGitInstructions") ? (ps.includeGitInstructions ?? true) : (configManager.settings.includeGitInstructions ?? true)
        defaultShell = rawProjectJSON.keys.contains("defaultShell") ? (ps.defaultShell ?? "bash") : (configManager.settings.defaultShell ?? "bash")
        plansDirectory = rawProjectJSON.keys.contains("plansDirectory") ? (ps.plansDirectory ?? "") : (configManager.settings.plansDirectory ?? "")

        // Memory
        autoMemoryEnabled = rawProjectJSON.keys.contains("autoMemoryEnabled") ? (ps.autoMemoryEnabled ?? true) : (configManager.settings.autoMemoryEnabled ?? true)
        localProjectJSON = configManager.loadProjectLocalRawJSON(projectPath: projectPath)
        autoMemoryDirectory = (localProjectJSON["autoMemoryDirectory"] as? String)
            ?? (rawProjectJSON["autoMemoryDirectory"] as? String)
            ?? configManager.settings.autoMemoryDirectory ?? ""

        // Environment
        if let envDict = rawProjectJSON["env"] as? [String: String] {
            envVars = envDict.sorted(by: { $0.key < $1.key }).map { ProjectEnvEntry(key: $0.key, value: $0.value) }
        } else {
            envVars = []
        }

        // Permissions
        if let permsDict = rawProjectJSON["permissions"] as? [String: Any] {
            permDefaultMode = DefaultPermissionMode.parse(permsDict["defaultMode"] as? String)?.rawValue ?? (permsDict["defaultMode"] as? String) ?? "default"
            permAllow = (permsDict["allow"] as? [String])?.joined(separator: ", ") ?? ""
            permDeny = (permsDict["deny"] as? [String])?.joined(separator: ", ") ?? ""
            permAsk = (permsDict["ask"] as? [String])?.joined(separator: ", ") ?? ""
        } else {
            let p = configManager.settings.permissions
            permDefaultMode = p.defaultMode ?? "default"
            permAllow = ""
            permDeny = ""
            permAsk = ""
        }

        // Sandbox
        if rawProjectJSON.keys.contains("sandbox") {
            sandboxEnabled = ps.sandbox?.enabled ?? false
            sandboxAllowWrite = (ps.sandbox?.filesystem?.allowWrite ?? []).joined(separator: ", ")
            sandboxDenyWrite = (ps.sandbox?.filesystem?.denyWrite ?? []).joined(separator: ", ")
        }

        // Worktree
        if rawProjectJSON.keys.contains("worktree") {
            worktreeSparsePaths = (ps.worktree?.sparsePaths ?? []).joined(separator: ", ")
            worktreeSymlinkDirs = (ps.worktree?.symlinkDirectories ?? []).joined(separator: ", ")
        }

        DispatchQueue.main.async { isLoaded = true }
    }

    // MARK: - Save Helpers

    private func isOverridden(_ key: String) -> Bool {
        rawProjectJSON.keys.contains(key)
    }

    private func saveProjectField(_ keyPath: String, value: Any?) {
        guard isEditable else { return }
        configManager.saveField(keyPath, value: value, to: projectSettingsURL)
    }

    private func reloadRawJSON() {
        rawProjectJSON = configManager.loadProjectRawJSON(projectPath: projectPath)
        localProjectJSON = configManager.loadProjectLocalRawJSON(projectPath: projectPath)
    }

    private func saveLocalProjectField(_ keyPath: String, value: Any?) {
        guard isEditable else { return }
        configManager.saveField(keyPath, value: value, to: configManager.projectLocalSettingsURL(projectPath: projectPath))
    }

    private func moveAutoMemoryDirectoryToLocal() {
        guard let dir = rawProjectJSON["autoMemoryDirectory"] as? String else { return }
        saveLocalProjectField("autoMemoryDirectory", value: dir)
        saveProjectField("autoMemoryDirectory", value: nil)
        reloadRawJSON()
        autoMemoryDirectory = dir
    }

    private func parseCSV(_ text: String) -> [String]? {
        let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

    private func saveProjectEnv() {
        var dict: [String: String] = [:]
        for entry in envVars {
            let key = entry.key.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty { dict[key] = entry.value }
        }
        // Per-variable writes against what is on disk right now: only changed variables are
        // set, only deleted ones are removed, and variables this view never loaded stay put.
        let onDisk = (configManager.loadProjectRawJSON(projectPath: projectPath)["env"] as? [String: Any]) ?? [:]
        let previous = onDisk.compactMapValues { $0 as? String }
        let changed = dict.filter { previous[$0.key] != $0.value }
        let removed = previous.keys.filter { dict[$0] == nil }
        configManager.saveEnvChanges(set: changed, remove: Array(removed), to: projectSettingsURL)
    }

    // The sub-key writers below use dotted paths so keys this screen does not manage
    // (permissions.denyInsteadOfPrompting, sandbox.network, worktree.location, …) survive.

    private func saveProjectPermissions() {
        configManager.saveFields([
            (keyPath: "permissions.defaultMode", value: permDefaultMode != "default" ? permDefaultMode : nil),
            (keyPath: "permissions.allow", value: parseCSV(permAllow)),
            (keyPath: "permissions.deny", value: parseCSV(permDeny)),
            (keyPath: "permissions.ask", value: parseCSV(permAsk))
        ], to: projectSettingsURL)
    }

    private func saveProjectSandbox() {
        configManager.saveFields([
            (keyPath: "sandbox.enabled", value: sandboxEnabled ? true : nil),
            (keyPath: "sandbox.filesystem.allowWrite", value: parseCSV(sandboxAllowWrite)),
            (keyPath: "sandbox.filesystem.denyWrite", value: parseCSV(sandboxDenyWrite))
        ], to: projectSettingsURL)
    }

    private func saveProjectWorktree() {
        configManager.saveFields([
            (keyPath: "worktree.sparsePaths", value: parseCSV(worktreeSparsePaths)),
            (keyPath: "worktree.symlinkDirectories", value: parseCSV(worktreeSymlinkDirs))
        ], to: projectSettingsURL)
    }
}

// MARK: - Env Entry

private struct ProjectEnvEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}
