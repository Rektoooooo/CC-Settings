import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @EnvironmentObject var themeManager: ThemeManager

    // Model
    // (bound directly via $configManager.settings.model)

    // Appearance
    @State private var prefersReducedMotion: Bool = false

    // Language & Output
    @State private var language: String = ""
    @State private var effortLevel: String = ""
    @State private var outputStyle: String = ""
    @State private var verbose: Bool = false

    // Behavior
    @State private var showTurnDuration: Bool = true
    @State private var respectGitignore: Bool = true
    @State private var defaultShell: String = "bash"
    @State private var includeGitInstructions: Bool = true
    @State private var showThinkingSummaries: Bool = false
    @State private var showClearContextOnPlanAccept: Bool = false
    @State private var voiceEnabled: Bool = false
    @State private var autoCompactEnabled: Bool = true
    @State private var autoCompactInstructions: String = ""
    @State private var plansDirectory: String = ""

    // Memory
    @State private var autoMemoryEnabled: Bool = false
    @State private var autoMemoryDirectory: String = ""

    // Git
    @State private var mainBranch: String = ""
    @State private var selectedGitApp: String = "system"
    @State private var customGitAppPath: String = ""

    // Updates
    @State private var autoUpdates: Bool = true
    @State private var autoUpdatesChannel: String = "latest"

    // Notifications
    @State private var preferredNotifChannel: String = "iterm2"

    // Data Retention
    @State private var cleanupPeriodDays: Double = 30

    // Attribution
    @State private var commitAttribution: String = ""
    @State private var prAttribution: String = ""

    // Teams
    @State private var teammateMode: String = "auto"

    // API Key Helper
    @State private var apiKeyHelper: String = ""

    // Claude Code Version
    @State private var installedVersion: String = ""
    @State private var latestVersion: String = ""
    @State private var isCheckingUpdate: Bool = false
    @State private var isUpdating: Bool = false
    @State private var updateOutput: String = ""

    // Prevents onChange from firing during initial load
    @State private var isLoaded: Bool = false

    var body: some View {
        Form {
            claudeVersionSection
            ProfilesSectionView()
            modelSection
            appearanceSection
            languageSection
            behaviorSection
            memorySection
            gitSection
            updatesSection
            notificationsSection
            dataRetentionSection
            attributionSection
            teamsSection
            apiKeyHelperSection
            aboutSection
        }
        .formStyle(.grouped)
        .onAppear {
            loadFromSettings()
            // Defer isLoaded so onChange handlers (fired by @State changes above)
            // still see isLoaded == false and skip the spurious save.
            DispatchQueue.main.async { isLoaded = true }
        }
        .onChange(of: configManager.settings) {
            // Suppress saves during external reload to avoid feedback loop
            loadFromSettings()
            DispatchQueue.main.async { isLoaded = true }
        }
        .background {
            autoSaveObservers
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
            fetchInstalledVersion()
            checkForUpdates()
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
            HierarchicalModelPicker(selectedModelId: $configManager.settings.model)

            Toggle("Fast Mode", isOn: Binding(
                get: { configManager.settings.fastMode ?? false },
                set: { configManager.settings.fastMode = $0 ? true : nil }
            ))
            .onChange(of: configManager.settings.fastMode) {
                        configManager.saveField("fastMode", value: configManager.settings.fastMode)
                    }
            Text("Enable fast mode for quicker responses.")
                .font(.caption)
                .foregroundColor(.secondary)

            if configManager.settings.fastMode ?? false {
                Toggle("Per-Session Opt-In", isOn: Binding(
                    get: { configManager.settings.fastModePerSessionOptIn ?? false },
                    set: { configManager.settings.fastModePerSessionOptIn = $0 ? true : nil }
                ))
                .onChange(of: configManager.settings.fastModePerSessionOptIn) {
                        configManager.saveField("fastModePerSessionOptIn", value: configManager.settings.fastModePerSessionOptIn)
                    }
                Text("Require opt-in to fast mode each session.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
                Text("Auto").tag("auto")
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
                Text("Max").tag("max")
            }
            .pickerStyle(.segmented)
            Text("Controls Opus 4.6 adaptive reasoning effort.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextField("Output Style", text: $outputStyle, prompt: Text("Default"))
                .textFieldStyle(.roundedBorder)
            Text("Controls response verbosity (e.g. Explanatory, Concise).")
                .font(.caption)
                .foregroundColor(.secondary)

            Toggle("Verbose Output", isOn: $verbose)
            Text("Show full bash and command outputs.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
        }
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
        }
    }

    @ViewBuilder
    private var teamsSection: some View {
        Section("Teams") {
            Picker("Teammate Display Mode", selection: $teammateMode) {
                Text("Auto").tag("auto")
                Text("In-Process").tag("in-process")
                Text("Tmux").tag("tmux")
            }
            Text("How teammate agents are displayed in the terminal.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
            .onChange(of: configManager.settings.model) {
                guard isLoaded else { return }
                configManager.saveField("model", value: configManager.settings.model)
            }
            .onChange(of: themeManager.selectedThemeName) {
                guard isLoaded else { return }
                configManager.saveField("theme", value: themeManager.currentTheme.cliTheme)
            }
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
            .onChange(of: teammateMode) {
                guard isLoaded else { return }
                configManager.saveField("teammateMode", value: teammateMode == "auto" ? nil : teammateMode)
            }
            .onChange(of: apiKeyHelper) {
                guard isLoaded else { return }
                let trimmed = apiKeyHelper.trimmingCharacters(in: .whitespacesAndNewlines)
                configManager.saveField("apiKeyHelper", value: trimmed.isEmpty ? nil : trimmed)
            }
    }

    // MARK: - Data Sync

    private func loadFromSettings() {
        isLoaded = false
        let s = configManager.settings

        // Appearance
        prefersReducedMotion = s.prefersReducedMotion ?? false

        // Language & Output
        language = s.language ?? ""
        effortLevel = s.effortLevel ?? ""
        outputStyle = s.outputStyle ?? ""
        verbose = s.verbose ?? false

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

        // Teams
        teammateMode = s.teammateMode ?? "auto"

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

        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: resolved)
        process.arguments = args
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error.localizedDescription)"
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
        if commit == nil && pr == nil {
            configManager.saveField("attribution", value: nil)
        } else {
            var dict: [String: Any] = [:]
            if let c = commit { dict["commit"] = c }
            if let p = pr { dict["pr"] = p }
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
}
