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
    @State private var effortLevel: String = "high"
    @State private var outputStyle: String = ""
    @State private var verbose: Bool = false

    // Behavior
    @State private var showTurnDuration: Bool = true
    @State private var respectGitignore: Bool = true
    @State private var autoCompactEnabled: Bool = true
    @State private var autoCompactInstructions: String = ""
    @State private var plansDirectory: String = ""

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

    var body: some View {
        Form {
            // MARK: - Model
            Section("Model") {
                HierarchicalModelPicker(selectedModelId: $configManager.settings.model)
            }

            // MARK: - Appearance
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

            // MARK: - Language & Output
            Section("Language & Output") {
                TextField("Response Language", text: $language, prompt: Text("English"))
                    .textFieldStyle(.roundedBorder)
                Text("Claude's preferred response language (e.g. Japanese, Spanish).")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Effort Level", selection: $effortLevel) {
                    Text("Low").tag("low")
                    Text("Medium").tag("medium")
                    Text("High").tag("high")
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

            // MARK: - Behavior
            Section("Behavior") {
                Toggle("Show Turn Duration", isOn: $showTurnDuration)
                Text("Display how long each turn takes.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Toggle("Respect .gitignore", isOn: $respectGitignore)
                Text("Whether the @ file picker respects .gitignore rules.")
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

            // MARK: - Git
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

            // MARK: - Updates
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

            // MARK: - Notifications
            Section("Notifications") {
                Picker("Notification Channel", selection: $preferredNotifChannel) {
                    Text("iTerm2").tag("iterm2")
                    Text("iTerm2 with Bell").tag("iterm2_with_bell")
                    Text("Terminal Bell").tag("terminal_bell")
                    Text("Disabled").tag("notifications_disabled")
                }
            }

            // MARK: - Data Retention
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

            // MARK: - Attribution
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

            // MARK: - Teams
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

            // MARK: - API Key Helper
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
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    save()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .onAppear {
            loadFromSettings()
        }
    }

    // MARK: - Data Sync

    private func loadFromSettings() {
        let s = configManager.settings

        // Appearance
        prefersReducedMotion = s.prefersReducedMotion ?? false

        // Language & Output
        language = s.language ?? ""
        effortLevel = s.effortLevel ?? "high"
        outputStyle = s.outputStyle ?? ""
        verbose = s.verbose ?? false

        // Behavior
        showTurnDuration = s.showTurnDuration ?? true
        respectGitignore = s.respectGitignore ?? true
        autoCompactEnabled = s.autoCompact != nil
        autoCompactInstructions = s.autoCompact?.customInstructions ?? ""
        plansDirectory = s.plansDirectory ?? ""

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

    private func save() {
        // Appearance
        configManager.settings.theme = themeManager.currentTheme.cliTheme
        configManager.settings.prefersReducedMotion = prefersReducedMotion ? true : nil

        // Language & Output
        let trimmedLang = language.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.settings.language = trimmedLang.isEmpty ? nil : trimmedLang
        configManager.settings.effortLevel = effortLevel == "high" ? nil : effortLevel
        let trimmedStyle = outputStyle.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.settings.outputStyle = trimmedStyle.isEmpty ? nil : trimmedStyle
        configManager.settings.verbose = verbose ? true : nil

        // Behavior
        configManager.settings.showTurnDuration = showTurnDuration ? nil : false
        configManager.settings.respectGitignore = respectGitignore ? nil : false
        if autoCompactEnabled {
            let trimmedInstructions = autoCompactInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
            configManager.settings.autoCompact = AutoCompactConfig(
                customInstructions: trimmedInstructions.isEmpty ? nil : trimmedInstructions
            )
        } else {
            configManager.settings.autoCompact = nil
        }
        let trimmedPlans = plansDirectory.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.settings.plansDirectory = trimmedPlans.isEmpty ? nil : trimmedPlans

        // Git
        let trimmedBranch = mainBranch.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.settings.mainBranch = (trimmedBranch.isEmpty || trimmedBranch == "main") ? nil : trimmedBranch
        if selectedGitApp == "system" {
            configManager.settings.preferredGitApp = nil
            configManager.settings.customGitAppPath = nil
        } else if let app = GitAppPreference(rawValue: selectedGitApp) {
            configManager.settings.preferredGitApp = app
            configManager.settings.customGitAppPath = app == .custom ? (customGitAppPath.isEmpty ? nil : customGitAppPath) : nil
        }

        // Updates
        configManager.settings.autoUpdates = autoUpdates ? nil : false
        configManager.settings.autoUpdatesChannel = autoUpdatesChannel == "latest" ? nil : autoUpdatesChannel

        // Notifications
        configManager.settings.preferredNotifChannel = preferredNotifChannel == "iterm2" ? nil : preferredNotifChannel

        // Data
        configManager.settings.cleanupPeriodDays = Int(cleanupPeriodDays) == 30 ? nil : Int(cleanupPeriodDays)

        // Attribution
        let trimmedCommit = commitAttribution.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPR = prAttribution.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCommit.isEmpty && trimmedPR.isEmpty {
            configManager.settings.attribution = nil
        } else {
            configManager.settings.attribution = AttributionConfig(
                commit: trimmedCommit.isEmpty ? nil : trimmedCommit,
                pr: trimmedPR.isEmpty ? nil : trimmedPR
            )
        }

        // Teams
        configManager.settings.teammateMode = teammateMode == "auto" ? nil : teammateMode

        // API Key Helper
        let trimmedHelper = apiKeyHelper.trimmingCharacters(in: .whitespacesAndNewlines)
        configManager.settings.apiKeyHelper = trimmedHelper.isEmpty ? nil : trimmedHelper

        configManager.saveSettings()
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
