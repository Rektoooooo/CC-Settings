import SwiftUI

struct ExperimentalFeaturesView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    // Thinking
    @State private var thinkingEnabled: Bool = false
    @State private var thinkingBudget: Double = 10000

    // Agent Teams
    @State private var agentTeamsEnabled: Bool = false

    // Performance
    @State private var skipWebFetchPreflight: Bool = false
    @State private var disableNonEssentialCalls: Bool = false

    // Privacy
    @State private var disableTelemetry: Bool = false
    @State private var disableErrorReporting: Bool = false
    @State private var disableAutoUpdater: Bool = false

    // Sandbox
    @State private var enableWeakerSandbox: Bool = false
    @State private var unsandboxedCommands: String = ""
    @State private var allowLocalBinding: Bool = false
    @State private var allowAllUnixSockets: Bool = false
    @State private var allowedDomains: String = ""

    // Spinner
    @State private var spinnerTipsEnabled: Bool = true
    @State private var spinnerVerbsMode: String = "append"
    @State private var spinnerVerbs: String = ""
    @State private var customTips: String = ""
    @State private var excludeDefaultTips: Bool = false

    // Status Line
    @State private var statusLineCommand: String = ""

    var body: some View {
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
                    .onChange(of: thinkingEnabled) { _, _ in saveSettings() }
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
                        .onChange(of: thinkingBudget) { _, _ in saveSettings() }

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
                                saveSettings()
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
            }

            // MARK: - Agent Teams
            Section {
                Toggle("Enable Agent Teams", isOn: $agentTeamsEnabled)
                    .onChange(of: agentTeamsEnabled) { _, _ in saveSettings() }
                Text("Allow multiple Claude agents to work together on tasks.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Agent Teams")
            }

            // MARK: - Performance
            Section {
                Toggle("Skip WebFetch Preflight", isOn: $skipWebFetchPreflight)
                    .onChange(of: skipWebFetchPreflight) { _, _ in saveSettings() }
                Text("Skip preflight validation before fetching web content.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Non-Essential Model Calls", isOn: $disableNonEssentialCalls)
                    .onChange(of: disableNonEssentialCalls) { _, _ in saveSettings() }
                Text("Reduce API usage by disabling non-essential model calls.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Performance")
            }

            // MARK: - Privacy & Telemetry
            Section {
                Toggle("Disable Telemetry", isOn: $disableTelemetry)
                    .onChange(of: disableTelemetry) { _, _ in saveSettings() }
                Text("Disable all telemetry data collection.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Error Reporting", isOn: $disableErrorReporting)
                    .onChange(of: disableErrorReporting) { _, _ in saveSettings() }
                Text("Disable automatic error reporting to Anthropic.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Auto-Updater", isOn: $disableAutoUpdater)
                    .onChange(of: disableAutoUpdater) { _, _ in saveSettings() }
                Text("Prevent Claude Code from updating automatically.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Privacy & Updates")
            }

            // MARK: - Sandbox
            Section {
                Toggle("Enable Weaker Sandbox", isOn: $enableWeakerSandbox)
                    .onChange(of: enableWeakerSandbox) { _, _ in saveSettings() }
                Text("Use a weaker sandbox for Docker or unprivileged environments.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Unsandboxed Commands", text: $unsandboxedCommands, prompt: Text("git, docker, npm"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...3)
                Text("Comma-separated commands that should never run in the sandbox.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Network") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Allow Local Binding", isOn: $allowLocalBinding)
                            .onChange(of: allowLocalBinding) { _, _ in saveSettings() }
                        Text("Allow binding to localhost (macOS).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Toggle("Allow All Unix Sockets", isOn: $allowAllUnixSockets)
                            .onChange(of: allowAllUnixSockets) { _, _ in saveSettings() }
                        Text("Allow connections to all Unix sockets.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        TextField("Allowed Domains", text: $allowedDomains, prompt: Text("*.github.com, api.example.com"), axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1...3)
                        Text("Comma-separated domains allowed for outbound traffic (supports wildcards).")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Sandbox")
            }

            // MARK: - Spinner
            Section {
                Toggle("Show Spinner Tips", isOn: $spinnerTipsEnabled)
                    .onChange(of: spinnerTipsEnabled) { _, _ in saveSettings() }

                Picker("Custom Verbs Mode", selection: $spinnerVerbsMode) {
                    Text("Append to defaults").tag("append")
                    Text("Replace defaults").tag("replace")
                }
                .onChange(of: spinnerVerbsMode) { _, _ in saveSettings() }

                TextField("Custom Verbs", text: $spinnerVerbs, prompt: Text("Pondering, Crafting, Brewing"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Text("Comma-separated custom action verbs for the spinner.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Exclude Default Tips", isOn: $excludeDefaultTips)
                    .onChange(of: excludeDefaultTips) { _, _ in saveSettings() }

                TextField("Custom Tips", text: $customTips, prompt: Text("Tip 1, Tip 2, Tip 3"), axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                Text("Comma-separated custom tip strings shown in the spinner.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Spinner Customization")
            }

            // MARK: - Status Line
            Section {
                TextField("Status Line Command", text: $statusLineCommand, prompt: Text("~/.claude/statusline.sh"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Path to a script that generates the status line content.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Status Line")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadSettings()
        }
    }

    // MARK: - Budget Helpers

    private var budgetColor: Color {
        switch Int(thinkingBudget) {
        case ...10000: return .green
        case ...25000: return .blue
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

        // Sandbox - these need to be stored/loaded from settings
        // For now they use local state; full implementation would need model updates
        enableWeakerSandbox = false
        allowLocalBinding = false
        allowAllUnixSockets = false

        // Spinner
        spinnerTipsEnabled = true

        // Status line
        statusLineCommand = ""
    }

    private func saveSettings() {
        // Settings-based
        configManager.settings.alwaysThinkingEnabled = thinkingEnabled ? true : nil
        configManager.settings.thinkingBudgetTokens = thinkingEnabled ? Int(thinkingBudget) : nil
        configManager.settings.skipWebFetchPreflight = skipWebFetchPreflight ? true : nil

        // Env-based
        setEnvFlag("CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS", enabled: agentTeamsEnabled)
        setEnvFlag("DISABLE_NON_ESSENTIAL_MODEL_CALLS", enabled: disableNonEssentialCalls)
        setEnvFlag("DISABLE_TELEMETRY", enabled: disableTelemetry)
        setEnvFlag("DISABLE_ERROR_REPORTING", enabled: disableErrorReporting)
        setEnvFlag("DISABLE_AUTOUPDATER", enabled: disableAutoUpdater)

        configManager.saveSettings()
    }

    private func setEnvFlag(_ key: String, enabled: Bool) {
        if enabled {
            configManager.settings.env[key] = "1"
        } else {
            configManager.settings.env.removeValue(forKey: key)
        }
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
        case .info: return .blue
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
