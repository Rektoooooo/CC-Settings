import SwiftUI
import AppKit
import Sparkle

struct GeneralSettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.sparkleUpdater) private var sparkleUpdater
    @Binding var scrollToSection: String?

    // All @State defaults read from the singleton so the FIRST render shows real values.
    // ConfigurationManager.shared.loadAll() runs synchronously before any view is created.
    private static var s: ClaudeSettings { ConfigurationManager.shared.settings }

    // Model
    @State private var selectedModel: String = s.model
    @State private var fastMode: Bool = s.fastMode ?? false
    @State private var fastModePerSessionOptIn: Bool = s.fastModePerSessionOptIn ?? false
    @State private var fallbackModels: String = (s.fallbackModel ?? []).joined(separator: ", ")
    @State private var advisorModel: String = s.advisorModel ?? ""
    @State private var enforceAvailableModels: Bool = s.enforceAvailableModels ?? false

    // Appearance
    @State private var prefersReducedMotion: Bool = s.prefersReducedMotion ?? false

    // Language & Output
    @State private var language: String = s.language ?? ""
    @State private var effortLevel: String = s.effortLevel ?? ""
    @State private var dynamicWorkflowsEnabled: Bool = !(s.disableWorkflows ?? false)
    @State private var ultracodeKeywordEnabled: Bool = s.workflowKeywordTriggerEnabled ?? true
    @State private var outputStyle: String = s.outputStyle ?? ""
    @State private var verbose: Bool = s.verbose ?? false
    @State private var skillOverrides: String = s.skillOverrides ?? ""
    @State private var bundledSkillsEnabled: Bool = !(s.disableBundledSkills ?? false)
    @State private var workflowSizeGuideline: String = s.workflowSizeGuideline ?? ""

    // Behavior
    @State private var showTurnDuration: Bool = s.showTurnDuration ?? true
    @State private var respectGitignore: Bool = s.respectGitignore ?? true
    @State private var defaultShell: String = s.defaultShell ?? "bash"
    @State private var includeGitInstructions: Bool = s.includeGitInstructions ?? true
    @State private var showThinkingSummaries: Bool = s.showThinkingSummaries ?? false
    @State private var showClearContextOnPlanAccept: Bool = s.showClearContextOnPlanAccept ?? false
    @State private var voiceEnabled: Bool = s.voiceEnabled ?? false
    @State private var autoCompactEnabled: Bool = s.autoCompact != nil
    @State private var autoCompactInstructions: String = s.autoCompact?.customInstructions ?? ""
    @State private var plansDirectory: String = s.plansDirectory ?? ""
    @State private var autoCompactWindow: String = s.autoCompactWindow.map(String.init) ?? ""
    @State private var precomputeCompactionEnabled: Bool = s.precomputeCompactionEnabled ?? false
    @State private var todoFeatureEnabled: Bool = s.todoFeatureEnabled ?? true
    @State private var askUserQuestionTimeout: String = s.askUserQuestionTimeout ?? ""
    @State private var awaySummaryEnabled: Bool = s.awaySummaryEnabled ?? true
    @State private var promptSuggestionEnabled: Bool = s.promptSuggestionEnabled ?? true
    @State private var emojiCompletionEnabled: Bool = s.emojiCompletionEnabled ?? true
    @State private var fileCheckpointingEnabled: Bool = s.fileCheckpointingEnabled ?? true
    @State private var fileSuggestionCommand: String = s.fileSuggestion?.command ?? ""

    // Terminal & Accessibility
    @State private var axScreenReader: Bool = s.axScreenReader ?? false
    @State private var autoScrollEnabled: Bool = s.autoScrollEnabled ?? true
    @State private var wheelScrollAcceleration: Bool = s.wheelScrollAccelerationEnabled ?? true
    @State private var terminalProgressBarEnabled: Bool = s.terminalProgressBarEnabled ?? false
    @State private var showMessageTimestamps: Bool = s.showMessageTimestamps ?? false
    @State private var syntaxHighlightingEnabled: Bool = !(s.syntaxHighlightingDisabled ?? false)
    @State private var hideVimModeIndicator: Bool = s.hideVimModeIndicator ?? false
    @State private var vimEscapeSequences: String = (s.vimInsertModeRemaps ?? [:]).keys.sorted().joined(separator: ", ")

    // Memory
    @State private var autoMemoryEnabled: Bool = s.autoMemoryEnabled ?? false
    @State private var autoMemoryDirectory: String = s.autoMemoryDirectory ?? ""

    // Git
    @State private var mainBranch: String = s.mainBranch ?? ""
    @State private var selectedGitApp: String = s.preferredGitApp?.rawValue ?? "system"
    @State private var customGitAppPath: String = s.customGitAppPath ?? ""

    // Updates
    @State private var autoUpdates: Bool = s.autoUpdates ?? true
    @State private var autoUpdatesChannel: String = s.autoUpdatesChannel ?? "latest"

    // Notifications
    @State private var preferredNotifChannel: String = s.preferredNotifChannel ?? "iterm2"

    // Data Retention
    @State private var cleanupPeriodDays: Double = Double(s.cleanupPeriodDays ?? 30)

    // Attribution
    @State private var commitAttribution: String = s.attribution?.commit ?? ""
    @State private var prAttribution: String = s.attribution?.pr ?? ""
    @State private var prUrlTemplate: String = s.prUrlTemplate ?? ""
    @State private var attributionSessionUrl: Bool = s.attribution?.sessionUrl ?? true

    // Teams
    @State private var teammateMode: String = s.teammateMode ?? "auto"

    // Agent View & Remote Control
    @State private var agentViewEnabled: Bool = !(s.disableAgentView ?? false)
    @State private var subagentStatusLineCommand: String = s.subagentStatusLine?.command ?? ""
    @State private var remoteControlEnabled: Bool = !(s.disableRemoteControl ?? false)
    @State private var remoteControlAtStartup: Bool = s.remoteControlAtStartup ?? false
    @State private var agentPushNotifEnabled: Bool = s.agentPushNotifEnabled ?? false

    @State private var allowAllClaudeAiMcps: Bool = s.allowAllClaudeAiMcps ?? false
    @State private var pluginSuggestionMarketplaces: String = (s.pluginSuggestionMarketplaces ?? []).joined(separator: ", ")
    @State private var artifactEnabled: Bool = (s.enableArtifact ?? true) && !(s.disableArtifact ?? false)
    @State private var claudeAiConnectorsEnabled: Bool = !(s.disableClaudeAiConnectors ?? false)
    @State private var channelsEnabled: Bool = s.channelsEnabled ?? false
    @State private var allowedMcpServers: String = (s.allowedMcpServers ?? []).joined(separator: ", ")
    @State private var strictKnownMarketplaces: String = (s.strictKnownMarketplaces ?? []).joined(separator: ", ")
    @State private var blockedMarketplaces: String = (s.blockedMarketplaces ?? []).joined(separator: ", ")
    @State private var sideloadFlagsEnabled: Bool = !(s.disableSideloadFlags ?? false)
    @State private var skillShellExecutionEnabled: Bool = !(s.disableSkillShellExecution ?? false)
    @State private var deepLinkRegistrationEnabled: Bool = s.disableDeepLinkRegistration != "disable"
    @State private var feedbackSurveyRate: String = s.feedbackSurveyRate.map { String($0) } ?? ""

    // API Key Helper
    @State private var apiKeyHelper: String = s.apiKeyHelper ?? ""

    // Claude Code Version
    @State private var installedVersion: String = ""
    @State private var latestVersion: String = ""
    @State private var isCheckingUpdate: Bool = false
    @State private var isUpdating: Bool = false
    @State private var updateOutput: String = ""

    // Prevents onChange from firing during initial load
    @State private var isLoaded: Bool = false

    var body: some View {
        ScrollViewReader { proxy in
            Form {
                appUpdateSection
                claudeVersionSection
                ProfilesSectionView().id("profiles")
                modelSection.id("model")
                appearanceSection.id("appearance")
                languageSection.id("language")
                behaviorSection.id("behavior")
                terminalSection.id("terminal")
                memorySection.id("memory")
                gitSection.id("git")
                updatesSection.id("updates")
                notificationsSection.id("notifications")
                dataRetentionSection.id("data-retention")
                attributionSection.id("attribution")
                teamsSection.id("teams")
                agentViewSection.id("agent-view")
                enterpriseSection.id("enterprise")
                apiKeyHelperSection.id("api-key-helper")
                aboutSection
            }
            .formStyle(.grouped)
            .onAppear {
                loadFromSettings()
                DispatchQueue.main.async { isLoaded = true }
                if let target = scrollToSection {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                        scrollToSection = nil
                    }
                }
            }
            .onChange(of: scrollToSection) {
                if let target = scrollToSection {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation { proxy.scrollTo(target, anchor: .top) }
                        scrollToSection = nil
                    }
                }
            }
            .onChange(of: configManager.settings) {
                loadFromSettings()
                DispatchQueue.main.async { isLoaded = true }
            }
        }
        .background {
            autoSaveObservers
        }
    }

    // MARK: - App Update

    private var appUpdateSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.accentColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("CC Settings v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Check for app updates via Sparkle")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Check for App Updates") {
                    sparkleUpdater?.checkForUpdates()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(sparkleUpdater == nil || !(sparkleUpdater?.canCheckForUpdates ?? false))
            }
        } header: {
            Text("CC Settings")
        }
    }

    // MARK: - Claude Code Version

    private var claudeVersionSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "terminal")
                    .font(.title2)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    if installedVersion.isEmpty {
                        Text("Claude Code")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Checking version...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Claude Code v\(installedVersion)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if isCheckingUpdate {
                            Text("Checking for updates...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if !latestVersion.isEmpty && latestVersion != installedVersion {
                            Text("v\(latestVersion) available")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else if !latestVersion.isEmpty {
                            Text("Up to date")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                    }
                }

                Spacer()

                if isUpdating {
                    ProgressView()
                        .controlSize(.small)
                    Text("Updating...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !latestVersion.isEmpty && latestVersion != installedVersion {
                    Button("Update") {
                        runUpdate()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                } else if !isCheckingUpdate {
                    Button("Check for Updates") {
                        checkForUpdates()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if !updateOutput.isEmpty {
                Text(updateOutput)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(updateOutput.contains("error") || updateOutput.contains("Error") ? .red : .secondary)
                    .lineLimit(4)
                    .textSelection(.enabled)
            }
        } header: {
            Text("Claude Code")
        }
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                fetchInstalledVersion()
                checkForUpdates()
            }
        }
    }

    private func fetchInstalledVersion() {
        Task.detached {
            let version = await runShell("claude", args: ["--version"])
            let cleaned = version.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " (Claude Code)", with: "")
            await MainActor.run {
                installedVersion = cleaned
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        latestVersion = ""
        Task.detached {
            let json = await runShell("/usr/bin/curl", args: ["-s", "https://registry.npmjs.org/@anthropic-ai/claude-code/latest"])
            var latest = ""
            if let data = json.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let v = obj["version"] as? String {
                latest = v
            }
            await MainActor.run {
                latestVersion = latest
                isCheckingUpdate = false
            }
        }
    }

    private func runUpdate() {
        isUpdating = true
        updateOutput = ""
        Task.detached {
            let output = await runShell("claude", args: ["update"])
            await MainActor.run {
                updateOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
                isUpdating = false
                // Re-check version after update
                fetchInstalledVersion()
                checkForUpdates()
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var modelSection: some View {
        Section("Model") {
            HierarchicalModelPicker(selectedModelId: $selectedModel)

            TextField("Fallback Models", text: $fallbackModels, prompt: Text("e.g. opus, sonnet"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Comma-separated chain tried in order when the primary model is overloaded or unavailable (max 3). Accepts aliases or full model IDs.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Fast Mode", isOn: $fastMode)
            Text("Enable fast mode for quicker responses.")
                .font(.caption)
                .foregroundColor(.secondary)

            if fastMode {
                Toggle("Per-Session Opt-In", isOn: $fastModePerSessionOptIn)
                Text("Require opt-in to fast mode each session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField("Advisor Model", text: $advisorModel, prompt: Text("e.g. sonnet"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Model backing the server-side advisor tool. Accepts an alias or a full model ID.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Enforce Available Models", isOn: $enforceAvailableModels)
            Text("Also constrain the Default model to the Available Models allowlist — if the tier default isn't allowed, Default falls back to the first allowed entry. No effect unless an allowlist is set.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeManager.selectedThemeName) {
                ForEach(AppTheme.allCases) { theme in
                    HStack(spacing: 6) {
                        if let color = theme.accentColor {
                            Circle()
                                .fill(color)
                                .frame(width: 10, height: 10)
                        }
                        Text(theme.displayName)
                    }
                    .tag(theme.rawValue)
                }
            }
            Text("Controls this app's window appearance only. The CLI color theme (in settings.json) is managed in the Themes section.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Reduce Motion", isOn: $prefersReducedMotion)
            Text("Reduce or disable UI animations for accessibility.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var languageSection: some View {
        Section("Language & Output") {
            TextField("Response Language", text: $language, prompt: Text("English"))
                .textFieldStyle(.roundedBorder)
            Text("Claude's preferred response language (e.g. Japanese, Spanish).")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Effort Level", selection: $effortLevel) {
                Text("Default").tag("")
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
                Text("Xhigh").tag("xhigh")
                Text("Max").tag("max")
                Text("Ultracode").tag("ultracode")
            }
            .pickerStyle(.segmented)
            Text("Controls adaptive reasoning effort on Opus models. Ultracode uses xhigh effort and lets Claude auto-orchestrate dynamic workflows.")
                .font(.caption)
                .foregroundColor(.secondary)

            dynamicWorkflowsRow

            ultracodeKeywordRow

            if dynamicWorkflowsEnabled {
                Picker("Dynamic Workflow Size", selection: $workflowSizeGuideline) {
                    Text("Default").tag("")
                    Text("Small").tag("small")
                    Text("Medium").tag("medium")
                    Text("Large").tag("large")
                    Text("Unrestricted").tag("unrestricted")
                }
                .pickerStyle(.segmented)
                Text("Advisory ceiling on how many agents Claude's workflows use — Small aims for under 5, Medium (the default) under 15, Large under 50.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            TextField("Output Style", text: $outputStyle, prompt: Text("Default"))
                .textFieldStyle(.roundedBorder)
            Text("Controls response verbosity (e.g. Explanatory, Concise).")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Verbose Output", isOn: $verbose)
            Text("Show full bash and command outputs.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Skill Visibility", selection: $skillOverrides) {
                Text("Default").tag("")
                Text("Name Only").tag("name-only")
                Text("User-Invocable Only").tag("user-invocable-only")
                Text("Off").tag("off")
            }
            .pickerStyle(.segmented)
            Text("Controls how skills appear to the model and to /. \"Name Only\" hides descriptions, \"User-Invocable Only\" hides skills from the model (still visible via /), \"Off\" hides them everywhere.")
                .font(.caption)
                .foregroundColor(.secondary)

            bundledSkillsRow
        }
    }

    @ViewBuilder
    private var dynamicWorkflowsRow: some View {
        // Save via the binding rather than another `.onChange` to keep that chain
        // under SwiftUI's type-check limit. Inverted: write `disableWorkflows: true`
        // only when off; clear the key when on.
        Toggle("Dynamic Workflows", isOn: Binding(
            get: { dynamicWorkflowsEnabled },
            set: { newValue in
                dynamicWorkflowsEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableWorkflows", value: newValue ? nil : true)
            }
        ))
        Text("Let Claude orchestrate multi-agent workflows. Turning this off disables bundled workflow commands and removes Ultracode from the effort options.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var ultracodeKeywordRow: some View {
        // Default true: clear the key when on, write `false` only when off.
        Toggle("Ultracode Keyword Trigger", isOn: Binding(
            get: { ultracodeKeywordEnabled },
            set: { newValue in
                ultracodeKeywordEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("workflowKeywordTriggerEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Typing \"ultracode\" in a prompt starts a dynamic workflow. Turn off to keep workflows available only via explicit /workflows invocation.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var bundledSkillsRow: some View {
        // Inverted: write `disableBundledSkills: true` only when off; clear the key when on.
        Toggle("Bundled Skills", isOn: Binding(
            get: { bundledSkillsEnabled },
            set: { newValue in
                bundledSkillsEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableBundledSkills", value: newValue ? nil : true)
            }
        ))
        Text("Show Claude Code's bundled skills (/code-review, /loop, /debug, …) to the model. Turn off to hide them from sessions.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var behaviorSection: some View {
        Section("Behavior") {
            Toggle("Show Turn Duration", isOn: $showTurnDuration)
            Text("Display how long each turn takes.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Respect .gitignore", isOn: $respectGitignore)
            Text("Whether the @ file picker respects .gitignore rules.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Default Shell", selection: $defaultShell) {
                Text("bash").tag("bash")
                Text("powershell").tag("powershell")
            }
            Text("Shell used for command execution.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Include Git Instructions", isOn: $includeGitInstructions)
            Text("Include git-related instructions in the system prompt.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Show Thinking Summaries", isOn: $showThinkingSummaries)
            Text("Display summaries of Claude's thinking process.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Show Clear Context on Plan Accept", isOn: $showClearContextOnPlanAccept)
            Text("Show option to clear context when accepting a plan.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Voice Dictation", isOn: $voiceEnabled)
            Text("Enable voice input for dictation.")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Toggle("Auto-Compact", isOn: $autoCompactEnabled)
                Text("Automatically summarize conversation when context limit is reached.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if autoCompactEnabled {
                    TextField("Custom Instructions", text: $autoCompactInstructions, prompt: Text("e.g. Preserve all file paths, function names..."), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    Text("Custom instructions for auto-compact summaries.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    TextField("Window Size", text: $autoCompactWindow, prompt: Text("e.g. 200000"))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Text("Token window that triggers compaction. Claude Code clamps this to 100,000–1,000,000; leave empty for the default.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Precompute Compaction", isOn: $precomputeCompactionEnabled)
                    Text("Build the compaction summary in the background before it's needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                TextField("Plans Directory", text: $plansDirectory, prompt: Text("~/.claude/plans"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Browse...") {
                    choosePlansDirectory()
                }
            }
            Text("Directory where plan files are stored.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Question Timeout", selection: $askUserQuestionTimeout) {
                Text("Default").tag("")
                Text("60s").tag("60s")
                Text("5m").tag("5m")
                Text("10m").tag("10m")
                Text("Never").tag("never")
            }
            .pickerStyle(.segmented)
            Text("How long an unanswered question from Claude waits before it continues with whatever answers it has.")
                .font(.caption)
                .foregroundColor(.secondary)

            fileCheckpointingRow

            todoPanelRow

            awaySummaryRow

            promptSuggestionRow

            emojiCompletionRow

            HStack {
                TextField("File Suggestion Script", text: $fileSuggestionCommand, prompt: Text("/path/to/suggest.sh"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Choose...") {
                    chooseFileSuggestionScript()
                }
            }
            Text("Custom script backing @ file autocomplete. Leave empty to use the built-in file search.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // Default-on toggles: clear the key when enabled, write `false`/`true` only to
    // deviate from Claude Code's default. Saved through the binding to keep the
    // `.onChange` chains under SwiftUI's type-check limit.
    @ViewBuilder
    private var fileCheckpointingRow: some View {
        Toggle("File Checkpointing", isOn: Binding(
            get: { fileCheckpointingEnabled },
            set: { newValue in
                fileCheckpointingEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("fileCheckpointingEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Snapshot files before edits so /rewind can restore them.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var todoPanelRow: some View {
        Toggle("Todo Panel", isOn: Binding(
            get: { todoFeatureEnabled },
            set: { newValue in
                todoFeatureEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("todoFeatureEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Show the todo / task tracking panel during sessions.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var awaySummaryRow: some View {
        Toggle("Away Recap", isOn: Binding(
            get: { awaySummaryEnabled },
            set: { newValue in
                awaySummaryEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("awaySummaryEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Show a one-line session recap when you come back after five minutes or more away.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var promptSuggestionRow: some View {
        Toggle("Prompt Suggestions", isOn: Binding(
            get: { promptSuggestionEnabled },
            set: { newValue in
                promptSuggestionEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("promptSuggestionEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Offer suggested prompts in the input box.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var emojiCompletionRow: some View {
        Toggle("Emoji Completion", isOn: Binding(
            get: { emojiCompletionEnabled },
            set: { newValue in
                emojiCompletionEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("emojiCompletionEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Suggest emoji for :shortcode: typed in the prompt and replace it inline.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var terminalSection: some View {
        Section("Terminal & Accessibility") {
            Toggle("Screen Reader Mode", isOn: $axScreenReader)
            Text("Render flat, screen-reader friendly output with no decorative borders or animations. Overridden by CLAUDE_AX_SCREEN_READER and --ax-screen-reader.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Message Timestamps", isOn: $showMessageTimestamps)
            Text("Stamp each message with its arrival time.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Terminal Progress Bar", isOn: $terminalProgressBarEnabled)
            Text("Emit OSC 9;4 progress sequences during long operations, so the terminal can show a progress indicator.")
                .font(.caption)
                .foregroundColor(.secondary)

            syntaxHighlightingRow

            autoScrollRow

            wheelScrollRow

            Toggle("Hide Vim Mode Indicator", isOn: $hideVimModeIndicator)
            Text("Hide the built-in -- INSERT -- / -- VISUAL -- line. Use this when your status line renders vim.mode itself.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Vim Escape Sequences", text: $vimEscapeSequences, prompt: Text("jj, kk"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Comma-separated two-character INSERT-mode sequences that return to NORMAL mode. Requires Editor Mode set to vim; <Esc> is the only target Claude Code supports.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var syntaxHighlightingRow: some View {
        // Inverted: write `syntaxHighlightingDisabled: true` only when off.
        Toggle("Syntax Highlighting", isOn: Binding(
            get: { syntaxHighlightingEnabled },
            set: { newValue in
                syntaxHighlightingEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("syntaxHighlightingDisabled", value: newValue ? nil : true)
            }
        ))
        Text("Colourise code in diffs.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var autoScrollRow: some View {
        Toggle("Auto-Scroll", isOn: Binding(
            get: { autoScrollEnabled },
            set: { newValue in
                autoScrollEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("autoScrollEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Follow new output to the bottom. Fullscreen rendering only.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var wheelScrollRow: some View {
        Toggle("Wheel Scroll Acceleration", isOn: Binding(
            get: { wheelScrollAcceleration },
            set: { newValue in
                wheelScrollAcceleration = newValue
                guard isLoaded else { return }
                configManager.saveField("wheelScrollAccelerationEnabled", value: newValue ? nil : false)
            }
        ))
        Text("Ramp mouse-wheel scroll speed during fast scrolls. Fullscreen rendering only.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var memorySection: some View {
        Section("Memory") {
            Toggle("Auto Memory", isOn: $autoMemoryEnabled)
            Text("Automatically save context to memory between sessions.")
                .font(.caption)
                .foregroundColor(.secondary)

            if autoMemoryEnabled {
                TextField("Memory Directory", text: $autoMemoryDirectory, prompt: Text("~/.claude/memory"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Directory where auto-memory files are stored.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var gitSection: some View {
        Section("Git") {
            TextField("Main Branch", text: $mainBranch, prompt: Text("main"))
                .textFieldStyle(.roundedBorder)

            Picker("Git Application", selection: $selectedGitApp) {
                Text("System Default").tag("system")
                Divider()
                ForEach(GitAppPreference.allCases) { app in
                    Label(app.rawValue, systemImage: app.icon)
                        .tag(app.rawValue)
                }
            }

            if selectedGitApp == GitAppPreference.custom.rawValue {
                HStack {
                    TextField("Custom Git App Path", text: $customGitAppPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                    Button("Browse...") {
                        chooseCustomGitApp()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var updatesSection: some View {
        Section("Updates") {
            Toggle("Automatic Updates", isOn: $autoUpdates)
            Text("Allow Claude Code to update automatically.")
                .font(.caption)
                .foregroundColor(.secondary)

            if autoUpdates {
                Picker("Update Channel", selection: $autoUpdatesChannel) {
                    Text("Stable").tag("stable")
                    Text("Latest").tag("latest")
                }
            }
        }
    }

    @ViewBuilder
    private var notificationsSection: some View {
        Section("Notifications") {
            Picker("Notification Channel", selection: $preferredNotifChannel) {
                Text("iTerm2").tag("iterm2")
                Text("iTerm2 with Bell").tag("iterm2_with_bell")
                Text("Terminal Bell").tag("terminal_bell")
                Text("Disabled").tag("notifications_disabled")
            }
        }
    }

    @ViewBuilder
    private var dataRetentionSection: some View {
        Section("Data Retention") {
            HStack {
                Text("Keep sessions for")
                Spacer()
                Text("\(Int(cleanupPeriodDays)) days")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            Slider(value: $cleanupPeriodDays, in: 1...365, step: 1)
            Text("Number of days to retain chat transcripts locally.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var attributionSection: some View {
        Section("Attribution") {
            TextField("Commit Attribution", text: $commitAttribution, prompt: Text("Default co-authored-by"))
                .textFieldStyle(.roundedBorder)
            Text("Text appended to git commits. Leave empty to use default, set to a space to hide.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("PR Attribution", text: $prAttribution, prompt: Text("Default PR text"))
                .textFieldStyle(.roundedBorder)
            Text("Text appended to pull request descriptions.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("PR URL Template", text: $prUrlTemplate, prompt: Text("https://github.com/{owner}/{repo}/pull/{number}"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Custom code-review URL for the footer PR badge. Leave empty to use github.com.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Session Link", isOn: $attributionSessionUrl)
            Text("Append the claude.ai session link to commits and PRs created from web or Remote Control sessions. Off omits the Claude-Session trailer and the PR-body link.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var teamsSection: some View {
        Section("Teams") {
            Picker("Teammate Display Mode", selection: $teammateMode) {
                Text("Auto").tag("auto")
                Text("In-Process").tag("in-process")
                Text("Tmux").tag("tmux")
                Text("iTerm2").tag("iterm2")
            }
            Text("How teammate agents are displayed in the terminal.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var agentViewSection: some View {
        Section("Agent View & Remote Control") {
            agentViewRow

            HStack {
                TextField("Subagent Status Line", text: $subagentStatusLineCommand, prompt: Text("/path/to/subagent-status.sh"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Choose...") {
                    chooseSubagentStatusLine()
                }
            }
            Text("Script rendering each row in the agent panel. Receives that row's context as JSON on stdin.")
                .font(.caption)
                .foregroundColor(.secondary)

            remoteControlRow

            if remoteControlEnabled {
                Toggle("Start at Session Start", isOn: $remoteControlAtStartup)
                Text("Bring up the Remote Control bridge automatically for every session.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Push Notifications", isOn: $agentPushNotifEnabled)
                Text("Let Claude send proactive mobile notifications while Remote Control is connected.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    @ViewBuilder
    private var agentViewRow: some View {
        // Inverted: write `disableAgentView: true` only when off.
        Toggle("Agent View", isOn: Binding(
            get: { agentViewEnabled },
            set: { newValue in
                agentViewEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableAgentView", value: newValue ? nil : true)
            }
        ))
        Text("Enable background agents — claude agents, --bg, /background and the on-demand daemon.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var remoteControlRow: some View {
        Toggle("Remote Control", isOn: Binding(
            get: { remoteControlEnabled },
            set: { newValue in
                remoteControlEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableRemoteControl", value: newValue ? nil : true)
            }
        ))
        Text("Drive this machine's sessions from claude.ai/code or the mobile app.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var enterpriseSection: some View {
        Section("Enterprise") {
            Toggle("Allow All Claude.ai MCP Connectors", isOn: $allowAllClaudeAiMcps)
            Text("Permit all cloud MCP connectors from Claude.ai without per-server approval. Typically a managed/org-admin setting.")
                .font(.caption)
                .foregroundColor(.secondary)

            claudeAiConnectorsRow

            TextField("Plugin Suggestion Marketplaces", text: $pluginSuggestionMarketplaces, prompt: Text("org-marketplace, team-tools"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated allowlist of plugin marketplaces suggested to users. Typically a managed/org-admin setting.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Strict Known Marketplaces", text: $strictKnownMarketplaces, prompt: Text("https://github.com/acme/plugins"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated exhaustive allowlist. Set in managed settings, ONLY these exact sources may be added as marketplaces — checked before download, so blocked sources never touch disk.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Blocked Marketplaces", text: $blockedMarketplaces, prompt: Text("https://github.com/untrusted/plugins"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated blocklist of marketplace sources, also checked before download.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Allowed MCP Servers", text: $allowedMcpServers, prompt: Text("github, sentry"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated allowlist of usable MCP servers across all scopes. Leave empty to allow every server; the denylist wins on conflict.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Channel Notifications", isOn: $channelsEnabled)
            Text("Org opt-in letting MCP servers with the claude/channel capability push inbound messages.")
                .font(.caption)
                .foregroundColor(.secondary)

            artifactRow

            skillShellExecutionRow

            sideloadFlagsRow

            deepLinkRow

            TextField("Feedback Survey Rate", text: $feedbackSurveyRate, prompt: Text("0.05"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
            Text("Probability from 0 to 1 that the session quality survey appears when eligible. Leave empty for the default.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var claudeAiConnectorsRow: some View {
        Toggle("Claude.ai Cloud Connectors", isOn: Binding(
            get: { claudeAiConnectorsEnabled },
            set: { newValue in
                claudeAiConnectorsEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableClaudeAiConnectors", value: newValue ? nil : true)
            }
        ))
        Text("Auto-fetch and connect claude.ai MCP cloud connectors.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var artifactRow: some View {
        // Two keys back one switch: `disableArtifact` is the hard kill switch and wins,
        // `enableArtifact` is the per-user opt-in. Turning this off writes the kill
        // switch; turning it on clears both and falls back to the default (enabled).
        Toggle("Artifact Tool", isOn: Binding(
            get: { artifactEnabled },
            set: { newValue in
                artifactEnabled = newValue
                guard isLoaded else { return }
                configManager.saveFields([
                    (keyPath: "disableArtifact", value: newValue ? nil : true),
                    (keyPath: "enableArtifact", value: nil)
                ])
            }
        ))
        Text("Let Claude publish session output with the Artifact tool.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var skillShellExecutionRow: some View {
        Toggle("Skill Shell Execution", isOn: Binding(
            get: { skillShellExecutionEnabled },
            set: { newValue in
                skillShellExecutionEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableSkillShellExecution", value: newValue ? nil : true)
            }
        ))
        Text("Run inline shell commands embedded in skills and custom slash commands. Turn off to replace them with a placeholder instead.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var sideloadFlagsRow: some View {
        Toggle("Allow Sideload Flags", isOn: Binding(
            get: { sideloadFlagsEnabled },
            set: { newValue in
                sideloadFlagsEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableSideloadFlags", value: newValue ? nil : true)
            }
        ))
        Text("Accept --plugin-dir, --plugin-url, --agents and non-SDK --mcp-config at startup. Turning this off closes the CLI-flag bypass of Strict Known Marketplaces.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var deepLinkRow: some View {
        Toggle("Deep Link Registration", isOn: Binding(
            get: { deepLinkRegistrationEnabled },
            set: { newValue in
                deepLinkRegistrationEnabled = newValue
                guard isLoaded else { return }
                configManager.saveField("disableDeepLinkRegistration", value: newValue ? nil : "disable")
            }
        ))
        Text("Register the claude-cli:// protocol handler with macOS.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var apiKeyHelperSection: some View {
        Section("API Key Helper") {
            HStack {
                TextField("Path to API key helper script", text: $apiKeyHelper)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Choose...") {
                    chooseApiKeyHelper()
                }
            }
            Text("A script or executable that returns an API key on stdout.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version") {
                Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                    .foregroundColor(.secondary)
            }
            LabeledContent("Author") {
                Text("Sebastian Kucera")
                    .foregroundColor(.secondary)
            }
            LabeledContent("GitHub") {
                Link("Rektoooooo/CC-Settings", destination: URL(string: "https://github.com/Rektoooooo/CC-Settings")!)
            }
            LabeledContent("License") {
                Text("MIT")
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Auto-Save Observers

    @ViewBuilder
    private var autoSaveObservers: some View {
        Color.clear
            .onChange(of: selectedModel) {
                guard isLoaded else { return }
                // Empty == "no override"; clear the key rather than persisting a fake default.
                configManager.saveField("model", value: selectedModel.isEmpty ? nil : selectedModel)
            }
            .onChange(of: fastMode) {
                guard isLoaded else { return }
                configManager.saveField("fastMode", value: fastMode ? true : nil)
            }
            .onChange(of: fastModePerSessionOptIn) {
                guard isLoaded else { return }
                configManager.saveField("fastModePerSessionOptIn", value: fastModePerSessionOptIn ? true : nil)
            }
            // NOTE: the app-appearance picker no longer writes settings.json "theme".
            // That mapping was lossy (ocean/forest/claude all collapsed to "dark") and
            // overwrote the CLI theme. CLI theme is managed in the Themes section.
            .onChange(of: prefersReducedMotion) {
                guard isLoaded else { return }
                configManager.saveField("prefersReducedMotion", value: prefersReducedMotion ? true : nil)
            }
            .onChange(of: language) {
                guard isLoaded else { return }
                let trimmed = language.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("language", value: trimmed.isEmpty ? nil : trimmed)
            }
            .onChange(of: effortLevel) {
                guard isLoaded else { return }
                configManager.saveField("effortLevel", value: effortLevel.isEmpty ? nil : effortLevel)
            }
            .onChange(of: outputStyle) {
                guard isLoaded else { return }
                let trimmed = outputStyle.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("outputStyle", value: trimmed.isEmpty ? nil : trimmed)
            }
            .onChange(of: verbose) {
                guard isLoaded else { return }
                configManager.saveField("verbose", value: verbose ? true : nil)
            }
            .onChange(of: skillOverrides) {
                guard isLoaded else { return }
                configManager.saveField("skillOverrides", value: skillOverrides.isEmpty ? nil : skillOverrides)
            }
            .onChange(of: showTurnDuration) {
                guard isLoaded else { return }
                configManager.saveField("showTurnDuration", value: showTurnDuration ? nil : false)
            }
            .onChange(of: respectGitignore) {
                guard isLoaded else { return }
                configManager.saveField("respectGitignore", value: respectGitignore ? nil : false)
            }
        Color.clear
            .onChange(of: defaultShell) {
                guard isLoaded else { return }
                configManager.saveField("defaultShell", value: defaultShell == "bash" ? nil : defaultShell)
            }
            .onChange(of: includeGitInstructions) {
                guard isLoaded else { return }
                configManager.saveField("includeGitInstructions", value: includeGitInstructions ? nil : false)
            }
            .onChange(of: showThinkingSummaries) {
                guard isLoaded else { return }
                configManager.saveField("showThinkingSummaries", value: showThinkingSummaries ? true : nil)
            }
            .onChange(of: showClearContextOnPlanAccept) {
                guard isLoaded else { return }
                configManager.saveField("showClearContextOnPlanAccept", value: showClearContextOnPlanAccept ? true : nil)
            }
            .onChange(of: voiceEnabled) {
                guard isLoaded else { return }
                configManager.saveField("voiceEnabled", value: voiceEnabled ? true : nil)
            }
            .onChange(of: autoMemoryEnabled) {
                guard isLoaded else { return }
                configManager.saveField("autoMemoryEnabled", value: autoMemoryEnabled ? true : nil)
            }
            .onChange(of: autoMemoryDirectory) {
                guard isLoaded else { return }
                let trimmed = autoMemoryDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("autoMemoryDirectory", value: trimmed.isEmpty ? nil : trimmed)
            }
            .onChange(of: autoCompactEnabled) {
                guard isLoaded else { return }
                saveAutoCompact()
            }
            .onChange(of: autoCompactInstructions) {
                guard isLoaded else { return }
                saveAutoCompact()
            }
            .onChange(of: plansDirectory) {
                guard isLoaded else { return }
                let trimmed = plansDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("plansDirectory", value: trimmed.isEmpty ? nil : trimmed)
            }
        Color.clear
            .onChange(of: mainBranch) {
                guard isLoaded else { return }
                let trimmed = mainBranch.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("mainBranch", value: (trimmed.isEmpty || trimmed == "main") ? nil : trimmed)
            }
            .onChange(of: selectedGitApp) {
                guard isLoaded else { return }
                saveGitApp()
            }
            .onChange(of: customGitAppPath) {
                guard isLoaded else { return }
                saveGitApp()
            }
            .onChange(of: autoUpdates) {
                guard isLoaded else { return }
                configManager.saveField("autoUpdates", value: autoUpdates ? nil : false)
            }
            .onChange(of: autoUpdatesChannel) {
                guard isLoaded else { return }
                configManager.saveField("autoUpdatesChannel", value: autoUpdatesChannel == "latest" ? nil : autoUpdatesChannel)
            }
            .onChange(of: preferredNotifChannel) {
                guard isLoaded else { return }
                configManager.saveField("preferredNotifChannel", value: preferredNotifChannel == "iterm2" ? nil : preferredNotifChannel)
            }
            .onChange(of: cleanupPeriodDays) {
                guard isLoaded else { return }
                configManager.saveField("cleanupPeriodDays", value: Int(cleanupPeriodDays) == 30 ? nil : Int(cleanupPeriodDays))
            }
            .onChange(of: commitAttribution) {
                guard isLoaded else { return }
                saveAttribution()
            }
            .onChange(of: prAttribution) {
                guard isLoaded else { return }
                saveAttribution()
            }
            .onChange(of: prUrlTemplate) {
                guard isLoaded else { return }
                let trimmed = prUrlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("prUrlTemplate", value: trimmed.isEmpty ? nil : trimmed)
            }
            .onChange(of: teammateMode) {
                guard isLoaded else { return }
                configManager.saveField("teammateMode", value: teammateMode == "auto" ? nil : teammateMode)
            }
            .onChange(of: allowAllClaudeAiMcps) {
                guard isLoaded else { return }
                configManager.saveField("allowAllClaudeAiMcps", value: allowAllClaudeAiMcps ? true : nil)
            }
            .onChange(of: pluginSuggestionMarketplaces) {
                guard isLoaded else { return }
                let parts: [String] = pluginSuggestionMarketplaces.components(separatedBy: ",")
                let list: [String] = parts
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                configManager.saveField("pluginSuggestionMarketplaces", value: list.isEmpty ? nil : list)
            }
            .onChange(of: apiKeyHelper) {
                guard isLoaded else { return }
                let trimmed = apiKeyHelper.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("apiKeyHelper", value: trimmed.isEmpty ? nil : trimmed)
            }
        Color.clear
            .onChange(of: fallbackModels) {
                guard isLoaded else { return }
                saveFallbackModels()
            }
            .onChange(of: advisorModel) {
                guard isLoaded else { return }
                saveOptionalString("advisorModel", advisorModel)
            }
            .onChange(of: enforceAvailableModels) {
                guard isLoaded else { return }
                saveFlag("enforceAvailableModels", enforceAvailableModels)
            }
            .onChange(of: workflowSizeGuideline) {
                guard isLoaded else { return }
                saveOptionalString("workflowSizeGuideline", workflowSizeGuideline)
            }
        Color.clear
            .onChange(of: askUserQuestionTimeout) {
                guard isLoaded else { return }
                saveOptionalString("askUserQuestionTimeout", askUserQuestionTimeout)
            }
            .onChange(of: autoCompactWindow) {
                guard isLoaded else { return }
                // Claude Code clamps to 100_000…1_000_000 — don't write a value it will reject
                let parsed: Int? = Int(autoCompactWindow.trimmingCharacters(in: .whitespaces))
                let valid: Int? = parsed.flatMap { (100_000...1_000_000).contains($0) ? $0 : nil }
                configManager.saveField("autoCompactWindow", value: valid)
            }
            .onChange(of: precomputeCompactionEnabled) {
                guard isLoaded else { return }
                saveFlag("precomputeCompactionEnabled", precomputeCompactionEnabled)
            }
            .onChange(of: fileSuggestionCommand) {
                guard isLoaded else { return }
                saveCommandScript("fileSuggestion", command: fileSuggestionCommand)
            }
            .onChange(of: axScreenReader) {
                guard isLoaded else { return }
                saveFlag("axScreenReader", axScreenReader)
            }
            .onChange(of: showMessageTimestamps) {
                guard isLoaded else { return }
                saveFlag("showMessageTimestamps", showMessageTimestamps)
            }
        Color.clear
            .onChange(of: terminalProgressBarEnabled) {
                guard isLoaded else { return }
                saveFlag("terminalProgressBarEnabled", terminalProgressBarEnabled)
            }
            .onChange(of: hideVimModeIndicator) {
                guard isLoaded else { return }
                saveFlag("hideVimModeIndicator", hideVimModeIndicator)
            }
            .onChange(of: vimEscapeSequences) {
                guard isLoaded else { return }
                saveVimEscapeSequences()
            }
            .onChange(of: attributionSessionUrl) {
                guard isLoaded else { return }
                saveAttribution()
            }
            .onChange(of: subagentStatusLineCommand) {
                guard isLoaded else { return }
                saveCommandScript("subagentStatusLine", command: subagentStatusLineCommand)
            }
            .onChange(of: remoteControlAtStartup) {
                guard isLoaded else { return }
                saveFlag("remoteControlAtStartup", remoteControlAtStartup)
            }
        Color.clear
            .onChange(of: agentPushNotifEnabled) {
                guard isLoaded else { return }
                saveFlag("agentPushNotifEnabled", agentPushNotifEnabled)
            }
            .onChange(of: channelsEnabled) {
                guard isLoaded else { return }
                saveFlag("channelsEnabled", channelsEnabled)
            }
            .onChange(of: allowedMcpServers) {
                guard isLoaded else { return }
                configManager.saveField("allowedMcpServers", value: commaList(allowedMcpServers))
            }
            .onChange(of: strictKnownMarketplaces) {
                guard isLoaded else { return }
                configManager.saveField("strictKnownMarketplaces", value: commaList(strictKnownMarketplaces))
            }
            .onChange(of: blockedMarketplaces) {
                guard isLoaded else { return }
                configManager.saveField("blockedMarketplaces", value: commaList(blockedMarketplaces))
            }
            .onChange(of: feedbackSurveyRate) {
                guard isLoaded else { return }
                // Out-of-range values are rejected by Claude Code — clear instead of writing
                let parsed: Double? = Double(feedbackSurveyRate.trimmingCharacters(in: .whitespaces))
                let valid: Double? = parsed.flatMap { (0.0...1.0).contains($0) ? $0 : nil }
                configManager.saveField("feedbackSurveyRate", value: valid)
            }
    }

    /// Trims and writes a string field, removing the key when the result is empty.
    /// Explicitly typed so the `Any?` parameter doesn't push the enclosing
    /// `.onChange` chain past SwiftUI's type-check budget.
    private func saveOptionalString(_ key: String, _ raw: String) {
        let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let value: String? = trimmed.isEmpty ? nil : trimmed
        configManager.saveField(key, value: value)
    }

    /// Writes `true` for an off-by-default flag, and removes the key when false.
    private func saveFlag(_ key: String, _ isOn: Bool) {
        let value: Bool? = isOn ? true : nil
        configManager.saveField(key, value: value)
    }

    /// Splits a comma-separated field into a trimmed list, or `nil` when empty so the
    /// key is removed rather than written as `[]` (which means "deny everything" for
    /// the MCP and marketplace allowlists).
    private func commaList(_ raw: String) -> [String]? {
        let parts: [String] = raw.components(separatedBy: ",")
        let list: [String] = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return list.isEmpty ? nil : list
    }

    /// `{ "type": "command", "command": "…" }`, or removed entirely when blank.
    private func saveCommandScript(_ key: String, command: String) {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            configManager.saveField(key, value: nil)
        } else {
            configManager.saveField(key, value: ["type": "command", "command": trimmed])
        }
    }

    /// Claude Code only supports `<Esc>` as a remap target and requires each key to be
    /// exactly two printable characters, so the UI collects just the sequences.
    private func saveVimEscapeSequences() {
        let parts: [String] = vimEscapeSequences.components(separatedBy: ",")
        let sequences: [String] = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.count == 2 }
        if sequences.isEmpty {
            configManager.saveField("vimInsertModeRemaps", value: nil)
        } else {
            var map: [String: String] = [:]
            for sequence in sequences { map[sequence] = "<Esc>" }
            configManager.saveField("vimInsertModeRemaps", value: map)
        }
    }

    private func saveFallbackModels() {
        let parts: [String] = fallbackModels.components(separatedBy: ",")
        let list: [String] = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Claude Code ignores entries past the third — don't write them
        configManager.saveField("fallbackModel", value: list.isEmpty ? nil : Array(list.prefix(3)))
    }

    // MARK: - Data Sync

    private func loadFromSettings() {
        isLoaded = false
        let s = configManager.settings

        // Model
        selectedModel = s.model
        fastMode = s.fastMode ?? false
        fastModePerSessionOptIn = s.fastModePerSessionOptIn ?? false
        fallbackModels = (s.fallbackModel ?? []).joined(separator: ", ")
        advisorModel = s.advisorModel ?? ""
        enforceAvailableModels = s.enforceAvailableModels ?? false

        // Appearance
        prefersReducedMotion = s.prefersReducedMotion ?? false

        // Language & Output
        language = s.language ?? ""
        effortLevel = s.effortLevel ?? ""
        dynamicWorkflowsEnabled = !(s.disableWorkflows ?? false)
        ultracodeKeywordEnabled = s.workflowKeywordTriggerEnabled ?? true
        outputStyle = s.outputStyle ?? ""
        verbose = s.verbose ?? false
        skillOverrides = s.skillOverrides ?? ""
        bundledSkillsEnabled = !(s.disableBundledSkills ?? false)
        workflowSizeGuideline = s.workflowSizeGuideline ?? ""

        // Behavior
        showTurnDuration = s.showTurnDuration ?? true
        respectGitignore = s.respectGitignore ?? true
        defaultShell = s.defaultShell ?? "bash"
        includeGitInstructions = s.includeGitInstructions ?? true
        showThinkingSummaries = s.showThinkingSummaries ?? false
        showClearContextOnPlanAccept = s.showClearContextOnPlanAccept ?? false
        voiceEnabled = s.voiceEnabled ?? false
        autoCompactEnabled = s.autoCompact != nil
        autoCompactInstructions = s.autoCompact?.customInstructions ?? ""
        plansDirectory = s.plansDirectory ?? ""
        autoCompactWindow = s.autoCompactWindow.map(String.init) ?? ""
        precomputeCompactionEnabled = s.precomputeCompactionEnabled ?? false
        todoFeatureEnabled = s.todoFeatureEnabled ?? true
        askUserQuestionTimeout = s.askUserQuestionTimeout ?? ""
        awaySummaryEnabled = s.awaySummaryEnabled ?? true
        promptSuggestionEnabled = s.promptSuggestionEnabled ?? true
        emojiCompletionEnabled = s.emojiCompletionEnabled ?? true
        fileCheckpointingEnabled = s.fileCheckpointingEnabled ?? true
        fileSuggestionCommand = s.fileSuggestion?.command ?? ""

        // Terminal & Accessibility
        axScreenReader = s.axScreenReader ?? false
        autoScrollEnabled = s.autoScrollEnabled ?? true
        wheelScrollAcceleration = s.wheelScrollAccelerationEnabled ?? true
        terminalProgressBarEnabled = s.terminalProgressBarEnabled ?? false
        showMessageTimestamps = s.showMessageTimestamps ?? false
        syntaxHighlightingEnabled = !(s.syntaxHighlightingDisabled ?? false)
        hideVimModeIndicator = s.hideVimModeIndicator ?? false
        vimEscapeSequences = (s.vimInsertModeRemaps ?? [:]).keys.sorted().joined(separator: ", ")

        // Memory
        autoMemoryEnabled = s.autoMemoryEnabled ?? false
        autoMemoryDirectory = s.autoMemoryDirectory ?? ""

        // Git
        mainBranch = s.mainBranch ?? ""
        customGitAppPath = s.customGitAppPath ?? ""
        if let gitApp = s.preferredGitApp {
            selectedGitApp = gitApp.rawValue
        } else {
            selectedGitApp = "system"
        }

        // Updates
        autoUpdates = s.autoUpdates ?? true
        autoUpdatesChannel = s.autoUpdatesChannel ?? "latest"

        // Notifications
        preferredNotifChannel = s.preferredNotifChannel ?? "iterm2"

        // Data
        cleanupPeriodDays = Double(s.cleanupPeriodDays ?? 30)

        // Attribution
        commitAttribution = s.attribution?.commit ?? ""
        prAttribution = s.attribution?.pr ?? ""
        prUrlTemplate = s.prUrlTemplate ?? ""
        attributionSessionUrl = s.attribution?.sessionUrl ?? true

        // Teams
        teammateMode = s.teammateMode ?? "auto"

        // Agent View & Remote Control
        agentViewEnabled = !(s.disableAgentView ?? false)
        subagentStatusLineCommand = s.subagentStatusLine?.command ?? ""
        remoteControlEnabled = !(s.disableRemoteControl ?? false)
        remoteControlAtStartup = s.remoteControlAtStartup ?? false
        agentPushNotifEnabled = s.agentPushNotifEnabled ?? false

        // Enterprise
        allowAllClaudeAiMcps = s.allowAllClaudeAiMcps ?? false
        pluginSuggestionMarketplaces = (s.pluginSuggestionMarketplaces ?? []).joined(separator: ", ")
        artifactEnabled = (s.enableArtifact ?? true) && !(s.disableArtifact ?? false)
        claudeAiConnectorsEnabled = !(s.disableClaudeAiConnectors ?? false)
        channelsEnabled = s.channelsEnabled ?? false
        allowedMcpServers = (s.allowedMcpServers ?? []).joined(separator: ", ")
        strictKnownMarketplaces = (s.strictKnownMarketplaces ?? []).joined(separator: ", ")
        blockedMarketplaces = (s.blockedMarketplaces ?? []).joined(separator: ", ")
        sideloadFlagsEnabled = !(s.disableSideloadFlags ?? false)
        skillShellExecutionEnabled = !(s.disableSkillShellExecution ?? false)
        deepLinkRegistrationEnabled = s.disableDeepLinkRegistration != "disable"
        feedbackSurveyRate = s.feedbackSurveyRate.map { String($0) } ?? ""

        // API Key Helper
        apiKeyHelper = s.apiKeyHelper ?? ""
    }

    // MARK: - Shell Helper

    /// Resolves the full path to the `claude` binary by checking common install locations.
    private static let claudePath: String? = {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.npm-global/bin/claude",
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    private func runShell(_ command: String, args: [String] = []) async -> String {
        let resolved: String
        if command == "claude", let path = Self.claudePath {
            resolved = path
        } else {
            resolved = command
        }

        return await withCheckedContinuation { continuation in
            // Lock-guarded mutable state shared between readability and termination
            // callbacks. Lives as a reference type so the closures capture it as `let`,
            // satisfying Swift 6 strict concurrency while still allowing mutation.
            final class State: @unchecked Sendable {
                let lock = NSLock()
                var collected = Data()
                var isHandleClosed = false

                func closeHandle(_ fileHandle: FileHandle) {
                    if !isHandleClosed {
                        fileHandle.readabilityHandler = nil
                        fileHandle.closeFile()
                        isHandleClosed = true
                    }
                }
            }
            let state = State()

            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: resolved)
            process.arguments = args
            process.standardOutput = pipe
            process.standardError = pipe

            let handle = pipe.fileHandleForReading
            handle.readabilityHandler = { fileHandle in
                let chunk = fileHandle.availableData
                state.lock.lock()
                defer { state.lock.unlock() }
                guard !chunk.isEmpty else {
                    state.closeHandle(fileHandle)
                    return
                }
                state.collected.append(chunk)
            }

            process.terminationHandler = { _ in
                state.lock.lock()
                defer { state.lock.unlock() }
                if !state.isHandleClosed {
                    let remainder = handle.availableData
                    if !remainder.isEmpty {
                        state.collected.append(remainder)
                    }
                }
                state.closeHandle(handle)
                let output = String(data: state.collected, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            }

            do {
                try process.run()
            } catch {
                state.lock.lock()
                defer { state.lock.unlock() }
                state.closeHandle(handle)
                continuation.resume(returning: "Error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Compound Field Savers

    private func saveAutoCompact() {
        if autoCompactEnabled {
            let trimmed = autoCompactInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
            var dict: [String: Any] = [:]
            if !trimmed.isEmpty { dict["customInstructions"] = trimmed }
            configManager.saveField("autoCompact", value: dict)
        } else {
            configManager.saveField("autoCompact", value: nil)
        }
    }

    private func saveAttribution() {
        let commit = commitAttribution.isEmpty ? nil : commitAttribution
        let pr = prAttribution.isEmpty ? nil : prAttribution
        // `sessionUrl` defaults to true, so only persist the opt-out. All three fields
        // are rewritten together because this writes the whole `attribution` object.
        let sessionUrl: Bool? = attributionSessionUrl ? nil : false
        if commit == nil && pr == nil && sessionUrl == nil {
            configManager.saveField("attribution", value: nil)
        } else {
            var dict: [String: Any] = [:]
            if let c = commit { dict["commit"] = c }
            if let p = pr { dict["pr"] = p }
            if let s = sessionUrl { dict["sessionUrl"] = s }
            configManager.saveField("attribution", value: dict)
        }
    }

    private func saveGitApp() {
        if selectedGitApp == "system" {
            configManager.saveFields([
                (keyPath: "preferredGitApp", value: nil),
                (keyPath: "customGitAppPath", value: nil)
            ])
        } else if let app = GitAppPreference(rawValue: selectedGitApp) {
            let customPath: String? = app == .custom ? (customGitAppPath.isEmpty ? nil : customGitAppPath) : nil
            configManager.saveFields([
                (keyPath: "preferredGitApp", value: app.rawValue),
                (keyPath: "customGitAppPath", value: customPath)
            ])
        }
    }

    // MARK: - File Pickers

    private func chooseApiKeyHelper() {
        let panel = NSOpenPanel()
        panel.title = "Choose API Key Helper"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .executable]
        if panel.runModal() == .OK, let url = panel.url {
            apiKeyHelper = url.path
        }
    }

    private func chooseCustomGitApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose Git Application"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.application]
        if panel.runModal() == .OK, let url = panel.url {
            customGitAppPath = url.path
        }
    }

    private func choosePlansDirectory() {
        let panel = NSOpenPanel()
        panel.title = "Choose Plans Directory"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            plansDirectory = url.path
        }
    }

    private func chooseFileSuggestionScript() {
        let panel = NSOpenPanel()
        panel.title = "Choose File Suggestion Script"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .executable]
        if panel.runModal() == .OK, let url = panel.url {
            fileSuggestionCommand = url.path
        }
    }

    private func chooseSubagentStatusLine() {
        let panel = NSOpenPanel()
        panel.title = "Choose Subagent Status Line Script"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.shellScript, .executable]
        if panel.runModal() == .OK, let url = panel.url {
            subagentStatusLineCommand = url.path
        }
    }
}
