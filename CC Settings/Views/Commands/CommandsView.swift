import SwiftUI

// MARK: - SlashCommand Model

struct SlashCommand: Identifiable, Hashable {
    let id: String
    let name: String
    var description: String
    var argumentHint: String
    var allowedTools: [String]
    var body: String
    let fileURL: URL
    let isSymlink: Bool
    let fileSize: Int64
    var scope: ConfigScope

    var symlinkTarget: String? {
        guard isSymlink else { return nil }
        return (try? FileManager.default.destinationOfSymbolicLink(atPath: fileURL.path)) ?? nil
    }

    static func == (lhs: SlashCommand, rhs: SlashCommand) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// Parse a .md file into a SlashCommand
    /// - Parameters:
    ///   - url: The file URL to parse
    ///   - scope: The config scope (global or project)
    ///   - nameOverride: Optional name override for nested commands (e.g. "subdir:cmd")
    static func parse(from url: URL, scope: ConfigScope = .global, nameOverride: String? = nil) -> SlashCommand? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let fm = FileManager.default
        let attrs = try? fm.attributesOfItem(atPath: url.path)
        let fileSize = (attrs?[.size] as? Int64) ?? 0
        let isSymlink = (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false

        let name = nameOverride ?? url.deletingPathExtension().lastPathComponent

        var description = ""
        var argumentHint = ""
        var allowedTools: [String] = []
        var bodyContent = content

        // Parse frontmatter between --- delimiters
        if content.hasPrefix("---") {
            let lines = content.components(separatedBy: "\n")
            var endIndex = -1
            for i in 1..<lines.count {
                if lines[i].trimmingCharacters(in: .whitespaces) == "---" {
                    endIndex = i
                    break
                }
            }
            if endIndex > 0 {
                let frontmatterLines = Array(lines[1..<endIndex])
                for line in frontmatterLines {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("description:") {
                        description = String(trimmed.dropFirst("description:".count)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("argument-hint:") {
                        argumentHint = String(trimmed.dropFirst("argument-hint:".count)).trimmingCharacters(in: .whitespaces)
                    } else if trimmed.hasPrefix("allowed-tools:") {
                        let toolsStr = String(trimmed.dropFirst("allowed-tools:".count)).trimmingCharacters(in: .whitespaces)
                        allowedTools = toolsStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                    }
                }
                let bodyLines = Array(lines[(endIndex + 1)...])
                bodyContent = bodyLines.joined(separator: "\n")
                if bodyContent.hasPrefix("\n") {
                    bodyContent = String(bodyContent.dropFirst())
                }
            }
        }

        return SlashCommand(
            id: url.path,
            name: name,
            description: description,
            argumentHint: argumentHint,
            allowedTools: allowedTools,
            body: bodyContent,
            fileURL: url,
            isSymlink: isSymlink,
            fileSize: fileSize,
            scope: scope
        )
    }

    /// Serialize back to markdown with frontmatter
    func toMarkdown() -> String {
        var parts: [String] = []

        if !description.isEmpty || !argumentHint.isEmpty || !allowedTools.isEmpty {
            parts.append("---")
            if !description.isEmpty {
                parts.append("description: \(description)")
            }
            if !argumentHint.isEmpty {
                parts.append("argument-hint: \(argumentHint)")
            }
            if !allowedTools.isEmpty {
                parts.append("allowed-tools: \(allowedTools.joined(separator: ", "))")
            }
            parts.append("---")
            parts.append("")
        }

        parts.append(body)
        return parts.joined(separator: "\n")
    }

    /// Known Claude Code tools for the allowed-tools picker
    static let knownTools: [String] = [
        "Bash", "Read", "Write", "Edit", "MultiEdit",
        "Glob", "Grep", "WebFetch", "WebSearch",
        "Task", "NotebookEdit"
    ]
}

// MARK: - CommandsView

struct CommandsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var commands: [SlashCommand] = []
    @State private var selectedCommand: SlashCommand?
    @State private var searchText = ""
    @State private var showNewCommandSheet = false
    @State private var isLoading = false
    @State private var scopeFilter: ScopeFilter = .all
    @State private var projects: [Project] = []
    @State private var editorTargetScope: ConfigScope = .global

    private var globalCommandsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/commands")
    }

    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(commands.compactMap { cmd -> String? in
            if case .project(let id, _) = cmd.scope { return id }
            return nil
        })
        for project in projects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var allAvailableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            scopes.append(.project(id: project.id, path: project.originalPath))
        }
        return scopes
    }

    private var filteredCommands: [SlashCommand] {
        var result = commands

        switch scopeFilter {
        case .all: break
        case .global: result = result.filter { $0.scope.isGlobal }
        case .project(let id):
            result = result.filter {
                if case .project(let pid, _) = $0.scope { return pid == id }
                return false
            }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.description.lowercased().contains(query) ||
                $0.scope.displayName.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            // Left column - Command list
            VStack(spacing: 0) {
                headerSection
                searchAndFilterSection
                Divider()
                commandListSection
                Divider()
                footerSection
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 380)

            // Right column - Editor
            if let command = selectedCommand,
               let currentCommand = commands.first(where: { $0.id == command.id }) {
                CommandDetailEditor(
                    command: currentCommand,
                    onSave: { updated in
                        saveCommand(updated)
                    },
                    onDelete: {
                        deleteCommand(currentCommand)
                    }
                )
            } else {
                EmptyContentPlaceholder(
                    icon: "command",
                    title: "Select a Command",
                    subtitle: "Choose a command from the list to view or edit"
                )
            }
        }
        .onAppear {
            loadCommands()
        }
        .sheet(isPresented: $showNewCommandSheet) {
            CommandEditorSheet(
                commandsURL: commandsURLForScope(editorTargetScope),
                targetScope: editorTargetScope,
                availableScopes: allAvailableScopes
            ) { newCommand in
                loadCommands()
                selectedCommand = commands.first(where: { $0.name == newCommand.name })
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.themeAccent)
                    .font(.title3)
                Text("Commands")
                    .font(.headline)
                Spacer()
                Button {
                    editorTargetScope = .global
                    showNewCommandSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("New Command")

                Button {
                    loadCommands()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            Text("Global + Project commands")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
    }

    // MARK: - Search & Filter

    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search commands...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))

            if availableScopes.count > 1 {
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
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Command List

    @ViewBuilder
    private var commandListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading commands...")
                .font(.caption)
            Spacer()
        } else if filteredCommands.isEmpty {
            Spacer()
            EmptyContentPlaceholder(
                icon: "command",
                title: commands.isEmpty ? "No Commands" : "No Results",
                subtitle: commands.isEmpty ? "Add slash commands" : "No commands match your search"
            )
            Spacer()
        } else {
            List(selection: $selectedCommand) {
                ForEach(filteredCommands) { command in
                    CommandItemRow(command: command)
                        .tag(command)
                        .contextMenu {
                            if allAvailableScopes.count > 1 {
                                Menu("Move to...") {
                                    ForEach(allAvailableScopes.filter { $0 != command.scope }) { scope in
                                        Button(scope.displayName) {
                                            moveCommand(command, to: scope)
                                        }
                                    }
                                }
                            }
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(command.fileURL.path, inFileViewerRootedAtPath: command.fileURL.deletingLastPathComponent().path)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                deleteCommand(command)
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerSection: some View {
        HStack {
            Text("\(filteredCommands.count) command\(filteredCommands.count == 1 ? "" : "s")")
                .font(.caption)
                .foregroundColor(.secondary)
            if scopeFilter != .all {
                Text("(filtered)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Helpers

    private func commandsURLForScope(_ scope: ConfigScope) -> URL {
        switch scope {
        case .global:
            return globalCommandsURL
        case .project(_, let path):
            return URL(fileURLWithPath: path).appendingPathComponent(".claude/commands")
        }
    }

    // MARK: - Data Operations

    private func loadCommands() {
        isLoading = true
        projects = configManager.loadProjects()
        let fm = FileManager.default
        var loaded: [SlashCommand] = []

        // Load global commands
        loaded += loadCommandsFrom(url: globalCommandsURL, scope: .global, fm: fm)

        // Load project commands
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            let projectCommandsURL = URL(fileURLWithPath: project.originalPath)
                .appendingPathComponent(".claude/commands")
            let scope = ConfigScope.project(id: project.id, path: project.originalPath)
            loaded += loadCommandsFrom(url: projectCommandsURL, scope: scope, fm: fm)
        }

        commands = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false

        if let sel = selectedCommand, !commands.contains(where: { $0.id == sel.id }) {
            selectedCommand = nil
        }
    }

    private func loadCommandsFrom(url: URL, scope: ConfigScope, fm: FileManager) -> [SlashCommand] {
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isSymbolicLinkKey, .fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [SlashCommand] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            // Build the command name from the relative path within the commands directory
            // e.g. "subdir/cmd.md" becomes "subdir:cmd"
            let relativePath = fileURL.path.replacingOccurrences(of: url.path + "/", with: "")
            let name = relativePath
                .replacingOccurrences(of: ".md", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "/", with: ":")
            if let command = SlashCommand.parse(from: fileURL, scope: scope, nameOverride: name) {
                results.append(command)
            }
        }
        return results
    }

    private func saveCommand(_ command: SlashCommand) {
        let markdown = command.toMarkdown()
        do {
            try markdown.write(to: command.fileURL, atomically: true, encoding: .utf8)
            loadCommands()
            selectedCommand = commands.first(where: { $0.id == command.id })
        } catch {
            // Error handling
        }
    }

    private func deleteCommand(_ command: SlashCommand) {
        do {
            try FileManager.default.removeItem(at: command.fileURL)
            if selectedCommand?.id == command.id {
                selectedCommand = nil
            }
            loadCommands()
        } catch {
            // Error handling
        }
    }

    private func moveCommand(_ command: SlashCommand, to targetScope: ConfigScope) {
        let targetDir = commandsURLForScope(targetScope)
        let targetURL = targetDir.appendingPathComponent(command.fileURL.lastPathComponent)
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
            let markdown = command.toMarkdown()
            try markdown.write(to: targetURL, atomically: true, encoding: .utf8)
            try fm.removeItem(at: command.fileURL)
            loadCommands()
        } catch {
            // Error handling
        }
    }
}

// MARK: - CommandItemRow

private struct CommandItemRow: View {
    let command: SlashCommand

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: command.isSymlink ? "link" : "terminal")
                .foregroundColor(command.isSymlink ? .orange : .themeAccent)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("/\(command.name)")
                        .font(.body.monospaced())
                        .lineLimit(1)
                    if command.isSymlink {
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(spacing: 4) {
                    ScopeBadge(scope: command.scope)
                    if !command.description.isEmpty {
                        Text(command.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - CommandDetailEditor

/// Editor with separated metadata fields and body editor.
/// Metadata (description, argument hint, allowed tools) are edited as
/// structured fields — the user never has to touch raw frontmatter.
private struct CommandDetailEditor: View {
    let command: SlashCommand
    var onSave: ((SlashCommand) -> Void)?
    var onDelete: (() -> Void)?

    @State private var description: String = ""
    @State private var argumentHint: String = ""
    @State private var allowedTools: [String] = []
    @State private var promptBody: String = ""
    @State private var viewMode: ViewMode = .source
    @State private var showDeleteAlert = false
    @State private var showMetadata = true
    @State private var newToolName: String = ""

    // Originals for change tracking
    @State private var origDescription: String = ""
    @State private var origArgumentHint: String = ""
    @State private var origAllowedTools: [String] = []
    @State private var origPromptBody: String = ""

    private var isReadOnly: Bool {
        command.isSymlink
    }

    private var hasChanges: Bool {
        description != origDescription ||
        argumentHint != origArgumentHint ||
        allowedTools != origAllowedTools ||
        promptBody != origPromptBody
    }

    private var currentCommand: SlashCommand {
        var cmd = command
        cmd.description = description
        cmd.argumentHint = argumentHint
        cmd.allowedTools = allowedTools
        cmd.body = promptBody
        return cmd
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Image(systemName: command.isSymlink ? "link" : "terminal")
                    .foregroundColor(command.isSymlink ? .orange : .themeAccent)
                    .font(.title3)

                Text("/\(command.name)")
                    .font(.headline.monospaced())
                    .lineLimit(1)

                ScopeBadge(scope: command.scope)

                ViewModePicker(mode: $viewMode)

                Spacer()

                if hasChanges && !isReadOnly {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                        .help("Unsaved changes")
                }

                if !isReadOnly {
                    if hasChanges {
                        Button("Revert") {
                            loadContent()
                        }
                    }

                    Button {
                        onSave?(currentCommand)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!hasChanges)
                }

                Button(role: .destructive) {
                    showDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .help("Delete command")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            // Symlink info banner
            if command.isSymlink, let target = command.symlinkTarget {
                ReadOnlyBanner(message: "This command is a symlink to: \(target)")
            }

            // Metadata section
            metadataSection

            Divider()

            // Content area
            switch viewMode {
            case .source:
                sourceView
            case .preview:
                previewView
            case .split:
                HSplitView {
                    VStack(spacing: 0) {
                        PaneHeader(icon: "doc.text", title: "Source")
                        sourceView
                    }
                    VStack(spacing: 0) {
                        PaneHeader(icon: "eye", title: "Preview")
                        previewView
                    }
                }
            }
        }
        .frame(minWidth: 400)
        .onAppear {
            loadContent()
        }
        .onChange(of: command.id) { _, _ in
            loadContent()
        }
        .alert("Delete Command", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDelete?()
            }
        } message: {
            Text("Are you sure you want to delete /\(command.name)? This cannot be undone.")
        }
    }

    // MARK: - Metadata Section

    @ViewBuilder
    private var metadataSection: some View {
        VStack(spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    showMetadata.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: showMetadata ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(width: 10)
                    Text("Metadata")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    if !showMetadata {
                        // Show summary when collapsed
                        if !description.isEmpty {
                            Text(description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        if !allowedTools.isEmpty {
                            Text("\(allowedTools.count) tool\(allowedTools.count == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(3)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if showMetadata {
                VStack(spacing: 8) {
                    // Description
                    HStack(alignment: .top) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)
                        if isReadOnly {
                            Text(description.isEmpty ? "—" : description)
                                .font(.caption)
                                .foregroundColor(description.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TextField("What does this command do?", text: $description)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                        }
                    }

                    // Argument hint
                    HStack(alignment: .top) {
                        Text("Argument")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)
                        if isReadOnly {
                            Text(argumentHint.isEmpty ? "—" : argumentHint)
                                .font(.caption.monospaced())
                                .foregroundColor(argumentHint.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            TextField("<file-path>", text: $argumentHint)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption.monospaced())
                        }
                    }

                    // Allowed tools
                    HStack(alignment: .top) {
                        Text("Tools")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .trailing)

                        toolsEditor
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Tools Editor

    @ViewBuilder
    private var toolsEditor: some View {
        if isReadOnly {
            if allowedTools.isEmpty {
                Text("All tools (default)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                FlowLayout(spacing: 4) {
                    ForEach(allowedTools, id: \.self) { tool in
                        toolChip(tool, removable: false)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(alignment: .leading, spacing: 6) {
                // Current tools as removable chips
                if !allowedTools.isEmpty {
                    FlowLayout(spacing: 4) {
                        ForEach(allowedTools, id: \.self) { tool in
                            toolChip(tool, removable: true)
                        }
                    }
                } else {
                    Text("All tools allowed (none restricted)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Add tool — known tools as quick buttons
                let available = SlashCommand.knownTools.filter { !allowedTools.contains($0) }
                if !available.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(available, id: \.self) { tool in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        allowedTools.append(tool)
                                    }
                                } label: {
                                    Text("+ \(tool)")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.themeAccent.opacity(0.1))
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // Custom tool name field
                HStack(spacing: 4) {
                    TextField("Custom tool...", text: $newToolName)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospaced())
                        .frame(maxWidth: 150)
                        .onSubmit {
                            addCustomTool()
                        }
                    Button("Add") {
                        addCustomTool()
                    }
                    .font(.caption)
                    .disabled(newToolName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func toolChip(_ name: String, removable: Bool) -> some View {
        HStack(spacing: 3) {
            Text(name)
                .font(.caption2.monospaced())
            if removable {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        allowedTools.removeAll { $0 == name }
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.15))
        .cornerRadius(4)
    }

    private func addCustomTool() {
        let name = newToolName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !allowedTools.contains(name) else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            allowedTools.append(name)
        }
        newToolName = ""
    }

    // MARK: - Source / Preview

    @ViewBuilder
    private var sourceView: some View {
        if isReadOnly {
            ScrollView {
                Text(promptBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .textSelection(.enabled)
            }
        } else {
            TextEditor(text: $promptBody)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
        }
    }

    @ViewBuilder
    private var previewView: some View {
        ScrollView {
            if promptBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                EmptyContentPlaceholder(
                    icon: "doc.text",
                    title: "Empty",
                    subtitle: "Start typing in the source view"
                )
            } else {
                MarkdownPreview(markdown: promptBody)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Data

    private func loadContent() {
        description = command.description
        argumentHint = command.argumentHint
        allowedTools = command.allowedTools
        promptBody = command.body

        origDescription = command.description
        origArgumentHint = command.argumentHint
        origAllowedTools = command.allowedTools
        origPromptBody = command.body
    }
}

// MARK: - CommandEditorSheet

struct CommandEditorSheet: View {
    let commandsURL: URL
    var targetScope: ConfigScope = .global
    var availableScopes: [ConfigScope] = [.global]
    var onCreate: ((SlashCommand) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var nameError: String?
    @State private var existsError = false
    @State private var selectedScope: ConfigScope

    private let namePattern = "^[a-z][a-z0-9-]*$"

    init(commandsURL: URL, targetScope: ConfigScope = .global, availableScopes: [ConfigScope] = [.global], onCreate: ((SlashCommand) -> Void)? = nil) {
        self.commandsURL = commandsURL
        self.targetScope = targetScope
        self.availableScopes = availableScopes
        self.onCreate = onCreate
        _selectedScope = State(initialValue: targetScope)
    }

    private var isValid: Bool {
        !name.isEmpty && nameError == nil && !existsError
    }

    private var effectiveCommandsURL: URL {
        switch selectedScope {
        case .global:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/commands")
        case .project(_, let path):
            return URL(fileURLWithPath: path).appendingPathComponent(".claude/commands")
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Command")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 16) {
                // Scope picker
                if availableScopes.count > 1 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.subheadline.bold())
                        Picker("Scope", selection: $selectedScope) {
                            ForEach(availableScopes) { scope in
                                Label(scope.displayName, systemImage: scope.icon)
                                    .tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // Name field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Command Name")
                        .font(.subheadline.bold())
                    HStack {
                        Text("/")
                            .font(.body.monospaced())
                            .foregroundColor(.secondary)
                        TextField("my-command", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                            .onChange(of: name) { _, newValue in
                                validateName(newValue)
                            }
                    }
                    if let error = nameError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    if existsError {
                        Text("A command with this name already exists.")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    Text("Lowercase letters, numbers, and hyphens. Must start with a letter.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Description field
                VStack(alignment: .leading, spacing: 4) {
                    Text("Description (optional)")
                        .font(.subheadline.bold())
                    TextField("What does this command do?", text: $description)
                        .textFieldStyle(.roundedBorder)
                }

                Text("You can add the command body, argument hints, and allowed tools after creation.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Spacer()

            Divider()

            // Footer
            HStack {
                ScopeBadge(scope: selectedScope)
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Create") {
                    createCommand()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 450, height: 380)
    }

    private func validateName(_ value: String) {
        nameError = nil
        existsError = false

        guard !value.isEmpty else { return }

        if value.range(of: namePattern, options: .regularExpression) == nil {
            nameError = "Invalid command name format."
            return
        }

        let fileURL = effectiveCommandsURL.appendingPathComponent("\(value).md")
        if FileManager.default.fileExists(atPath: fileURL.path) {
            existsError = true
        }
    }

    private func createCommand() {
        let fm = FileManager.default
        let targetDir = effectiveCommandsURL
        try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let fileURL = targetDir.appendingPathComponent("\(name).md")

        let command = SlashCommand(
            id: fileURL.path,
            name: name,
            description: description,
            argumentHint: "",
            allowedTools: [],
            body: "",
            fileURL: fileURL,
            isSymlink: false,
            fileSize: 0,
            scope: selectedScope
        )

        let markdown = command.toMarkdown()

        do {
            try markdown.write(to: fileURL, atomically: true, encoding: .utf8)
            onCreate?(command)
            dismiss()
        } catch {
            // Error handling
        }
    }
}
