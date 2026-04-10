import SwiftUI

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
    case projectSettings(String)
    case projectClaudeMD(String)
    case projectSessions(String)
    case claudeMDEditor
    case sessionHistory
    case commands
    case skills
    case plugins
    case mcpServers
    case agents
    case rules
    case stats
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
        case .projectFiles: return "Files"
        case .projectSettings: return "Settings"
        case .projectClaudeMD: return "CLAUDE.md"
        case .projectSessions: return "Sessions"
        case .claudeMDEditor: return "CLAUDE.md"
        case .sessionHistory: return "Session History"
        case .commands: return "Commands"
        case .skills: return "Skills"
        case .plugins: return "Plugins"
        case .mcpServers: return "MCP Servers"
        case .agents: return "Agents"
        case .rules: return "Rules"
        case .stats: return "Stats"
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
        case .projectSettings: return "gearshape"
        case .projectClaudeMD: return "doc.richtext"
        case .projectSessions: return "clock.arrow.circlepath"
        case .claudeMDEditor: return "doc.richtext"
        case .sessionHistory: return "clock.arrow.circlepath"
        case .commands: return "command"
        case .skills: return "star"
        case .plugins: return "puzzlepiece"
        case .mcpServers: return "server.rack"
        case .agents: return "person.crop.rectangle.stack"
        case .rules: return "list.bullet.rectangle"
        case .stats: return "chart.bar.xaxis"
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
            return ["general", "model", "opus", "sonnet", "haiku", "fast mode", "per-session",
                    "theme", "appearance", "reduce motion",
                    "language", "effort", "output", "verbose",
                    "turn duration", "gitignore", "shell", "bash", "zsh",
                    "git", "branch", "git app", "git instructions",
                    "thinking", "voice", "auto-compact", "compact", "plans",
                    "memory", "auto memory",
                    "updates", "auto updates", "notifications",
                    "cleanup", "retention", "data retention",
                    "attribution", "commit", "pull request",
                    "teams", "teammate",
                    "api key", "api key helper",
                    "profiles", "profile", "save settings", "load settings"]
        case .permissions:
            return ["permissions", "allow", "deny", "ask", "tools", "sandbox", "directories", "mode",
                    "bypass", "dangerous", "default mode"]
        case .environment:
            return ["environment", "env", "variables", "api key", "api base", "proxy", "http proxy",
                    "model override", "tokens", "output tokens", "thinking tokens", "prompt caching",
                    "mcp timeout", "telemetry"]
        case .experimentalFeatures:
            return ["experimental", "thinking", "thinking budget", "agent teams",
                    "preflight", "web fetch", "telemetry", "error reporting", "auto-updater",
                    "sandbox", "worktree", "spinner", "status line", "statusline",
                    "disable auto mode", "disable hooks"]
        case .hooks:
            return ["hooks", "pre tool", "post tool", "prompt submit", "command", "matcher",
                    "notification", "stop", "subagent", "compact", "elicitation", "setup"]
        case .hud:
            return ["hud", "statusline", "status line", "claude-hud", "context bar",
                    "tools", "agents", "todos", "git status", "usage", "layout", "preset"]
        case .globalFiles:
            return ["global", "files", "claude", "settings.json"]
        case .projectFiles:
            return ["project", "files"]
        case .projectSettings:
            return ["project", "settings", "override", "model", "permissions"]
        case .projectClaudeMD:
            return ["project", "claude.md", "instructions"]
        case .projectSessions:
            return ["project", "sessions", "history"]
        case .claudeMDEditor:
            return ["claude.md", "markdown", "editor", "instructions", "system prompt", "templates", "template"]
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
        case .agents:
            return ["agents", "subagents", "custom", "prompt"]
        case .rules:
            return ["rules", "instructions", "path", "patterns"]
        case .stats:
            return ["stats", "usage", "analytics", "tokens", "models", "tools"]
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

struct SearchableSection: Identifiable, Hashable {
    let id: String          // section ID for scrollTo
    let label: String       // display name e.g. "Language & Output"
    let keywords: [String]  // keywords that match this section
    let parent: NavigationItem
}

// MARK: - Section Mappings

