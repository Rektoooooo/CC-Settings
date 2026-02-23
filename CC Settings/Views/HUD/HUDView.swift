import SwiftUI

// MARK: - HUD Config Model

/// Represents the claude-hud plugin configuration at ~/.claude/plugins/claude-hud/config.json
struct HUDConfig: Codable, Equatable {
    var display: HUDDisplayConfig
    var layout: HUDLayoutConfig
    var usage: HUDUsageConfig
    var gitStatus: HUDGitConfig

    init() {
        display = HUDDisplayConfig()
        layout = HUDLayoutConfig()
        usage = HUDUsageConfig()
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
        var autocompactBuffer: Bool = true
        var showTools: Bool = true
        var showAgents: Bool = true
        var showTodos: Bool = true
    }

    struct HUDLayoutConfig: Codable, Equatable {
        var lineLayout: String = "expanded"
        var showSeparators: Bool = true
        var pathLevels: Int = 2
    }

    struct HUDUsageConfig: Codable, Equatable {
        var showUsage: Bool = true
        var usageBarEnabled: Bool = true
        var usageThreshold: Int = 80
        var sevenDayThreshold: Int = 80
        var environmentThreshold: Int = 80
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
            Picker("Line Layout", selection: $config.layout.lineLayout) {
                Text("Expanded").tag("expanded")
                Text("Compact").tag("compact")
            }
            .onChange(of: config.layout.lineLayout) { _, _ in saveConfig() }

            if config.layout.lineLayout == "compact" {
                Toggle("Show Separators", isOn: $config.layout.showSeparators)
                    .onChange(of: config.layout.showSeparators) { _, _ in saveConfig() }
            }

            Picker("Path Levels", selection: $config.layout.pathLevels) {
                Text("1").tag(1)
                Text("2").tag(2)
                Text("3").tag(3)
            }
            .onChange(of: config.layout.pathLevels) { _, _ in saveConfig() }
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
                Text("Enabled").tag(true)
                Text("Disabled").tag(false)
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
            Toggle("Show Usage Rate Limits", isOn: $config.usage.showUsage)
                .onChange(of: config.usage.showUsage) { _, _ in saveConfig() }

            if config.usage.showUsage {
                Toggle("Visual Bar", isOn: $config.usage.usageBarEnabled)
                    .onChange(of: config.usage.usageBarEnabled) { _, _ in saveConfig() }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("5-Hour Threshold")
                        Spacer()
                        Text("\(config.usage.usageThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.usage.usageThreshold) },
                            set: { config.usage.usageThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.usage.usageThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("7-Day Threshold")
                        Spacer()
                        Text("\(config.usage.sevenDayThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.usage.sevenDayThreshold) },
                            set: { config.usage.sevenDayThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.usage.sevenDayThreshold) { _, _ in saveConfig() }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Environment Threshold")
                        Spacer()
                        Text("\(config.usage.environmentThreshold)%")
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(config.usage.environmentThreshold) },
                            set: { config.usage.environmentThreshold = Int($0) }
                        ),
                        in: 0...100,
                        step: 5
                    )
                    .onChange(of: config.usage.environmentThreshold) { _, _ in saveConfig() }
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
        var lines: [String] = []

        // Line 1: Header
        var header = ""
        if config.display.showModel {
            header += "[Opus | Max]"
        }
        let gitPart = config.gitStatus.enabled
            ? "git:(main\(config.gitStatus.showDirty ? "*" : ""))"
            : ""
        let pathPart = "my-project"
        if !header.isEmpty && !gitPart.isEmpty {
            header += " | \(pathPart) \(gitPart)"
        } else if !header.isEmpty {
            header += " | \(pathPart)"
        } else if !gitPart.isEmpty {
            header = "\(pathPart) \(gitPart)"
        } else {
            header = pathPart
        }
        if config.gitStatus.enabled && config.gitStatus.showAheadBehind {
            header += " +2/-1"
        }
        lines.append(header)

        // Line 2: Context + Usage
        var statusParts: [String] = []
        if config.display.showContextBar {
            if config.display.contextValue == "percent" {
                statusParts.append("Context \u{2588}\u{2588}\u{2588}\u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 45%")
            } else {
                statusParts.append("Context 45k/100k tokens")
            }
        }
        if config.usage.showUsage {
            if config.usage.usageBarEnabled {
                statusParts.append("Usage \u{2588}\u{2588}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591}\u{2591} 25% (1h 30m / 5h)")
            } else {
                statusParts.append("Usage 25% (1h 30m / 5h)")
            }
        }
        if config.display.showDuration {
            statusParts.append("12m 34s")
        }
        if config.display.showSpeed {
            statusParts.append("~85 tok/s")
        }
        if !statusParts.isEmpty {
            let sep = config.layout.lineLayout == "compact" && config.layout.showSeparators ? " | " : " | "
            lines.append(statusParts.joined(separator: sep))
        }

        // Line 3: Tool activity
        if config.display.showTools {
            lines.append("\u{25D0} Edit: auth.ts | \u{2713} Read \u{00D7}3 | \u{2713} Grep \u{00D7}2")
        }

        // Line 4: Agent status
        if config.display.showAgents {
            lines.append("\u{25D0} explore [haiku]: Finding auth code (2m 15s)")
        }

        // Line 5: Todos
        if config.display.showTodos {
            lines.append("\u{25B8} Fix authentication bug (2/5)")
        }

        // Line 6: Git file stats
        if config.gitStatus.enabled && config.gitStatus.showFileStats {
            lines.append("+42 -18 across 5 files")
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
            showSpeed: true, autocompactBuffer: true, showTools: true,
            showAgents: true, showTodos: true
        )
        config.layout = HUDConfig.HUDLayoutConfig(
            lineLayout: "expanded", showSeparators: true, pathLevels: 2
        )
        config.usage = HUDConfig.HUDUsageConfig(
            showUsage: true, usageBarEnabled: true, usageThreshold: 80,
            sevenDayThreshold: 80, environmentThreshold: 80
        )
        config.gitStatus = HUDConfig.HUDGitConfig(
            enabled: true, showDirty: true, showAheadBehind: true, showFileStats: true
        )
        saveConfig()
    }

