import SwiftUI

// MARK: - HUD Config Model

/// Represents the claude-hud plugin configuration at ~/.claude/plugins/claude-hud/config.json
/// The plugin expects usage fields inside `display`, and `autocompactBuffer` as "enabled"/"disabled".
struct HUDConfig: Codable, Equatable {
    var display: HUDDisplayConfig
    var lineLayout: String
    var showSeparators: Bool
    var pathLevels: Int
    var gitStatus: HUDGitConfig

    init() {
        display = HUDDisplayConfig()
        lineLayout = "expanded"
        showSeparators = true
        pathLevels = 2
        gitStatus = HUDGitConfig()
    }

    struct HUDDisplayConfig: Codable, Equatable {
        var showModel: Bool = true
        var showContextBar: Bool = true
        var contextValue: String = "percent"
        var showTokenBreakdown: Bool = true
        var showConfigCounts: Bool = false
        var showDuration: Bool = false
        var showSpeed: Bool = false
        var autocompactBuffer: String = "enabled"
        var showTools: Bool = true
        var showAgents: Bool = true
        var showTodos: Bool = true
        var showUsage: Bool = true
        var usageBarEnabled: Bool = true
        var usageThreshold: Int = 0
        var sevenDayThreshold: Int = 0
        var environmentThreshold: Int = 0
    }

    struct HUDGitConfig: Codable, Equatable {
        var enabled: Bool = true
        var showDirty: Bool = true
        var showAheadBehind: Bool = true
        var showFileStats: Bool = false
    }
}

// MARK: - Installed Plugins Model

private struct InstalledPlugins: Codable {
    var version: Int?
    var plugins: [String: [PluginEntry]]?

    struct PluginEntry: Codable {
        var version: String?
        var installPath: String?
    }
}

// MARK: - HUDView

struct HUDView: View {
    @State private var config = HUDConfig()
    @State private var isInstalled = false
    @State private var installedVersion: String?
    @State private var hasLoadedOnce = false

