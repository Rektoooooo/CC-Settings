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
            } header: {
                Text("API & Authentication")
            }

            // MARK: - Model Overrides
            Section {
                TextField("Default Model", text: $anthropicModel, prompt: Text("Override model (e.g. claude-opus-4-6)"))
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
                            TextField("e.g. claude-opus-4-6", text: $defaultOpusModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("sonnet =")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            TextField("e.g. claude-sonnet-4-5-20250514", text: $defaultSonnetModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                        HStack {
                            Text("haiku =")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 80, alignment: .trailing)
                            TextField("e.g. claude-3-5-haiku-20241022", text: $defaultHaikuModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                    .padding(.vertical, 4)
                }
                Text("Pin the \"opus\", \"sonnet\", \"haiku\" aliases to specific model versions.")
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

                Toggle("Disable Bug Report Command", isOn: $disableBugCommand)
                    .onChange(of: disableBugCommand) { _, _ in save() }
                Text("Remove the /bug command from Claude Code.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } header: {
                Text("Display")
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