    private func applyEssentialPreset() {
        config.display = HUDConfig.HUDDisplayConfig(
            showModel: true, showContextBar: true, contextValue: "percent",
            showTokenBreakdown: true, showConfigCounts: false, showDuration: true,
            showSpeed: false, autocompactBuffer: true, showTools: true,
            showAgents: true, showTodos: true
        )
        config.layout = HUDConfig.HUDLayoutConfig(
            lineLayout: "expanded", showSeparators: true, pathLevels: 2
        )
        config.usage = HUDConfig.HUDUsageConfig(
            showUsage: false, usageBarEnabled: true, usageThreshold: 80,
            sevenDayThreshold: 80, environmentThreshold: 80
        )
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

        // Merge display
        if let display = json["display"] as? [String: Any] {
            if let v = display["showModel"] as? Bool { config.display.showModel = v }
            if let v = display["showContextBar"] as? Bool { config.display.showContextBar = v }
            if let v = display["contextValue"] as? String { config.display.contextValue = v }
            if let v = display["showTokenBreakdown"] as? Bool { config.display.showTokenBreakdown = v }
            if let v = display["showConfigCounts"] as? Bool { config.display.showConfigCounts = v }
            if let v = display["showDuration"] as? Bool { config.display.showDuration = v }
            if let v = display["showSpeed"] as? Bool { config.display.showSpeed = v }
            if let v = display["autocompactBuffer"] as? Bool { config.display.autocompactBuffer = v }
            if let v = display["showTools"] as? Bool { config.display.showTools = v }
            if let v = display["showAgents"] as? Bool { config.display.showAgents = v }
            if let v = display["showTodos"] as? Bool { config.display.showTodos = v }
        }

        // Merge layout
        if let layout = json["layout"] as? [String: Any] {
            if let v = layout["lineLayout"] as? String { config.layout.lineLayout = v }
            if let v = layout["showSeparators"] as? Bool { config.layout.showSeparators = v }
            if let v = layout["pathLevels"] as? Int { config.layout.pathLevels = v }
        }

        // Merge usage
        if let usage = json["usage"] as? [String: Any] {
            if let v = usage["showUsage"] as? Bool { config.usage.showUsage = v }
            if let v = usage["usageBarEnabled"] as? Bool { config.usage.usageBarEnabled = v }
            if let v = usage["usageThreshold"] as? Int { config.usage.usageThreshold = v }
            if let v = usage["sevenDayThreshold"] as? Int { config.usage.sevenDayThreshold = v }
            if let v = usage["environmentThreshold"] as? Int { config.usage.environmentThreshold = v }
        }

        // Merge gitStatus
        if let git = json["gitStatus"] as? [String: Any] {
            if let v = git["enabled"] as? Bool { config.gitStatus.enabled = v }
            if let v = git["showDirty"] as? Bool { config.gitStatus.showDirty = v }
            if let v = git["showAheadBehind"] as? Bool { config.gitStatus.showAheadBehind = v }
            if let v = git["showFileStats"] as? Bool { config.gitStatus.showFileStats = v }
        }
    }

    private func saveConfig() {
        guard hasLoadedOnce else { return }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(config) else { return }

        // Ensure directory exists
        let dir = configURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        try? data.write(to: configURL, options: .atomic)
    }
}
