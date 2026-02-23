import SwiftUI

struct MCPServerEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingServer: MCPServerConfig?
    let existingNames: Set<String>
    let onSave: (MCPServerConfig) -> Void

    @State private var name: String = ""
    @State private var transportType: MCPTransportType = .stdio
    @State private var command: String = ""
    @State private var args: [ArgEntry] = [ArgEntry()]
    @State private var url: String = ""
    @State private var envVars: [EnvEntry] = [EnvEntry()]
    @State private var nameError: String?

    private var isEditing: Bool { existingServer != nil }

    init(existingServer: MCPServerConfig? = nil, existingNames: Set<String> = [], onSave: @escaping (MCPServerConfig) -> Void) {
        self.existingServer = existingServer
        self.existingNames = existingNames
        self.onSave = onSave

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
        }
    }

    private var isValid: Bool {
        guard !name.isEmpty, nameError == nil else { return false }
        switch transportType {
        case .stdio:
            return !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .sse:
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

        switch transportType {
        case .stdio:
            return MCPServerConfig(
                id: name,
                type: "stdio",
                command: command.trimmingCharacters(in: .whitespacesAndNewlines),
                args: trimmedArgs.isEmpty ? nil : trimmedArgs,
                env: envDict.isEmpty ? nil : envDict
            )
        case .sse:
            return MCPServerConfig(
                id: name,
                type: "sse",
                env: envDict.isEmpty ? nil : envDict,
                url: url.trimmingCharacters(in: .whitespacesAndNewlines)
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

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
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
                        sseFields
                    }

                    Divider()

                    // Environment variables
                    envVarsFields

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

            Divider()

            // Footer
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(isEditing ? "Save Changes" : "Add Server") {
                    onSave(builtServer)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
            .padding()
        }
        .frame(width: 600, height: 600)
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

    // MARK: - SSE Fields

    @ViewBuilder
    private var sseFields: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Server URL")
                .font(.subheadline.bold())
            TextField("https://example.com/mcp/sse", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
            Text("The SSE endpoint URL for the MCP server.")
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
