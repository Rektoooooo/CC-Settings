import SwiftUI

// MARK: - Agent Model

struct AgentEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let scope: ConfigScope
    let isSymlink: Bool
    let symlinkTarget: String?
    var files: [AgentFile]
    var promptContent: String?

    static func == (lhs: AgentEntry, rhs: AgentEntry) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    var mainFile: AgentFile? {
        files.first(where: { $0.name.lowercased() == "\(name.lowercased()).md" }) ??
        files.first(where: { $0.name.hasSuffix(".md") })
    }
}

struct AgentFile: Identifiable, Hashable {
    let id: String
    let name: String
    let path: URL
    let relativePath: String
    let size: Int64

    var isMarkdown: Bool { name.hasSuffix(".md") }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    static func == (lhs: AgentFile, rhs: AgentFile) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - AgentsView

struct AgentsView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var agents: [AgentEntry] = []
    @State private var selectedAgent: AgentEntry?
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var scopeFilter: ScopeFilter = .all
    @State private var projects: [Project] = []

    private var globalAgentsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/agents")
    }

    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(agents.compactMap { a -> String? in
            if case .project(let id, _) = a.scope { return id }
            return nil
        })
        for project in projects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var filteredAgents: [AgentEntry] {
        var result = agents

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
                $0.scope.displayName.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        HSplitView {
            VStack(spacing: 0) {
                headerSection
                searchAndFilterSection
                Divider()
                agentListSection
                Divider()
                footerSection
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 380)

            if let agent = selectedAgent,
               let current = agents.first(where: { $0.id == agent.id }) {
                AgentDetailView(agent: current)
            } else {
                EmptyContentPlaceholder(
                    icon: "person.crop.rectangle.stack",
                    title: "Select an Agent",
                    subtitle: "Choose an agent to view its definition"
                )
            }
        }
        .onAppear {
            loadAgents()
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "person.crop.rectangle.stack")
                    .foregroundColor(.themeAccent)
                    .font(.title3)
                Text("Agents")
                    .font(.headline)
                Spacer()
                Button {
                    loadAgents()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            Text("Global + Project agents")
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
                TextField("Search agents...", text: $searchText)
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

    // MARK: - Agent List

    @ViewBuilder
    private var agentListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading agents...")
                .font(.caption)
            Spacer()
        } else if filteredAgents.isEmpty {
            Spacer()
            EmptyContentPlaceholder(
                icon: "person.crop.rectangle.stack",
                title: agents.isEmpty ? "No Agents" : "No Results",
                subtitle: agents.isEmpty ? "Agents will appear in ~/.claude/agents/ or project .claude/agents/" : "No agents match your search"
            )
            Spacer()
        } else {
            List(selection: $selectedAgent) {
                ForEach(filteredAgents) { agent in
                    AgentItemRow(agent: agent)
                        .tag(agent)
                        .contextMenu {
                            Button("Show in Finder") {
                                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: agent.path.path)
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
            Text("\(filteredAgents.count) agent\(filteredAgents.count == 1 ? "" : "s")")
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

    // MARK: - Data

    private func loadAgents() {
        isLoading = true
        projects = configManager.loadProjects()
        let fm = FileManager.default
        var loaded: [AgentEntry] = []

        loaded += loadAgentsFrom(url: globalAgentsURL, scope: .global, fm: fm)

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            let projectAgentsURL = URL(fileURLWithPath: project.originalPath)
                .appendingPathComponent(".claude/agents")
            let scope = ConfigScope.project(id: project.id, path: project.originalPath)
            loaded += loadAgentsFrom(url: projectAgentsURL, scope: scope, fm: fm)
        }

        agents = loaded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        isLoading = false

        if let sel = selectedAgent, !agents.contains(where: { $0.id == sel.id }) {
            selectedAgent = nil
        }
    }

    private func loadAgentsFrom(url: URL, scope: ConfigScope, fm: FileManager) -> [AgentEntry] {
        guard let contents = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var result: [AgentEntry] = []
        for itemURL in contents {
            let isSymlink = (try? itemURL.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink ?? false
            let resolvedURL = isSymlink ? itemURL.resolvingSymlinksInPath() : itemURL
            let isDirectory = (try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true

            let symlinkTarget: String? = isSymlink
                ? (try? fm.destinationOfSymbolicLink(atPath: itemURL.path))
                : nil

            if isDirectory {
                // Directory-based agent (bundle with multiple files)
                let files = loadAgentFiles(from: resolvedURL, basePath: resolvedURL)
                let name = itemURL.lastPathComponent

                let mainMD = files.first(where: { $0.name.lowercased() == "\(name.lowercased()).md" }) ??
                             files.first(where: { $0.name.hasSuffix(".md") })
                let promptContent = mainMD.flatMap { try? String(contentsOf: $0.path, encoding: .utf8) }

                result.append(AgentEntry(
                    id: itemURL.path,
                    name: name,
                    path: itemURL,
                    scope: scope,
                    isSymlink: isSymlink,
                    symlinkTarget: symlinkTarget,
                    files: files,
                    promptContent: promptContent
                ))
            } else if itemURL.pathExtension.lowercased() == "md" {
                // Standalone .md file agent
                let name = itemURL.deletingPathExtension().lastPathComponent
                let attrs = try? itemURL.resourceValues(forKeys: [.fileSizeKey])
                let fileSize = Int64(attrs?.fileSize ?? 0)
                let promptContent = try? String(contentsOf: itemURL, encoding: .utf8)

                let file = AgentFile(
                    id: itemURL.path,
                    name: itemURL.lastPathComponent,
                    path: itemURL,
                    relativePath: itemURL.lastPathComponent,
                    size: fileSize
                )

                result.append(AgentEntry(
                    id: itemURL.path,
                    name: name,
                    path: itemURL,
                    scope: scope,
                    isSymlink: isSymlink,
                    symlinkTarget: symlinkTarget,
                    files: [file],
                    promptContent: promptContent
                ))
            }
        }
        return result
    }

    private func loadAgentFiles(from url: URL, basePath: URL) -> [AgentFile] {
        let fm = FileManager.default
        var result: [AgentFile] = []

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory != true else {
                continue
            }
            let attrs = try? fileURL.resourceValues(forKeys: [.fileSizeKey])
            let relativePath = fileURL.path.replacingOccurrences(of: basePath.path + "/", with: "")

            result.append(AgentFile(
                id: fileURL.path,
                name: fileURL.lastPathComponent,
                path: fileURL,
                relativePath: relativePath,
                size: Int64(attrs?.fileSize ?? 0)
            ))
        }

        return result.sorted { a, b in
            if a.isMarkdown != b.isMarkdown { return a.isMarkdown }
            return a.relativePath.localizedCaseInsensitiveCompare(b.relativePath) == .orderedAscending
        }
    }
}

// MARK: - AgentItemRow

private struct AgentItemRow: View {
    let agent: AgentEntry

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: agent.isSymlink ? "link" : "person.crop.rectangle.stack")
                .foregroundColor(agent.isSymlink ? .orange : .themeAccent)
                .font(.body)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name)
                    .font(.body)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    ScopeBadge(scope: agent.scope)
                    Text("\(agent.files.count) file\(agent.files.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - AgentDetailView

private struct AgentDetailView: View {
    let agent: AgentEntry
    @State private var selectedFile: AgentFile?
    @State private var content: String = ""
    @State private var viewMode: ViewMode = .preview

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: agent.isSymlink ? "link" : "person.crop.rectangle.stack")
                    .foregroundColor(agent.isSymlink ? .orange : .themeAccent)
                    .font(.title3)

                Text(agent.name)
                    .font(.headline)
                    .lineLimit(1)

                ScopeBadge(scope: agent.scope)

                Spacer()

                if agent.files.count > 1 {
                    Picker("", selection: fileBinding) {
                        ForEach(agent.files) { file in
                            HStack(spacing: 4) {
                                Image(systemName: file.isMarkdown ? "doc.richtext" : "doc")
                                Text(file.relativePath)
                            }
                            .tag(file as AgentFile?)
                        }
                    }
                    .frame(maxWidth: 200)
                }

                if agent.files.first(where: { $0.isMarkdown }) != nil {
                    ViewModePicker(mode: $viewMode)
                }

                Text("\(agent.files.count) file\(agent.files.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassToolbar()

            // Content
            if let file = selectedFile {
                if file.isMarkdown {
                    switch viewMode {
                    case .source:
                        sourceView
                    case .preview:
                        markdownPreviewView
                    case .split:
                        HSplitView {
                            VStack(spacing: 0) {
                                PaneHeader(icon: "doc.text", title: "Source")
                                sourceView
                            }
                            VStack(spacing: 0) {
                                PaneHeader(icon: "eye", title: "Preview")
                                markdownPreviewView
                            }
                        }
                    }
                } else {
                    sourceView
                }
            } else {
                EmptyContentPlaceholder(
                    icon: "doc.text",
                    title: "No Files",
                    subtitle: "This agent has no viewable files"
                )
            }
        }
        .frame(minWidth: 400)
        .onAppear {
            selectedFile = agent.mainFile ?? agent.files.first
            loadContent()
        }
        .onChange(of: agent.id) { _, _ in
            selectedFile = agent.mainFile ?? agent.files.first
            loadContent()
        }
        .onChange(of: selectedFile?.id) { _, _ in
            loadContent()
        }
    }

    private var fileBinding: Binding<AgentFile?> {
        Binding(get: { selectedFile }, set: { selectedFile = $0 })
    }

    @ViewBuilder
    private var sourceView: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .textSelection(.enabled)
        }
    }

    @ViewBuilder
    private var markdownPreviewView: some View {
        ScrollView {
            MarkdownPreview(markdown: content)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    private func loadContent() {
        guard let file = selectedFile else {
            content = ""
            return
        }
        content = (try? String(contentsOf: file.path, encoding: .utf8)) ?? "[Unable to read file]"
    }
}
