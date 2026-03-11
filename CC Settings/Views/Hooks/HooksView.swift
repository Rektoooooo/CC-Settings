import SwiftUI

// MARK: - Hook Type

enum HookType: String, CaseIterable, Identifiable {
    case preToolUse = "PreToolUse"
    case postToolUse = "PostToolUse"
    case prePromptSubmit = "PrePromptSubmit"
    case postPromptSubmit = "PostPromptSubmit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .preToolUse: return "Pre Tool Use"
        case .postToolUse: return "Post Tool Use"
        case .prePromptSubmit: return "Pre Prompt Submit"
        case .postPromptSubmit: return "Post Prompt Submit"
        }
    }

    var icon: String {
        switch self {
        case .preToolUse: return "chevron.left.square.fill"
        case .postToolUse: return "chevron.right.square.fill"
        case .prePromptSubmit: return "arrow.up.square.fill"
        case .postPromptSubmit: return "arrow.down.square.fill"
        }
    }

    var color: Color {
        switch self {
        case .preToolUse: return .themeAccent
        case .postToolUse: return .purple
        case .prePromptSubmit: return .green
        case .postPromptSubmit: return .orange
        }
    }

    var description: String {
        switch self {
        case .preToolUse: return "Runs before a tool is executed"
        case .postToolUse: return "Runs after a tool has completed"
        case .prePromptSubmit: return "Runs before a prompt is sent"
        case .postPromptSubmit: return "Runs after a prompt response"
        }
    }

    var placeholder: String {
        switch self {
        case .preToolUse: return "echo \"About to use $TOOL_NAME\""
        case .postToolUse: return "npm run lint -- --fix"
        case .prePromptSubmit: return "date >> ~/.claude/prompt-log.txt"
        case .postPromptSubmit: return "say 'Done' &"
        }
    }
}

// MARK: - Scoped Hook Group

/// A hook group tagged with its source scope, type, and position for editing.
struct ScopedHookGroup: Identifiable {
    let id: String
    let hookType: HookType
    let group: HookGroup
    let scope: ConfigScope
    let indexInScope: Int

    init(hookType: HookType, group: HookGroup, scope: ConfigScope, indexInScope: Int) {
        self.id = "\(scope.id):\(hookType.rawValue):\(indexInScope)"
        self.hookType = hookType
        self.group = group
        self.scope = scope
        self.indexInScope = indexInScope
    }
}

// MARK: - Hook Group Model

struct HookGroupModel: Identifiable, Equatable {
    let id = UUID()
    var matcherTool: String = ""
    var matcherPattern: String = ""
    var commands: [String] = [""]

    init() {}

    init(from group: HookGroup) {
        self.matcherTool = group.matcher?.tool ?? ""
        self.matcherPattern = group.matcher?.pattern ?? ""
        self.commands = group.hooks.map(\.command)
        if self.commands.isEmpty {
            self.commands = [""]
        }
    }

    func toHookGroup() -> HookGroup {
        let matcher: HookMatcher?
        let trimmedTool = matcherTool.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPattern = matcherPattern.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedTool.isEmpty && trimmedPattern.isEmpty {
            matcher = nil
        } else {
            matcher = HookMatcher(
                tool: trimmedTool.isEmpty ? nil : trimmedTool,
                pattern: trimmedPattern.isEmpty ? nil : trimmedPattern
            )
        }

        let hooks = commands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { HookDefinition(command: $0) }

        return HookGroup(matcher: matcher, hooks: hooks)
    }

    var hasValidCommands: Bool {
        commands.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}

// MARK: - Hooks View

struct HooksView: View {
    @EnvironmentObject var configManager: ConfigurationManager

    // All scoped hooks
    @State private var allHooks: [ScopedHookGroup] = []
    @State private var projects: [Project] = []
    @State private var projectSettingsCache: [String: ClaudeSettings] = [:]

    // Scope filter
    @State private var scopeFilter: ScopeFilter = .all

    // Add hook state
    @State private var addingForType: HookType?
    @State private var addScope: ConfigScope = .global
    @State private var newTool: String = ""
    @State private var newPattern: String = ""
    @State private var newCommands: [String] = [""]

    // Edit state
    @State private var editingId: String?
    @State private var editTool: String = ""
    @State private var editPattern: String = ""
    @State private var editCommands: [String] = [""]
    @State private var editScopedGroup: ScopedHookGroup?

    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(allHooks.compactMap { h -> String? in
            if case .project(let id, _) = h.scope { return id }
            return nil
        })
        for project in filteredProjects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var filteredProjects: [Project] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return projects.filter { project in
            guard project.originalPath != home else { return false }
            return !project.sessions.isEmpty || project.settings != nil || project.claudeMD != nil
        }
    }

