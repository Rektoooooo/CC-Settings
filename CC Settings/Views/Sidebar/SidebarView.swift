import SwiftUI

// MARK: - Themed Row Background

private extension View {
    @ViewBuilder
    func themedRowBackground(isSelected: Bool, color: Color) -> some View {
        if isSelected {
            self.listRowBackground(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
            )
        } else {
            self
        }
    }
}

// MARK: - SubfolderEntry

struct SubfolderEntry: Identifiable, Sendable {
    let id: String
    let name: String
    let itemCount: Int

    static func icon(for name: String) -> String {
        switch name.lowercased() {
        case "plans": return "list.clipboard"
        case "tasks": return "checklist"
        case "todos": return "checklist.checked"
        case "backups": return "clock.arrow.circlepath"
        case "debug": return "ant"
        case "file-history": return "clock"
        case "session-env": return "terminal"
        case "shell-snapshots": return "camera"
        case "paste-cache": return "doc.on.clipboard"
        case "ide": return "hammer"
        case "statsig": return "chart.bar"
        case "apple": return "apple.logo"
        default: return "folder"
        }
    }
}

// MARK: - NavigationItem

enum NavigationItem: Hashable {
    case general
    case permissions
    case environment
    case experimentalFeatures
    case hooks
    case hud
    case globalFiles
    case projectFiles(String)
    case claudeMDEditor
    case sessionHistory
    case commands
    case skills
    case plugins
    case mcpServers
    case cleanup
    case sync
    case folder(String)
    case none

    var label: String {
        switch self {
        case .general: return "General"
        case .permissions: return "Permissions"
        case .environment: return "Environment"
        case .experimentalFeatures: return "Experimental"
        case .hooks: return "Hooks"
        case .hud: return "HUD"
        case .globalFiles: return "Global"
        case .projectFiles: return "Project"
        case .claudeMDEditor: return "CLAUDE.md"
        case .sessionHistory: return "Session History"
        case .commands: return "Commands"
        case .skills: return "Skills"
        case .plugins: return "Plugins"
        case .mcpServers: return "MCP Servers"
        case .cleanup: return "Cleanup"
        case .sync: return "Version Control"
        case .folder(let name): return name.capitalized
        case .none: return ""
        }
    }

    var icon: String {
        switch self {
        case .general: return "gearshape"
        case .permissions: return "lock.shield"
        case .environment: return "terminal"
        case .experimentalFeatures: return "flask"
        case .hooks: return "arrow.triangle.branch"
        case .hud: return "gauge.open.with.lines.needle.33percent"
        case .globalFiles: return "house"
        case .projectFiles: return "folder"
        case .claudeMDEditor: return "doc.richtext"
        case .sessionHistory: return "clock.arrow.circlepath"
        case .commands: return "command"
        case .skills: return "star"
        case .plugins: return "puzzlepiece"
        case .mcpServers: return "server.rack"
        case .cleanup: return "trash"
        case .sync: return "arrow.triangle.branch"
        case .folder(let name): return SubfolderEntry.icon(for: name)
        case .none: return ""
        }
    }

    /// Keywords for search filtering — includes setting names within each section
    var searchKeywords: [String] {
        switch self {
        case .general:
            return ["general", "model", "theme", "appearance", "language", "effort", "output", "verbose",
                    "git", "branch", "api key", "updates", "notifications", "attribution", "teams",
                    "teammate", "cleanup", "retention", "auto-compact", "plans", "reduce motion"]
        case .permissions:
            return ["permissions", "allow", "deny", "ask", "tools", "sandbox", "directories", "mode"]
        case .environment:
            return ["environment", "env", "variables", "telemetry", "proxy", "api"]
        case .experimentalFeatures:
            return ["experimental", "thinking", "agent teams", "preflight", "telemetry", "error reporting", "auto-updater"]
        case .hooks:
            return ["hooks", "pre tool", "post tool", "prompt submit", "command", "matcher"]
        case .hud:
            return ["hud", "statusline", "status line", "claude-hud", "context bar", "tools", "agents", "todos", "git status"]
        case .globalFiles:
            return ["global", "files", "claude", "settings.json"]
        case .projectFiles:
            return ["project", "files"]
        case .claudeMDEditor:
            return ["claude.md", "markdown", "editor", "instructions", "system prompt"]
        case .sessionHistory:
            return ["session", "history", "chat", "conversation", "transcript"]
        case .commands:
            return ["commands", "slash", "custom"]
        case .skills:
            return ["skills", "skill.md", "agents"]
        case .plugins:
            return ["plugins", "marketplace", "extensions"]
        case .mcpServers:
            return ["mcp", "servers", "model context protocol", "tools", "stdio", "sse"]
        case .cleanup:
            return ["cleanup", "delete", "sessions", "storage", "disk"]
        case .sync:
            return ["version control", "git", "sync", "backup", "commit", "save", "repository", "diff", "push", "pull", "branch"]
        case .folder(let name):
            return ["folder", name.lowercased()]
        case .none:
            return []
        }
    }
}

