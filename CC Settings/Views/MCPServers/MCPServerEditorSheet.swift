import SwiftUI

struct MCPServerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingServer: MCPServerConfig?
    let existingNames: Set<String>
    let targetScope: ConfigScope
    let availableScopes: [ConfigScope]
    /// Full on-disk JSON of the server being edited (shown read-only for unsupported types).
    var rawJSON: String?
    let onSave: (MCPServerConfig, ConfigScope) -> Void

    @State private var name: String = ""
    @State private var transportType: MCPTransportType = .stdio
    @State private var command: String = ""
    @State private var args: [ArgEntry] = [ArgEntry()]
    @State private var url: String = ""
    @State private var envVars: [EnvEntry] = [EnvEntry()]
    @State private var headerEntries: [EnvEntry] = [EnvEntry()]
    @State private var alwaysLoad: Bool = false
    @State private var nameError: String?
    @State private var selectedScope: ConfigScope

    private var isEditing: Bool { existingServer != nil }
    private var isReadOnly: Bool { existingServer?.hasUnsupportedType ?? false }

    init(
        existingServer: MCPServerConfig? = nil,
        existingNames: Set<String> = [],
        targetScope: ConfigScope = .global,
        availableScopes: [ConfigScope] = [.global],
        rawJSON: String? = nil,
        onSave: @escaping (MCPServerConfig, ConfigScope) -> Void
    ) {
        self.existingServer = existingServer
        self.existingNames = existingNames
        self.targetScope = targetScope
        self.availableScopes = availableScopes
        self.rawJSON = rawJSON
        self.onSave = onSave
        _selectedScope = State(initialValue: targetScope)

        if let server = existingServer {
            _name = State(initialValue: server.id)
            _transportType = State(initialValue: server.transportType)
            _command = State(initialValue: server.command ?? "")
            _args = State(initialValue: {
                let entries = (server.args ?? []).map { ArgEntry(text: $0) }
                return entries.isEmpty ? [ArgEntry()] : entries
            }())
            _url = State(initialValue: server.url ?? "")
            _envVars = State(initialValue: {
                let entries = (server.env ?? [:]).sorted(by: { $0.key < $1.key }).map { EnvEntry(key: $0.key, value: $0.value) }
                return entries.isEmpty ? [EnvEntry()] : entries
            }())
            _headerEntries = State(initialValue: {
                let entries = (server.headers ?? [:]).sorted(by: { $0.key < $1.key }).map { EnvEntry(key: $0.key, value: $0.value) }
                return entries.isEmpty ? [EnvEntry()] : entries
            }())
            _alwaysLoad = State(initialValue: server.alwaysLoad ?? false)
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty, nameError == nil else { return false }
        switch transportType {
        case .stdio:
            return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .sse, .http:
            return !url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var builtServer: MCPServerConfig {
        let trimmedArgs = args
            .map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var envDict: [String: String] = [:]
        for entry in envVars {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                envDict[key] = entry.value
            }
        }

        var headerDict: [String: String] = [:]
        for entry in headerEntries {
            let key = entry.key.trimmingCharacters(in: .whitespacesAndNewlines)
            if !key.isEmpty {
                headerDict[key] = entry.value
            }
        }

        // Keep the file's own `type` (or lack of one) unless the user changed the transport.
        let typeValue: String? = {
            if let existing = existingServer, existing.transportType == transportType {
                return existing.type
            }
            return transportType.rawValue
        }()
        let alwaysLoadValue: Bool? = alwaysLoad ? true : (existingServer?.alwaysLoad == false ? false : nil)

        switch transportType {
        case .stdio:
            return MCPServerConfig(
                id: name,
                type: typeValue,
                command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                args: trimmedArgs.isEmpty ? nil : trimmedArgs,
                env: envDict.isEmpty ? nil : envDict,
                alwaysLoad: alwaysLoadValue
            )
        case .sse, .http:
            return MCPServerConfig(
                id: name,
                type: typeValue,
                env: envDict.isEmpty ? nil : envDict,
                url: url.trimmingCharacters(in: .whitespacesAndNewlines),
                headers: headerDict.isEmpty ? nil : headerDict,
                alwaysLoad: alwaysLoadValue
            )
        }
    }

    private var jsonPreview: String {
        let server = builtServer
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode([server.id: server]),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .foregroundColor(.accentColor)
                    Text(isEditing ? "Edit MCP Server" : "Add MCP Server")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            if isReadOnly {
                readOnlyBody
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                            Text(selectedScope.mcpPathDescription)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    // Name field
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Server Name")
                            .font(.subheadline.bold())
                        TextField("my-server", text: $name)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                            .onChange(of: name) { _, newValue in
                                validateName(newValue)
                            }
                        if let error = nameError {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        Text("A unique identifier for this server. No spaces allowed.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // Transport type picker
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Transport Type")
                            .font(.subheadline.bold())
                        Picker("Transport", selection: $transportType) {
                            ForEach(MCPTransportType.allCases, id: \.self) { type in
                                HStack(spacing: 4) {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    Divider()

                    // Transport-specific fields
                    if transportType == .stdio {
                        stdioFields
                    } else {
                        urlFields
                    }

                    Divider()

                    // Environment variables
                    envVarsFields

                    if transportType != .stdio {
                        Divider()
                        headersFields
                    }

                    Divider()

                    // Tool loading behavior
                    VStack(alignment: .leading, spacing: 4) {
                        Toggle("Always Load Tools", isOn: $alwaysLoad)
                        Text("Skip tool-search deferral — all tools from this server are immediately available to the model. Use sparingly to avoid context bloat.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Divider()

                    // JSON Preview
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "curlybraces")
                                .foregroundColor(.accentColor)
                            Text("JSON Preview")
                                .font(.headline)
                        }

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(jsonPreview)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .padding(10)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxHeight: 160)
                        .glassContainer()
                    }
                }
                .padding()
            }
            }

            Divider()

            // Footer
            HStack {
                if !isEditing {
                    ScopeBadge(scope: selectedScope)
                }
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                if !isReadOnly {
                    Button(isEditing ? "Save Changes" : "Add Server") {
                        onSave(builtServer, selectedScope)
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
                }
            }
            .padding()
        }
        .frame(minWidth: 450, idealWidth: 600, maxWidth: 800,
               minHeight: 450, idealHeight: 650, maxHeight: 850)
    }

    // MARK: - Stdio Fields

    @ViewBuilder
    private var stdioFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Command
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.subheadline.bold())
                TextField("e.g., npx, uvx, node", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.body.monospaced())
            }

            // Arguments
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Arguments")
                        .font(.subheadline.bold())
                    Spacer()
                    Button {
                        args.append(ArgEntry())
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }

                ForEach(Array(args.enumerated()), id: \.element.id) { index, _ in
                    HStack(spacing: 8) {
                        Text("\(index)")
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .trailing)
                        TextField("argument", text: $args[index].text)
                            .textFieldStyle(.roundedBorder)
                            .font(.body.monospaced())
                        if args.count > 1 {
                            Button {
                                args.remove(at: index)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    // MARK: - URL Fields (SSE / HTTP)

    @ViewBuilder
    private var urlFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Server URL")
                .font(.subheadline.bold())
            TextField("https://example.com/mcp", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            Text("The endpoint URL for the MCP server.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Environment Variables

    @ViewBuilder
    private var envVarsFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Environment Variables")
                    .font(.subheadline.bold())
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    envVars.append(EnvEntry())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            ForEach(Array(envVars.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("KEY", text: $envVars[index].key)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .frame(maxWidth: 200)
                    Text("=")
                        .font(.body.monospaced())
                        .foregroundColor(.secondary)
                    TextField("value", text: $envVars[index].value)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                    if envVars.count > 1 {
                        Button {
                            envVars.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Headers (SSE / HTTP)

    @ViewBuilder
    private var headersFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Headers")
                    .font(.subheadline.bold())
                Text("(Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    headerEntries.append(EnvEntry())
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }

            ForEach(Array(headerEntries.enumerated()), id: \.element.id) { index, _ in
                HStack(spacing: 8) {
                    TextField("Header-Name", text: $headerEntries[index].key)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                        .frame(maxWidth: 200)
                    Text(":")
                        .font(.body.monospaced())
                        .foregroundColor(.secondary)
                    TextField("value", text: $headerEntries[index].value)
                        .textFieldStyle(.roundedBorder)
                        .font(.body.monospaced())
                    if headerEntries.count > 1 {
                        Button {
                            headerEntries.remove(at: index)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Read-only (unsupported transport types)

    @ViewBuilder
    private var readOnlyBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("This server uses the \"\(existingServer?.type ?? "")\" transport, which CC Settings can't edit without changing it. It is shown read-only so nothing is lost; edit ~/.claude.json or .mcp.json directly, or use `claude mcp`.")
                    .font(.callout)
                    .foregroundColor(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(rawJSON ?? jsonPreview)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .padding(10)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassContainer()
            }
            .padding()
        }
    }

    // MARK: - Validation

    private func validateName(_ value: String) {
        nameError = nil
        guard !value.isEmpty else { return }

        if value.contains(" ") {
            nameError = "Server name cannot contain spaces."
            return
        }

        // Check for duplicate names (exclude current name when editing)
        let isRename = existingServer?.id != value
        if isRename && existingNames.contains(value) {
            nameError = "A server with this name already exists."
        }
    }
}

// MARK: - Entry Types

struct ArgEntry: Identifiable, Equatable {
    let id = UUID()
    var text: String = ""
}

struct EnvEntry: Identifiable, Equatable {
    let id = UUID()
    var key: String = ""
    var value: String = ""
}
