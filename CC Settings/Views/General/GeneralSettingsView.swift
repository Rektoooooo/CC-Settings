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
    @State private var promptCacheTtl: String = s.promptCacheTtl ?? ""

    // Appearance
    @State private var prefersReducedMotion: Bool = s.prefersReducedMotion ?? false

    // Language & Output
    @State private var language: String = s.language ?? ""
    @State private var effortLevel: String = ""
    @State private var maxEffortLevel: String = ""
    @State private var invalidTopLevelEffort: String? = nil
    @State private var dynamicWorkflowsEnabled: Bool = !(s.disableWorkflows ?? false)
    @State private var ultracodeKeywordEnabled: Bool = s.workflowKeywordTriggerEnabled ?? true
    @State private var outputStyle: String = s.outputStyle ?? ""
    @State private var verbose: Bool = s.verbose ?? false
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
    @State private var autoCompactEnabled: Bool = s.autoCompactEnabled ?? true
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
    @State private var autoContinueAtUsageLimit: Bool = s.autoContinueAtUsageLimit ?? false
    @State private var bashOutputMaxChars: String = s.bashOutputMaxChars.map(String.init) ?? ""
    @State private var idleCompaction: Bool = s.idleCompaction ?? true
    @State private var switchModelsOnFlag: Bool = s.switchModelsOnFlag ?? true
    @State private var bashEditDiff: String = s.bashEditDiffEnabled.map { $0 ? "on" : "off" } ?? ""
    @State private var maxProseWidth: String = s.maxProseWidth.map(String.init) ?? ""
    @State private var instructionFiles: InstructionFilesMode = ConfigurationManager.shared.readInstructionFiles()
    @State private var attributionProject: String = s.attributionProject ?? ""
    @State private var attributionProjectInvalid: Bool = false
    @State private var syncClaudeAiSkills: Bool = s.syncClaudeAiSkills ?? true
    @State private var syncClaudeAiPlugins: Bool = s.syncClaudeAiPlugins ?? true

    // Terminal & Accessibility
    @State private var axScreenReader: Bool = s.axScreenReader ?? false
    @State private var autoScrollEnabled: Bool = s.autoScrollEnabled ?? true
    @State private var wheelScrollAcceleration: Bool = s.wheelScrollAccelerationEnabled ?? true
    @State private var terminalProgressBarEnabled: Bool = s.terminalProgressBarEnabled ?? false
    @State private var showMessageTimestamps: Bool = s.showMessageTimestamps ?? false
    @State private var syntaxHighlightingEnabled: Bool = !(s.syntaxHighlightingDisabled ?? false)
    @State private var hideVimModeIndicator: Bool = s.statusLine?.hideVimModeIndicator ?? false
    @State private var vimEscapeSequences: String = (s.vimInsertModeRemaps ?? [:]).keys.sorted().joined(separator: ", ")
    @State private var spellcheckEnabled: Bool = s.spellcheck?.enabled ?? false
    @State private var spellcheckChecker: String = s.spellcheck?.checker ?? ""
    @State private var spellcheckLanguage: String = s.spellcheck?.language ?? ""

    // Time & Locale
    @State private var timeFormat: String = s.timeFormat ?? ""
    @State private var timeZoneName: String = s.timeZone ?? ""

    // Memory
    @State private var autoMemoryEnabled: Bool = s.autoMemoryEnabled ?? true
    @State private var autoMemoryDirectory: String = s.autoMemoryDirectory ?? ""

    // Git
    // App-only preferences (Claude Code doesn't read them), stored in UserDefaults.
    @AppStorage(AppGitPreferences.mainBranchKey) private var mainBranch: String = ""
    @AppStorage(AppGitPreferences.appKey) private var selectedGitAppRaw: String = ""
    @AppStorage(AppGitPreferences.customPathKey) private var customGitAppPath: String = ""

    // Updates
    @State private var autoUpdates: Bool = ConfigurationManager.shared.globalAutoUpdatesEnabled()
    @State private var autoUpdatesChannel: String = s.autoUpdatesChannel ?? "latest"

    // Notifications
    @State private var preferredNotifChannel: String = s.preferredNotifChannel ?? "auto"

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
    @State private var crossSessionInbound: String = s.crossSessionInbound ?? ""
    @State private var dialogExpiry: String = s.dialogExpiry ?? ""

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
            // Claude Code snapshots the model at startup; its settings watcher never
            // updates the running session's model (verified in the 2.1.280 binary).
            Label("Applies to new Claude Code sessions. A running session keeps its model — use /model there to switch it live.", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Fallback Models", text: $fallbackModels, prompt: Text("e.g. opus, sonnet"))
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: fallbackModels) { commitFallbackModels() }
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
                .commitOnFocusLoss(of: advisorModel) { commitAdvisorModel() }
                .font(.system(.body, design: .monospaced))
            Text("Model backing the server-side advisor tool. Accepts an alias or a full model ID.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Enforce Available Models", isOn: $enforceAvailableModels)
            Text("Also constrain the Default model to the Available Models allowlist — if the tier default isn't allowed, Default falls back to the first allowed entry. No effect unless an allowlist is set.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Prompt Cache TTL", selection: $promptCacheTtl) {
                Text("Automatic").tag("")
                Text("5 minutes").tag("5m")
                Text("1 hour").tag("1h")
            }
            Text("Cache lifetime for the main conversation. Automatic means 1 hour on a Claude subscription within its usage limits, 5 minutes on an API key, Bedrock, Vertex or Foundry.")
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
                .commitOnFocusLoss(of: language) { commitLanguage() }
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
            }
            .pickerStyle(.segmented)
            .disabled(selectedModel.isEmpty)
            Text(selectedModel.isEmpty
                 ? "Choose a model above to set effort — Claude Code stores effort per model."
                 : (usesLegacyTopLevelEffort(canonicalId: canonicalModelId(selectedModel))
                    ? "Saved as the top-level effortLevel, which applies to this model."
                    : "Saved per model (modelSettings.\(canonicalModelId(selectedModel)).effortLevel), matching /effort."))
                .font(.caption)
                .foregroundColor(.secondary)
            Label("Applies to new Claude Code sessions.", systemImage: "info.circle")
                .font(.caption)
                .foregroundColor(.secondary)

            if let bad = invalidTopLevelEffort {
                HStack {
                    Label("effortLevel \"\(bad)\" in settings.json is not valid — Claude Code ignores it.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Button("Clear") {
                        configManager.clearTopLevelEffort()
                        invalidTopLevelEffort = nil
                    }
                }
            }

            Picker("Max Effort Cap", selection: $maxEffortLevel) {
                Text("None").tag("")
                ForEach(EffortLevels.cap, id: \.self) { level in
                    Text(level.capitalized).tag(level)
                }
            }
            Text("maxEffortLevel caps the effort any session can use; if several scopes set it, the lowest wins.")
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
                .commitOnFocusLoss(of: outputStyle) { commitOutputStyle() }
            Text("Controls response verbosity (e.g. Explanatory, Concise).")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Verbose Output", isOn: $verbose)
            Text("Show full bash and command outputs.")
                .font(.caption)
                .foregroundColor(.secondary)

            LabeledContent("Skill Visibility", value: skillOverridesSummary)
            Text("Per-skill overrides (skillOverrides) map a skill name to \"on\", \"name-only\", \"user-invocable-only\" or \"off\". Edit them in settings.json; this app leaves them untouched.")
                .font(.caption)
                .foregroundColor(.secondary)

            bundledSkillsRow
        }
    }

    private var skillOverridesSummary: String {
        let count = configManager.settings.skillOverrides?.count ?? 0
        return count == 0 ? "None set" : "\(count) skill override\(count == 1 ? "" : "s")"
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
                    TextField("Window Size", text: $autoCompactWindow, prompt: Text("e.g. 200000"))
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .commitOnFocusLoss(of: autoCompactWindow) { commitAutoCompactWindow() }
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
                    .commitOnFocusLoss(of: plansDirectory) { commitPlansDirectory() }
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
                    .commitOnFocusLoss(of: fileSuggestionCommand) { commitFileSuggestionCommand() }
                    .font(.system(.body, design: .monospaced))
                Button("Choose...") {
                    chooseFileSuggestionScript()
                }
            }
            Text("Custom script backing @ file autocomplete. Leave empty to use the built-in file search.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Continue Automatically at Usage Limit", isOn: $autoContinueAtUsageLimit)
            Text("Wait out a claude.ai usage limit and resume the task automatically. When off, the limit dialog offers the wait as a choice instead.")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                Text("Bash Output Limit")
                Spacer()
                TextField("30000", text: $bashOutputMaxChars)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .frame(width: 100)
                    .commitOnFocusLoss(of: bashOutputMaxChars) { commitBashOutputMaxChars() }
                Text("chars")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text("Characters of a successful shell command's output Claude receives inline. Default 30000; clamped to 4000–128000. Longer output is saved to a file Claude can read.")
                .font(.caption)
                .foregroundColor(.secondary)

            behaviorRowsV2
        }
    }

    // Claude Code 2.1.322 additions. Kept in their own builder so the Behavior section
    // stays under SwiftUI's type-check budget.
    @ViewBuilder
    private var behaviorRowsV2: some View {
        Toggle("Idle Compaction", isOn: Binding(
            get: { idleCompaction },
            set: { newValue in
                idleCompaction = newValue
                guard isLoaded else { return }
                configManager.saveDefaultOnFlag("idleCompaction", enabled: newValue)
            }
        ))
        Text("Compact a long conversation while the session is idle, before the prompt cache expires. On by default; off writes idleCompaction: false.")
            .font(.caption)
            .foregroundColor(.secondary)

        Toggle("Switch Models When a Message Is Flagged", isOn: Binding(
            get: { switchModelsOnFlag },
            set: { newValue in
                switchModelsOnFlag = newValue
                guard isLoaded else { return }
                configManager.saveDefaultOnFlag("switchModelsOnFlag", enabled: newValue)
            }
        ))
        Text("When safeguards flag a message, automatically switch to a different model to keep chatting. When off, the session pauses instead.")
            .font(.caption)
            .foregroundColor(.secondary)

        Picker("Bash Edit Diff", selection: Binding(
            get: { bashEditDiff },
            set: { newValue in
                bashEditDiff = newValue
                guard isLoaded else { return }
                configManager.saveTriStateFlag("bashEditDiffEnabled", value: newValue.isEmpty ? nil : newValue == "on")
            }
        )) {
            Text("Default").tag("")
            Text("On").tag("on")
            Text("Off").tag("off")
        }
        .pickerStyle(.segmented)
        Text("Show a diff of the files a Bash command changed. Default: off, except in auto and bypassPermissions modes. Claude Code honours \"on\" only from user, flag or policy settings (never project settings), so it is only offered here.")
            .font(.caption)
            .foregroundColor(.secondary)

        HStack {
            Text("Max Prose Width")
            Spacer()
            TextField("full width", text: $maxProseWidth)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .frame(width: 100)
                .commitOnFocusLoss(of: maxProseWidth) { commitMaxProseWidth() }
            Text("cols")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        Text("Maximum width, in terminal columns, of response prose; tables and code blocks keep the full width. Minimum 40. Empty uses the full terminal width.")
            .font(.caption)
            .foregroundColor(.secondary)

        Picker("Instruction Files", selection: Binding(
            get: { instructionFiles },
            set: { newValue in
                instructionFiles = newValue
                guard isLoaded else { return }
                configManager.saveInstructionFiles(newValue)
            }
        )) {
            ForEach(InstructionFilesMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
            }
        }
        Text("Which project instruction files load. Default: a project without a CLAUDE.md gets its AGENTS.md instead. \"Managed instructions only\" drops project and personal instruction files and keeps the organization's. Stored in pluginConfigs for the built-in agents-md plugin.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var attributionProjectRow: some View {
        TextField("Attribution Project", text: $attributionProject, prompt: Text("claude_proj_… or chan_…"))
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))
            .commitOnFocusLoss(of: attributionProject) { commitAttributionProject() }
        if attributionProjectInvalid {
            Text("Not saved: use a claude.ai Project ID starting with claude_proj_ or chan_, or the UUID of a claude_proj_ Project.")
                .font(.caption)
                .foregroundColor(.red)
        }
        Text("The claude.ai Project this session is named under in your organization's usage reports. Sent only with a claude.ai login on the direct Anthropic API; CLAUDE_CODE_ATTRIBUTION_PROJECT takes precedence. Project settings count only in trusted folders.")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    @ViewBuilder
    private var claudeAiSyncRows: some View {
        Toggle("Sync claude.ai Skills", isOn: Binding(
            get: { syncClaudeAiSkills },
            set: { newValue in
                syncClaudeAiSkills = newValue
                guard isLoaded else { return }
                configManager.saveDefaultOnFlag("syncClaudeAiSkills", enabled: newValue)
            }
        ))
        Text("Off writes syncClaudeAiSkills: false: no more downloads, and synced skills are hidden and moved to the trash folder at next launch. Only false is honoured, and it is not read from project settings.")
            .font(.caption)
            .foregroundColor(.secondary)

        Toggle("Sync claude.ai Plugins", isOn: Binding(
            get: { syncClaudeAiPlugins },
            set: { newValue in
                syncClaudeAiPlugins = newValue
                guard isLoaded else { return }
                configManager.saveDefaultOnFlag("syncClaudeAiPlugins", enabled: newValue)
            }
        ))
        Text("Off writes syncClaudeAiPlugins: false: no more downloads, and synced plugins are hidden and moved to the trash folder at next launch. Only false is honoured, and it is not read from project settings.")
            .font(.caption)
            .foregroundColor(.secondary)
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
                .disabled(configManager.settings.statusLine?.command == nil)
            Text("Hide the built-in -- INSERT -- / -- VISUAL -- line (statusLine.hideVimModeIndicator). Use this when your status line renders vim.mode itself. Needs a status line command to be configured.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Vim Escape Sequences", text: $vimEscapeSequences, prompt: Text("jj, kk"))
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: vimEscapeSequences) { commitVimEscapeSequences() }
                .font(.system(.body, design: .monospaced))
            Text("Comma-separated two-character INSERT-mode sequences that return to NORMAL mode. Requires Editor Mode set to vim; <Esc> is the only target Claude Code supports.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Time Format", selection: $timeFormat) {
                Text("Auto (locale)").tag("")
                Text("12-hour").tag("12-hour")
                Text("24-hour").tag("24-hour")
                Text("24-hour UTC").tag("24-hour-utc")
            }
            Text("Clock format for the turn-end time and transcript timestamps. A strftime pattern (any value containing %) can be set by editing settings.json directly.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Time Zone", text: $timeZoneName, prompt: Text("System default"))
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: timeZoneName) { commitTimeZoneName() }
                .font(.system(.body, design: .monospaced))
            Text("IANA time zone for times shown in the UI, e.g. UTC or Europe/Prague. Leave empty to follow the system time zone; an unknown name falls back to it.")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Spell Check Prompt Input", isOn: $spellcheckEnabled)
            Text("Underline misspelled words as you type. Requires aspell, hunspell, or ispell installed on your PATH.")
                .font(.caption)
                .foregroundColor(.secondary)

            if spellcheckEnabled {
                Picker("Spell Checker", selection: $spellcheckChecker) {
                    Text("Auto-detect").tag("")
                    Text("aspell").tag("aspell")
                    Text("hunspell").tag("hunspell")
                    Text("ispell").tag("ispell")
                }

                TextField("Dictionary", text: $spellcheckLanguage, prompt: Text("e.g. en_US"))
                    .textFieldStyle(.roundedBorder)
                    .commitOnFocusLoss(of: spellcheckLanguage) { commitSpellcheckLanguage() }
                    .font(.system(.body, design: .monospaced))
                Text("Passed to the checker as-is (aspell --lang, hunspell -d). Leave empty for the checker's default.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
            Text("Let Claude read and write the auto-memory directory. On by default; turning it off writes autoMemoryEnabled: false.")
                .font(.caption)
                .foregroundColor(.secondary)

            if autoMemoryEnabled {
                TextField("Memory Directory", text: $autoMemoryDirectory, prompt: Text("~/.claude/projects/<project>/memory"))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .commitOnFocusLoss(of: autoMemoryDirectory) { commitAutoMemoryDirectory() }
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
            Text("CC Settings only. Claude Code does not read this, so it is kept in the app's own preferences, not settings.json.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Git Application", selection: selectedGitApp) {
                Text("System Default").tag("system")
                Divider()
                ForEach(GitAppPreference.allCases) { app in
                    Label(app.rawValue, systemImage: app.icon)
                        .tag(app.rawValue)
                }
            }

            if selectedGitAppRaw == GitAppPreference.custom.rawValue {
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
            Text("Allow Claude Code to update automatically. Stored in ~/.claude.json (autoUpdates), not settings.json. Native installs can ignore it; the DISABLE_AUTOUPDATER env var also turns updates off.")
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
                Text("Auto").tag("auto")
                Text("iTerm2").tag("iterm2")
                Text("iTerm2 with Bell").tag("iterm2_with_bell")
                Text("Terminal Bell").tag("terminal_bell")
                Text("Kitty").tag("kitty")
                Text("Ghostty").tag("ghostty")
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
                .commitOnFocusLoss(of: commitAttribution) { commitCommitAttribution() }
            Text("Text appended to git commits. Leave empty to use default, set to a space to hide.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("PR Attribution", text: $prAttribution, prompt: Text("Default PR text"))
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: prAttribution) { commitPrAttribution() }
            Text("Text appended to pull request descriptions.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("PR URL Template", text: $prUrlTemplate, prompt: Text("https://github.com/{owner}/{repo}/pull/{number}"))
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .commitOnFocusLoss(of: prUrlTemplate) { commitPrUrlTemplate() }
            Text("Custom code-review URL for the footer PR badge. Leave empty to use github.com.")
                .font(.caption)
                .foregroundColor(.secondary)

            attributionProjectRow

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
                    .commitOnFocusLoss(of: subagentStatusLineCommand) { commitSubagentStatusLineCommand() }
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

            Picker("Messages From Your Other Sessions", selection: $crossSessionInbound) {
                Text("Match permission mode").tag("")
                Text("Accept").tag("accept")
                Text("Hold for review").tag("hold")
                Text("Refuse").tag("refuse")
            }
            Text("How inbound SendMessage peer messages are handled. The default delivers a message only when the sending session's permission-mode class matches this one's.")
                .font(.caption)
                .foregroundColor(.secondary)

            Picker("Dialog Expiry", selection: $dialogExpiry) {
                Text("Default").tag("")
                Text("60s").tag("60s")
                Text("5m").tag("5m")
                Text("10m").tag("10m")
                Text("Never").tag("never")
            }
            .pickerStyle(.segmented)
            Text("How long a dialog forwarded to Remote Control or an SDK host stays parked, and how long a held cross-session message awaits approval, before resolving to its safe no-action default.")
                .font(.caption)
                .foregroundColor(.secondary)
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

            claudeAiSyncRows

            TextField("Plugin Suggestion Marketplaces", text: $pluginSuggestionMarketplaces, prompt: Text("org-marketplace, team-tools"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: pluginSuggestionMarketplaces) { commitPluginSuggestionMarketplaces() }
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated allowlist of plugin marketplaces suggested to users. Typically a managed/org-admin setting.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Strict Known Marketplaces", text: $strictKnownMarketplaces, prompt: Text("https://github.com/acme/plugins"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: strictKnownMarketplaces) { commitStrictKnownMarketplaces() }
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated exhaustive allowlist. Set in managed settings, ONLY these exact sources may be added as marketplaces — checked before download, so blocked sources never touch disk.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Blocked Marketplaces", text: $blockedMarketplaces, prompt: Text("https://github.com/untrusted/plugins"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: blockedMarketplaces) { commitBlockedMarketplaces() }
                .font(.system(.body, design: .monospaced))
                .lineLimit(1...3)
            Text("Comma-separated blocklist of marketplace sources, also checked before download.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Allowed MCP Servers", text: $allowedMcpServers, prompt: Text("github, sentry"), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .commitOnFocusLoss(of: allowedMcpServers) { commitAllowedMcpServers() }
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
                .commitOnFocusLoss(of: feedbackSurveyRate) { commitFeedbackSurveyRate() }
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
                    .commitOnFocusLoss(of: apiKeyHelper) { commitApiKeyHelper() }
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
                // Effort is stored per model: show the new model's value (the effort onChange
                // below skips writes that match what is already on disk).
                reloadEffortState()
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
            .onChange(of: effortLevel) {
                guard isLoaded else { return }
                let onDisk = configManager.readEffort(forModel: selectedModel).value ?? ""
                guard effortLevel != onDisk else { return }
                configManager.saveEffortLevel(effortLevel.isEmpty ? nil : effortLevel, forModel: selectedModel)
            }
            .onChange(of: maxEffortLevel) {
                guard isLoaded else { return }
                configManager.saveMaxEffortLevel(maxEffortLevel.isEmpty ? nil : maxEffortLevel)
            }
            .onChange(of: verbose) {
                guard isLoaded else { return }
                configManager.saveField("verbose", value: verbose ? true : nil)
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
                // Claude Code defaults auto-memory to on, so only "off" is written.
                configManager.saveField("autoMemoryEnabled", value: autoMemoryEnabled ? nil : false)
            }
            .onChange(of: autoCompactEnabled) {
                guard isLoaded else { return }
                // Default is on; only "off" is written.
                configManager.saveField("autoCompactEnabled", value: autoCompactEnabled ? nil : false)
            }
        Color.clear
            .onChange(of: autoUpdates) {
                guard isLoaded else { return }
                configManager.saveGlobalAutoUpdates(autoUpdates)
            }
            .onChange(of: autoUpdatesChannel) {
                guard isLoaded else { return }
                configManager.saveField("autoUpdatesChannel", value: autoUpdatesChannel == "latest" ? nil : autoUpdatesChannel)
            }
            .onChange(of: preferredNotifChannel) {
                guard isLoaded else { return }
                configManager.saveField("preferredNotifChannel", value: preferredNotifChannel == "auto" ? nil : preferredNotifChannel)
            }
            .onChange(of: cleanupPeriodDays) {
                guard isLoaded else { return }
                configManager.saveField("cleanupPeriodDays", value: Int(cleanupPeriodDays) == 30 ? nil : Int(cleanupPeriodDays))
            }
            .onChange(of: teammateMode) {
                guard isLoaded else { return }
                configManager.saveField("teammateMode", value: teammateMode == "auto" ? nil : teammateMode)
            }
            .onChange(of: allowAllClaudeAiMcps) {
                guard isLoaded else { return }
                configManager.saveField("allowAllClaudeAiMcps", value: allowAllClaudeAiMcps ? true : nil)
            }
        Color.clear
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
            .onChange(of: precomputeCompactionEnabled) {
                guard isLoaded else { return }
                saveFlag("precomputeCompactionEnabled", precomputeCompactionEnabled)
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
                configManager.saveField("statusLine.hideVimModeIndicator", value: hideVimModeIndicator ? true : nil)
            }
            .onChange(of: attributionSessionUrl) {
                guard isLoaded else { return }
                saveAttribution()
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
        // Claude Code 2.1.221 → 2.1.263. Kept in its own Color.clear block so the
        // chain stays under SwiftUI's type-check budget.
        Color.clear
            .onChange(of: promptCacheTtl) {
                guard isLoaded else { return }
                saveOptionalString("promptCacheTtl", promptCacheTtl)
            }
            .onChange(of: autoContinueAtUsageLimit) {
                guard isLoaded else { return }
                saveFlag("autoContinueAtUsageLimit", autoContinueAtUsageLimit)
            }
            .onChange(of: timeFormat) {
                guard isLoaded else { return }
                saveOptionalString("timeFormat", timeFormat)
            }
            .onChange(of: crossSessionInbound) {
                guard isLoaded else { return }
                saveOptionalString("crossSessionInbound", crossSessionInbound)
            }
            .onChange(of: dialogExpiry) {
                guard isLoaded else { return }
                saveOptionalString("dialogExpiry", dialogExpiry)
            }
        Color.clear
            .onChange(of: spellcheckEnabled) {
                guard isLoaded else { return }
                saveSpellcheck()
            }
            .onChange(of: spellcheckChecker) {
                guard isLoaded else { return }
                saveSpellcheck()
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

    /// `spellcheck` is a nested object. Written whole so disabling it removes the key
    /// outright rather than leaving `{"enabled": false}` (or an empty `{}`) behind.
    private func saveSpellcheck() {
        guard spellcheckEnabled else {
            configManager.saveField("spellcheck", value: nil)
            return
        }
        let checker: String = spellcheckChecker.trimmingCharacters(in: .whitespacesAndNewlines)
        let language: String = spellcheckLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.saveFields([
            (keyPath: "spellcheck.enabled", value: true),
            (keyPath: "spellcheck.checker", value: checker.isEmpty ? nil : checker),
            (keyPath: "spellcheck.language", value: language.isEmpty ? nil : language)
        ])
    }

    /// Writes a positive integer field, clamped to Claude Code's accepted range.
    /// A blank or unparseable value removes the key so the CLI default applies.
    private func saveClampedInt(_ key: String, _ raw: String, min lower: Int, max upper: Int) {
        let trimmed: String = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsed = Int(trimmed) else {
            configManager.saveField(key, value: nil)
            return
        }
        configManager.saveField(key, value: Swift.min(Swift.max(parsed, lower), upper))
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

    /// Re-reads effort for the current model straight from settings.json (modelSettings and
    /// maxEffortLevel are not part of the decoded model).
    private func reloadEffortState() {
        let raw = configManager.rawSettingsObject()
        let reading = ConfigurationManager.readEffort(in: raw, model: selectedModel)
        effortLevel = reading.value ?? ""
        invalidTopLevelEffort = reading.invalidTopLevel
        maxEffortLevel = raw["maxEffortLevel"] as? String ?? ""
    }

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
        promptCacheTtl = s.promptCacheTtl ?? ""

        // Appearance
        prefersReducedMotion = s.prefersReducedMotion ?? false

        // Language & Output
        language = s.language ?? ""
        reloadEffortState()
        dynamicWorkflowsEnabled = !(s.disableWorkflows ?? false)
        ultracodeKeywordEnabled = s.workflowKeywordTriggerEnabled ?? true
        outputStyle = s.outputStyle ?? ""
        verbose = s.verbose ?? false
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
        autoCompactEnabled = s.autoCompactEnabled ?? true
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
        autoContinueAtUsageLimit = s.autoContinueAtUsageLimit ?? false
        bashOutputMaxChars = s.bashOutputMaxChars.map(String.init) ?? ""

        // Terminal & Accessibility
        axScreenReader = s.axScreenReader ?? false
        autoScrollEnabled = s.autoScrollEnabled ?? true
        wheelScrollAcceleration = s.wheelScrollAccelerationEnabled ?? true
        terminalProgressBarEnabled = s.terminalProgressBarEnabled ?? false
        showMessageTimestamps = s.showMessageTimestamps ?? false
        syntaxHighlightingEnabled = !(s.syntaxHighlightingDisabled ?? false)
        hideVimModeIndicator = s.statusLine?.hideVimModeIndicator ?? false
        vimEscapeSequences = (s.vimInsertModeRemaps ?? [:]).keys.sorted().joined(separator: ", ")
        spellcheckEnabled = s.spellcheck?.enabled ?? false
        spellcheckChecker = s.spellcheck?.checker ?? ""
        spellcheckLanguage = s.spellcheck?.language ?? ""
        timeFormat = s.timeFormat ?? ""
        timeZoneName = s.timeZone ?? ""

        // Memory
        autoMemoryEnabled = s.autoMemoryEnabled ?? true
        autoMemoryDirectory = s.autoMemoryDirectory ?? ""

        // Git
        AppGitPreferences.migrateIfNeeded(from: s)

        // Updates
        autoUpdates = configManager.globalAutoUpdatesEnabled()
        autoUpdatesChannel = s.autoUpdatesChannel ?? "latest"

        // Notifications
        preferredNotifChannel = s.preferredNotifChannel ?? "auto"

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
        crossSessionInbound = s.crossSessionInbound ?? ""
        dialogExpiry = s.dialogExpiry ?? ""

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
        idleCompaction = s.idleCompaction ?? true
        switchModelsOnFlag = s.switchModelsOnFlag ?? true
        bashEditDiff = s.bashEditDiffEnabled.map { $0 ? "on" : "off" } ?? ""
        maxProseWidth = s.maxProseWidth.map(String.init) ?? ""
        instructionFiles = configManager.readInstructionFiles()
        attributionProject = s.attributionProject ?? ""
        attributionProjectInvalid = false
        syncClaudeAiSkills = s.syncClaudeAiSkills ?? true
        syncClaudeAiPlugins = s.syncClaudeAiPlugins ?? true

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

    // MARK: - Commit handlers (run on Return / focus loss / navigating away)

    private func commitLanguage() {
        guard isLoaded else { return }
        saveOptionalString("language", language)
    }

    private func commitOutputStyle() {
        guard isLoaded else { return }
        saveOptionalString("outputStyle", outputStyle)
    }

    private func commitPlansDirectory() {
        guard isLoaded else { return }
        saveOptionalString("plansDirectory", plansDirectory)
    }

    private func commitAutoMemoryDirectory() {
        guard isLoaded else { return }
        saveOptionalString("autoMemoryDirectory", autoMemoryDirectory)
    }

    private func commitFallbackModels() {
        guard isLoaded else { return }
        saveFallbackModels()
    }

    private func commitAdvisorModel() {
        guard isLoaded else { return }
        saveOptionalString("advisorModel", advisorModel)
    }

    private func commitFileSuggestionCommand() {
        guard isLoaded else { return }
        saveCommandScript("fileSuggestion", command: fileSuggestionCommand)
    }

    private func commitVimEscapeSequences() {
        guard isLoaded else { return }
        saveVimEscapeSequences()
    }

    private func commitTimeZoneName() {
        guard isLoaded else { return }
        saveOptionalString("timeZone", timeZoneName)
    }

    private func commitSpellcheckLanguage() {
        guard isLoaded else { return }
        saveSpellcheck()
    }

    private func commitCommitAttribution() {
        guard isLoaded else { return }
        saveAttribution()
    }

    private func commitPrAttribution() {
        guard isLoaded else { return }
        saveAttribution()
    }

    private func commitSubagentStatusLineCommand() {
        guard isLoaded else { return }
        saveCommandScript("subagentStatusLine", command: subagentStatusLineCommand)
    }

    private func commitPluginSuggestionMarketplaces() {
        guard isLoaded else { return }
        let parts: [String] = pluginSuggestionMarketplaces.components(separatedBy: ",")
        let list: [String] = parts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        configManager.saveField("pluginSuggestionMarketplaces", value: list.isEmpty ? nil : list)
    }

    private func commitStrictKnownMarketplaces() {
        guard isLoaded else { return }
        configManager.saveField("strictKnownMarketplaces", value: commaList(strictKnownMarketplaces))
    }

    private func commitBlockedMarketplaces() {
        guard isLoaded else { return }
        configManager.saveField("blockedMarketplaces", value: commaList(blockedMarketplaces))
    }

    private func commitAllowedMcpServers() {
        guard isLoaded else { return }
        configManager.saveField("allowedMcpServers", value: commaList(allowedMcpServers))
    }

    /// Claude Code requires an integer >= 40. An invalid entry snaps back to what is stored.
    private func commitMaxProseWidth() {
        guard isLoaded else { return }
        if !configManager.saveMaxProseWidth(maxProseWidth) {
            maxProseWidth = configManager.settings.maxProseWidth.map(String.init) ?? ""
        }
    }

    private func commitAttributionProject() {
        guard isLoaded else { return }
        attributionProjectInvalid = !configManager.saveAttributionProject(attributionProject)
    }

    private func commitPrUrlTemplate() {
        guard isLoaded else { return }
        saveOptionalString("prUrlTemplate", prUrlTemplate)
    }

    private func commitApiKeyHelper() {
        guard isLoaded else { return }
        saveOptionalString("apiKeyHelper", apiKeyHelper)
    }

    private func commitBashOutputMaxChars() {
        guard isLoaded else { return }
        saveClampedInt("bashOutputMaxChars", bashOutputMaxChars, min: 4000, max: 128000)
    }

    /// Claude Code accepts 100_000…1_000_000. An empty field clears the key; an out-of-range
    /// or non-numeric entry is discarded and the field snaps back to what is stored.
    private func commitAutoCompactWindow() {
        guard isLoaded else { return }
        let trimmed = autoCompactWindow.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            configManager.saveField("autoCompactWindow", value: nil)
        } else if let parsed = Int(trimmed), (100_000...1_000_000).contains(parsed) {
            configManager.saveField("autoCompactWindow", value: parsed)
        } else {
            autoCompactWindow = configManager.settings.autoCompactWindow.map(String.init) ?? ""
        }
    }

    /// Claude Code requires 0…1. Same empty / invalid handling as `commitAutoCompactWindow`.
    private func commitFeedbackSurveyRate() {
        guard isLoaded else { return }
        let trimmed = feedbackSurveyRate.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            configManager.saveField("feedbackSurveyRate", value: nil)
        } else if let parsed = Double(trimmed), (0.0...1.0).contains(parsed) {
            configManager.saveField("feedbackSurveyRate", value: parsed)
        } else {
            feedbackSurveyRate = configManager.settings.feedbackSurveyRate.map { String($0) } ?? ""
        }
    }

    private var selectedGitApp: Binding<String> {
        Binding(
            get: { selectedGitAppRaw.isEmpty ? "system" : selectedGitAppRaw },
            set: { selectedGitAppRaw = $0 == "system" ? "" : $0 }
        )
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
            // Dotted paths so any other attribution key survives.
            configManager.saveFields([
                (keyPath: "attribution.commit", value: commit),
                (keyPath: "attribution.pr", value: pr),
                (keyPath: "attribution.sessionUrl", value: sessionUrl)
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
            commitApiKeyHelper()
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
            commitFileSuggestionCommand()
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
            commitSubagentStatusLineCommand()
        }
    }
}