struct SidebarView: View {
    @Binding var selection: NavigationItem
    @EnvironmentObject var configManager: ConfigurationManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var projects: [Project] = []
    @State private var isLoadingProjects = false
    @State private var filesExpanded = true
    @State private var searchText: String = ""
    @State private var discoveredSubfolders: [SubfolderEntry] = []
    @State private var isLoadingSubfolders = false
    @State private var commandsCount: Int = 0
    @State private var skillsCount: Int = 0
    @State private var pluginsCount: Int = 0
    @State private var mcpServersCount: Int = 0

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func matchesSearch(_ item: NavigationItem) -> Bool {
        guard isSearching else { return true }
        let query = searchText.lowercased()
        return item.searchKeywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Global search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.caption)
                TextField("Search settings...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                if isSearching {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .padding(.horizontal, 4)

            Divider()

            List {
                if !isSearching || [NavigationItem.general, .permissions, .environment, .experimentalFeatures, .hooks, .hud].contains(where: matchesSearch) {
                    Section("Settings") {
                        if matchesSearch(.general) {
                            navItem(.general, label: "General", systemImage: "gearshape")
                        }
                        if matchesSearch(.permissions) {
                            navItem(.permissions, label: "Permissions", systemImage: "lock.shield")
                        }
                        if matchesSearch(.environment) {
                            navItem(.environment, label: "Environment", systemImage: "terminal")
                        }
                        if matchesSearch(.experimentalFeatures) {
                            navItem(.experimentalFeatures, label: "Experimental", systemImage: "flask")
                        }
                        if matchesSearch(.hooks) {
                            navItem(.hooks, label: "Hooks", systemImage: "arrow.triangle.branch")
                        }
                        if matchesSearch(.hud) {
                            navItem(.hud, label: "HUD", systemImage: "gauge.open.with.lines.needle.33percent")
                        }
                    }
                }

                if !isSearching || [NavigationItem.claudeMDEditor, .sessionHistory].contains(where: matchesSearch) {
                    Section("Content") {
                        if matchesSearch(.claudeMDEditor) {
                            navItem(.claudeMDEditor, label: "CLAUDE.md", systemImage: "doc.richtext")
                        }

                        if matchesSearch(.sessionHistory) {
                            navItem(.sessionHistory, label: "Session History", systemImage: "clock.arrow.circlepath")
                        }
                    }
                }

                if !isSearching || [NavigationItem.commands, .skills, .plugins, .mcpServers].contains(where: matchesSearch) {
                    Section("Extensions") {
                        if matchesSearch(.commands) {
                            navCountRow(.commands, label: "Commands", icon: "command", count: commandsCount)
                        }
                        if matchesSearch(.skills) {
                            navCountRow(.skills, label: "Skills", icon: "star", count: skillsCount)
                        }
                        if matchesSearch(.plugins) {
                            navCountRow(.plugins, label: "Plugins", icon: "puzzlepiece", count: pluginsCount)
                        }
                        if matchesSearch(.mcpServers) {
                            navCountRow(.mcpServers, label: "MCP Servers", icon: "server.rack", count: mcpServersCount)
                        }
                    }
                }

                if !isSearching || matchesSearch(.globalFiles) || matchesSearchForAnyProject() || matchesSearchForAnySubfolder() {
                    Section("Folders") {
                        if !isSearching {
                            DisclosureGroup(isExpanded: $filesExpanded) {
                                navItem(.globalFiles, label: "Global", systemImage: "house")

                                if isLoadingProjects {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    ForEach(filteredProjects) { project in
                                        navProjectRow(project)
                                    }
                                }
                            } label: {
                                Label("Files", systemImage: "folder")
                            }
                        } else {
                            if matchesSearch(.globalFiles) {
                                navItem(.globalFiles, label: "Global Files", systemImage: "house")
                            }
                        }

                        if isLoadingSubfolders {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            ForEach(discoveredSubfolders) { subfolder in
                                if matchesSearch(.folder(subfolder.name)) {
                                    navCountRow(
                                        .folder(subfolder.name),
                                        label: subfolder.name.capitalized,
                                        icon: SubfolderEntry.icon(for: subfolder.name),
                                        count: subfolder.itemCount
                                    )
                                }
                            }
                        }
                    }
                }

                if !isSearching || [NavigationItem.cleanup, .sync].contains(where: matchesSearch) {
                    Section("Maintenance") {
                        if matchesSearch(.cleanup) {
                            navItem(.cleanup, label: "Cleanup", systemImage: "trash")
                        }
                        if matchesSearch(.sync) {
                            navItem(.sync, label: "Version Control", systemImage: "arrow.triangle.branch")
                        }
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .onAppear {
            loadProjects()
            discoverSubfolders()
        }
    }

    private func matchesSearchForAnyProject() -> Bool {
        guard isSearching else { return true }
        return matchesSearch(.globalFiles)
    }

    private func matchesSearchForAnySubfolder() -> Bool {
        guard isSearching else { return false }
        return discoveredSubfolders.contains { matchesSearch(.folder($0.name)) }
    }

    private var filteredProjects: [Project] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return projects.filter { project in
            guard project.originalPath != home else { return false }
            let hasClaudeMD = project.claudeMD != nil
            let hasSessions = !project.sessions.isEmpty
            let hasSettings = project.settings != nil
            return hasClaudeMD || hasSessions || hasSettings
        }
    }

    private func loadProjects() {
        isLoadingProjects = true
        projects = configManager.loadProjects()
        isLoadingProjects = false
    }

    // MARK: - Navigation Row Helpers

    private var selectionColor: Color {
        themeManager.resolvedAccentColor
    }

    private func navItem(_ item: NavigationItem, label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(selection == item ? .white : .primary)
            .contentShape(Rectangle())
            .onTapGesture { selection = item }
            .themedRowBackground(isSelected: selection == item, color: selectionColor)
    }

    private func navCountRow(_ item: NavigationItem, label: String, icon: String, count: Int) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(selection == item ? .white.opacity(0.7) : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        (selection == item ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15)),
                        in: Capsule()
                    )
            }
        }
        .foregroundStyle(selection == item ? .white : .primary)
        .contentShape(Rectangle())
        .onTapGesture { selection = item }
        .themedRowBackground(isSelected: selection == item, color: selectionColor)
    }

    private func navProjectRow(_ project: Project) -> some View {
        let item = NavigationItem.projectFiles(project.id)
        return VStack(alignment: .leading, spacing: 2) {
            Label(project.displayName, systemImage: "folder")
            Text(project.originalPath)
                .font(.caption2)
                .foregroundColor(selection == item ? .white.opacity(0.7) : .secondary)
                .lineLimit(1)
        }
        .foregroundStyle(selection == item ? .white : .primary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { selection = item }
        .themedRowBackground(isSelected: selection == item, color: selectionColor)
    }

    private func discoverSubfolders() {
        isLoadingSubfolders = true
        Task.detached {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let claudeDir = home.appendingPathComponent(".claude")
            let fm = FileManager.default

            // Count items in known extension directories
            let cmdCount = (try? fm.contentsOfDirectory(atPath: claudeDir.appendingPathComponent("commands").path))?.count ?? 0
            let sklCount = (try? fm.contentsOfDirectory(atPath: claudeDir.appendingPathComponent("skills").path))?.count ?? 0
            let plgCount = (try? fm.contentsOfDirectory(atPath: claudeDir.appendingPathComponent("plugins").path))?.count ?? 0

            // Count MCP servers from config
            let mcpCount: Int = await MainActor.run {
                configManager.loadMCPServers().count
            }

            // Known sidebar items to exclude from discovered folders
            let excludedNames: Set<String> = ["commands", "skills", "plugins", "projects"]

            guard let contents = try? fm.contentsOfDirectory(
                at: claudeDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                await MainActor.run {
                    commandsCount = cmdCount
                    skillsCount = sklCount
                    pluginsCount = plgCount
                    mcpServersCount = mcpCount
                    discoveredSubfolders = []
                    isLoadingSubfolders = false
                }
                return
            }

            var subfolders: [SubfolderEntry] = []
            for url in contents {
                guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                      values.isDirectory == true else { continue }
                let name = url.lastPathComponent
                guard !excludedNames.contains(name) else { continue }

                let itemCount = (try? fm.contentsOfDirectory(atPath: url.path))?.count ?? 0
                subfolders.append(SubfolderEntry(id: name, name: name, itemCount: itemCount))
            }

            subfolders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            await MainActor.run {
                commandsCount = cmdCount
                skillsCount = sklCount
                pluginsCount = plgCount
                mcpServersCount = mcpCount
                discoveredSubfolders = subfolders
                isLoadingSubfolders = false
            }
        }
    }
}
