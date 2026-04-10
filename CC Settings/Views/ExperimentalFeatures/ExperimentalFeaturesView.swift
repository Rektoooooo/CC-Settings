import SwiftUI

struct ExperimentalFeaturesView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @Binding var scrollToSection: String?
    @State private var isSyncing = false

    private static var s: ClaudeSettings { ConfigurationManager.shared.settings }
    private static var env: [String: String] { s.env }

    // Thinking
    @State private var thinkingEnabled: Bool = s.alwaysThinkingEnabled ?? false
    @State private var thinkingBudget: Double = Double(s.thinkingBudgetTokens ?? 10000)

    // Agent Teams
    @State private var agentTeamsEnabled: Bool = env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] == "1"

    // Performance
    @State private var skipWebFetchPreflight: Bool = s.skipWebFetchPreflight ?? false
    @State private var disableNonEssentialCalls: Bool = env["DISABLE_NON_ESSENTIAL_MODEL_CALLS"] == "1"

    // Privacy
    @State private var disableTelemetry: Bool = env["DISABLE_TELEMETRY"] == "1"
    @State private var disableErrorReporting: Bool = env["DISABLE_ERROR_REPORTING"] == "1"
    @State private var disableAutoUpdater: Bool = env["DISABLE_AUTOUPDATER"] == "1"

    // Mode Control
    @State private var disableAutoMode: Bool = s.disableAutoMode == "disable"
    @State private var disableAllHooks: Bool = s.disableAllHooks ?? false

    // Sandbox (legacy)
    @State private var enableWeakerSandbox: Bool = s.enableWeakerSandbox ?? false
    @State private var unsandboxedCommands: String = (s.unsandboxedCommands ?? []).joined(separator: ", ")
    @State private var allowLocalBinding: Bool = s.allowLocalBinding ?? false
    @State private var allowAllUnixSockets: Bool = s.allowAllUnixSockets ?? false
    @State private var allowedDomains: String = (s.allowedDomains ?? []).joined(separator: ", ")

    // Sandbox (new nested)
    @State private var sandboxEnabled: Bool = s.sandbox?.enabled ?? false
    @State private var sandboxFailIfUnavailable: Bool = s.sandbox?.failIfUnavailable ?? false
    @State private var autoAllowBashIfSandboxed: Bool = s.sandbox?.autoAllowBashIfSandboxed ?? true
    @State private var enableWeakerNetworkIsolation: Bool = s.sandbox?.enableWeakerNetworkIsolation ?? false
    @State private var sandboxAllowWrite: String = (s.sandbox?.filesystem?.allowWrite ?? []).joined(separator: ", ")
    @State private var sandboxDenyWrite: String = (s.sandbox?.filesystem?.denyWrite ?? []).joined(separator: ", ")
    @State private var sandboxDenyRead: String = (s.sandbox?.filesystem?.denyRead ?? []).joined(separator: ", ")
    @State private var sandboxAllowRead: String = (s.sandbox?.filesystem?.allowRead ?? []).joined(separator: ", ")

    // Worktree
    @State private var worktreeSparsePaths: String = (s.worktree?.sparsePaths ?? []).joined(separator: ", ")
    @State private var worktreeSymlinkDirs: String = (s.worktree?.symlinkDirectories ?? []).joined(separator: ", ")

    // Spinner
    @State private var spinnerTipsEnabled: Bool = s.spinnerTipsEnabled ?? true
    @State private var spinnerVerbsMode: String = s.spinnerVerbsMode ?? "append"
    @State private var spinnerVerbs: String = (s.spinnerVerbs ?? []).joined(separator: ", ")
    @State private var customTips: String = (s.spinnerTipsOverride?.tips ?? s.customTips ?? []).joined(separator: ", ")
    @State private var excludeDefaultTips: Bool = s.spinnerTipsOverride?.excludeDefault ?? s.excludeDefaultTips ?? false

    // Status Line
    @State private var statusLineCommand: String = s.statusLine?.command ?? s.statusLineCommand ?? ""
    @State private var statusLinePadding: String = s.statusLine?.padding.map { String($0) } ?? ""

    var body: some View {
        ScrollViewReader { proxy in
        Form {
            // MARK: - Warning
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("These features are experimental and may change or be removed.")
                        .font(.subheadline)
                }
            }

            // MARK: - Thinking
            Section {
                Toggle("Extended Thinking", isOn: $thinkingEnabled)
                    .onChange(of: thinkingEnabled) { _, _ in saveThinking() }
                Text("Enable Claude to think more deeply before responding. Uses additional tokens.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if thinkingEnabled {
                    HStack {
                        Text("Budget")
                        Spacer()
                        Text("\(Int(thinkingBudget).formatted()) tokens")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }

                    Slider(value: $thinkingBudget, in: 1000...100000, step: 1000)
                        .onChange(of: thinkingBudget) { _, _ in saveThinking() }

                    HStack(spacing: 6) {
                        Circle()
                            .fill(budgetColor)
                            .frame(width: 8, height: 8)
                        Text(budgetLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(budgetColor)
                    }

                    HStack(spacing: 8) {
                        Text("Presets:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ForEach(["5K", "10K", "25K", "50K"], id: \.self) { preset in
                            Button(preset) {
                                thinkingBudget = presetValue(preset)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .font(.caption)
                        }
                    }

                    if thinkingBudget > 50000 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            Text("High budget may significantly increase API costs and response times.")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            } header: {
                Text("Thinking")
            }.id("thinking")

            // MARK: - Agent Teams
            Section {
                Toggle("Enable Agent Teams", isOn: $agentTeamsEnabled)
                    .onChange(of: agentTeamsEnabled) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS", value: agentTeamsEnabled ? "1" : nil)
                    }
                Text("Allow multiple Claude agents to work together on tasks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Agent Teams")
            }.id("agent-teams")

            // MARK: - Performance
            Section {
                Toggle("Skip WebFetch Preflight", isOn: $skipWebFetchPreflight)
                    .onChange(of: skipWebFetchPreflight) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("skipWebFetchPreflight", value: skipWebFetchPreflight ? true : nil)
                    }
                Text("Skip preflight validation before fetching web content.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Non-Essential Model Calls", isOn: $disableNonEssentialCalls)
                    .onChange(of: disableNonEssentialCalls) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("env.DISABLE_NON_ESSENTIAL_MODEL_CALLS", value: disableNonEssentialCalls ? "1" : nil)
                    }
                Text("Reduce API usage by disabling non-essential model calls.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Performance")
            }.id("performance")

            // MARK: - Privacy & Telemetry
            Section {
                Toggle("Disable Telemetry", isOn: $disableTelemetry)
                    .onChange(of: disableTelemetry) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("env.DISABLE_TELEMETRY", value: disableTelemetry ? "1" : nil)
                    }
                Text("Disable all telemetry data collection.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Error Reporting", isOn: $disableErrorReporting)
                    .onChange(of: disableErrorReporting) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("env.DISABLE_ERROR_REPORTING", value: disableErrorReporting ? "1" : nil)
                    }
                Text("Disable automatic error reporting to Anthropic.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Auto-Updater", isOn: $disableAutoUpdater)
                    .onChange(of: disableAutoUpdater) { _, _ in
                        guard !isSyncing else { return }
                        configManager.saveField("env.DISABLE_AUTOUPDATER", value: disableAutoUpdater ? "1" : nil)
                    }
                Text("Prevent Claude Code from updating automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Privacy & Updates")
            }.id("privacy")

            // MARK: - Mode Control
            Section {
                FeatureToggle(
                    title: "Disable Auto Mode",
                    description: "Prevent auto mode activation",
                    isOn: $disableAutoMode,
                    onChange: {
                        guard !isSyncing else { return }
                        configManager.saveField("disableAutoMode", value: disableAutoMode ? "disable" : nil)
                    }
                )

                FeatureToggle(
                    title: "Disable All Hooks",
                    description: "Kill switch for all hooks and custom status line",
                    isOn: $disableAllHooks,
                    onChange: {
                        guard !isSyncing else { return }
                        configManager.saveField("disableAllHooks", value: disableAllHooks ? true : nil)
                    }
                )
            } header: {
                Text("Mode Control")
            }.id("mode-control")

            // MARK: - Sandbox
            Section {
                Toggle("Enable Sandbox", isOn: $sandboxEnabled)
                    .onChange(of: sandboxEnabled) { _, _ in saveSandbox() }
                Text("Enable the sandbox for command execution.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Fail If Unavailable", isOn: $sandboxFailIfUnavailable)
                    .onChange(of: sandboxFailIfUnavailable) { _, _ in saveSandbox() }
                Text("Fail instead of falling back when sandbox is unavailable.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Auto-Allow Bash When Sandboxed", isOn: $autoAllowBashIfSandboxed)
                    .onChange(of: autoAllowBashIfSandboxed) { _, _ in saveSandbox() }
                Text("Automatically allow bash commands when running inside the sandbox.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Weaker Network Isolation", isOn: $enableWeakerNetworkIsolation)
                    .onChange(of: enableWeakerNetworkIsolation) { _, _ in saveSandbox() }
                Text("Allow more permissive network access from the sandbox.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Filesystem Rules") {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Allow Write", text: $sandboxAllowWrite, prompt: Text("/tmp, /var/folders"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                            .onSubmit { saveSandbox() }
                        Text("Comma-separated paths allowed for writing.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Deny Write", text: $sandboxDenyWrite, prompt: Text("/etc, /usr"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                            .onSubmit { saveSandbox() }
                        Text("Comma-separated paths denied for writing.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Deny Read", text: $sandboxDenyRead, prompt: Text("/private, /secrets"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                            .onSubmit { saveSandbox() }
                        Text("Comma-separated paths denied for reading.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Allow Read", text: $sandboxAllowRead, prompt: Text("/usr/local, /opt"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                            .onSubmit { saveSandbox() }
                        Text("Comma-separated paths allowed for reading.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Toggle("Enable Weaker Sandbox", isOn: $enableWeakerSandbox)
                    .onChange(of: enableWeakerSandbox) { _, _ in saveLegacySandbox() }
                Text("Use a weaker sandbox for Docker or unprivileged environments.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Unsandboxed Commands", text: $unsandboxedCommands, prompt: Text("git, docker, npm"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...3)
                    .onSubmit { saveLegacySandbox() }
                Text("Comma-separated commands that should never run in the sandbox.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Network") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Allow Local Binding", isOn: $allowLocalBinding)
                            .onChange(of: allowLocalBinding) { _, _ in saveLegacySandbox() }
                        Text("Allow binding to localhost (macOS).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Allow All Unix Sockets", isOn: $allowAllUnixSockets)
                            .onChange(of: allowAllUnixSockets) { _, _ in saveLegacySandbox() }
                        Text("Allow connections to all Unix sockets.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Allowed Domains", text: $allowedDomains, prompt: Text("*.github.com, api.example.com"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                            .onSubmit { saveLegacySandbox() }
                        Text("Comma-separated domains allowed for outbound traffic (supports wildcards).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Sandbox")
            }.id("sandbox")

            // MARK: - Worktree
            Section {
                TextField("Sparse Checkout Paths", text: $worktreeSparsePaths, prompt: Text("src, docs, tests"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...3)
                    .onSubmit { saveWorktree() }
                Text("Comma-separated paths for sparse checkout in worktrees.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Symlink Directories", text: $worktreeSymlinkDirs, prompt: Text("node_modules, .venv"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...3)
                    .onSubmit { saveWorktree() }
                Text("Comma-separated directories to symlink in worktrees.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Worktree")
            }.id("worktree")

            // MARK: - Spinner
            Section {
                Toggle("Show Spinner Tips", isOn: $spinnerTipsEnabled)
                    .onChange(of: spinnerTipsEnabled) { _, _ in saveSpinner() }

                Picker("Custom Verbs Mode", selection: $spinnerVerbsMode) {
                    Text("Append to defaults").tag("append")
                    Text("Replace defaults").tag("replace")
                }
                .onChange(of: spinnerVerbsMode) { _, _ in saveSpinner() }

                TextField("Custom Verbs", text: $spinnerVerbs, prompt: Text("Pondering, Crafting, Brewing"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit { saveSpinner() }
                Text("Comma-separated custom action verbs for the spinner.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Exclude Default Tips", isOn: $excludeDefaultTips)
                    .onChange(of: excludeDefaultTips) { _, _ in saveSpinner() }

                TextField("Custom Tips", text: $customTips, prompt: Text("Tip 1, Tip 2, Tip 3"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit { saveSpinner() }
                Text("Comma-separated custom tip strings shown in the spinner.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Spinner Customization")
            }.id("spinner")

            // MARK: - Status Line
            Section {
                TextField("Command", text: $statusLineCommand, prompt: Text("~/.claude/statusline.sh"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: statusLineCommand) { _, _ in saveStatusLine() }

                TextField("Padding", text: $statusLinePadding, prompt: Text("0"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onChange(of: statusLinePadding) { _, _ in saveStatusLine() }

                Text("Path to a script or command that generates the status line. Padding adds extra blank lines.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Status Line")
            }.id("status-line")
        }
        .formStyle(.grouped)
        .onDisappear {
            guard !isSyncing else { return }
            saveSandbox()
            saveLegacySandbox()
            saveWorktree()
            saveSpinner()
            saveStatusLine()
        }
        .onAppear {
            isSyncing = true
            loadSettings()
            DispatchQueue.main.async { isSyncing = false }
        }
        .onChange(of: configManager.settings) {
            isSyncing = true
            loadSettings()
            DispatchQueue.main.async { isSyncing = false }
        }
        .onChange(of: scrollToSection) {
            if let target = scrollToSection {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation { proxy.scrollTo(target, anchor: .top) }
                    scrollToSection = nil
                }
            }
        }
        } // ScrollViewReader
    }

    // MARK: - Budget Helpers

    private var budgetColor: Color {
        switch Int(thinkingBudget) {
        case ...10000: return .green
        case ...25000: return .themeAccent
        case ...50000: return .orange
        default: return .red
        }
    }

    private var budgetLabel: String {
        switch Int(thinkingBudget) {
        case ...10000: return "Light"
        case ...25000: return "Standard"
        case ...50000: return "Deep"
        default: return "Maximum"
        }
    }

    private func presetValue(_ preset: String) -> Double {
        switch preset {
        case "5K": return 5000
        case "10K": return 10000
        case "25K": return 25000
        case "50K": return 50000
        default: return 10000
        }
    }

    // MARK: - Data Sync

    private func loadSettings() {
        let s = configManager.settings
        let env = s.env

        // Thinking
        thinkingEnabled = s.alwaysThinkingEnabled ?? false
        thinkingBudget = Double(s.thinkingBudgetTokens ?? 10000)

        // Agent Teams
        agentTeamsEnabled = env["CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS"] == "1"

        // Performance
        skipWebFetchPreflight = s.skipWebFetchPreflight ?? false
        disableNonEssentialCalls = env["DISABLE_NON_ESSENTIAL_MODEL_CALLS"] == "1"

        // Privacy
        disableTelemetry = env["DISABLE_TELEMETRY"] == "1"
        disableErrorReporting = env["DISABLE_ERROR_REPORTING"] == "1"
        disableAutoUpdater = env["DISABLE_AUTOUPDATER"] == "1"

        // Mode Control
        disableAutoMode = s.disableAutoMode == "disable"
        disableAllHooks = s.disableAllHooks ?? false

        // Sandbox (legacy)
        enableWeakerSandbox = s.enableWeakerSandbox ?? false
        unsandboxedCommands = (s.unsandboxedCommands ?? []).joined(separator: ", ")
        allowLocalBinding = s.allowLocalBinding ?? false
        allowAllUnixSockets = s.allowAllUnixSockets ?? false
        allowedDomains = (s.allowedDomains ?? []).joined(separator: ", ")

        // Sandbox (nested)
        sandboxEnabled = s.sandbox?.enabled ?? false
        sandboxFailIfUnavailable = s.sandbox?.failIfUnavailable ?? false
        autoAllowBashIfSandboxed = s.sandbox?.autoAllowBashIfSandboxed ?? true
        enableWeakerNetworkIsolation = s.sandbox?.enableWeakerNetworkIsolation ?? false
        sandboxAllowWrite = (s.sandbox?.filesystem?.allowWrite ?? []).joined(separator: ", ")
        sandboxDenyWrite = (s.sandbox?.filesystem?.denyWrite ?? []).joined(separator: ", ")
        sandboxDenyRead = (s.sandbox?.filesystem?.denyRead ?? []).joined(separator: ", ")
        sandboxAllowRead = (s.sandbox?.filesystem?.allowRead ?? []).joined(separator: ", ")

        // Worktree
        worktreeSparsePaths = (s.worktree?.sparsePaths ?? []).joined(separator: ", ")
        worktreeSymlinkDirs = (s.worktree?.symlinkDirectories ?? []).joined(separator: ", ")

        // Spinner — prefer nested overrides, fall back to flat fields
        spinnerTipsEnabled = s.spinnerTipsEnabled ?? true
        spinnerVerbsMode = s.spinnerVerbsMode ?? "append"
        spinnerVerbs = (s.spinnerVerbs ?? []).joined(separator: ", ")
        if let tipsOverride = s.spinnerTipsOverride {
            customTips = (tipsOverride.tips ?? []).joined(separator: ", ")
            excludeDefaultTips = tipsOverride.excludeDefault ?? false
        } else {
            customTips = (s.customTips ?? []).joined(separator: ", ")
            excludeDefaultTips = s.excludeDefaultTips ?? false
        }

        // Status line
        // Status line: prefer nested object, fall back to legacy flat field
        if let sl = s.statusLine {
            statusLineCommand = sl.command ?? ""
            statusLinePadding = sl.padding.map { String($0) } ?? ""
        } else {
            statusLineCommand = s.statusLineCommand ?? ""
            statusLinePadding = ""
        }
    }

    // MARK: - Per-Field Save Helpers

    private func saveThinking() {
        guard !isSyncing else { return }
        configManager.saveFields([
            (keyPath: "alwaysThinkingEnabled", value: thinkingEnabled ? true : nil),
            (keyPath: "thinkingBudgetTokens", value: thinkingEnabled ? Int(thinkingBudget) : nil)
        ])
    }

    private func saveSandbox() {
        guard !isSyncing else { return }
        var sb: [String: Any] = [:]
        if sandboxEnabled { sb["enabled"] = true }
        if sandboxFailIfUnavailable { sb["failIfUnavailable"] = true }
        if !autoAllowBashIfSandboxed { sb["autoAllowBashIfSandboxed"] = false }
        if enableWeakerNetworkIsolation { sb["enableWeakerNetworkIsolation"] = true }

        var fs: [String: Any] = [:]
        if let v = parseCSV(sandboxAllowWrite) { fs["allowWrite"] = v }
        if let v = parseCSV(sandboxDenyWrite) { fs["denyWrite"] = v }
        if let v = parseCSV(sandboxDenyRead) { fs["denyRead"] = v }
        if let v = parseCSV(sandboxAllowRead) { fs["allowRead"] = v }
        if !fs.isEmpty { sb["filesystem"] = fs }

        configManager.saveField("sandbox", value: sb.isEmpty ? nil : sb)
    }

    private func saveLegacySandbox() {
        guard !isSyncing else { return }
        configManager.saveFields([
            (keyPath: "enableWeakerSandbox", value: enableWeakerSandbox ? true : nil),
            (keyPath: "allowLocalBinding", value: allowLocalBinding ? true : nil),
            (keyPath: "allowAllUnixSockets", value: allowAllUnixSockets ? true : nil),
            (keyPath: "unsandboxedCommands", value: parseCSV(unsandboxedCommands)),
            (keyPath: "allowedDomains", value: parseCSV(allowedDomains))
        ])
    }

    private func saveWorktree() {
        guard !isSyncing else { return }
        var wt: [String: Any] = [:]
        if let v = parseCSV(worktreeSparsePaths) { wt["sparsePaths"] = v }
        if let v = parseCSV(worktreeSymlinkDirs) { wt["symlinkDirectories"] = v }
        configManager.saveField("worktree", value: wt.isEmpty ? nil : wt)
    }

    private func saveSpinner() {
        guard !isSyncing else { return }
        var fields: [(keyPath: String, value: Any?)] = [
            (keyPath: "spinnerTipsEnabled", value: spinnerTipsEnabled ? nil : false),
            (keyPath: "spinnerVerbsMode", value: spinnerVerbsMode != "append" ? spinnerVerbsMode : nil),
            (keyPath: "spinnerVerbs", value: parseCSV(spinnerVerbs)),
            (keyPath: "customTips", value: parseCSV(customTips)),
            (keyPath: "excludeDefaultTips", value: excludeDefaultTips ? true : nil)
        ]
        let tips = parseCSV(customTips)
        if tips != nil || excludeDefaultTips {
            var overrideDict: [String: Any] = [:]
            if excludeDefaultTips { overrideDict["excludeDefault"] = true }
            if let t = tips { overrideDict["tips"] = t }
            fields.append((keyPath: "spinnerTipsOverride", value: overrideDict))
        } else {
            fields.append((keyPath: "spinnerTipsOverride", value: nil))
        }
        configManager.saveFields(fields)
    }

    private func saveStatusLine() {
        guard !isSyncing else { return }
        if statusLineCommand.isEmpty {
            configManager.saveFields([
                (keyPath: "statusLine", value: nil),
                (keyPath: "statusLineCommand", value: nil)
            ])
        } else {
            var dict: [String: Any] = ["type": "command", "command": statusLineCommand]
            if let padding = Int(statusLinePadding) { dict["padding"] = padding }
            configManager.saveFields([
                (keyPath: "statusLine", value: dict),
                (keyPath: "statusLineCommand", value: nil)
            ])
        }
    }

    private func parseCSV(_ text: String) -> [String]? {
        let items = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return items.isEmpty ? nil : items
    }

}

// MARK: - Reusable Components (kept for backward compat)

struct WarningBanner: View {
    let message: String
    let level: WarningLevel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: level.icon)
                .foregroundColor(level.color)
            Text(message)
                .font(.subheadline)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassBanner(tint: level.color)
    }
}

enum WarningLevel {
    case info, caution, danger

    var icon: String {
        switch self {
        case .info: return "info.circle.fill"
        case .caution: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        }
    }

    var color: Color {
        switch self {
        case .info: return .themeAccent
        case .caution: return .orange
        case .danger: return .red
        }
    }
}

struct FeatureToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    var showWarning: Bool = false
    var onChange: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .onChange(of: isOn) { _, _ in onChange?() }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(title).fontWeight(.medium)
                    if showWarning {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct ThinkingBudgetSlider: View {
    @Binding var budget: Double
    var onChange: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Thinking Budget").font(.subheadline)
                Spacer()
                Text("\(Int(budget).formatted()) tokens")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $budget, in: 1000...100000, step: 1000)
                .onChange(of: budget) { _, _ in onChange?() }
        }
        .padding(.leading, 44)
    }
}
