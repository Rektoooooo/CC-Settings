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

    // Inline add state — which hook type is currently showing the add form
    @State private var addingForType: HookType?
    @State private var newTool: String = ""
    @State private var newPattern: String = ""
    @State private var newCommands: [String] = [""]

    // Inline edit state
    @State private var editingId: UUID?
    @State private var editTool: String = ""
    @State private var editPattern: String = ""
    @State private var editCommands: [String] = [""]
    @State private var editType: HookType = .preToolUse
    @State private var editIndex: Int = 0

    var body: some View {
        Form {
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
    }

    // MARK: - Section for Each Hook Type

    @ViewBuilder
    private func hookSection(for hookType: HookType) -> some View {
        Section {
            // Existing hook groups
            let groups = groupsForType(hookType)
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if editingId == group.id {
                    // Inline edit form
                    inlineEditForm(hookType: hookType, index: index)
                } else {
                    hookGroupRow(group: group, hookType: hookType, index: index)
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
            }
        } footer: {
            Text(hookType.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Hook Group Row (Display)

    @ViewBuilder
    private func hookGroupRow(group: HookGroup, hookType: HookType, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            // Matcher line
            HStack(spacing: 6) {
                if let matcher = group.matcher {
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
                    startEditing(group: group, hookType: hookType, index: index)
                } label: {
                    Image(systemName: "pencil")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Button {
                    deleteGroup(at: index, for: hookType)
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }

            // Commands
            ForEach(group.hooks.indices, id: \.self) { i in
                HStack(spacing: 4) {
                    Text("$")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(hookType.color)
                    Text(group.hooks[i].command)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Inline Add Form

    @ViewBuilder
    private func inlineAddForm(hookType: HookType) -> some View {
        VStack(alignment: .leading, spacing: 10) {
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
    private func inlineEditForm(hookType: HookType, index: Int) -> some View {
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
    }

    private func startEditing(group: HookGroup, hookType: HookType, index: Int) {
        editingId = group.id
        editTool = group.matcher?.tool ?? ""
        editPattern = group.matcher?.pattern ?? ""
        editCommands = group.hooks.map(\.command)
        if editCommands.isEmpty { editCommands = [""] }
        editType = hookType
        editIndex = index
    }

    private func saveNewHook(for hookType: HookType) {
        var model = HookGroupModel()
        model.matcherTool = newTool
        model.matcherPattern = newPattern
        model.commands = newCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var groups = groupsForType(hookType)
        groups.append(model.toHookGroup())
        setGroups(groups, for: hookType)

        addingForType = nil
        resetAddForm()
    }

    private func saveEdit() {
        var model = HookGroupModel()
        model.matcherTool = editTool
        model.matcherPattern = editPattern
        model.commands = editCommands
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var groups = groupsForType(editType)
        guard editIndex < groups.count else { return }
        groups[editIndex] = model.toHookGroup()
        setGroups(groups, for: editType)

        editingId = nil
    }

    // MARK: - Data Access

    private func groupsForType(_ type: HookType) -> [HookGroup] {
        let hooks = configManager.settings.hooks
        switch type {
        case .preToolUse: return hooks?.PreToolUse ?? []
        case .postToolUse: return hooks?.PostToolUse ?? []
        case .prePromptSubmit: return hooks?.PrePromptSubmit ?? []
        case .postPromptSubmit: return hooks?.PostPromptSubmit ?? []
        }
    }

    private func setGroups(_ groups: [HookGroup], for type: HookType) {
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

    private func deleteGroup(at index: Int, for type: HookType) {
        var groups = groupsForType(type)
        guard index < groups.count else { return }
        groups.remove(at: index)
        setGroups(groups, for: type)
    }
}

// MARK: - Command Entry (kept for backward compat)

struct CommandEntry: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
}