    /// Hardcoded path matching the claude-hud plugin's expected config location.
    /// This is the canonical path used by the plugin itself; deriving it from install
    /// metadata would add complexity without benefit since the plugin always reads from here.
    private let configURL: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/claude-hud/config.json")
    }()

    var body: some View {
        Form {
            statusBannerSection
            previewSection
            layoutSection
            displaySection
            usageSection
            activitySection
            gitStatusSection
            presetsSection
            creditSection
        }
        .formStyle(.grouped)
        .navigationTitle("HUD")
        .onAppear {
            checkInstallation()
            loadConfig()
        }
    }

    // MARK: - Status Banner

    private var statusBannerSection: some View {
        Section {
            if isInstalled {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("claude-hud is installed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let version = installedVersion {
                            Text("Version \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("claude-hud is not installed")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Install with: /install-plugin claude-hud@claude-hud")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    // MARK: - Live Preview

    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 0) {
                Text(buildPreview())
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineSpacing(2)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        } header: {
            Text("Preview")
        } footer: {
            Text("Live preview of how the HUD will appear in Claude Code.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Layout Section

    private var layoutSection: some View {
        Section {
            Picker("Line Layout", selection: $config.lineLayout) {
                Text("Expanded").tag("expanded")
                Text("Compact").tag("compact")
            }
            .onChange(of: config.lineLayout) { _, _ in saveConfig() }

            if config.lineLayout == "compact" {
                Toggle("Show Separators", isOn: $config.showSeparators)
                    .onChange(of: config.showSeparators) { _, _ in saveConfig() }
            }

            Picker("Path Levels", selection: $config.pathLevels) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .onChange(of: config.pathLevels) { _, _ in saveConfig() }
        } header: {
            Text("Layout")
        } footer: {
            Text("Controls line density and project path display depth.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Display Section

    private var displaySection: some View {
        Section {
            Toggle("Show Model Name", isOn: $config.display.showModel)
                .onChange(of: config.display.showModel) { _, _ in saveConfig() }

            Toggle("Show Context Bar", isOn: $config.display.showContextBar)
                .onChange(of: config.display.showContextBar) { _, _ in saveConfig() }

            if config.display.showContextBar {
                Picker("Context Value", selection: $config.display.contextValue) {
                    Text("Percent").tag("percent")
                    Text("Tokens").tag("tokens")
                }
                .onChange(of: config.display.contextValue) { _, _ in saveConfig() }

                Toggle("Token Breakdown at 85%+", isOn: $config.display.showTokenBreakdown)
                    .onChange(of: config.display.showTokenBreakdown) { _, _ in saveConfig() }
            }

            Toggle("Show Config Counts", isOn: $config.display.showConfigCounts)
                .onChange(of: config.display.showConfigCounts) { _, _ in saveConfig() }

            Toggle("Show Session Duration", isOn: $config.display.showDuration)
                .onChange(of: config.display.showDuration) { _, _ in saveConfig() }

            Toggle("Show Output Speed", isOn: $config.display.showSpeed)
                .onChange(of: config.display.showSpeed) { _, _ in saveConfig() }

            Picker("Auto-Compact Buffer", selection: $config.display.autocompactBuffer) {
                Text("Enabled").tag("enabled")
                Text("Disabled").tag("disabled")
            }
            .onChange(of: config.display.autocompactBuffer) { _, _ in saveConfig() }
        } header: {
            Text("Display")
        } footer: {
            Text("Controls which information appears on the status line.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Usage Section

    private var usageSection: some View {
        Section {
            Toggle("Show Usage Rate Limits", isOn: $config.display.showUsage)
                .onChange(of: config.display.showUsage) { _, _ in saveConfig() }

            if config.display.showUsage {
                Toggle("Visual Bar", isOn: $config.display.usageBarEnabled)
                    .onChange(of: config.display.usageBarEnabled) { _, _ in saveConfig() }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("5-Hour Threshold")
                        Spacer()
                        Text("\(config.display.usageThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.usageThreshold) },
                            set: { config.display.usageThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.usageThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("7-Day Threshold")
                        Spacer()
                        Text("\(config.display.sevenDayThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.sevenDayThreshold) },
                            set: { config.display.sevenDayThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.sevenDayThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Environment Threshold")
                        Spacer()
                        Text("\(config.display.environmentThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.display.environmentThreshold) },
                            set: { config.display.environmentThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.display.environmentThreshold) { _, _ in saveConfig() }
                }
            }
        } header: {
            Text("Usage")
        } footer: {
            Text("Rate limit display and warning thresholds.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Activity Lines Section

    private var activitySection: some View {
        Section {
            Toggle("Show Tool Activity", isOn: $config.display.showTools)
                .onChange(of: config.display.showTools) { _, _ in saveConfig() }

            Toggle("Show Agent Status", isOn: $config.display.showAgents)
                .onChange(of: config.display.showAgents) { _, _ in saveConfig() }

            Toggle("Show Todo Progress", isOn: $config.display.showTodos)
                .onChange(of: config.display.showTodos) { _, _ in saveConfig() }
        } header: {
            Text("Activity Lines")
        } footer: {
            Text("Real-time tool, agent, and task progress indicators.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Git Status Section

    private var gitStatusSection: some View {
        Section {
            Toggle("Show Git Branch", isOn: $config.gitStatus.enabled)
                .onChange(of: config.gitStatus.enabled) { _, _ in saveConfig() }

            if config.gitStatus.enabled {
                Toggle("Show Dirty Indicator", isOn: $config.gitStatus.showDirty)
                    .onChange(of: config.gitStatus.showDirty) { _, _ in saveConfig() }

                Toggle("Show Ahead/Behind", isOn: $config.gitStatus.showAheadBehind)
                    .onChange(of: config.gitStatus.showAheadBehind) { _, _ in saveConfig() }

                Toggle("Show File Stats", isOn: $config.gitStatus.showFileStats)
                    .onChange(of: config.gitStatus.showFileStats) { _, _ in saveConfig() }
            }
        } header: {
            Text("Git Status")
        } footer: {
            Text("Git branch, dirty state, and file change information.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Presets Section

    private var presetsSection: some View {
        Section {
            HStack(spacing: 12) {
                presetButton("Full", icon: "square.grid.3x3.fill") {
                    applyFullPreset()
                }
                presetButton("Essential", icon: "star.fill") {
                    applyEssentialPreset()
                }
                presetButton("Minimal", icon: "minus.circle") {
                    applyMinimalPreset()
                }
            }
        } header: {
            Text("Presets")
        } footer: {
            Text("Quick-apply a preset configuration. Full enables everything, Essential shows activity + git + duration, Minimal shows only core defaults.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private func presetButton(_ label: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }

    // MARK: - Preview Builder

    private func buildPreview() -> String {
        let isExpanded = config.lineLayout == "expanded"
        var lines: [String] = []

        // --- Build git suffix ---
        var gitSuffix = ""
        if config.gitStatus.enabled {
            var insideParens = "main"
            if config.gitStatus.showDirty { insideParens += "*" }
            if config.gitStatus.showFileStats { insideParens += " ?1" }
            gitSuffix = " git:(\(insideParens))"
            if config.gitStatus.showAheadBehind {
                gitSuffix += " \u{2191}2 \u{2193}1"
            }
        }

        if isExpanded {
            // Line 1: [Model | Budget] | project-name git:(main* ?1) ↑2 ↓1
            var headerLine = ""
            if config.display.showModel {
                headerLine += "[Opus 4.6 | Max] | "
            }
            headerLine += "my-project\(gitSuffix)"
            lines.append(headerLine)

            // Line 2: Context + Usage bars combined on one line
            var barParts: [String] = []
            if config.display.showContextBar {
                if config.display.contextValue == "percent" {
                    barParts.append("Context \u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  28%")
                } else {
                    barParts.append("Context 28k/100k")
                }
            }
            if config.display.showUsage {
                if config.display.usageBarEnabled {
                    barParts.append("Usage \u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  18% (3h 39m / 5h)")
                    barParts.append("\u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}  42% (1h 25m / 7d)")
                } else {
                    barParts.append("Usage 18% (3h 39m / 5h)")
                    barParts.append("42% (1h 25m / 7d)")
                }
            }
            if !barParts.isEmpty {
                lines.append(barParts.joined(separator: " | "))
            }

            // Config counts (optional)
            if config.display.showConfigCounts {
                lines.append("1 CLAUDE.md | 2 MCPs")
            }

            // Duration + speed extras (optional)
            var extras: [String] = []
            if config.display.showDuration { extras.append("\u{23F1} 58m") }
            if config.display.showSpeed { extras.append("out: 85 tok/s") }
            if !extras.isEmpty {
                lines.append(extras.joined(separator: " | "))
            }
        } else {
            // Compact: single line with all header info
            var parts: [String] = []
            let sep = config.showSeparators ? " | " : "  "

            if config.display.showModel {
                parts.append("[Opus 4.6 | Max]")
            }

            if config.display.showContextBar {
                if config.display.contextValue == "percent" {
                    parts.append("\u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 28%")
                } else {
                    parts.append("28k/100k")
                }
            }

            if config.display.showUsage {
                if config.display.usageBarEnabled {
                    parts.append("Usage \u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 18%")
                } else {
                    parts.append("Usage 18%")
                }
            }

            parts.append("my-project\(gitSuffix)")

            if config.display.showConfigCounts {
                parts.append("1 CLAUDE.md | 2 MCPs")
            }

            if config.display.showDuration { parts.append("\u{23F1} 58m") }
            if config.display.showSpeed { parts.append("out: 85 tok/s") }

            if !parts.isEmpty {
                lines.append(parts.joined(separator: sep))
            }
        }

        // Separator between header and activity
        let hasActivity = config.display.showTools || config.display.showAgents || config.display.showTodos
        if config.showSeparators && hasActivity && !lines.isEmpty {
            lines.append(String(repeating: "\u{2500}", count: 35))
        }

        // Activity lines (always separate lines in both modes)
        if config.display.showTools {
            lines.append("\u{25D0} Edit: auth.ts | \u{2713} Bash \u{00D7}10 | \u{2713} Read \u{00D7}3 | \u{2713} Write \u{00D7}2")
        }

        if config.display.showAgents {
            lines.append("\u{2713} Explore: Explore codebase patterns (1m 14s)")
        }

        if config.display.showTodos {
            lines.append("\u{25B8}\u{25B8} accept edits on (shift+tab to cycle)")
        }

        if lines.isEmpty {
            return "(nothing to display)"
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Presets

    private func applyFullPreset() {
        config.display = HUDConfig.HUDDisplayConfig(
            showModel: true, showContextBar: true, contextValue: "percent",
            showTokenBreakdown: true, showConfigCounts: true, showDuration: true,
            showSpeed: true, autocompactBuffer: "enabled", showTools: true,
            showAgents: true, showTodos: true, showUsage: true, usageBarEnabled: true,
            usageThreshold: 0, sevenDayThreshold: 0, environmentThreshold: 0
        )
        config.lineLayout = "expanded"
        config.showSeparators = true
        config.pathLevels = 2
        config.gitStatus = HUDConfig.HUDGitConfig(
            enabled: true, showDirty: true, showAheadBehind: true, showFileStats: true
        )
        saveConfig()
    }

    private func applyEssentialPreset() {
        config.display = HUDConfig.HUDDisplayConfig(
            showModel: true, showContextBar: true, contextValue: "percent",
            showTokenBreakdown: true, showConfigCounts: false, showDuration: true,
            showSpeed: false, autocompactBuffer: "enabled", showTools: true,
            showAgents: true, showTodos: true, showUsage: false, usageBarEnabled: true,
            usageThreshold: 0, sevenDayThreshold: 0, environmentThreshold: 0
        )
        config.lineLayout = "expanded"
        config.showSeparators = true
        config.pathLevels = 2
        config.gitStatus = HUDConfig.HUDGitConfig(
            enabled: true, showDirty: true, showAheadBehind: false, showFileStats: false
        )
        saveConfig()
    }

    private func applyMinimalPreset() {
        config = HUDConfig()
        saveConfig()
    }

    // MARK: - Credit Section

    private var creditSection: some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "person.circle")
                    .font(.title3)
                    .foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Created by Jarrod Watts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Link("github.com/jarrodwatts/claude-hud",
                         destination: URL(string: "https://github.com/jarrodwatts/claude-hud")!)
                        .font(.caption)
                }
                Spacer()
            }
        } header: {
            Text("About")
        }
    }

    // MARK: - Config I/O

    private func checkInstallation() {
        let pluginsURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/plugins/installed_plugins.json")
        guard let data = try? Data(contentsOf: pluginsURL),
              let installed = try? JSONDecoder().decode(InstalledPlugins.self, from: data),
              let entries = installed.plugins?["claude-hud@claude-hud"],
              let first = entries.first else {
            isInstalled = false
            installedVersion = nil
            return
        }
        isInstalled = true
        installedVersion = first.version
    }

    private func loadConfig() {
        let decoder = JSONDecoder()
        guard let data = try? Data(contentsOf: configURL),
              let loaded = try? decoder.decode(HUDConfig.self, from: data) else {
            // Try partial decode — merge whatever exists with defaults
            loadPartialConfig()
            hasLoadedOnce = true
            return
        }
        config = loaded
        hasLoadedOnce = true
    }

    /// Handles partial JSON that may only contain some keys (e.g. {"display":{"showTools":true}})
    private func loadPartialConfig() {
        guard let data = try? Data(contentsOf: configURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }

        // Merge display (plugin stores usage fields here too)
        if let display = json["display"] as? [String: Any] {
            if let v = display["showModel"] as? Bool { config.display.showModel = v }
            if let v = display["showContextBar"] as? Bool { config.display.showContextBar = v }
            if let v = display["contextValue"] as? String { config.display.contextValue = v }
            if let v = display["showTokenBreakdown"] as? Bool { config.display.showTokenBreakdown = v }
            if let v = display["showConfigCounts"] as? Bool { config.display.showConfigCounts = v }
            if let v = display["showDuration"] as? Bool { config.display.showDuration = v }
            if let v = display["showSpeed"] as? Bool { config.display.showSpeed = v }
            if let v = display["autocompactBuffer"] as? String { config.display.autocompactBuffer = v }
            if let v = display["showTools"] as? Bool { config.display.showTools = v }
            if let v = display["showAgents"] as? Bool { config.display.showAgents = v }
            if let v = display["showTodos"] as? Bool { config.display.showTodos = v }
            if let v = display["showUsage"] as? Bool { config.display.showUsage = v }
            if let v = display["usageBarEnabled"] as? Bool { config.display.usageBarEnabled = v }
            if let v = display["usageThreshold"] as? Int { config.display.usageThreshold = v }
            if let v = display["sevenDayThreshold"] as? Int { config.display.sevenDayThreshold = v }
            if let v = display["environmentThreshold"] as? Int { config.display.environmentThreshold = v }
        }

        // Merge layout (top-level fields)
        if let v = json["lineLayout"] as? String { config.lineLayout = v }
        if let v = json["showSeparators"] as? Bool { config.showSeparators = v }
        if let v = json["pathLevels"] as? Int { config.pathLevels = v }

        // Legacy: migrate old nested "layout" key
        if let layout = json["layout"] as? [String: Any] {
            if json["lineLayout"] == nil, let v = layout["lineLayout"] as? String { config.lineLayout = v }
            if json["showSeparators"] == nil, let v = layout["showSeparators"] as? Bool { config.showSeparators = v }
            if json["pathLevels"] == nil, let v = layout["pathLevels"] as? Int { config.pathLevels = v }
        }

        // Legacy: migrate old separate "usage" section into display
        if let usage = json["usage"] as? [String: Any] {
            if let v = usage["showUsage"] as? Bool { config.display.showUsage = v }
            if let v = usage["usageBarEnabled"] as? Bool { config.display.usageBarEnabled = v }
            if let v = usage["usageThreshold"] as? Int { config.display.usageThreshold = v }
            if let v = usage["sevenDayThreshold"] as? Int { config.display.sevenDayThreshold = v }
            if let v = usage["environmentThreshold"] as? Int { config.display.environmentThreshold = v }
        }

        // Merge gitStatus
        if let git = json["gitStatus"] as? [String: Any] {
            if let v = git["enabled"] as? Bool { config.gitStatus.enabled = v }
            if let v = git["showDirty"] as? Bool { config.gitStatus.showDirty = v }
            if let v = git["showAheadBehind"] as? Bool { config.gitStatus.showAheadBehind = v }
            if let v = git["showFileStats"] as? Bool { config.gitStatus.showFileStats = v }
        }
    }

    /// Top-level keys that HUDConfig models — used to merge without destroying unknown plugin keys.
    private static let knownHUDConfigKeys: Set<String> = [
        "display", "lineLayout", "showSeparators", "pathLevels", "gitStatus",
    ]

    private func saveConfig() {
        guard hasLoadedOnce else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let encodedData = try? encoder.encode(config) else { return }

        // Ensure directory exists
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Load existing JSON to preserve unknown keys the plugin may use
        var existingJSON: [String: Any] = [:]
        if let fileData = try? Data(contentsOf: configURL),
           let json = try? JSONSerialization.jsonObject(with: fileData) as? [String: Any] {
            existingJSON = json
        }

        // Merge our known keys on top
        if let configJSON = try? JSONSerialization.jsonObject(with: encodedData) as? [String: Any] {
            for (key, value) in configJSON {
                existingJSON[key] = value
            }
            // Remove keys that our model explicitly set to nil (encoded as absent)
            for key in existingJSON.keys {
                if configJSON[key] == nil, Self.knownHUDConfigKeys.contains(key) {
                    existingJSON.removeValue(forKey: key)
                }
            }
        }

        if let outputData = try? JSONSerialization.data(withJSONObject: existingJSON, options: [.prettyPrinted, .sortedKeys]) {
            try? outputData.write(to: configURL, options: .atomic)
        }
    }
}