let generalSections: [SearchableSection] = [
    SearchableSection(id: "profiles", label: "Profiles", keywords: ["profiles", "profile", "save settings", "load settings"], parent: .general),
    SearchableSection(id: "model", label: "Model", keywords: ["model", "opus", "sonnet", "haiku", "fast mode", "per-session"], parent: .general),
    SearchableSection(id: "appearance", label: "Appearance", keywords: ["theme", "appearance", "reduce motion"], parent: .general),
    SearchableSection(id: "language", label: "Language & Output", keywords: ["language", "effort", "output", "verbose"], parent: .general),
    SearchableSection(id: "behavior", label: "Behavior", keywords: ["turn duration", "gitignore", "shell", "bash", "zsh", "git instructions", "voice", "auto-compact", "compact", "plans"], parent: .general),
    SearchableSection(id: "memory", label: "Memory", keywords: ["memory", "auto memory"], parent: .general),
    SearchableSection(id: "git", label: "Git", keywords: ["git", "branch", "git app"], parent: .general),
    SearchableSection(id: "updates", label: "Updates", keywords: ["updates", "auto updates"], parent: .general),
    SearchableSection(id: "notifications", label: "Notifications", keywords: ["notifications"], parent: .general),
    SearchableSection(id: "data-retention", label: "Data Retention", keywords: ["cleanup", "retention", "data retention"], parent: .general),
    SearchableSection(id: "attribution", label: "Attribution", keywords: ["attribution", "commit", "pull request"], parent: .general),
    SearchableSection(id: "teams", label: "Teams", keywords: ["teams", "teammate"], parent: .general),
    SearchableSection(id: "api-key-helper", label: "API Key Helper", keywords: ["api key", "api key helper"], parent: .general),
]

let experimentalSections: [SearchableSection] = [
    SearchableSection(id: "thinking", label: "Thinking", keywords: ["thinking", "thinking budget"], parent: .experimentalFeatures),
    SearchableSection(id: "agent-teams", label: "Agent Teams", keywords: ["agent teams"], parent: .experimentalFeatures),
    SearchableSection(id: "performance", label: "Performance", keywords: ["preflight", "web fetch"], parent: .experimentalFeatures),
    SearchableSection(id: "privacy", label: "Privacy & Updates", keywords: ["telemetry", "error reporting", "auto-updater"], parent: .experimentalFeatures),
    SearchableSection(id: "mode-control", label: "Mode Control", keywords: ["disable auto mode", "disable hooks"], parent: .experimentalFeatures),
    SearchableSection(id: "sandbox", label: "Sandbox", keywords: ["sandbox"], parent: .experimentalFeatures),
    SearchableSection(id: "worktree", label: "Worktree", keywords: ["worktree"], parent: .experimentalFeatures),
    SearchableSection(id: "spinner", label: "Spinner", keywords: ["spinner"], parent: .experimentalFeatures),
    SearchableSection(id: "status-line", label: "Status Line", keywords: ["status line", "statusline"], parent: .experimentalFeatures),
]

let permissionsSections: [SearchableSection] = [
    SearchableSection(id: "default-mode", label: "Default Mode", keywords: ["default mode", "bypass", "dangerous"], parent: .permissions),
    SearchableSection(id: "tool-permissions", label: "Tool Permissions", keywords: ["allow", "deny", "ask", "tools"], parent: .permissions),
]

let environmentSections: [SearchableSection] = [
    SearchableSection(id: "api", label: "API & Auth", keywords: ["api key", "api base"], parent: .environment),
    SearchableSection(id: "model-overrides", label: "Model Overrides", keywords: ["model override"], parent: .environment),
    SearchableSection(id: "performance", label: "Performance", keywords: ["tokens", "output tokens", "thinking tokens", "prompt caching", "mcp timeout"], parent: .environment),
    SearchableSection(id: "network", label: "Network & Proxy", keywords: ["proxy", "http proxy"], parent: .environment),
]

let allSearchableSections: [SearchableSection] = generalSections + experimentalSections + permissionsSections + environmentSections

