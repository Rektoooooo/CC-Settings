import SwiftUI

struct MCPServersView: View {
    @EnvironmentObject var configManager: ConfigurationManager
    @State private var servers: [MCPServerConfig] = []
    @State private var selectedServer: MCPServerConfig?
    @State private var searchText = ""
    @State private var showEditorSheet = false
    @State private var editingServer: MCPServerConfig?
    @State private var isLoading = false
    @State private var showDeleteAlert = false
    @State private var serverToDelete: MCPServerConfig?

    private let configPath: String = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude.json").path
    }()

    private var filteredServers: [MCPServerConfig] {
        if searchText.isEmpty {
            return servers
        }
        let query = searchText.lowercased()
        return servers.filter {
            $0.id.lowercased().contains(query) ||
            ($0.command?.lowercased().contains(query) ?? false) ||
            ($0.url?.lowercased().contains(query) ?? false)
        }
    }

    var body: some View {
        HSplitView {
            // Left column - Server list
            VStack(spacing: 0) {
                // Header
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
                    Text("~/.claude.json")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                .padding(12)

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
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                Divider()

                // Server list
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
                            MCPServerItemRow(server: server)
                                .tag(server)
                                .contextMenu {
                                    Button("Edit") {
                                        editingServer = server
                                        showEditorSheet = true
                                    }
                                    Button("Show in Finder") {
                                        NSWorkspace.shared.selectFile(configPath, inFileViewerRootedAtPath: URL(fileURLWithPath: configPath).deletingLastPathComponent().path)
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

                Divider()

                // Footer
                HStack {
                    Text("\(filteredServers.count) server\(filteredServers.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            }
            .frame(minWidth: 200, idealWidth: 280, maxWidth: 350)

            // Right column - Detail
            if let server = selectedServer,
               let currentServer = servers.first(where: { $0.id == server.id }) {
                MCPServerDetailView(
                    server: currentServer,
                    onEdit: {
                        editingServer = currentServer
                        showEditorSheet = true
                    },
                    onDelete: {
                        serverToDelete = currentServer
                        showDeleteAlert = true
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
                existingServer: editingServer,
                existingNames: Set(servers.map(\.id))
            ) { savedServer in
                saveServer(savedServer, replacing: editingServer?.id)
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
                Text("Are you sure you want to delete \"\(server.id)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Data Operations

    private func loadServers() {
        isLoading = true
        let dict = configManager.loadMCPServers()
        servers = dict.map { key, value in
            var config = value
            config.id = key
            return config
        }.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending }
        isLoading = false

        if let sel = selectedServer, !servers.contains(where: { $0.id == sel.id }) {
            selectedServer = nil
        }
    }

    private func saveServer(_ server: MCPServerConfig, replacing oldName: String?) {
        var dict = configManager.loadMCPServers()

        // If renaming, remove old entry
        if let oldName = oldName, oldName != server.id {
            dict.removeValue(forKey: oldName)
        }

        dict[server.id] = server
        configManager.saveMCPServers(dict)
        loadServers()
        selectedServer = servers.first(where: { $0.id == server.id })
    }

    private func deleteServer(_ server: MCPServerConfig) {
        var dict = configManager.loadMCPServers()
        dict.removeValue(forKey: server.id)
        configManager.saveMCPServers(dict)

        if selectedServer?.id == server.id {
            selectedServer = nil
        }
        loadServers()
    }
}

// MARK: - MCPServerItemRow

struct MCPServerItemRow: View {
    let server: MCPServerConfig

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
