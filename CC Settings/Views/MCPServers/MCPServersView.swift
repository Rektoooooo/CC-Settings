import SwiftUI

struct MCPServersView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var servers: [ScopedMCPServer] = []
    @State private var selectedServer: ScopedMCPServer?
    @State private var searchText = ""
    @State private var showEditorSheet = false
    @State private var editingServer: ScopedMCPServer?
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    @State private var serverToDelete: ScopedMCPServer?
    @State private var scopeFilter: ScopeFilter = .all
    @State private var projects: [Project] = []
    @State private var showMoveSheet = false
    @State private var serverToMove: ScopedMCPServer?
    @State private var editorTargetScope: ConfigScope = .global

    /// All distinct scopes found across loaded servers + known projects with .mcp.json.
    private var availableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let seen = Set(servers.compactMap { s -> String? in
            if case .project(let id, _) = s.scope { return id }
            return nil
        })
        for project in projects {
            if seen.contains(project.id) {
                scopes.append(.project(id: project.id, path: project.originalPath))
            }
        }
        return scopes
    }

    private var filteredServers: [ScopedMCPServer] {
        var result = servers

        // Apply scope filter
        switch scopeFilter {
        case .all:
            break
        case .global:
            result = result.filter { $0.scope.isGlobal }
        case .project(let id):
            result = result.filter {
                if case .project(let pid, _) = $0.scope { return pid == id }
                return false
            }
        }

        // Apply search
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.config.id.lowercased().contains(query) ||
                ($0.config.command?.lowercased().contains(query) ?? false) ||
                ($0.config.url?.lowercased().contains(query) ?? false) ||
                $0.scope.displayName.lowercased().contains(query)
            }
        }

        return result
    }

    var body: some View {
        HSplitView {
            // Left column - Server list
            VStack(spacing: 0) {
                headerSection
                searchAndFilterSection
                Divider()
                serverListSection
                Divider()
                footerSection
            }
            .frame(minWidth: 200, idealWidth: 300, maxWidth: 380)

            // Right column - Detail
            if let selected = selectedServer,
               let currentServer = servers.first(where: { $0.id == selected.id }) {
                MCPServerDetailView(
                    server: currentServer.config,
                    scope: currentServer.scope,
                    onEdit: {
                        editingServer = currentServer
                        editorTargetScope = currentServer.scope
                        showEditorSheet = true
                    },
                    onDelete: {
                        serverToDelete = currentServer
                        showDeleteAlert = true
                    },
                    onMove: {
                        serverToMove = currentServer
                        showMoveSheet = true
                    }
                )
            } else {
                EmptyContentPlaceholder(
                    icon: "server.rack",
                    title: "Select a Server",
                    subtitle: "Choose a server from the list to view details"
                )
            }
        }
        .onAppear {
            loadServers()
        }
        .sheet(isPresented: $showEditorSheet) {
            MCPServerEditorSheet(
                existingServer: editingServer?.config,
                existingNames: existingNamesForScope(editorTargetScope),
                targetScope: editorTargetScope,
                availableScopes: allAvailableScopes
            ) { savedServer, scope in
                saveServer(savedServer, replacing: editingServer?.config.id, scope: scope, originalScope: editingServer?.scope)
            }
        }
        .alert("Delete Server", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let server = serverToDelete {
                    deleteServer(server)
                }
            }
        } message: {
            if let server = serverToDelete {
                Text("Are you sure you want to delete \"\(server.config.id)\" from \(server.scope.displayName)? This cannot be undone.")
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            if let server = serverToMove {
                MoveServerSheet(
                    server: server,
                    availableScopes: allAvailableScopes.filter { $0 != server.scope }
                ) { targetScope in
                    configManager.moveMCPServer(server.config, from: server.scope, to: targetScope)
                    loadServers()
                }
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundColor(.themeAccent)
                    .font(.title3)
                Text("MCP Servers")
                    .font(.headline)
                Spacer()
                Button {
                    editingServer = nil
                    editorTargetScope = .global
                    showEditorSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .help("Add Server")

                Button {
                    loadServers()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .help("Reload")
            }
            Text("Global + Project configs")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(12)
    }

    // MARK: - Search & Filter

    @ViewBuilder
    private var searchAndFilterSection: some View {
        VStack(spacing: 8) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Search servers...", text: $searchText)
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

            // Scope filter
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

    // MARK: - Server List

    @ViewBuilder
    private var serverListSection: some View {
        if isLoading {
            Spacer()
            ProgressView("Loading servers...")
                .font(.caption)
            Spacer()
        } else if filteredServers.isEmpty {
            Spacer()
            EmptyContentPlaceholder(
                icon: "server.rack",
                title: servers.isEmpty ? "No MCP Servers" : "No Results",
                subtitle: servers.isEmpty ? "No MCP servers configured" : "No servers match your search"
            )
            Spacer()
        } else {
            List(selection: $selectedServer) {
                ForEach(filteredServers) { server in
                    MCPServerItemRow(server: server.config, scope: server.scope)
                        .tag(server)
                        .contextMenu {
                            Button("Edit") {
                                editingServer = server
                                editorTargetScope = server.scope
                                showEditorSheet = true
                            }

                            Menu("Move to...") {
                                ForEach(allAvailableScopes.filter { $0 != server.scope }) { scope in
                                    Button(scope.displayName) {
                                        configManager.moveMCPServer(server.config, from: server.scope, to: scope)
                                        loadServers()
                                    }
                                }
                            }

                            Button("Show in Finder") {
                                let path = configFilePath(for: server.scope)
                                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: URL(fileURLWithPath: path).deletingLastPathComponent().path)
                            }
                            Divider()
                            Button("Delete", role: .destructive) {
                                serverToDelete = server
                                showDeleteAlert = true
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
            Text("\(filteredServers.count) server\(filteredServers.count == 1 ? "" : "s")")
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

    /// All scopes the user can target (global + all known projects).
    private var allAvailableScopes: [ConfigScope] {
        var scopes: [ConfigScope] = [.global]
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        for project in projects {
            guard project.originalPath != home else { continue }
            scopes.append(.project(id: project.id, path: project.originalPath))
        }
        return scopes
    }

    private func existingNamesForScope(_ scope: ConfigScope) -> Set<String> {
        Set(servers.filter { $0.scope == scope }.map(\.config.id))
    }

    private func configFilePath(for scope: ConfigScope) -> String {
        switch scope {
        case .global:
            return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json").path
        case .project(_, let path):
            return URL(fileURLWithPath: path).appendingPathComponent(".mcp.json").path
        }
    }

    // MARK: - Data Operations

    private func loadServers() {
        isLoading = true
        projects = configManager.loadProjects()
        servers = configManager.loadAllScopedMCPServers()
        isLoading = false

        if let sel = selectedServer, !servers.contains(where: { $0.id == sel.id }) {
            selectedServer = nil
        }
    }

    private func saveServer(_ server: MCPServerConfig, replacing oldName: String?, scope: ConfigScope, originalScope: ConfigScope?) {
        // If scope changed, move the server
        if let origScope = originalScope, origScope != scope {
            // Delete from original scope
            switch origScope {
            case .global:
                var dict = configManager.loadMCPServers()
                dict.removeValue(forKey: oldName ?? server.id)
                configManager.saveMCPServers(dict)
            case .project(_, let path):
                var dict = configManager.loadProjectMCPServers(projectPath: path)
                dict.removeValue(forKey: oldName ?? server.id)
                configManager.saveProjectMCPServers(dict, projectPath: path)
            }
        }

        // Save to target scope
        switch scope {
        case .global:
            var dict = configManager.loadMCPServers()
            if let oldName = oldName, oldName != server.id {
                dict.removeValue(forKey: oldName)
            }
            dict[server.id] = server
            configManager.saveMCPServers(dict)
        case .project(_, let path):
            var dict = configManager.loadProjectMCPServers(projectPath: path)
            if let oldName = oldName, oldName != server.id {
                dict.removeValue(forKey: oldName)
            }
            dict[server.id] = server
            configManager.saveProjectMCPServers(dict, projectPath: path)
        }

        loadServers()
        selectedServer = servers.first(where: { $0.config.id == server.id && $0.scope == scope })
    }

    private func deleteServer(_ server: ScopedMCPServer) {
        switch server.scope {
        case .global:
            var dict = configManager.loadMCPServers()
            dict.removeValue(forKey: server.config.id)
            configManager.saveMCPServers(dict)
        case .project(_, let path):
            var dict = configManager.loadProjectMCPServers(projectPath: path)
            dict.removeValue(forKey: server.config.id)
            configManager.saveProjectMCPServers(dict, projectPath: path)
        }

        if selectedServer?.id == server.id {
            selectedServer = nil
        }
        loadServers()
    }
}

// MARK: - Scope Filter

enum ScopeFilter: Equatable {
    case all
    case global
    case project(id: String)
}

// MARK: - Scope Filter Chip

struct ScopeFilterChip: View {
    let label: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(isSelected ? Color.themeAccent.opacity(0.2) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isSelected ? Color.themeAccent : Color.secondary.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundColor(isSelected ? .themeAccent : .secondary)
    }
}

// MARK: - MCPServerItemRow

struct MCPServerItemRow: View {
    let server: MCPServerConfig
    let scope: ConfigScope

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: server.transportType.icon)
                .foregroundColor(server.transportType == .stdio ? .themeAccent : .purple)
                .font(.body)

            VStack(alignment: .leading, spacing: 2) {
                Text(server.id)
                    .font(.body.monospaced())
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(server.transportType.displayName)
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(server.transportType == .stdio ? Color.themeAccent.opacity(0.8) : Color.purple.opacity(0.8))
                        .cornerRadius(3)

                    // Scope badge
                    ScopeBadge(scope: scope)

                    if let command = server.command {
                        Text(command)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else if let url = server.url {
                        Text(url)
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

// MARK: - Scope Badge

struct ScopeBadge: View {
    let scope: ConfigScope

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: scope.icon)
                .font(.system(size: 8))
            Text(scope.displayName)
                .font(.caption2)
        }
        .foregroundColor(scope.isGlobal ? .orange : .cyan)
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background((scope.isGlobal ? Color.orange : Color.cyan).opacity(0.15))
        .cornerRadius(3)
    }
}

// MARK: - Move Server Sheet

struct MoveServerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let server: ScopedMCPServer
    let availableScopes: [ConfigScope]
    let onMove: (ConfigScope) -> Void

    @State private var selectedScope: ConfigScope?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "arrow.right.arrow.left")
                    .foregroundColor(.accentColor)
                Text("Move \"\(server.config.id)\"")
                    .font(.title3.bold())
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            VStack(alignment: .leading, spacing: 12) {
                Text("Current location:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 6) {
                    ScopeBadge(scope: server.scope)
                    Text(server.scope.mcpPathDescription)
                        .font(.caption.monospaced())
                        .foregroundColor(.secondary)
                }

                Divider()

                Text("Move to:")
                    .font(.subheadline.bold())

                ForEach(availableScopes) { scope in
                    Button {
                        selectedScope = scope
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: selectedScope == scope ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selectedScope == scope ? .accentColor : .secondary)
                            Image(systemName: scope.icon)
                            VStack(alignment: .leading) {
                                Text(scope.displayName)
                                    .font(.body)
                                Text(scope.mcpPathDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(selectedScope == scope ? Color.accentColor.opacity(0.1) : Color.clear)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Spacer()
            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Move") {
                    if let scope = selectedScope {
                        onMove(scope)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedScope == nil)
            }
            .padding()
        }
        .frame(width: 400, height: 400)
    }
}
