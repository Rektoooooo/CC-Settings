import SwiftUI

// MARK: - Known Tools

enum ClaudeTool: String, CaseIterable, Identifiable {
    case bash = "Bash"
    case read = "Read"
    case write = "Write"
    case edit = "Edit"
    case multiEdit = "MultiEdit"
    case glob = "Glob"
    case grep = "Grep"
    case ls = "LS"
    case webFetch = "WebFetch"
    case webSearch = "WebSearch"
    case task = "Task"
    case notebookEdit = "NotebookEdit"
    case notebookRead = "NotebookRead"
    case todoWrite = "TodoWrite"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .bash: return "terminal"
        case .read: return "doc.text"
        case .write: return "square.and.pencil"
        case .edit: return "pencil.line"
        case .multiEdit: return "pencil.and.list.clipboard"
        case .glob: return "magnifyingglass"
        case .grep: return "text.magnifyingglass"
        case .ls: return "folder"
        case .webFetch: return "network"
        case .webSearch: return "globe"
        case .task: return "person.2"
        case .notebookEdit: return "book"
        case .notebookRead: return "book.pages"
        case .todoWrite: return "checklist"
        }
    }

    var description: String {
        switch self {
        case .bash: return "Execute shell commands"
        case .read: return "Read file contents"
        case .write: return "Create new files"
        case .edit: return "Edit existing files"
        case .multiEdit: return "Edit multiple files at once"
        case .glob: return "Search for files by pattern"
        case .grep: return "Search file contents"
        case .ls: return "List directory contents"
        case .webFetch: return "Fetch web page content"
        case .webSearch: return "Search the web"
        case .task: return "Spawn sub-agents"
        case .notebookEdit: return "Edit Jupyter notebooks"
        case .notebookRead: return "Read Jupyter notebooks"
        case .todoWrite: return "Write to task list"
        }
    }
}

// MARK: - Permission State

enum PermissionState: String, CaseIterable {
    case notSet = "Default"
    case allow = "Allow"
    case deny = "Deny"
    case ask = "Ask"

    var color: Color {
        switch self {
        case .notSet: return .secondary
        case .allow: return .green
        case .deny: return .red
        case .ask: return .orange
        }
    }

    var icon: String {
        switch self {
        case .notSet: return "minus.circle"
        case .allow: return "checkmark.circle.fill"
        case .deny: return "xmark.circle.fill"
        case .ask: return "questionmark.circle.fill"
        }
    }
}

// MARK: - Custom Rule

struct CustomPermissionRule: Identifiable, Equatable {
    let id = UUID()
    var pattern: String
    var state: PermissionState

    var toolName: String {
        if let paren = pattern.firstIndex(of: "(") {
            return String(pattern[pattern.startIndex..<paren])
        }
        return pattern
    }

    var specifier: String {
        guard let openParen = pattern.firstIndex(of: "("),
              let closeParen = pattern.lastIndex(of: ")") else { return "" }
        let start = pattern.index(after: openParen)
        return String(pattern[start..<closeParen])
    }
}

// MARK: - Permission Mode

enum DefaultPermissionMode: String, CaseIterable, Identifiable {
    case defaultMode = "default"
    case acceptEdits = "acceptEdits"
    case plan = "plan"
    case bypassPermissions = "bypassPermissions"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .defaultMode: return "Default"
        case .acceptEdits: return "Accept Edits"
        case .plan: return "Plan Mode"
        case .bypassPermissions: return "Bypass All"
        }
    }

    var description: String {
        switch self {
        case .defaultMode: return "Ask for permission on each tool use"
        case .acceptEdits: return "Auto-approve file edits, ask for other tools"
        case .plan: return "Require plan approval before implementation"
        case .bypassPermissions: return "Auto-approve all tool use (dangerous)"
        }
    }
}

// MARK: - Permissions View