    private func hooksForType(_ type: HookType) -> [ScopedHookGroup] {
        allHooks.filter { hook in
            guard hook.hookType == type else { return false }
            switch scopeFilter {
            case .all: return true
            case .global: return hook.scope.isGlobal
            case .project(let id):
                if case .project(let pid, _) = hook.scope { return pid == id }
                return false
            }
        }
    }

    var body: some View {
        Form {
            // MARK: - Scope Filter
            if availableScopes.count > 1 {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ScopeFilterChip(label: "All", icon: "tray.2", isSelected: scopeFilter == .all) {
                                scopeFilter = .all
                            }
                            ScopeFilterChip(label: "Global", icon: "globe", isSelected: scopeFilter == .global) {
                                scopeFilter = .global
                            }
                            ForEach(availableScopes.filter { !$0.isGlobal }) { scope in
                                if case .project(let id, _) = scope {
                                    ScopeFilterChip(label: scope.displayName, icon: "folder", isSelected: scopeFilter == .project(id: id)) {
                                        scopeFilter = .project(id: id)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // MARK: - Info
            Section {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.themeAccent)
                    Text("Hooks run shell commands at different stages of Claude Code's execution. Use them for linting, logging, notifications, and more.")
                        .font(.subheadline)
                }
            }

            // MARK: - Hook Type Sections
            ForEach(HookType.allCases) { hookType in
                hookSection(for: hookType)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            loadAllHooks()
        }
    }

    // MARK: - Section for Each Hook Type

    @ViewBuilder
    private func hookSection(for hookType: HookType) -> some View {
        Section {
            let hooks = hooksForType(hookType)
            if hooks.isEmpty && addingForType != hookType {
                Text("No hooks configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                ForEach(hooks) { scopedHook in
                    if editingId == scopedHook.id {
                        inlineEditForm(hookType: hookType)
                    } else {
                        hookGroupRow(scopedHook: scopedHook)
                    }
                }
            }

            // Inline add form
            if addingForType == hookType {
                inlineAddForm(hookType: hookType)
            } else {
                Button {
                    resetAddForm()
                    addingForType = hookType
                } label: {
                    Label("Add Hook", systemImage: "plus")
                }
            }
        } header: {
            HStack(spacing: 6) {
                Image(systemName: hookType.icon)
                    .foregroundColor(hookType.color)
                Text(hookType.displayName)
                Spacer()
                let count = hooksForType(hookType).count
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                }
            }
        } footer: {
            Text(hookType.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hook Group Row

    @ViewBuilder
    private func hookGroupRow(scopedHook: ScopedHookGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Scope badge + matcher line
            HStack(spacing: 6) {
                ScopeBadge(scope: scopedHook.scope)

                if let matcher = scopedHook.group.matcher {
                    if let tool = matcher.tool {
                        Text("Tool:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(tool)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                    }
                    if let pattern = matcher.pattern {
                        if matcher.tool != nil {
                            Text("|")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text("Pattern:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(pattern)
                            .font(.system(.caption, design: .monospaced))
                            .fontWeight(.medium)
                    }
                } else {
                    Text("Matches all")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }

                Spacer()

                Button {
                    startEditing(scopedHook: scopedHook)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    deleteHook(scopedHook)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Commands
            ForEach(scopedHook.group.hooks.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(scopedHook.hookType.color)
                    Text(scopedHook.group.hooks[i].command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
        .contextMenu {
            Button("Show in Finder") {
                let settingsPath: String
                if scopedHook.scope.isGlobal {
                    settingsPath = FileManager.default.homeDirectoryForCurrentUser
                        .appendingPathComponent(".claude/settings.json").path
                } else if case .project(_, let path) = scopedHook.scope {
                    settingsPath = URL(fileURLWithPath: path)
                        .appendingPathComponent(".claude/settings.json").path
                } else {
                    return
                }
                NSWorkspace.shared.selectFile(settingsPath,
                    inFileViewerRootedAtPath: URL(fileURLWithPath: settingsPath).deletingLastPathComponent().path)
            }
        }
    }

    // MARK: - Inline Add Form

    @ViewBuilder
    private func inlineAddForm(hookType: HookType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Scope picker
            HStack(spacing: 8) {
                Text("Add to:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $addScope) {
                    Label("Global", systemImage: "globe").tag(ConfigScope.global)
                    ForEach(filteredProjects) { project in
                        Label(project.displayName, systemImage: "folder")
                            .tag(ConfigScope.project(id: project.id, path: project.originalPath))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 200)
            }

            // Matcher fields
            GroupBox("Matcher (optional)") {
                VStack(spacing: 6) {
                    HStack {
                        Text("Tool")
                            .font(.caption)
                            .frame(width: 50, alignment: .trailing)
                        TextField("e.g. Bash, Read, Write", text: $newTool)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Pattern")
                            .font(.caption)
                            .frame(width: 50, alignment: .trailing)
                        TextField("regex, e.g. git\\s+push.*", text: $newPattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 2)
            }

            // Commands
            GroupBox("Commands") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(newCommands.indices, id: \.self) { i in
                        HStack(spacing: 6) {
                            Text("$")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(hookType.color)
                            TextField(hookType.placeholder, text: $newCommands[i])
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            if newCommands.count > 1 {
                                Button {
                                    newCommands.remove(at: i)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        newCommands.append("")
                    } label: {
                        Label("Add Command", systemImage: "plus")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 2)
            }

            // Actions
            HStack {
                Spacer()
                Button("Cancel") {
                    addingForType = nil
                }
                Button("Add") {
                    saveNewHook(for: hookType)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasValidNewCommands)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Inline Edit Form

    @ViewBuilder
    private func inlineEditForm(hookType: HookType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            GroupBox("Matcher (optional)") {
                VStack(spacing: 6) {
                    HStack {
                        Text("Tool")
                            .font(.caption)
                            .frame(width: 50, alignment: .trailing)
                        TextField("e.g. Bash, Read, Write", text: $editTool)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                    HStack {
                        Text("Pattern")
                            .font(.caption)
                            .frame(width: 50, alignment: .trailing)
                        TextField("regex", text: $editPattern)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                .padding(.vertical, 2)
            }

            GroupBox("Commands") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(editCommands.indices, id: \.self) { i in
                        HStack(spacing: 6) {
                            Text("$")
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(hookType.color)
                            TextField("command", text: $editCommands[i])
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.body, design: .monospaced))
                            if editCommands.count > 1 {
                                Button {
                                    editCommands.remove(at: i)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    Button {
                        editCommands.append("")
                    } label: {
                        Label("Add Command", systemImage: "plus")
                            .font(.caption)
                    }
                }
                .padding(.vertical, 2)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    editingId = nil
                    editScopedGroup = nil
                }
                Button("Save") {
                    saveEdit()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!hasValidEditCommands)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Validation

    private var hasValidNewCommands: Bool {
        newCommands.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private var hasValidEditCommands: Bool {
        editCommands.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    // MARK: - Actions

    private func resetAddForm() {
        newTool = ""
        newPattern = ""
        newCommands = [""]
        addScope = .global
    }

    private func startEditing(scopedHook: ScopedHookGroup) {
        editingId = scopedHook.id
        editScopedGroup = scopedHook
        editTool = scopedHook.group.matcher?.tool ?? ""
        editPattern = scopedHook.group.matcher?.pattern ?? ""
        editCommands = scopedHook.group.hooks.map(\.command)
        if editCommands.isEmpty { editCommands = [""] }
    }

    private func saveNewHook(for hookType: HookType) {
        var model = HookGroupModel()
        model.matcherTool = newTool
        model.matcherPattern = newPattern
        model.commands = newCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let newGroup = model.toHookGroup()
        appendGroup(newGroup, for: hookType, scope: addScope)

        addingForType = nil
        resetAddForm()
    }

    private func saveEdit() {
        guard let scopedHook = editScopedGroup else { return }

        var model = HookGroupModel()
        model.matcherTool = editTool
        model.matcherPattern = editPattern
        model.commands = editCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        replaceGroup(at: scopedHook.indexInScope, with: model.toHookGroup(),
                     for: scopedHook.hookType, scope: scopedHook.scope)

        editingId = nil
        editScopedGroup = nil
    }

    private func deleteHook(_ scopedHook: ScopedHookGroup) {
        removeGroup(at: scopedHook.indexInScope, for: scopedHook.hookType, scope: scopedHook.scope)
    }

    // MARK: - Data Loading

    private func loadAllHooks() {
        projects = configManager.loadProjects()
        projectSettingsCache = [:]
        var result: [ScopedHookGroup] = []

        // Global hooks
        let globalHooks = configManager.settings.hooks
        result += collectScopedGroups(from: globalHooks, scope: .global)

        // Project hooks
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in filteredProjects {
            guard project.originalPath != home else { continue }
            let scope = ConfigScope.project(id: project.id, path: project.originalPath)
            if let settings = configManager.loadProjectSettings(projectPath: project.originalPath) {
                projectSettingsCache[project.originalPath] = settings
                result += collectScopedGroups(from: settings.hooks, scope: scope)
            }
        }

        allHooks = result
    }

    private func collectScopedGroups(from hooks: HooksConfig?, scope: ConfigScope) -> [ScopedHookGroup] {
        var result: [ScopedHookGroup] = []
        for hookType in HookType.allCases {
            let groups: [HookGroup]
            switch hookType {
            case .preToolUse: groups = hooks?.PreToolUse ?? []
            case .postToolUse: groups = hooks?.PostToolUse ?? []
            case .prePromptSubmit: groups = hooks?.PrePromptSubmit ?? []
            case .postPromptSubmit: groups = hooks?.PostPromptSubmit ?? []
            }
            for (index, group) in groups.enumerated() {
                result.append(ScopedHookGroup(hookType: hookType, group: group, scope: scope, indexInScope: index))
            }
        }
        return result
    }

    // MARK: - Data Mutation

    private func getGroups(for type: HookType, scope: ConfigScope) -> [HookGroup] {
        let hooks: HooksConfig?
        if scope.isGlobal {
            hooks = configManager.settings.hooks
        } else if case .project(_, let path) = scope {
            hooks = projectSettingsCache[path]?.hooks
        } else {
            hooks = nil
        }
        switch type {
        case .preToolUse: return hooks?.PreToolUse ?? []
        case .postToolUse: return hooks?.PostToolUse ?? []
        case .prePromptSubmit: return hooks?.PrePromptSubmit ?? []
        case .postPromptSubmit: return hooks?.PostPromptSubmit ?? []
        }
    }

    private func setGroups(_ groups: [HookGroup], for type: HookType, scope: ConfigScope) {
        if scope.isGlobal {
            setGlobalGroups(groups, for: type)
        } else if case .project(_, let path) = scope {
            setProjectGroups(groups, for: type, projectPath: path)
        }
        loadAllHooks()
    }

    private func appendGroup(_ group: HookGroup, for type: HookType, scope: ConfigScope) {
        var groups = getGroups(for: type, scope: scope)
        groups.append(group)
        setGroups(groups, for: type, scope: scope)
    }

    private func replaceGroup(at index: Int, with group: HookGroup, for type: HookType, scope: ConfigScope) {
        var groups = getGroups(for: type, scope: scope)
        guard index < groups.count else { return }
        groups[index] = group
        setGroups(groups, for: type, scope: scope)
    }

    private func removeGroup(at index: Int, for type: HookType, scope: ConfigScope) {
        var groups = getGroups(for: type, scope: scope)
        guard index < groups.count else { return }
        groups.remove(at: index)
        setGroups(groups, for: type, scope: scope)
    }

    private func setGlobalGroups(_ groups: [HookGroup], for type: HookType) {
        if configManager.settings.hooks == nil {
            configManager.settings.hooks = HooksConfig()
        }
        let value = groups.isEmpty ? nil : groups
        switch type {
        case .preToolUse: configManager.settings.hooks?.PreToolUse = value
        case .postToolUse: configManager.settings.hooks?.PostToolUse = value
        case .prePromptSubmit: configManager.settings.hooks?.PrePromptSubmit = value
        case .postPromptSubmit: configManager.settings.hooks?.PostPromptSubmit = value
        }
        if let hooks = configManager.settings.hooks,
           hooks.PreToolUse == nil && hooks.PostToolUse == nil &&
           hooks.PrePromptSubmit == nil && hooks.PostPromptSubmit == nil {
            configManager.settings.hooks = nil
        }
        configManager.saveSettings()
    }

    private func setProjectGroups(_ groups: [HookGroup], for type: HookType, projectPath: String) {
        var settings = projectSettingsCache[projectPath] ?? ClaudeSettings()
        if settings.hooks == nil {
            settings.hooks = HooksConfig()
        }
        let value = groups.isEmpty ? nil : groups
        switch type {
        case .preToolUse: settings.hooks?.PreToolUse = value
        case .postToolUse: settings.hooks?.PostToolUse = value
        case .prePromptSubmit: settings.hooks?.PrePromptSubmit = value
        case .postPromptSubmit: settings.hooks?.PostPromptSubmit = value
        }
        if let hooks = settings.hooks,
           hooks.PreToolUse == nil && hooks.PostToolUse == nil &&
           hooks.PrePromptSubmit == nil && hooks.PostPromptSubmit == nil {
            settings.hooks = nil
        }
        configManager.saveProjectSettings(settings, projectPath: projectPath)
        projectSettingsCache[projectPath] = settings
    }
}

// MARK: - Command Entry (kept for backward compat)

struct CommandEntry: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
}