struct SidebarView: View {
    @Binding var selection: NavigationItem
    @Binding var scrollToSection: String?
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var projects: [Project] = []
    @State private var isLoadingProjects = false
    @State private var filesExpanded = true
    @State private var expandedProjects: Set<String> = []
    @State private var searchText: String = ""
    @State private var discoveredSubfolders: [SubfolderEntry] = []
    @State private var isLoadingSubfolders = false
    @State private var commandsCount: Int = 0
    @State private var skillsCount: Int = 0
    @State private var pluginsCount: Int = 0
    @State private var mcpServersCount: Int = 0
    @State private var agentsCount: Int = 0
    @State private var rulesCount: Int = 0

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func matchesSearch(_ item: NavigationItem) -> Bool {
        guard isSearching else { return true }
        let query = searchText.lowercased()
        return item.searchKeywords.contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func matchingSections(for item: NavigationItem) -> [SearchableSection] {
        guard isSearching else { return [] }
        let query = searchText.lowercased()
        return allSearchableSections.filter { section in
            section.parent == item && section.keywords.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    @ViewBuilder
    private func searchSubItems(for item: NavigationItem) -> some View {
        if isSearching {
            let sections = matchingSections(for: item)
            ForEach(sections) { section in
                HStack(spacing: 6) {
                    Image(systemName: "arrow.turn.down.right")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(section.label)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 24)
                .contentShape(Rectangle())
                .onTapGesture {
                    selection = item
                    scrollToSection = section.id
                }
            }
        }
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

            List(selection: $selection) {
                if !isSearching || [NavigationItem.general, .permissions, .environment, .experimentalFeatures, .hooks, .hud].contains(where: matchesSearch) {
                    Section("Settings") {
                        if matchesSearch(.general) {
                            navItem(.general, label: "General", systemImage: "gearshape")
                            searchSubItems(for: .general)
                        }
                        if matchesSearch(.permissions) {
                            navItem(.permissions, label: "Permissions", systemImage: "lock.shield")
                            searchSubItems(for: .permissions)
                        }
                        if matchesSearch(.environment) {
                            navItem(.environment, label: "Environment", systemImage: "terminal")
                            searchSubItems(for: .environment)
                        }
                        if matchesSearch(.experimentalFeatures) {
                            navItem(.experimentalFeatures, label: "Experimental", systemImage: "flask")
                            searchSubItems(for: .experimentalFeatures)
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

                if !isSearching || matchesSearch(.globalFiles) || matchesSearchForAnyProject() {
                    Section("Configuration") {
                        if matchesSearch(.globalFiles) {
                            navItem(.globalFiles, label: "Global", systemImage: "house")
                                .contextMenu {
                                    Button("Show in Finder") {
                                        let path = FileManager.default.homeDirectoryForCurrentUser
                                            .appendingPathComponent(".claude").path
                                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                    }
                                }
                        }

                        if !isSearching || matchesSearchForAnyProject() {
                            DisclosureGroup(isExpanded: $filesExpanded) {
                                if isLoadingProjects {
                                    ProgressView()
                                        .controlSize(.small)
                                } else {
                                    ForEach(filteredProjects) { project in
                                        navProjectRow(project)
                                    }
                                }
                            } label: {
                                navCountRow(.none, label: "Projects", icon: "folder", count: filteredProjects.count)
                            }
                        }
                    }
                }

                if !isSearching || [NavigationItem.commands, .skills, .plugins, .mcpServers, .agents, .rules].contains(where: matchesSearch) {
                    Section("Extensions") {
                        if matchesSearch(.commands) {
                            navCountRow(.commands, label: "Commands", icon: "command", count: commandsCount)
                                .contextMenu { showClaudeDirMenu("commands") }
                        }
                        if matchesSearch(.skills) {
                            navCountRow(.skills, label: "Skills", icon: "star", count: skillsCount)
                                .contextMenu { showClaudeDirMenu("skills") }
                        }
                        if matchesSearch(.plugins) {
                            navCountRow(.plugins, label: "Plugins", icon: "puzzlepiece", count: pluginsCount)
                                .contextMenu { showClaudeDirMenu("plugins") }
                        }
                        if matchesSearch(.mcpServers) {
                            navCountRow(.mcpServers, label: "MCP Servers", icon: "server.rack", count: mcpServersCount)
                                .contextMenu {
                                    Button("Show in Finder") {
                                        let path = FileManager.default.homeDirectoryForCurrentUser
                                            .appendingPathComponent(".claude.json").path
                                        NSWorkspace.shared.selectFile(path,
                                            inFileViewerRootedAtPath: FileManager.default.homeDirectoryForCurrentUser.path)
                                    }
                                }
                        }
                        if matchesSearch(.agents) {
                            navCountRow(.agents, label: "Agents", icon: "person.crop.rectangle.stack", count: agentsCount)
                                .contextMenu { showClaudeDirMenu("agents") }
                        }
                        if matchesSearch(.rules) {
                            navCountRow(.rules, label: "Rules", icon: "list.bullet.rectangle", count: rulesCount)
                                .contextMenu { showClaudeDirMenu("rules") }
                        }
                    }
                }

                if !isSearching || matchesSearchForAnySubfolder() {
                    if isLoadingSubfolders {
                        Section("Storage") {
                            ProgressView()
                                .controlSize(.small)
                        }
                    } else if !discoveredSubfolders.isEmpty {
                        Section("Storage") {
                            ForEach(discoveredSubfolders) { subfolder in
                                if matchesSearch(.folder(subfolder.name)) {
                                    navCountRow(
                                        .folder(subfolder.name),
                                        label: subfolder.name.capitalized,
                                        icon: SubfolderEntry.icon(for: subfolder.name),
                                        count: subfolder.itemCount
                                    )
                                    .contextMenu {
                                        Button("Show in Finder") {
                                            let path = FileManager.default.homeDirectoryForCurrentUser
                                                .appendingPathComponent(".claude/\(subfolder.name)").path
                                            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                if !isSearching || [NavigationItem.stats, .cleanup, .sync].contains(where: matchesSearch) {
                    Section("Maintenance") {
                        if matchesSearch(.stats) {
                            navItem(.stats, label: "Stats", systemImage: "chart.bar.xaxis")
                        }
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
            .onChange(of: searchText) {
                guard isSearching else { return }
                // Auto-select first matching section to prevent stale selection rendering
                let allItems: [NavigationItem] = [.general, .permissions, .environment, .experimentalFeatures, .hooks, .hud,
                                                   .claudeMDEditor, .sessionHistory, .commands, .skills, .plugins, .mcpServers,
                                                   .agents, .rules, .stats, .cleanup, .sync]
                if !matchesSearch(selection), let first = allItems.first(where: matchesSearch) {
                    selection = first
                }
            }
        }
        .onAppear {
            loadProjects()
            discoverSubfolders()
        }
    }

    private func matchesSearchForAnyProject() -> Bool {
        guard isSearching else { return true }
        let query = searchText.lowercased()
        return filteredProjects.contains { project in
            project.displayName.localizedCaseInsensitiveContains(query) ||
            project.originalPath.localizedCaseInsensitiveContains(query)
        }
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
        Task {
            projects = configManager.loadProjects()
            isLoadingProjects = false
        }
    }

    // MARK: - Context Menu Helpers

    @ViewBuilder
    private func showClaudeDirMenu(_ subdir: String) -> some View {
        Button("Show in Finder") {
            let path = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/\(subdir)").path
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        }
    }

    // MARK: - Navigation Row Helpers

    private func navItem(_ item: NavigationItem, label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .tag(item)
    }

    private func navCountRow(_ item: NavigationItem, label: String, icon: String, count: Int) -> some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15), in: Capsule())
            }
        }
        .tag(item)
    }

    private func navProjectRow(_ project: Project) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { expandedProjects.contains(project.id) },
                set: { expanded in
                    if expanded { expandedProjects.insert(project.id) }
                    else { expandedProjects.remove(project.id) }
                }
            )
        ) {
            Label("Settings", systemImage: "gearshape")
                .tag(NavigationItem.projectSettings(project.id))
            Label("CLAUDE.md", systemImage: "doc.richtext")
                .tag(NavigationItem.projectClaudeMD(project.id))
            Label("Files", systemImage: "folder")
                .tag(NavigationItem.projectFiles(project.id))
            Label("Sessions", systemImage: "clock.arrow.circlepath")
                .tag(NavigationItem.projectSessions(project.id))
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(project.displayName)
                Text(project.originalPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .contextMenu {
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.originalPath)
            }
            Button("Show .claude/ in Finder") {
                let claudeDir = URL(fileURLWithPath: project.originalPath).appendingPathComponent(".claude").path
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: claudeDir)
            }
        }
    }

    private func discoverSubfolders() {
        isLoadingSubfolders = true
        Task.detached {
            let home = FileManager.default.homeDirectoryForCurrentUser
            let claudeDir = home.appendingPathComponent(".claude")
            let fm = FileManager.default

            // Count commands: recursively find all .md files (matching CommandsView logic)
            let cmdCount = Self.countFilesRecursively(
                in: claudeDir.appendingPathComponent("commands"),
                matching: { $0.pathExtension.lowercased() == "md" },
                fm: fm
            )

            // Count skills: directories + standalone .md files (matching SkillsView logic)
            let sklCount = Self.countFiles(
                in: claudeDir.appendingPathComponent("skills"),
                matching: { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    return isDir || url.pathExtension.lowercased() == "md"
                },
                fm: fm
            )

            // Count installed plugins from known_marketplaces.json (matching PluginsView logic)
            let plgCount = Self.countInstalledPlugins(claudeDir: claudeDir)

            // Count MCP servers from config (global + project)
            let mcpCount: Int = await MainActor.run {
                configManager.loadAllScopedMCPServers().count
            }

            // Count agents: directories + standalone .md files (matching AgentsView logic)
            let agtCount = Self.countFiles(
                in: claudeDir.appendingPathComponent("agents"),
                matching: { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    return isDir || url.pathExtension.lowercased() == "md"
                },
                fm: fm
            )

            // Count rules: recursively find all .md files (matching RulesView logic)
            let rulCount = Self.countFilesRecursively(
                in: claudeDir.appendingPathComponent("rules"),
                matching: { $0.pathExtension.lowercased() == "md" },
                fm: fm
            )

            // Get projects on main actor, then count items off main actor
            let projects: [Project] = await MainActor.run {
                configManager.loadProjects()
            }
            let projectCounts = Self.countProjectItems(projects: projects, fm: fm)

            // Known sidebar items to exclude from discovered folders
            let excludedNames: Set<String> = ["commands", "skills", "plugins", "projects", "agents", "rules"]

            guard let contents = try? fm.contentsOfDirectory(
                at: claudeDir,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {
                await MainActor.run {
                    commandsCount = cmdCount + projectCounts.commands
                    skillsCount = sklCount + projectCounts.skills
                    pluginsCount = plgCount
                    mcpServersCount = mcpCount
                    agentsCount = agtCount + projectCounts.agents
                    rulesCount = rulCount + projectCounts.rules
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

                let itemCount = (try? fm.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                ))?.count ?? 0
                subfolders.append(SubfolderEntry(id: name, name: name, itemCount: itemCount))
            }

            subfolders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

            await MainActor.run {
                commandsCount = cmdCount + projectCounts.commands
                skillsCount = sklCount + projectCounts.skills
                pluginsCount = plgCount
                mcpServersCount = mcpCount
                agentsCount = agtCount + projectCounts.agents
                rulesCount = rulCount + projectCounts.rules
                discoveredSubfolders = subfolders
                isLoadingSubfolders = false
            }
        }
    }

    // MARK: - Count Helpers

    private struct ProjectItemCounts {
        var commands = 0
        var skills = 0
        var agents = 0
        var rules = 0
    }

    /// Count files in a directory matching a predicate, skipping hidden files.
    private nonisolated static func countFiles(in dir: URL, matching predicate: (URL) -> Bool, fm: FileManager) -> Int {
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return contents.filter(predicate).count
    }

    /// Recursively count files in a directory matching a predicate, skipping hidden files.
    private nonisolated static func countFilesRecursively(in dir: URL, matching predicate: (URL) -> Bool, fm: FileManager) -> Int {
        guard let enumerator = fm.enumerator(
            at: dir,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        var count = 0
        for case let fileURL as URL in enumerator {
            if predicate(fileURL) {
                count += 1
            }
        }
        return count
    }

    /// Count installed plugins by parsing known_marketplaces.json (matches PluginsView logic).
    private nonisolated static func countInstalledPlugins(claudeDir: URL) -> Int {
        let knownURL = claudeDir.appendingPathComponent("plugins/known_marketplaces.json")
        guard let data = try? Data(contentsOf: knownURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return 0
        }

        var count = 0
        for (_, value) in json {
            guard let entry = value as? [String: Any],
                  let installLocation = entry["installLocation"] as? String else { continue }
            let installURL = URL(fileURLWithPath: installLocation)
            let marketplaceJSON = installURL.appendingPathComponent(".claude-plugin/marketplace.json")

            if let mData = try? Data(contentsOf: marketplaceJSON),
               let mJSON = try? JSONSerialization.jsonObject(with: mData) as? [String: Any],
               let plugins = mJSON["plugins"] as? [[String: Any]] {
                count += plugins.count
            }
        }
        return count
    }

    /// Count project-level items across all known projects.
    private nonisolated static func countProjectItems(projects: [Project], fm: FileManager) -> ProjectItemCounts {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var counts = ProjectItemCounts()

        for project in projects {
            guard project.originalPath != home else { continue }
            let claudeDir = URL(fileURLWithPath: project.originalPath).appendingPathComponent(".claude")

            counts.commands += countFilesRecursively(
                in: claudeDir.appendingPathComponent("commands"),
                matching: { $0.pathExtension.lowercased() == "md" },
                fm: fm
            )
            counts.skills += countFiles(
                in: claudeDir.appendingPathComponent("skills"),
                matching: { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    return isDir || url.pathExtension.lowercased() == "md"
                },
                fm: fm
            )
            counts.agents += countFiles(
                in: claudeDir.appendingPathComponent("agents"),
                matching: { url in
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                    return isDir || url.pathExtension.lowercased() == "md"
                },
                fm: fm
            )
            counts.rules += countFilesRecursively(
                in: claudeDir.appendingPathComponent("rules"),
                matching: { $0.pathExtension.lowercased() == "md" },
                fm: fm
            )
        }
        return counts
    }
}
