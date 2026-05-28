import SwiftUI

struct EnvironmentView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @Binding var scrollToSection: String?
    @State private var isSyncing = false

    private static var env: [String: String] { ConfigurationManager.shared.settings.env }

    // API & Auth
    @State private var anthropicApiKey: String = env["ANTHROPIC_API_KEY"] ?? ""
    @State private var apiBaseURL: String = env["API_BASE_URL"] ?? ""

    // Model Overrides
    @State private var anthropicModel: String = env["ANTHROPIC_MODEL"] ?? ""
    @State private var subagentModel: String = env["CLAUDE_CODE_SUBAGENT_MODEL"] ?? ""
    @State private var defaultOpusModel: String = env["ANTHROPIC_DEFAULT_OPUS_MODEL"] ?? ""
    @State private var defaultSonnetModel: String = env["ANTHROPIC_DEFAULT_SONNET_MODEL"] ?? ""
    @State private var defaultHaikuModel: String = env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] ?? ""

    // Performance
    @State private var maxOutputTokens: String = env["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] ?? ""
    @State private var maxThinkingTokens: String = env["MAX_THINKING_TOKENS"] ?? ""
    @State private var autoCompactPct: String = env["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"] ?? ""
    @State private var disablePromptCaching: Bool = env["DISABLE_PROMPT_CACHING"] == "1"
    @State private var disablePromptCachingHaiku: Bool = env["DISABLE_PROMPT_CACHING_HAIKU"] == "1"
    @State private var disablePromptCachingSonnet: Bool = env["DISABLE_PROMPT_CACHING_SONNET"] == "1"
    @State private var disablePromptCachingOpus: Bool = env["DISABLE_PROMPT_CACHING_OPUS"] == "1"
    @State private var mcpTimeout: String = env["MCP_TIMEOUT"] ?? ""
    @State private var mcpToolTimeout: String = env["MCP_TOOL_TIMEOUT"] ?? ""

    // Network & Proxy
    @State private var httpProxy: String = env["HTTP_PROXY"] ?? ""
    @State private var httpsProxy: String = env["HTTPS_PROXY"] ?? ""
    @State private var noProxy: String = env["NO_PROXY"] ?? ""

    // Display & Misc
    @State private var hideAccountInfo: Bool = env["CLAUDE_CODE_HIDE_ACCOUNT_INFO"] == "1"
    @State private var disableBugCommand: Bool = env["DISABLE_BUG_COMMAND"] == "1"
    @State private var hideCwd: Bool = env["CLAUDE_CODE_HIDE_CWD"] == "1"
    @State private var forceSyncOutput: Bool = env["CLAUDE_CODE_FORCE_SYNC_OUTPUT"] == "1"

    // Updates
    @State private var disableUpdates: Bool = env["DISABLE_UPDATES"] == "1"
    @State private var packageManagerAutoUpdate: Bool = env["CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE"] == "1"

    // Subagents & Discovery
    @State private var forkSubagent: Bool = env["CLAUDE_CODE_FORK_SUBAGENT"] == "1"
    @State private var enableGatewayModelDiscovery: Bool = env["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"] == "1"

    // Bedrock
    @State private var bedrockServiceTier: String = env["ANTHROPIC_BEDROCK_SERVICE_TIER"] ?? ""

    // Added 2026-05 — Claude Code 2.1.132 → 2.1.141
    @State private var disableAlternateScreen: Bool = env["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] == "1"
    @State private var envEffortLevel: String = env["CLAUDE_CODE_EFFORT_LEVEL"] ?? ""
    @State private var enableFeedbackSurveyForOtel: Bool = env["CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL"] == "1"
    @State private var pluginPreferHttps: Bool = env["CLAUDE_CODE_PLUGIN_PREFER_HTTPS"] == "1"
    @State private var workspaceId: String = env["ANTHROPIC_WORKSPACE_ID"] ?? ""

    // Custom variables (not in any known category)
    @State private var customVars: [EnvVar] = []

    var body: some View {
        Form {
            // MARK: - API & Authentication
            Section {
                SecureField("API Key", text: $anthropicApiKey, prompt: Text("sk-ant-..."))
                    .font(.system(.body, design: .monospaced))
                Text("Your Anthropic API key. Alternatively, set this in your shell profile.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("API Base URL", text: $apiBaseURL, prompt: Text("https://api.anthropic.com"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Custom API endpoint URL. Leave empty for default Anthropic API.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Workspace ID", text: $workspaceId, prompt: Text("Workload identity federation workspace"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Scopes the minted token to a specific workspace when workload identity federation covers more than one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("API & Authentication")
            }

            // MARK: - Model Overrides
            Section {
                TextField("Default Model", text: $anthropicModel, prompt: Text("Override model (e.g. claude-opus-4-8)"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Override the model used by Claude Code. This takes priority over the model setting.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Subagent Model", text: $subagentModel, prompt: Text("Model for sub-agents"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Model used when spawning sub-agents (Task tool).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Pin Model Aliases") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("opus =")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            TextField("e.g. claude-opus-4-8", text: $defaultOpusModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("sonnet =")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            TextField("e.g. claude-sonnet-4-6", text: $defaultSonnetModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("haiku =")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            TextField("e.g. claude-haiku-4-5-20251001", text: $defaultHaikuModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 4)
                }
                Text("Pin the \"opus\", \"sonnet\", \"haiku\" aliases to specific model versions.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextField("Effort Level Override", text: $envEffortLevel, prompt: Text("low / medium / high / xhigh / max"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Env-var override for effort level. Takes priority over the effortLevel setting in General.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Model Overrides")
            }

            // MARK: - Performance
            Section {
                HStack {
                    Text("Max Output Tokens")
                    Spacer()
                    TextField("32000", text: $maxOutputTokens)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 120)
                }
                Text("Maximum output tokens per response (default 32K, max 64K).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Max Thinking Tokens")
                    Spacer()
                    TextField("31999", text: $maxThinkingTokens)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 120)
                }
                Text("Extended thinking token budget (default 31,999).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("Auto-Compact Threshold")
                    Spacer()
                    TextField("%", text: $autoCompactPct)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 80)
                }
                Text("Context % threshold (1-100) at which auto-compaction fires.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                GroupBox("Prompt Caching") {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Disable All Prompt Caching", isOn: $disablePromptCaching)
                            .onChange(of: disablePromptCaching) { _, _ in save() }
                        Toggle("Disable Haiku Caching", isOn: $disablePromptCachingHaiku)
                            .onChange(of: disablePromptCachingHaiku) { _, _ in save() }
                        Toggle("Disable Sonnet Caching", isOn: $disablePromptCachingSonnet)
                            .onChange(of: disablePromptCachingSonnet) { _, _ in save() }
                        Toggle("Disable Opus Caching", isOn: $disablePromptCachingOpus)
                            .onChange(of: disablePromptCachingOpus) { _, _ in save() }
                    }
                    .padding(.vertical, 4)
                }
                Text("Disabling prompt caching may increase costs but can help with debugging.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Text("MCP Startup Timeout")
                    Spacer()
                    TextField("ms", text: $mcpTimeout)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 100)
                    Text("ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("MCP Tool Timeout")
                    Spacer()
                    TextField("ms", text: $mcpToolTimeout)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 100)
                    Text("ms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Performance")
            }

            // MARK: - Network & Proxy
            Section {
                TextField("HTTP Proxy", text: $httpProxy, prompt: Text("http://proxy:8080"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                TextField("HTTPS Proxy", text: $httpsProxy, prompt: Text("https://proxy:8443"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                TextField("No Proxy", text: $noProxy, prompt: Text("localhost,127.0.0.1,.internal"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Comma-separated list of hosts to bypass the proxy.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Network & Proxy")
            }

            // MARK: - Display
            Section {
                Toggle("Hide Account Info", isOn: $hideAccountInfo)
                    .onChange(of: hideAccountInfo) { _, _ in save() }
                Text("Hide email and organization details from the UI.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Hide Working Directory in Logo", isOn: $hideCwd)
                    .onChange(of: hideCwd) { _, _ in save() }
                Text("Hide the cwd shown in the startup logo.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Bug Report Command", isOn: $disableBugCommand)
                    .onChange(of: disableBugCommand) { _, _ in save() }
                Text("Remove the /bug command from Claude Code.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Force Synchronized Terminal Output", isOn: $forceSyncOutput)
                    .onChange(of: forceSyncOutput) { _, _ in save() }
                Text("Forces sync output on terminals where auto-detection misses (e.g. Emacs eat).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Disable Fullscreen Alternate Screen", isOn: $disableAlternateScreen)
                    .onChange(of: disableAlternateScreen) { _, _ in save() }
                Text("Keeps the conversation in the terminal's native scrollback instead of using the alternate-screen renderer.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Display")
            }

            // MARK: - Plugins
            Section {
                Toggle("Prefer HTTPS for Plugin Clones", isOn: $pluginPreferHttps)
                    .onChange(of: pluginPreferHttps) { _, _ in save() }
                Text("Clones GitHub plugin sources over HTTPS instead of SSH. Useful in environments without a GitHub SSH key.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Plugins")
            }

            // MARK: - Telemetry
            Section {
                Toggle("Re-enable Feedback Survey for OTEL", isOn: $enableFeedbackSurveyForOtel)
                    .onChange(of: enableFeedbackSurveyForOtel) { _, _ in save() }
                Text("For enterprises capturing session quality survey responses through OpenTelemetry.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Telemetry")
            }

            // MARK: - Updates
            Section {
                Toggle("Disable All Updates", isOn: $disableUpdates)
                    .onChange(of: disableUpdates) { _, _ in save() }
                Text("Blocks all update paths including manual `claude update`. Stricter than DISABLE_AUTOUPDATER.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Package Manager Auto-Update", isOn: $packageManagerAutoUpdate)
                    .onChange(of: packageManagerAutoUpdate) { _, _ in save() }
                Text("On Homebrew or WinGet installs, run the upgrade in the background and prompt to restart.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Updates")
            }

            // MARK: - Subagents & Gateway Discovery
            Section {
                Toggle("Enable Forked Subagents", isOn: $forkSubagent)
                    .onChange(of: forkSubagent) { _, _ in save() }
                Text("Enables forked subagents on external builds (CLAUDE_CODE_FORK_SUBAGENT).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Enable Gateway Model Discovery", isOn: $enableGatewayModelDiscovery)
                    .onChange(of: enableGatewayModelDiscovery) { _, _ in save() }
                Text("Lets the /model picker list models from your gateway's /v1/models endpoint when ANTHROPIC_BASE_URL is set.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Subagents & Gateway Discovery")
            }

            // MARK: - Bedrock
            Section {
                Picker("Service Tier", selection: $bedrockServiceTier) {
                    Text("Default").tag("")
                    Text("default").tag("default")
                    Text("flex").tag("flex")
                    Text("priority").tag("priority")
                }
                .pickerStyle(.segmented)
                .onChange(of: bedrockServiceTier) { _, _ in save() }
                Text("Sent as the X-Amzn-Bedrock-Service-Tier header. Only used when running on Bedrock.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Bedrock")
            }

            // MARK: - Custom Variables
            Section {
                ForEach($customVars) { $envVar in
                    HStack(spacing: 8) {
                        TextField("KEY", text: $envVar.key)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 200)

                        TextField("value", text: $envVar.value)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))

                        Button {
                            customVars.removeAll { $0.id == envVar.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    customVars.append(EnvVar(key: "", value: ""))
                } label: {
                    Label("Add Variable", systemImage: "plus")
                }
            } header: {
                Text("Custom Variables")
            } footer: {
                Text("Additional environment variables not covered by the sections above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .onSubmit { save() }
        .onDisappear { save() }
        .onAppear {
            isSyncing = true
            loadFromSettings()
            DispatchQueue.main.async { isSyncing = false }
        }
        .onChange(of: configManager.settings) {
            isSyncing = true
            loadFromSettings()
            DispatchQueue.main.async { isSyncing = false }
        }
    }

    // MARK: - Known env var keys managed by this view

    private static let managedKeys: Set<String> = [
        "ANTHROPIC_API_KEY", "API_BASE_URL",
        "ANTHROPIC_MODEL", "CLAUDE_CODE_SUBAGENT_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL", "ANTHROPIC_DEFAULT_SONNET_MODEL", "ANTHROPIC_DEFAULT_HAIKU_MODEL",
        "CLAUDE_CODE_MAX_OUTPUT_TOKENS", "MAX_THINKING_TOKENS", "CLAUDE_AUTOCOMPACT_PCT_OVERRIDE",
        "DISABLE_PROMPT_CACHING", "DISABLE_PROMPT_CACHING_HAIKU", "DISABLE_PROMPT_CACHING_SONNET", "DISABLE_PROMPT_CACHING_OPUS",
        "MCP_TIMEOUT", "MCP_TOOL_TIMEOUT",
        "HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY",
        "CLAUDE_CODE_HIDE_ACCOUNT_INFO", "DISABLE_BUG_COMMAND",
        "CLAUDE_CODE_HIDE_CWD", "CLAUDE_CODE_FORCE_SYNC_OUTPUT",
        "DISABLE_UPDATES", "CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE",
        "CLAUDE_CODE_FORK_SUBAGENT", "CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY",
        "ANTHROPIC_BEDROCK_SERVICE_TIER",
        "CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN", "CLAUDE_CODE_EFFORT_LEVEL",
        "CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL", "CLAUDE_CODE_PLUGIN_PREFER_HTTPS",
        "ANTHROPIC_WORKSPACE_ID",
    ]

    // MARK: - Data Sync

    private func loadFromSettings() {
        let env = configManager.settings.env

        // API
        anthropicApiKey = env["ANTHROPIC_API_KEY"] ?? ""
        apiBaseURL = env["API_BASE_URL"] ?? ""

        // Model
        anthropicModel = env["ANTHROPIC_MODEL"] ?? ""
        subagentModel = env["CLAUDE_CODE_SUBAGENT_MODEL"] ?? ""
        defaultOpusModel = env["ANTHROPIC_DEFAULT_OPUS_MODEL"] ?? ""
        defaultSonnetModel = env["ANTHROPIC_DEFAULT_SONNET_MODEL"] ?? ""
        defaultHaikuModel = env["ANTHROPIC_DEFAULT_HAIKU_MODEL"] ?? ""

        // Performance
        maxOutputTokens = env["CLAUDE_CODE_MAX_OUTPUT_TOKENS"] ?? ""
        maxThinkingTokens = env["MAX_THINKING_TOKENS"] ?? ""
        autoCompactPct = env["CLAUDE_AUTOCOMPACT_PCT_OVERRIDE"] ?? ""
        disablePromptCaching = env["DISABLE_PROMPT_CACHING"] == "1"
        disablePromptCachingHaiku = env["DISABLE_PROMPT_CACHING_HAIKU"] == "1"
        disablePromptCachingSonnet = env["DISABLE_PROMPT_CACHING_SONNET"] == "1"
        disablePromptCachingOpus = env["DISABLE_PROMPT_CACHING_OPUS"] == "1"
        mcpTimeout = env["MCP_TIMEOUT"] ?? ""
        mcpToolTimeout = env["MCP_TOOL_TIMEOUT"] ?? ""

        // Network
        httpProxy = env["HTTP_PROXY"] ?? ""
        httpsProxy = env["HTTPS_PROXY"] ?? ""
        noProxy = env["NO_PROXY"] ?? ""

        // Display
        hideAccountInfo = env["CLAUDE_CODE_HIDE_ACCOUNT_INFO"] == "1"
        disableBugCommand = env["DISABLE_BUG_COMMAND"] == "1"
        hideCwd = env["CLAUDE_CODE_HIDE_CWD"] == "1"
        forceSyncOutput = env["CLAUDE_CODE_FORCE_SYNC_OUTPUT"] == "1"

        // Updates
        disableUpdates = env["DISABLE_UPDATES"] == "1"
        packageManagerAutoUpdate = env["CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE"] == "1"

        // Subagents & Discovery
        forkSubagent = env["CLAUDE_CODE_FORK_SUBAGENT"] == "1"
        enableGatewayModelDiscovery = env["CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY"] == "1"

        // Bedrock
        bedrockServiceTier = env["ANTHROPIC_BEDROCK_SERVICE_TIER"] ?? ""

        // Claude Code 2.1.132 → 2.1.141
        disableAlternateScreen = env["CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN"] == "1"
        envEffortLevel = env["CLAUDE_CODE_EFFORT_LEVEL"] ?? ""
        enableFeedbackSurveyForOtel = env["CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL"] == "1"
        pluginPreferHttps = env["CLAUDE_CODE_PLUGIN_PREFER_HTTPS"] == "1"
        workspaceId = env["ANTHROPIC_WORKSPACE_ID"] ?? ""

        // Custom: everything not in managed keys
        customVars = env
            .filter { !Self.managedKeys.contains($0.key) }
            .map { EnvVar(key: $0.key, value: $0.value) }
            .sorted { $0.key < $1.key }
    }

    private func save() {
        guard !isSyncing else { return }
        var env: [String: String] = [:]

        func setString(_ key: String, _ value: String) {
            let trimmed = value.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty { env[key] = trimmed }
        }

        func setFlag(_ key: String, _ value: Bool) {
            if value { env[key] = "1" }
        }

        // API
        setString("ANTHROPIC_API_KEY", anthropicApiKey)
        setString("API_BASE_URL", apiBaseURL)

        // Model
        setString("ANTHROPIC_MODEL", anthropicModel)
        setString("CLAUDE_CODE_SUBAGENT_MODEL", subagentModel)
        setString("ANTHROPIC_DEFAULT_OPUS_MODEL", defaultOpusModel)
        setString("ANTHROPIC_DEFAULT_SONNET_MODEL", defaultSonnetModel)
        setString("ANTHROPIC_DEFAULT_HAIKU_MODEL", defaultHaikuModel)

        // Performance
        setString("CLAUDE_CODE_MAX_OUTPUT_TOKENS", maxOutputTokens)
        setString("MAX_THINKING_TOKENS", maxThinkingTokens)
        setString("CLAUDE_AUTOCOMPACT_PCT_OVERRIDE", autoCompactPct)
        setFlag("DISABLE_PROMPT_CACHING", disablePromptCaching)
        setFlag("DISABLE_PROMPT_CACHING_HAIKU", disablePromptCachingHaiku)
        setFlag("DISABLE_PROMPT_CACHING_SONNET", disablePromptCachingSonnet)
        setFlag("DISABLE_PROMPT_CACHING_OPUS", disablePromptCachingOpus)
        setString("MCP_TIMEOUT", mcpTimeout)
        setString("MCP_TOOL_TIMEOUT", mcpToolTimeout)

        // Network
        setString("HTTP_PROXY", httpProxy)
        setString("HTTPS_PROXY", httpsProxy)
        setString("NO_PROXY", noProxy)

        // Display
        setFlag("CLAUDE_CODE_HIDE_ACCOUNT_INFO", hideAccountInfo)
        setFlag("DISABLE_BUG_COMMAND", disableBugCommand)
        setFlag("CLAUDE_CODE_HIDE_CWD", hideCwd)
        setFlag("CLAUDE_CODE_FORCE_SYNC_OUTPUT", forceSyncOutput)

        // Updates
        setFlag("DISABLE_UPDATES", disableUpdates)
        setFlag("CLAUDE_CODE_PACKAGE_MANAGER_AUTO_UPDATE", packageManagerAutoUpdate)

        // Subagents & Discovery
        setFlag("CLAUDE_CODE_FORK_SUBAGENT", forkSubagent)
        setFlag("CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY", enableGatewayModelDiscovery)

        // Bedrock
        setString("ANTHROPIC_BEDROCK_SERVICE_TIER", bedrockServiceTier)

        // Claude Code 2.1.132 → 2.1.141
        setFlag("CLAUDE_CODE_DISABLE_ALTERNATE_SCREEN", disableAlternateScreen)
        setString("CLAUDE_CODE_EFFORT_LEVEL", envEffortLevel)
        setFlag("CLAUDE_CODE_ENABLE_FEEDBACK_SURVEY_FOR_OTEL", enableFeedbackSurveyForOtel)
        setFlag("CLAUDE_CODE_PLUGIN_PREFER_HTTPS", pluginPreferHttps)
        setString("ANTHROPIC_WORKSPACE_ID", workspaceId)

        // Custom vars
        for v in customVars {
            let key = v.key.trimmingCharacters(in: .whitespaces)
            if !key.isEmpty {
                env[key] = v.value
            }
        }

        // Preserve any env vars not managed by this view (e.g. from ExperimentalFeaturesView)
        // by reading the current env from disk, not from the in-memory struct
        let currentEnv = configManager.settings.env
        for (key, value) in currentEnv {
            if !Self.managedKeys.contains(key) && env[key] == nil {
                env[key] = value
            }
        }

        // Write only the "env" key, preserving all other settings on disk
        configManager.saveField("env", value: env.isEmpty ? nil : env)
    }
}

// MARK: - EnvVar Model

struct EnvVar: Identifiable, Equatable {
    let id = UUID()
    var key: String
    var value: String

    func copy() -> EnvVar {
        EnvVar(key: key, value: value)
    }

    static func == (lhs: EnvVar, rhs: EnvVar) -> Bool {
        lhs.key == rhs.key && lhs.value == rhs.value
    }
}