struct PermissionsView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    @State private var toolPermissions: [ClaudeTool: PermissionState] = [:]
    @State private var customRules: [CustomPermissionRule] = []
    @State private var defaultMode: DefaultPermissionMode = .defaultMode
    @State private var additionalDirectories: [String] = []
    @State private var newDirectory: String = ""
    @State private var showingAddRule = false
    @State private var newRuleToolName: String = "Bash"
    @State private var newRuleSpecifier: String = ""
    @State private var newRuleState: PermissionState = .allow

    var body: some View {
        Form {
            // MARK: - Default Mode
            Section {
                Picker("Default Permission Mode", selection: $defaultMode) {
                    ForEach(DefaultPermissionMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                Text(defaultMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if defaultMode == .bypassPermissions {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                        Text("Bypass mode auto-approves all actions including destructive operations.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Default Mode")
            }

            // MARK: - Tool Permissions
            Section {
                ForEach(ClaudeTool.allCases) { tool in
                    ToolPermissionRow(
                        tool: tool,
                        state: Binding(
                            get: { toolPermissions[tool] ?? .notSet },
                            set: { newState in
                                toolPermissions[tool] = newState
                                savePermissions()
                            }
                        )
                    )
                }
            } header: {
                Text("Tool Permissions")
            } footer: {
                Text("Set per-tool permissions. \"Default\" follows the default permission mode above.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Custom Rules
            Section {
                if customRules.isEmpty && !showingAddRule {
                    Text("No custom rules. Add rules for granular control like Bash(git push *) or Read(.env).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                ForEach($customRules) { $rule in
                    CustomRuleRow(rule: $rule, onDelete: {
                        customRules.removeAll { $0.id == rule.id }
                        savePermissions()
                    }, onChange: {
                        savePermissions()
                    })
                }

                if showingAddRule {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Picker("Tool", selection: $newRuleToolName) {
                                ForEach(ClaudeTool.allCases) { tool in
                                    Text(tool.rawValue).tag(tool.rawValue)
                                }
                            }
                            .frame(width: 140)

                            TextField("pattern (e.g. git push *)", text: $newRuleSpecifier)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))

                            Picker("", selection: $newRuleState) {
                                Image(systemName: "checkmark.circle.fill").tag(PermissionState.allow)
                                Image(systemName: "xmark.circle.fill").tag(PermissionState.deny)
                                Image(systemName: "questionmark.circle.fill").tag(PermissionState.ask)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                        }

                        HStack {
                            Text("Result: ")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(newRuleFullPattern)
                                .font(.system(.caption, design: .monospaced))

                            Spacer()

                            Button("Cancel") {
                                showingAddRule = false
                                newRuleSpecifier = ""
                            }
                            Button("Add") {
                                addCustomRule()
                            }
                            .disabled(newRuleSpecifier.trimmingCharacters(in: .whitespaces).isEmpty)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                    }
                    .padding(.vertical, 4)
                } else {
                    Button {
                        showingAddRule = true
                    } label: {
                        Label("Add Custom Rule", systemImage: "plus")
                    }
                }
            } header: {
                Text("Custom Rules")
            } footer: {
                Text("Rules with specifiers like Bash(npm run lint) or Read(~/.zshrc) for fine-grained control.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // MARK: - Additional Directories
            Section {
                ForEach(Array(additionalDirectories.enumerated()), id: \.offset) { index, dir in
                    HStack {
                        Image(systemName: "folder")
                            .foregroundColor(.secondary)
                        Text(dir)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            additionalDirectories.remove(at: index)
                            savePermissions()
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    TextField("Directory path (e.g. ../docs/)", text: $newDirectory)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .onSubmit { addDirectory() }
                    Button("Add") {
                        addDirectory()
                    }
                    .disabled(newDirectory.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("Additional Directories")
            } footer: {
                Text("Extra directories Claude Code can access beyond the working directory.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    savePermissions()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }
                .keyboardShortcut("s", modifiers: .command)
            }
        }
        .onAppear {
            loadPermissions()
        }
    }

    // MARK: - Computed

    private var newRuleFullPattern: String {
        let specifier = newRuleSpecifier.trimmingCharacters(in: .whitespaces)
        if specifier.isEmpty {
            return newRuleToolName
        }
        return "\(newRuleToolName)(\(specifier))"
    }

    // MARK: - Actions

    private func addCustomRule() {
        let pattern = newRuleFullPattern
        let rule = CustomPermissionRule(pattern: pattern, state: newRuleState)
        customRules.append(rule)
        newRuleSpecifier = ""
        showingAddRule = false
        savePermissions()
    }

    private func addDirectory() {
        let trimmed = newDirectory.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        additionalDirectories.append(trimmed)
        newDirectory = ""
        savePermissions()
    }

    // MARK: - Data Sync

    private func loadPermissions() {
        let perms = configManager.settings.permissions
        let allowList = perms.allow ?? []
        let denyList = perms.deny ?? []
        let askList = perms.ask ?? []

        // Parse tool-level permissions (no specifier)
        var toolPerms: [ClaudeTool: PermissionState] = [:]
        var customs: [CustomPermissionRule] = []

        for pattern in allowList {
            if let tool = ClaudeTool(rawValue: pattern) {
                toolPerms[tool] = .allow
            } else {
                customs.append(CustomPermissionRule(pattern: pattern, state: .allow))
            }
        }
        for pattern in denyList {
            if let tool = ClaudeTool(rawValue: pattern) {
                toolPerms[tool] = .deny
            } else {
                customs.append(CustomPermissionRule(pattern: pattern, state: .deny))
            }
        }
        for pattern in askList {
            if let tool = ClaudeTool(rawValue: pattern) {
                toolPerms[tool] = .ask
            } else {
                customs.append(CustomPermissionRule(pattern: pattern, state: .ask))
            }
        }

        toolPermissions = toolPerms
        customRules = customs

        // Default mode
        if let mode = perms.defaultMode, let parsed = DefaultPermissionMode(rawValue: mode) {
            defaultMode = parsed
        }

        // Additional directories
        additionalDirectories = perms.additionalDirectories ?? []
    }

    private func savePermissions() {
        var allow: [String] = []
        var deny: [String] = []
        var ask: [String] = []

        // Tool-level permissions
        for (tool, state) in toolPermissions {
            switch state {
            case .allow: allow.append(tool.rawValue)
            case .deny: deny.append(tool.rawValue)
            case .ask: ask.append(tool.rawValue)
            case .notSet: break
            }
        }

        // Custom rules
        for rule in customRules {
            switch rule.state {
            case .allow: allow.append(rule.pattern)
            case .deny: deny.append(rule.pattern)
            case .ask: ask.append(rule.pattern)
            case .notSet: break
            }
        }

        configManager.settings.permissions.allow = allow.isEmpty ? nil : allow.sorted()
        configManager.settings.permissions.deny = deny.isEmpty ? nil : deny.sorted()
        configManager.settings.permissions.ask = ask.isEmpty ? nil : ask.sorted()
        configManager.settings.permissions.defaultMode = defaultMode == .defaultMode ? nil : defaultMode.rawValue
        configManager.settings.permissions.additionalDirectories = additionalDirectories.isEmpty ? nil : additionalDirectories

        configManager.saveSettings()
    }
}

// MARK: - Tool Permission Row

private struct ToolPermissionRow: View {
    let tool: ClaudeTool
    @Binding var state: PermissionState

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tool.icon)
                .foregroundColor(state.color)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(tool.rawValue)
                    .font(.body.weight(.medium))
                Text(tool.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Picker("", selection: $state) {
                ForEach(PermissionState.allCases, id: \.self) { perm in
                    Text(perm.rawValue).tag(perm)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Custom Rule Row

private struct CustomRuleRow: View {
    @Binding var rule: CustomPermissionRule
    let onDelete: () -> Void
    let onChange: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: rule.state.icon)
                .foregroundColor(rule.state.color)
                .frame(width: 20)

            Text(rule.pattern)
                .font(.system(.body, design: .monospaced))

            Spacer()

            Picker("", selection: $rule.state) {
                Text("Allow").tag(PermissionState.allow)
                Text("Deny").tag(PermissionState.deny)
                Text("Ask").tag(PermissionState.ask)
            }
            .pickerStyle(.menu)
            .frame(width: 90)
            .onChange(of: rule.state) { _, _ in onChange() }

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Old types kept for compatibility

enum PermissionType: String, CaseIterable, Identifiable {
    case allow = "Allow"
    case deny = "Deny"
    case ask = "Ask"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .allow: return "checkmark.circle.fill"
        case .deny: return "xmark.circle.fill"
        case .ask: return "questionmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .allow: return .green
        case .deny: return .red
        case .ask: return .orange
        }
    }
}
