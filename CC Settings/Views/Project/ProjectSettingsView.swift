import SwiftUI

struct ProjectSettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    let projectId: String

    // Resolved project path
    @State private var projectPath: String = ""
    @State private var rawProjectJSON: [String: Any] = [:]
    @State private var isLoaded = false

    // Model
    @State private var model: String = "sonnet"
    @State private var effortLevel: String = ""
    @State private var outputStyle: String = ""

    // Behavior
    @State private var respectGitignore: Bool = true
    @State private var includeGitInstructions: Bool = true
    @State private var defaultShell: String = "bash"
    @State private var autoCompactEnabled: Bool = true
    @State private var autoCompactInstructions: String = ""
    @State private var plansDirectory: String = ""

    // Memory
    @State private var autoMemoryEnabled: Bool = false
    @State private var autoMemoryDirectory: String = ""

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
        projectPath.split(separator: "/").last.map(String.init) ?? projectId
    }

    var body: some View {
        Form {
            headerSection
            modelSection
            behaviorSection
            memorySection
            environmentSection
            permissionsSection
            sandboxSection
            worktreeSection
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
                    Text(projectPath)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
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
                        saveProjectField("model", value: model)
                    } else {
                        saveProjectField("model", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                HierarchicalModelPicker(selectedModelId: $model)
                    .onChange(of: model) {
                        guard isLoaded, isOverridden("model") else { return }
                        saveProjectField("model", value: model)
                    }
            }

            OverridableSettingRow(
                title: "Effort Level",
                globalSummary: configManager.settings.effortLevel ?? "normal",
                isOverridden: isOverridden("effortLevel"),
                onToggleOverride: { enabled in
                    if enabled {
                        effortLevel = configManager.settings.effortLevel ?? ""
                        saveProjectField("effortLevel", value: effortLevel.isEmpty ? nil : effortLevel)
                    } else {
                        saveProjectField("effortLevel", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                Picker("", selection: $effortLevel) {
                    Text("Normal").tag("")
                    Text("Auto").tag("auto")
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
                    Text("Xhigh").tag("xhigh")
                    Text("Max").tag("max")
                }
                .pickerStyle(.segmented)
                .onChange(of: effortLevel) {
                    guard isLoaded, isOverridden("effortLevel") else { return }
                    saveProjectField("effortLevel", value: effortLevel.isEmpty ? nil : effortLevel)
                }
            }

            OverridableSettingRow(
                title: "Output Style",
                globalSummary: configManager.settings.outputStyle ?? "default",
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
                    .onSubmit {
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
                globalSummary: configManager.settings.defaultShell ?? "bash",
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
                globalSummary: configManager.settings.plansDirectory ?? "default",
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
                    .onSubmit {
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
                globalSummary: (configManager.settings.autoMemoryEnabled ?? false) ? "Enabled" : "Disabled",
                isOverridden: isOverridden("autoMemoryEnabled"),
                onToggleOverride: { enabled in
                    if enabled {
                        autoMemoryEnabled = configManager.settings.autoMemoryEnabled ?? false
                        saveProjectField("autoMemoryEnabled", value: autoMemoryEnabled ? true : nil)
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
                        saveProjectField("autoMemoryEnabled", value: autoMemoryEnabled ? true : nil)
                    }
            }

            OverridableSettingRow(
                title: "Memory Directory",
                globalSummary: configManager.settings.autoMemoryDirectory ?? "default",
                isOverridden: isOverridden("autoMemoryDirectory"),
                onToggleOverride: { enabled in
                    if enabled {
                        autoMemoryDirectory = configManager.settings.autoMemoryDirectory ?? ""
                        saveProjectField("autoMemoryDirectory", value: autoMemoryDirectory.isEmpty ? nil : autoMemoryDirectory)
                    } else {
                        saveProjectField("autoMemoryDirectory", value: nil)
                    }
                    reloadRawJSON()
                }
            ) {
                TextField("Memory directory", text: $autoMemoryDirectory)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        guard isOverridden("autoMemoryDirectory") else { return }
                        let trimmed = autoMemoryDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                        saveProjectField("autoMemoryDirectory", value: trimmed.isEmpty ? nil : trimmed)
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
                        Text("Default").tag("default")
                        Text("Allow All").tag("allowAll")
                        Text("Deny All").tag("denyAll")
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
                            .onSubmit { saveProjectPermissions() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deny").font(.caption.bold())
                        TextField("Edit, Bash(rm *)", text: $permDeny)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { saveProjectPermissions() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ask").font(.caption.bold())
                        TextField("Edit, Write", text: $permAsk)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { saveProjectPermissions() }
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
                        .onSubmit { saveProjectSandbox() }

                    TextField("Deny Write (comma-separated)", text: $sandboxDenyWrite)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { saveProjectSandbox() }
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
                            .onSubmit { saveProjectWorktree() }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Symlink Directories").font(.caption.bold())
                        TextField("node_modules, .venv", text: $worktreeSymlinkDirs)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .onSubmit { saveProjectWorktree() }
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
        outputStyle = rawProjectJSON.keys.contains("outputStyle") ? (ps.outputStyle ?? "") : (configManager.settings.outputStyle ?? "")

        // Behavior
        respectGitignore = rawProjectJSON.keys.contains("respectGitignore") ? (ps.respectGitignore ?? true) : (configManager.settings.respectGitignore ?? true)
        includeGitInstructions = rawProjectJSON.keys.contains("includeGitInstructions") ? (ps.includeGitInstructions ?? true) : (configManager.settings.includeGitInstructions ?? true)
        defaultShell = rawProjectJSON.keys.contains("defaultShell") ? (ps.defaultShell ?? "bash") : (configManager.settings.defaultShell ?? "bash")
        plansDirectory = rawProjectJSON.keys.contains("plansDirectory") ? (ps.plansDirectory ?? "") : (configManager.settings.plansDirectory ?? "")

        // Memory
        autoMemoryEnabled = rawProjectJSON.keys.contains("autoMemoryEnabled") ? (ps.autoMemoryEnabled ?? false) : (configManager.settings.autoMemoryEnabled ?? false)
        autoMemoryDirectory = rawProjectJSON.keys.contains("autoMemoryDirectory") ? (ps.autoMemoryDirectory ?? "") : (configManager.settings.autoMemoryDirectory ?? "")

        // Environment
        if let envDict = rawProjectJSON["env"] as? [String: String] {
            envVars = envDict.sorted(by: { $0.key < $1.key }).map { ProjectEnvEntry(key: $0.key, value: $0.value) }
        } else {
            envVars = []
        }

        // Permissions
        if let permsDict = rawProjectJSON["permissions"] as? [String: Any] {
            permDefaultMode = permsDict["defaultMode"] as? String ?? "default"
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
        configManager.saveField(keyPath, value: value, to: projectSettingsURL)
    }

    private func reloadRawJSON() {
        rawProjectJSON = configManager.loadProjectRawJSON(projectPath: projectPath)
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
        saveProjectField("env", value: dict.isEmpty ? nil : dict)
    }

    private func saveProjectPermissions() {
        var dict: [String: Any] = [:]
        if permDefaultMode != "default" { dict["defaultMode"] = permDefaultMode }
        if let allow = parseCSV(permAllow) { dict["allow"] = allow }
        if let deny = parseCSV(permDeny) { dict["deny"] = deny }
        if let ask = parseCSV(permAsk) { dict["ask"] = ask }
        saveProjectField("permissions", value: dict.isEmpty ? nil : dict)
    }

    private func saveProjectSandbox() {
        var dict: [String: Any] = [:]
        if sandboxEnabled { dict["enabled"] = true }
        var fs: [String: Any] = [:]
        if let v = parseCSV(sandboxAllowWrite) { fs["allowWrite"] = v }
        if let v = parseCSV(sandboxDenyWrite) { fs["denyWrite"] = v }
        if !fs.isEmpty { dict["filesystem"] = fs }
        saveProjectField("sandbox", value: dict.isEmpty ? nil : dict)
    }

    private func saveProjectWorktree() {
        var dict: [String: Any] = [:]
        if let v = parseCSV(worktreeSparsePaths) { dict["sparsePaths"] = v }
        if let v = parseCSV(worktreeSymlinkDirs) { dict["symlinkDirectories"] = v }
        saveProjectField("worktree", value: dict.isEmpty ? nil : dict)
    }
}

// MARK: - Env Entry

private struct ProjectEnvEntry: Identifiable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}
